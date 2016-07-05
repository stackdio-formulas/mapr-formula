
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

restart-oozie:
  cmd:
    - run
    - name: 'maprcli node services -name oozie -action restart -nodes {{ grains.fqdn }}'
    - user: mapr
    - require:
      - file: yarn-site
      - cmd: login

logout:
  cmd:
    - run
    - name: maprlogin logout
    - user: mapr
    - require:
      - cmd: login
      - cmd: restart-oozie
