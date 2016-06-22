
include:
  - mapr.repo
  {% if pillar.mapr.encrypted %}
  - mapr.cldb.genkeys
  {% endif %}
  - mapr.final

mapr-cldb:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - cmd: finalize
      {% if pillar.mapr.encrypted %}
      - cmd: generate-keys
      {% endif %}

{% if pillar.mapr.encrypted %}
extend:
  finalize:
    cmd:
      - require:
        - cmd: generate-keys
{% endif %}