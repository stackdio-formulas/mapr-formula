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

# Push them out to the rest of the cluster
push-key:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/cldb.key
    - require:
      - cmd: generate-keys-user

push-serverticket:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/maprserverticket
    - require:
      - cmd: generate-keys-user


# Write out our own keystore / truststore

/opt/mapr/conf/mapr.key:
  file:
    - managed
    - user: root
    - group: root
    - mode: 400
    - contents_pillar: ssl:private_key

/opt/mapr/conf/mapr.crt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 444
    - contents_pillar: ssl:certificate
    - require:
      - file: /opt/mapr/conf/mapr.key

/opt/mapr/conf/ca.crt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 444
    - contents_pillar: ssl:ca_certificate
    - require:
      - file: /opt/mapr/conf/mapr.key

/opt/mapr/conf/chained.crt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 444
    - contents_pillar: ssl:chained_certificate
    - require:
      - file: /opt/mapr/conf/mapr.key

create-pkcs12:
  cmd:
    - run
    - user: root
    - name: openssl pkcs12 -export -in /opt/mapr/conf/mapr.crt -certfile /opt/mapr/conf/chained.crt -inkey /opt/mapr/conf/mapr.key -out /opt/mapr/conf/mapr.pkcs12 -name {{ grains.namespace }} -password pass:mapr123
    - require:
      - file: /opt/mapr/conf/chained.crt
      - file: /opt/mapr/conf/mapr.crt
      - file: /opt/mapr/conf/mapr.key

create-truststore:
  cmd:
    - run
    - user: root
    - name: /usr/java/latest/bin/keytool -importcert -keystore /opt/mapr/conf/ssl_truststore -storepass mapr123 -file /opt/mapr/conf/ca.crt -alias root-ca -noprompt
    - unless: /usr/java/latest/bin/keytool -list -keystore /opt/mapr/conf/ssl_truststore -storepass mapr123 | grep root-ca
    - require:
      - file: /opt/mapr/conf/ca.crt
      - cmd: generate-keys-user

create-keystore:
  cmd:
    - run
    - user: root
    - name: /usr/java/latest/bin/keytool -importkeystore -srckeystore /opt/mapr/conf/mapr.pkcs12 -srcstorepass mapr123 -srcstoretype pkcs12 -destkeystore /opt/mapr/conf/ssl_keystore -deststorepass mapr123
    - unless: /usr/java/latest/bin/keytool -list -keystore /opt/mapr/conf/ssl_keystore -storepass mapr123 | grep {{ grains.namespace }}
    - require:
      - cmd: create-pkcs12
      - cmd: generate-keys-user

chmod-keystore:
  cmd:
    - run
    - user: root
    - name: chmod 400 /opt/mapr/conf/ssl_keystore
    - require:
      - cmd: create-keystore

{% endif %}
