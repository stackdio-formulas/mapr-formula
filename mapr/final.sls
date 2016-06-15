{% set zk_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.zookeeper', 'grains.items', 'compound').values() | attr('fqdn') | join(',') %}
{% set cldb_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb', 'grains.items', 'compound').values() | attr('fqdn') | join(',') %}
{% set rm_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.yarn.resourcemanager', 'grains.items', 'compound').values() | attr('fqdn') | join(',') %}
{% set hs_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.mapreduce.historyserver', 'grains.items', 'compound').values() | attr('fqdn') | join(',') %}

# This command should be idempotent
finalize:
  cmd:
    - run
    - user: root
    - name: '/opt/mapr/server/configure.sh -N {{ pillar.namespace }} -Z {{ zk_hosts }} -C {{ cldb_hosts }} -RM {{ rm_hosts }} -HS {{ hs_hosts }} -noDB'
