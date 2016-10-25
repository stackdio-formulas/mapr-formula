{% set zk_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.zookeeper', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set cldb_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts + salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb.master', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts | join(',') %}
{% set rm_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.yarn.resourcemanager', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set hs_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.mapreduce.historyserver', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set kdc_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:krb5.kdc', 'grains.items', 'compound').keys()[0] %}
{% set key_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb.master', 'grains.items', 'compound').keys()[0] %}

include:
  - mapr.hadoop-conf
  {% if pillar.mapr.kerberos %}
  - krb5
  {% endif %}

{% if pillar.mapr.kerberos %}

{% if 'mapr.cldb.master' not in grains.roles %}
load-keytab:
  module:
    - run
    - name: cp.get_file
    - path: salt://{{ key_host }}/opt/mapr/conf/mapr-cldb.keytab
    - dest: /opt/mapr/conf/mapr-cldb.keytab
    - user: root
    - group: root
    - mode: 600
    - require_in:
      - cmd: finalize
      - cmd: generate_http_keytab
{% endif %}

# load admin keytab from the master fileserver
load_admin_keytab:
  module:
    - run
    - name: cp.get_file
    - path: salt://{{ kdc_host }}/root/admin.keytab
    - dest: /root/admin.keytab
    - user: root
    - group: root
    - mode: 600
    - require:
      - file: krb5_conf_file
      - pkg: krb5-workstation
      - pkg: krb5-libs

generate_http_keytab:
  cmd:
    - script
    - source: salt://mapr/generate_mapr_keytab.sh
    - template: jinja
    - user: root
    - group: root
    - unless: test -f /opt/mapr/conf/mapr.keytab
    - require:
      - module: load_admin_keytab
    - require_in:
      - cmd: finalize
{% endif %}

{% if pillar.mapr.encrypted and 'mapr.cldb.master' not in grains.roles %}

{% if 'mapr.cldb' in grains.roles or 'mapr.zookeeper' in grains.roles %}
# The key is only needed on CLDB & zookeeper hosts
load-key:
  module:
    - run
    - name: cp.get_file
    - path: salt://{{ key_host }}/opt/mapr/conf/cldb.key
    - dest: /opt/mapr/conf/cldb.key
    - user: root
    - group: root
    - mode: 600
    - require_in:
      - cmd: finalize
{% endif %}

{% if 'mapr.client' not in grains.roles %}
# The keystore & serverticket are needed on all nodes except the client node
load-keystore:
  module:
    - run
    - name: cp.get_file
    - path: salt://{{ key_host }}/opt/mapr/conf/ssl_keystore
    - dest: /opt/mapr/conf/ssl_keystore
    - user: root
    - group: root
    - mode: 400
    - require_in:
      - cmd: finalize

load-serverticket:
  module:
    - run
    - name: cp.get_file
    - path: salt://{{ key_host }}/opt/mapr/conf/maprserverticket
    - dest: /opt/mapr/conf/maprserverticket
    - user: root
    - group: root
    - mode: 600
    - require_in:
      - cmd: finalize
{% endif %}

# Truststore is needed everywhere
load-truststore:
  module:
    - run
    - name: cp.get_file
    - path: salt://{{ key_host }}/opt/mapr/conf/ssl_truststore
    - dest: /opt/mapr/conf/ssl_truststore
    - user: root
    - group: root
    - mode: 444
    - require_in:
      - cmd: finalize

{% endif %}


/opt/mapr/conf/env.sh:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - source: salt://mapr/etc/mapr/conf/env.sh
    - template: jinja


{% set config_command = '/opt/mapr/server/configure.sh -N ' ~ grains.namespace ~ ' -Z ' ~ zk_hosts ~ ' -C ' ~ cldb_hosts ~ ' -RM ' ~ rm_hosts ~ ' -HS ' ~ hs_hosts ~ ' -noDB' %}

{% if pillar.mapr.kerberos %}
  {%- from 'krb5/settings.sls' import krb5 with context -%}
  {% set config_command = config_command ~ ' -K -P "mapr/' ~ grains.namespace ~ '@' ~ krb5.realm ~ '"' %}
{% endif %}

{% if pillar.mapr.encrypted %}
  {% set config_command = config_command ~ ' -secure' %}
{% endif %}

{% if 'mapr.client' in grains.roles %}
  {% set config_command = config_command ~ ' -c' %}
{% endif %}

# of the following 2 commands, only 1 should be run.

# Run this if the user does exist
finalize:
  cmd:
    - run
    - user: root
    - name: {{ config_command }}
    - onlyif: id -u mapr
    - require:
      - file: /opt/mapr/conf/env.sh

# Run this if the user doesn't exist
try-create-user:
  cmd:
    - run
    - user: root
    - name: {{ config_command }} --create-user
    - unless: id -u mapr
    - require:
      - cmd: finalize

add-password:
  cmd:
    - run
    - user: root
    - name: echo '1234' | passwd --stdin mapr
    - onlyif: id -u mapr
    - require:
      - cmd: try-create-user

{#{% if 'mapr.oozie' in grains.roles %}#}
{#login:#}
{#  cmd:#}
{#    - run#}
{#    - name: echo '1234' | maprlogin password#}
{#    - user: mapr#}
{#    - require:#}
{#      - cmd: add-password#}
{##}
{## Give oozie time to spin up#}
{#wait:#}
{#  cmd:#}
{#    - run#}
{#    - name: sleep 30#}
{#    - require:#}
{#      - cmd: login#}
{##}
{#{% if pillar.mapr.encrypted %}#}
{##}
{#stop-oozie:#}
{#  cmd:#}
{#    - run#}
{#    - name: 'maprcli node services -name oozie -action stop -nodes {{ grains.fqdn }}'#}
{#    - user: mapr#}
{#    - onlyif: test -f /opt/mapr/roles/oozie#}
{#    - require:#}
{#      - cmd: login#}
{#      - cmd: wait#}
{##}
{#oozie-secure-war:#}
{#  cmd:#}
{#    - run#}
{#    - name: '/opt/mapr/oozie/oozie-4.2.0/bin/oozie-setup.sh -hadoop 2.7.0 /opt/ -secure'#}
{#    - user: mapr#}
{#    - onlyif: test -f /opt/mapr/roles/oozie#}
{#    - require:#}
{#      - cmd: stop-oozie#}
{##}
{#start-oozie:#}
{#  cmd:#}
{#    - run#}
{#    - name: 'maprcli node services -name oozie -action start -nodes {{ grains.fqdn }}'#}
{#    - user: mapr#}
{#    - onlyif: test -f /opt/mapr/roles/oozie#}
{#    - require:#}
{#      - cmd: oozie-secure-war#}
{#    - require_in:#}
{#      - cmd: logout#}
{##}
{#{% else %}#}
{##}
{#restart-oozie:#}
{#  cmd:#}
{#    - run#}
{#    - name: 'maprcli node services -name oozie -action restart -nodes {{ grains.fqdn }}'#}
{#    - user: mapr#}
{#    - onlyif: test -f /opt/mapr/roles/oozie#}
{#    - require:#}
{#      - cmd: login#}
{#      - cmd: wait#}
{#    - require_in:#}
{#      - cmd: logout#}
{##}
{#{% endif %}#}
{##}
{#logout:#}
{#  cmd:#}
{#    - run#}
{#    - name: maprlogin logout#}
{#    - user: mapr#}
{#    - require:#}
{#      - cmd: login#}
{##}
{#{% endif %}#}

{% if 'mapr.fileserver' in grains.roles %}
/tmp/disks.txt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - contents:
      {% for disk in pillar.mapr.fs_disks %}
      - {{ disk }}
      {% endfor %}

setup-disks:
  cmd:
    - run
    - user: root
    - name: '/opt/mapr/server/disksetup /tmp/disks.txt'
    - unless: cat /opt/mapr/conf/disktab | grep {{ pillar.mapr.fs_disks[0] }}
    - onlyif: true
    - require:
      - file: /tmp/disks.txt
      - cmd: finalize
      - cmd: try-create-user
{% endif %}
