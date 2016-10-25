
include:
  - mapr.repo
  - mapr.cldb.genkeys

mapr-cldb:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    {% if pillar.mapr.encrypted or pillar.mapr.kerberos %}
    - require_in:
      {% if pillar.mapr.encrypted %}
      - cmd: generate-keys
      - cmd: generate-keys-user
      {% endif %}
      {% if pillar.mapr.kerberos %}
      - cmd: generate_cldb_keytab
      {% endif %}
    {% endif %}
