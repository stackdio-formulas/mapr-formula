
hadoop-conf:
  file:
    - recurse
    - name: /opt/mapr/hadoop/hadoop-2.7.0/etc/hadoop
    - source: salt://mapr/etc/hadoop/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644

yarn-site:
  file:
    - blockreplace
    - name: /opt/mapr/hadoop/hadoop-2.7.0/etc/hadoop/yarn-site.xml
    - marker_start: '<!-- :::CAUTION::: DO NOT EDIT ANYTHING ON OR ABOVE THIS LINE -->'
    - marker_end: '</configuration>'
    - source: salt://mapr/etc/hadoop/yarn-site.xml
    - template: jinja
