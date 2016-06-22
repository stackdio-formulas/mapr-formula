
include:
  - mapr.repo
  - mapr.cldb.genkeys
  - mapr.final

mapr-cldb:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - cmd: finalize
      - cmd: generate-keys

extend:
  finalize:
    cmd:
      - require:
        - cmd: generate-keys
