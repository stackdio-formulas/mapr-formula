
include:
  - mapr.repo

mapr-oozie:
  pkg:
    - installed
    - require:
      - cmd: mapr-key

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