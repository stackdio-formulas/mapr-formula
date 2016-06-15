
include:
  - mapr.repo
  - mapr.final

mapr-metrics:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - cmd: finalize
