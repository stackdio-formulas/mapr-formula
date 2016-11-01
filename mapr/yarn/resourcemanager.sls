
include:
  - mapr.repo

mapr-resourcemanager:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
