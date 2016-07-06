{%- from 'krb5/settings.sls' import krb5 with context -%}
{%- set realm = krb5.realm -%}
#!/bin/bash

export KRB5_CONFIG={{ pillar.krb5.conf_file }}

(
echo "addprinc -randkey mapr/{{ grains.namespace }}"
echo "ktadd -k /opt/mapr/conf/mapr-cldb.keytab mapr/{{ grains.namespace }}"
) | kadmin -p kadmin/admin -kt /root/admin.keytab -r {{ realm }}

chown root:root /opt/mapr/conf/mapr-cldb.keytab
chmod 600 /opt/mapr/conf/mapr-cldb.keytab
