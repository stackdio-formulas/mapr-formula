
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
      {% if pillar.mapr.encrypted %}
      - cmd: generate-keys
      - cmd: generate-keys-user
      {% endif %}
      {% if pillar.mapr.kerberos %}
      - cmd: generate_cldb_keytab
      {% endif %}

{% if pillar.mapr.encrypted or pillar.mapr.kerberos %}
extend:
  finalize:
    cmd:
      - require:
        {% if pillar.mapr.encrypted %}
        - cmd: generate-keys
        - cmd: generate-keys-user
        {% endif %}
        {% if pillar.mapr.kerberos %}
        - cmd: generate_cldb_keytab
        {% endif %}

  {% if pillar.mapr.kerberos %}
  generate_http_keytab:
    cmd:
      - require:
        - cmd: generate_cldb_keytab
  {% endif %}

  {% if pillar.mapr.kerberos and pillar.mapr.encrypted %}
  generate-keys:
    cmd:
      - require:
        - cmd: generate_http_keytab
  {% endif %}
{% endif %}