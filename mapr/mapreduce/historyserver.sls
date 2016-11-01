
include:
  - mapr.repo

mapr-historyserver:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
