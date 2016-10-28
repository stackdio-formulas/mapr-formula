{% set zk_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.zookeeper', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set cldb_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts + salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb.master', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts | join(',') %}
{% set rm_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.yarn.resourcemanager', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set hs_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.mapreduce.historyserver', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set kdc_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:krb5.kdc', 'grains.items', 'compound').keys()[0] %}
{% set key_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb.master', 'grains.items', 'compound').keys()[0] %}

{% if pillar.mapr.kerberos %}
include:
  - krb5

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
      - cmd: configure
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
      - cmd: configure
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
      - cmd: configure
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
      - cmd: configure

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
      - cmd: configure
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
      - cmd: configure

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
configure:
  cmd:
    - run
    - user: root
    - name: {{ config_command }} --create-user
    - unless: id -u mapr
    - require:
      - file: /opt/mapr/conf/env.sh

# Run this if the user doesn't exist
configure-no-user:
  cmd:
    - run
    - user: root
    - name: {{ config_command }}
    - onlyif: id -u mapr
    - require:
      - cmd: configure

# Then go again - run the same command, services just don't start the first time for some reason
start-services:
  cmd:
    - run
    - user: root
    - name: {{ config_command }}
    - require:
      - cmd: configure-no-user

{% if 'mapr.client' in grains.roles %}

# 2147483632 is the uid / gid mapr uses to create users for some reason?

mapr-group:
  group:
    - present
    - name: mapr
    - system: true
    - gid: 2147483632

mapr-user:
  user:
    - present
    - name: mapr
    - system: true
    - uid: 2147483632
    - gid: mapr
    - require:
      - group: mapr-group
    - require_in:
      - cmd: add-password

{% else %}

{# This only works because hadoop was installed in an earlier-run SLS. #}
{# This gets run when the SLS was compiled, so it would not work in the SLS that installs hadoop. #}
{% set hadoop_version = salt['cmd.run']('cat /opt/mapr/hadoop/hadoopversion') %}

# Needs to happen BEFORE we run configure / start services
hadoop-conf:
  file:
    - recurse
    - name: /opt/mapr/hadoop/hadoop-{{ hadoop_version }}/etc/hadoop
    - source: salt://mapr/etc/hadoop/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - require_in:
      - cmd: configure

# Needs to happen AFTER we run configure / start services
yarn-site:
  file:
    - blockreplace
    - name: /opt/mapr/hadoop/hadoop-{{ hadoop_version }}/etc/hadoop/yarn-site.xml
    - marker_start: '<!-- :::CAUTION::: DO NOT EDIT ANYTHING ON OR ABOVE THIS LINE -->'
    - marker_end: '</configuration>'
    - source: salt://mapr/etc/hadoop/yarn-site.xml
    - template: jinja
    - require:
      - cmd: start-services

{% endif %}

add-password:
  cmd:
    - run
    - user: root
    - name: echo '1234' | passwd --stdin mapr
    - require:
      - cmd: start-services

login:
  cmd:
    - run
    - name: echo '1234' | maprlogin password
    - user: mapr
    - require:
      - cmd: add-password

# Give things time to spin up
wait:
  cmd:
    - run
    - name: sleep 30
    - require:
      - cmd: login


{% if 'mapr.yarn.resourcemanager' in grains.roles %}

# Restart the RM to make sure it picks up the extra config in yarn-site
restart-rm:
  cmd:
    - run
    - name: 'maprcli node services -name resourcemanager -action restart -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - cmd: login
      - cmd: wait
      {% if 'mapr.client' not in grains.roles %}
      - file: yarn-site
      {% endif %}
    - require_in:
      - cmd: logout

{% endif %}


{% if 'mapr.mapreduce.historyserver' in grains.roles %}

# Restart the HS to make sure it picks up the extra config in yarn-site
restart-hs:
  cmd:
    - run
    - name: 'maprcli node services -name historyserver -action restart -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - cmd: login
      - cmd: wait
      {% if 'mapr.client' not in grains.roles %}
      - file: yarn-site
      {% endif %}
    - require_in:
      - cmd: logout

{% endif %}


{% if 'mapr.yarn.nodemanager' in grains.roles %}

# Wait again to make sure the resourcemanager gets a chance to restart first
wait-nm:
  cmd:
    - run
    - name: sleep 30
    - require:
      - cmd: login

# Restart the NM to make sure it picks up the extra config in yarn-site
restart-nm:
  cmd:
    - run
    - name: 'maprcli node services -name nodemanager -action restart -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - cmd: login
      - cmd: wait
      - cmd: wait-nm
      {% if 'mapr.client' not in grains.roles %}
      - file: yarn-site
      {% endif %}
    - require_in:
      - cmd: logout

{% endif %}


{% if 'mapr.oozie' in grains.roles and pillar.mapr.encrypted %}

{# This only works because hadoop was installed in an earlier-run SLS. #}
{# This gets run when the SLS was compiled, so it would not work in the SLS that installs hadoop. #}
{% set hadoop_version = salt['cmd.run']('cat /opt/mapr/hadoop/hadoopversion') %}
{% set oozie_version = salt['cmd.run']('cat /opt/mapr/oozie/oozieversion') %}

stop-oozie:
  cmd:
    - run
    - name: 'maprcli node services -name oozie -action stop -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - cmd: login
      - cmd: wait

oozie-secure-war:
  cmd:
    - run
    - name: '/opt/mapr/oozie/oozie-{{ oozie_version }}/bin/oozie-setup.sh -hadoop {{ hadoop_version }} /opt/mapr/hadoop/hadoop-{{ hadoop_version }} -secure'
    - user: root
    - require:
      - cmd: stop-oozie

start-oozie:
  cmd:
    - run
    - name: 'maprcli node services -name oozie -action start -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      {% if 'mapr.client' not in grains.roles %}
      - file: yarn-site
      {% endif %}
      - cmd: oozie-secure-war
    - require_in:
      - cmd: logout

{% endif %}

logout:
  cmd:
    - run
    - name: maprlogin logout
    - user: mapr
    - require:
      - cmd: login

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
    - require:
      - file: /tmp/disks.txt
      - cmd: configure
      - cmd: start-services
{% endif %}
