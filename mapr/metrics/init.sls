
include:
  - mapr.repo

{% if (pillar.mapr.version[0] | int) <= 5 %}

mapr-metrics:
  pkg:
    - installed
    - require:
      - cmd: mapr-key

{% else %}

date:
  cmd.run: []

{% endif %}

