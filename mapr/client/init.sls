
include:
  - mapr.repo

mapr-client:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
