
include:
  - mapr.repo
  - mapr.final

mapr-hue:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - cmd: finalize
      - file: /opt/mapr/conf/env.sh
