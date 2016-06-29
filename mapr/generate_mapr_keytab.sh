{%- from 'krb5/settings.sls' import krb5 with context -%}
{%- set realm = krb5.realm -%}
#!/bin/bash
export KRB5_CONFIG={{ pillar.krb5.conf_file }}
(
echo "addprinc -randkey mapr/{{ grains.namespace }}"
echo "ktadd -k /opt/mapr/conf/mapr.keytab mapr/{{ grains.namespace }}"
echo "addprinc -randkey HTTP/{{ grains.fqdn }}"
echo "ktadd -k /opt/mapr/conf/mapr.keytab HTTP/{{ grains.fqdn }}"
echo "addprinc -randkey mapr/{{ grains.fqdn }}"
echo "ktadd -k /opt/mapr/conf/mapr.keytab mapr/{{ grains.fqdn }}"
) | kadmin -p kadmin/admin -kt /root/admin.keytab -r {{ realm }}

chown root:root /opt/mapr/conf/mapr.keytab
chmod 600 /opt/mapr/conf/mapr.keytab
