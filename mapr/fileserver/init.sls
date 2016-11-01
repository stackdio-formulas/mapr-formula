
include:
  - mapr.repo

mapr-fileserver:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
