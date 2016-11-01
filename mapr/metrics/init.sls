
include:
  - mapr.repo

mapr-metrics:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
