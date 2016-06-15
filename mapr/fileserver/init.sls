
include:
  - mapr.repo
  - mapr.final

mapr-fileserver:
  pkg:
    - installed
    - require:
      - cmd: mapr-key
    - require_in:
      - cmd: finalize

/tmp/disks.txt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - contents:
      {% for disk in pillar.mapr.fs_disks %}
      - {{ disk }}
      {% endfor %}

# This only needs to happen here, since it's a fileserver thing
setup-disks:
  cmd:
    - run
    - user: root
    - name: '/opt/mapr/server/disksetup /tmp/disks.txt'
    - unless: cat /opt/mapr/conf/disktab | grep {{ pillar.mapr.fs_disks[0] }}
    - require:
      - file: /tmp/disks.txt
      - cmd: finalize
