
include:
  - mapr.repo
  - mapr.hadoop-conf
  - mapr.final

mapr-client:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - file: hadoop-conf

extend:
  finalize:
    cmd:
      - require:
        - file: hadoop-conf
