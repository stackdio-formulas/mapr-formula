
include:
  - mapr.repo
  - mapr.final

mapr-webserver:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - cmd: finalize
