{% set zk_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.zookeeper', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set cldb_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb', 'grains.items', 'compound').values() | map(attribute='fqdn') %}
{% set cldb_hosts = cldb_hosts + salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb.master', 'grains.items', 'compound').values() | map(attribute='fqdn') %}
{% set cldb_hosts = cldb_hosts | join(',') %}

# Generate the secure keys
generate-keys:
  cmd:
    - run
    - user: root
    - name: /opt/mapr/server/configure.sh -secure -genkeys -N {{ grains.namespace }} -Z {{ zk_hosts }} -C {{ cldb_hosts }}

# Push them out to the rest of the cluster
push-key:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/cldb.key
    - require:
      - cmd: generate-keys

push-keystore:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/ssl_keystore
    - require:
      - cmd: generate-keys

push-truststore:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/ssl_truststore
    - require:
      - cmd: generate-keys

push-serverticket:
  module:
    - run
    - name: cp.push
    - path: /opt/mapr/conf/maprserverticket
    - require:
      - cmd: generate-keys
