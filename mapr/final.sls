{% set zk_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.zookeeper', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set cldb_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.cldb', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set rm_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.yarn.resourcemanager', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}
{% set hs_hosts = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.mapreduce.historyserver', 'grains.items', 'compound').values() | map(attribute='fqdn') | join(',') %}

{% set config_command = '/opt/mapr/server/configure.sh -N ' ~ grains.namespace ~ ' -Z ' ~ zk_hosts ~ ' -C ' ~ cldb_hosts ~ ' -RM ' ~ rm_hosts ~ ' -HS ' ~ hs_hosts ~ ' -noDB' %}

# of the following 2 commands, only 1 should be run.

{% set fixed_roles = ['fileserver', 'cldb', 'webserver'] %}

# Run this if the user does exist
finalize:
  cmd:
    - run
    - user: root
    - name: {{ config_command }}
    - onlyif: id -u mapr{% for role in fixed_roles %}{% if 'mapr.' ~ role in grains.roles %} && test -f /opt/mapr/roles/{{ role }}{% endif %}{% endfor %}

# Run this if the user doesn't exist
try-create-user:
  cmd:
    - run
    - user: root
    - name: {{ config_command }} --create-user
    - unless: id -u mapr
    - onlyif: true{% for role in fixed_roles %}{% if 'mapr.' ~ role in grains.roles %} && test -f /opt/mapr/roles/{{ role }}{% endif %}{% endfor %}
    - require:
      - cmd: finalize
