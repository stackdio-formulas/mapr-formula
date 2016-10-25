
include:
  - mapr.repo

mapr-oozie:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
