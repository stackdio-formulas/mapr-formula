
{% set oozie_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:mapr.oozie', 'grains.items', 'compound').values()[0]['fqdn'] %}

{% if pillar.mapr.encrypted %}
  {% set oozie_url = 'https://' ~ oozie_host ~ ':11443/oozie' %}
{% else %}
  {% set oozie_url = 'http://' ~ oozie_host ~ ':11000/oozie' %}
{% endif %}

/etc/profile.d/oozie.sh:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - contents:
      - export OOZIE_URL={{ oozie_url }}
      {% if salt['pillar.get']('mapr:security:enable', False) %}
      - export OOZIE_CLIENT_OPTS="-Djava.security.krb5.conf={{ pillar.krb5.conf_file }}"
      {% endif %}
      {% if pillar.mapr.encrypted %}
      - export OOZIE_CLIENT_OPTS="${OOZIE_CLIENT_OPTS} -Djavax.net.ssl.trustStore=/opt/mapr/conf/ssl_truststore"
      {% endif %}
