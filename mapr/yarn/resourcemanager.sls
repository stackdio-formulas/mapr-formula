
include:
  - mapr.repo

mapr-resourcemanager:
  pkg:
    - installed
    - require:
      - cmd: mapr-key

{#rm-login:#}
{#  cmd:#}
{#    - run#}
{#    - name: echo '1234' | maprlogin password#}
{#    - user: mapr#}
{#    - require:#}
{#      - cmd: add-password#}
{##}
{## Give the RM time to spin up#}
{#rm-wait:#}
{#  cmd:#}
{#    - run#}
{#    - name: sleep 30#}
{#    - require:#}
{#      - cmd: rm-login#}
{##}
{#restart-resourcemanager:#}
{#  cmd:#}
{#    - run#}
{#    - name: 'maprcli node services -name resourcemanager -action restart -nodes {{ grains.fqdn }}'#}
{#    - user: mapr#}
{#    - require:#}
{#      - file: yarn-site#}
{#      - cmd: rm-login#}
{#      - cmd: rm-wait#}
{##}
{#rm-logout:#}
{#  cmd:#}
{#    - run#}
{#    - name: maprlogin logout#}
{#    - user: mapr#}
{#    - require:#}
{#      - cmd: rm-login#}
{#      - cmd: restart-resourcemanager#}
