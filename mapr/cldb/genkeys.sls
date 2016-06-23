{% set zk_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.zookeeper', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set cldb_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts + salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb.master', 'grains.items', 'compound').values() | map(attribute='fqdn') | list %}
{% set cldb_hosts = cldb_hosts | join(',') %}

{% set genkeys_command = '/opt/mapr/server/configure.sh -secure -genkeys -N ' ~ grains.namespace ~ ' -Z ' ~ zk_hosts ~ ' -C ' ~ cldb_hosts %}

# Generate the secure keys
generate-keys:
  cmd:
    - run
    - user: root
    - name: {{ genkeys_command }}
    - onlyif: id -u mapr

# Run this if the user doesn't exist
generate-keys-user:
  cmd:
    - run
    - user: root
    - name: {{ genkeys_command }} --create-user
    - unless: id -u mapr
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
