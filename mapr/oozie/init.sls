
include:
  - mapr.repo
  - mapr.hadoop-conf
  - mapr.final

mapr-oozie:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - file: hadoop-conf
      - file: /opt/mapr/conf/env.sh

extend:
  finalize:
    cmd:
      - require:
        - file: hadoop-conf
  yarn-site:
    file:
      - require:
        - cmd: try-create-user

  {% if pillar.mapr.encrypted %}
  start-oozie:
    cmd:
      - require:
        - file: yarn-site
  {% else %}
  restart-oozie:
    cmd:
      - require:
        - file: yarn-site
  {% endif %}