
include:
  - mapr.repo

mapr-hue:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
