
include:
  - mapr.repo

mapr-spark-historyserver:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
