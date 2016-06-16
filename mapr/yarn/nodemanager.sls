
include:
  - mapr.repo
  - mapr.hadoop-conf
  - mapr.final

mapr-nodemanager:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - file: hadoop-conf

/opt/tmp:
  file:
    - directory
    - user: root
    - group: root
    - mode: 777

extend:
  finalize:
    cmd:
      - require:
        - file: hadoop-conf
        - file: /opt/tmp
