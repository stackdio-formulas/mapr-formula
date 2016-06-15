
include:
  - mapr.repo
  - mapr.final

mapr-fileserver:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - cmd: finalize
