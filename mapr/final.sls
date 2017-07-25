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

{% if pillar.mapr.encrypted %}

# Some things are only needed if we're not the cldb master
{% if 'mapr.cldb.master' not in grains.roles %}

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
# The serverticket is needed on all nodes except the client node
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

{% endif %}

{% if 'mapr.client' not in grains.roles %}
# The keystore is needed on all nodes except the client node
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

/opt/mapr/conf/chained.crt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 444
    - contents_pillar: ssl:chained_certificate

create-pkcs12:
  cmd:
    - run
    - user: root
    - name: openssl pkcs12 -export -in /opt/mapr/conf/mapr.crt -certfile /opt/mapr/conf/chained.crt -inkey /opt/mapr/conf/mapr.key -out /opt/mapr/conf/mapr.pkcs12 -name {{ grains.namespace }} -password pass:mapr123
    - require:
      - file: /opt/mapr/conf/chained.crt
      - file: /opt/mapr/conf/mapr.crt
      - file: /opt/mapr/conf/mapr.key

create-keystore:
  cmd:
    - run
    - user: root
    - name: /usr/java/latest/bin/keytool -importkeystore -srckeystore /opt/mapr/conf/mapr.pkcs12 -srcstorepass mapr123 -srcstoretype pkcs12 -destkeystore /opt/mapr/conf/ssl_keystore -deststorepass mapr123
    - unless: /usr/java/latest/bin/keytool -list -keystore /opt/mapr/conf/ssl_keystore -storepass mapr123 | grep {{ grains.namespace }}
    - require:
      - cmd: create-pkcs12

chmod-keystore:
  cmd:
    - run
    - user: root
    - name: chmod 400 /opt/mapr/conf/ssl_keystore
    - require:
      - cmd: create-keystore
    - require_in:
      - cmd: configure
{% endif %}

# Truststore is needed everywhere
/opt/mapr/conf/ca.crt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 444
    - contents_pillar: ssl:ca_certificate

create-truststore:
  cmd:
    - run
    - user: root
    - name: /usr/java/latest/bin/keytool -importcert -keystore /opt/mapr/conf/ssl_truststore -storepass mapr123 -file /opt/mapr/conf/ca.crt -alias root-ca -noprompt
    - unless: /usr/java/latest/bin/keytool -list -keystore /opt/mapr/conf/ssl_truststore -storepass mapr123 | grep root-ca
    - require:
      - file: /opt/mapr/conf/ca.crt
    - require_in:
      - cmd: configure

{% endif %}


{% if 'mapr.oozie' in grains.roles %}

{% set oozie_version = salt['cmd.run']('cat /opt/mapr/oozie/oozieversion') %}

# Add the warden conf file for oozie

/opt/mapr/conf/conf.d/warden.oozie.conf:
  file:
    - copy
    - source: /opt/mapr/oozie/oozie-{{ oozie_version }}/conf/warden.oozie.conf
    - user: mapr
    - group: mapr
    - mode: 644
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

{% if 'mapr.cldb.master' not in grains.roles and 'mapr.cldb' not in grains.roles %}

# If this node doesn't have a cldb on it, we need to wait for the cldb to come up
wait-for-cldb:
  cmd:
    - run
    - name: sleep 60
    - require_in:
      - cmd: configure

{% endif %}

{% if 'mapr.oozie' in grains.roles %}

{% set oozie_version = salt['cmd.run']('cat /opt/mapr/oozie/oozieversion') %}

# Download extjs
/opt/mapr/oozie/oozie-{{ oozie_version }}/libext/ext-2.2.zip:
  file:
    - managed
    - user: mapr
    - group: mapr
    - mode: 644
    - source: http://archive.cloudera.com/gplextras/misc/ext-2.2.zip
    - skip_verify: true

# Fix the extjs url
/opt/mapr/oozie/oozie-{{ oozie_version }}/bin/oozie-setup.sh:
  file:
    - replace
    - pattern: http://dev.sencha.com/deploy/ext-2.2.zip
    - repl: http://archive.cloudera.com/gplextras/misc/ext-2.2.zip
    - require:
      - file: /opt/mapr/oozie/oozie-{{ oozie_version }}/libext/ext-2.2.zip
    - require_in:
      - cmd: configure

{% endif %}

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
      - cmd: configure-no-user
    - require_in:
      - cmd: start-services
{% endif %}

# Then go again - run the same command, but after disksetup takes place
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

{# I'm hard-coding this for now... the client doesn't have the hadoopversion file used below on non-clients #}
{% set hadoop_version = '2.7.0' %}

{% else %}

{# This only works because hadoop was installed in an earlier-run SLS. #}
{# This gets run when the SLS was compiled, so it would not work in the SLS that installs hadoop. #}
{% set hadoop_version = salt['cmd.run']('cat /opt/mapr/hadoop/hadoopversion') %}

{% endif %}

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

add-password:
  cmd:
    - run
    - user: root
    - name: echo '1234' | passwd --stdin mapr
    - require:
      - cmd: start-services

# Give things time to spin up
wait:
  cmd:
    - run
    - name: sleep 30
    - require:
      - cmd: start-services

# Wait for things to spin up before logging in
login:
  cmd:
    - run
    - name: echo '1234' | maprlogin password
    - user: mapr
    - require:
      - cmd: add-password
      - cmd: wait

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
      - file: yarn-site
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
      - file: yarn-site
    - require_in:
      - cmd: logout

{% endif %}


{% if 'mapr.spark.historyserver' in grains.roles %}

create-spark-dir:
  cmd:
    - run
    - name: 'hadoop fs -mkdir -p /apps/spark && hadoop fs -chmod 1777 /apps/spark'
    - user: mapr
    - require:
      - cmd: login
      - cmd: wait
    - require_in:
      - cmd: logout

# Restart the spark HS to make sure it can see the new directory
restart-shs:
  cmd:
    - run
    - name: 'maprcli node services -name spark-historyserver -action restart -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - cmd: login
      - cmd: wait
      - cmd: create-spark-dir
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
      - file: yarn-site
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
      - file: yarn-site
      - cmd: stop-oozie

start-oozie:
  cmd:
    - run
    - name: 'maprcli node services -name oozie -action start -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - file: yarn-site
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
