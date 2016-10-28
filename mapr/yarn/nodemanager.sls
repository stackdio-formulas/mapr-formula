
include:
  - mapr.repo

mapr-nodemanager:
  pkg:
    - installed
    - require:
      - cmd: mapr-key

/opt/tmp:
  file:
    - directory
    - user: root
    - group: root
    - mode: 777
