
include:
  - mapr.repo

mapr-nodemanager:
  pkg:
    - installed
    - require:
      - cmd: mapr-key

/opt/tmp:
  file:
    - directory
    - user: root
    - group: root
    - mode: 777

{#nm-login:#}
{#  cmd:#}
{#    - run#}
{#    - name: echo '1234' | maprlogin password#}
{#    - user: mapr#}
{#    - require:#}
{#      - cmd: add-password#}
{##}
{## Give the RM time to spin up#}
{#nm-wait:#}
{#  cmd:#}
{#    - run#}
{#    - name: sleep 30#}
{#    - require:#}
{#      - cmd: nm-login#}
{##}
{#restart-nodemanager:#}
{#  cmd:#}
{#    - run#}
{#    - name: 'maprcli node services -name nodemanager -action restart -nodes {{ grains.fqdn }}'#}
{#    - user: mapr#}
{#    - require:#}
{#      - file: yarn-site#}
{#      - cmd: nm-login#}
{#      - cmd: nm-wait#}
{##}
{#nm-logout:#}
{#  cmd:#}
{#    - run#}
{#    - name: maprlogin logout#}
{#    - user: mapr#}
{#    - require:#}
{#      - cmd: nm-login#}
{#      - cmd: restart-nodemanager#}
