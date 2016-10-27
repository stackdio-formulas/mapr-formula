{% set zk_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.zookeeper', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set cldb_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts + salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb.master', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts | join(',') %}

{% set genkeys_command = '/opt/mapr/server/configure.sh -secure -genkeys -N ' ~ grains.namespace ~ ' -Z ' ~ zk_hosts ~ ' -C ' ~ cldb_hosts %}

{% if pillar.mapr.kerberos %}

{% set kdc_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:krb5.kdc', 'grains.items', 'compound').keys()[0] %}

{% from 'krb5/settings.sls' import krb5 with context %}
{% set genkeys_command = genkeys_command ~ ' -K -P "mapr/' ~ grains.namespace ~ '@' ~ krb5.realm ~ '"' %}

include:
  - krb5

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

generate_cldb_keytab:
  cmd:
    - script
    - source: salt://mapr/cldb/generate_cldb_keytab.sh
    - template: jinja
    - user: root
    - group: root
    - unless: test -f /opt/mapr/conf/mapr-cldb.keytab
    - require:
      - module: load_admin_keytab

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

push-keytab:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/mapr-cldb.keytab
    - require:
      - cmd: generate_cldb_keytab

{% endif %}

{% if pillar.mapr.encrypted %}

# Generate the secure keys
generate-keys:
  cmd:
    - run
    - user: root
    - name: {{ genkeys_command }}
    - unless: test -f /opt/mapr/conf/cldb.key
    - onlyif: id -u mapr
    {% if pillar.mapr.kerberos %}
    - require:
      - cmd: generate_cldb_keytab
      - cmd: generate_http_keytab
    {% endif %}

# Run this if the user doesn't exist
generate-keys-user:
  cmd:
    - run
    - user: root
    - name: {{ genkeys_command }} --create-user
    - unless: id -u mapr || test -f /opt/mapr/conf/cldb.key
    - require:
      - cmd: generate-keys

{% for alias, cert in pillar.mapr.extra_certs.items() %}
{# Add any extra certs to the truststore before we push it out #}

write-{{ alias }}:
  file:
    - managed
    - name: /tmp/{{ alias }}.pem
    - user: root
    - group: root
    - mode: 400
    - contents: {{ cert }}

remove-key-{{ alias }}:
  cmd:
    - run
    - user: root
    - name: '/usr/java/latest/bin/keytool -delete -keystore /opt/mapr/conf/ssl_truststore -storepass mapr123 -alias {{ alias }}'
    - onlyif: '/usr/java/latest/bin/keytool -list -keystore /opt/mapr/conf/ssl_truststore -storepass mapr123 | grep {{ alias }}'

add-{{ alias }}:
  cmd:
    - run
    - user: root
    - name: '/usr/java/latest/bin/keytool -importcert -keystore /opt/mapr/conf/ssl_truststore -storepass mapr123 -file /tmp/{{ alias }}.pem -alias {{ alias }} -noprompt'
    - require:
      - file: write-{{ alias }}
      - cmd: remove-key-{{ alias }}
    - require_in:
      - module: push-truststore

# must be a cmd.run so as not to cause a name collision with write
delete-{{ alias }}:
  cmd:
    - run
    - name: rm -f /tmp/{{ alias }}.pem
    - require:
      - cmd: add-{{ alias }}

{% endfor %}

# Push them out to the rest of the cluster
push-key:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/cldb.key
    - require:
      - cmd: generate-keys-user

push-keystore:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/ssl_keystore
    - require:
      - cmd: generate-keys-user

push-truststore:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/ssl_truststore
    - require:
      - cmd: generate-keys-user

push-serverticket:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/maprserverticket
    - require:
      - cmd: generate-keys-user

{% endif %}
