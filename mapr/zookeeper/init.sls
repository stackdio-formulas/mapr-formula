
include:
  - mapr.repo

mapr-zookeeper:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
