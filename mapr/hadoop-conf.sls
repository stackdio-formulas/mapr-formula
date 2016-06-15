
hadoop-conf:
  file:
    - recurse
    - name: /opt/mapr/hadoop/hadoop-2.7.0/etc/hadoop
    - source: salt://mapr/etc/hadoop/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
