
include:
  - mapr.repo

mapr-cldb:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
