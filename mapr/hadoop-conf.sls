{% set needed_roles = ['mapr.client', 'mapr.mapreduce.historyserver', 'mapr.oozie', 'mapr.yarn.resourcemanager', 'mapr.yarn.nodemanager'] %}

{% set should_write_config = false %}

{% for role in needed_roles %}
  {% if role in grains.roles %}
    {% set should_write_config = true %}
  {% endif %}
{% endfor %}


{% if should_write_config %}

hadoop-conf:
  file:
    - recurse
    - name: /opt/mapr/hadoop/hadoop-2.7.0/etc/hadoop
    - source: salt://mapr/etc/hadoop/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - require_in:
      - cmd: finalize

yarn-site:
  file:
    - blockreplace
    - name: /opt/mapr/hadoop/hadoop-2.7.0/etc/hadoop/yarn-site.xml
    - marker_start: '<!-- :::CAUTION::: DO NOT EDIT ANYTHING ON OR ABOVE THIS LINE -->'
    - marker_end: '</configuration>'
    - source: salt://mapr/etc/hadoop/yarn-site.xml
    - template: jinja
    - require:
      - cmd: try-create-user

{% endif %}
