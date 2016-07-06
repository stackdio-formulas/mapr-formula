
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

login:
  cmd:
    - run
    - name: echo '1234' | maprlogin password
    - user: mapr
    - require:
      - cmd: add-password


# Give oozie time to spin up
wait:
  cmd:
    - run
    - name: sleep 30
    - require:
      - cmd: login

{% if pillar.mapr.encrypted %}

stop-oozie:
  cmd:
    - run
    - name: 'maprcli node services -name oozie -action stop -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - cmd: login
      - cmd: wait

oozie-secure-war:
  cmd:
    - run
    - name: '/opt/mapr/oozie/oozie-4.2.0/bin/oozie-setup.sh -hadoop 2.7.0 /opt/ -secure'
    - user: mapr
    - require:
      - cmd: stop-oozie

start-oozie:
  cmd:
    - run
    - name: 'maprcli node services -name oozie -action start -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - file: yarn-site
      - cmd: oozie-secure-war
    - require_in:
      - cmd: logout

{% else %}

restart-oozie:
  cmd:
    - run
    - name: 'maprcli node services -name oozie -action restart -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - file: yarn-site
      - cmd: login
      - cmd: wait
    - require_in:
      - cmd: logout

{% endif %}

logout:
  cmd:
    - run
    - name: maprlogin logout
    - user: mapr
    - require:
      - cmd: login
