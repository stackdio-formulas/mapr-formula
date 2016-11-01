
include:
  - mapr.repo

mapr-webserver:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
