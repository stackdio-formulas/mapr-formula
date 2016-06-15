{% if grains.os_family == 'Debian' %}

# TODO Change this later
/etc/apt/sources.list.d/mapr.list:
  file:
    - managed
    - source: salt://mapr/etc/apt/sources.list.d/mapr.list
    - user: root
    - group: root
    - mode: 644
    - template: jinja

mapr-key:
  cmd:
    - run
    - name: TODO
    - require:
      - file: /etc/apt/sources.list.d/mapr.list

{% if grains.os_family == 'RedHat' %}

# Set up the MapR yum repositories
maprtech:
  pkgrepo:
    - managed
    - humanname: MapR Technologies
    - baseurl: http://package.mapr.com/releases/v{{ pillar.mapr.version }}/redhat/
    - gpgkey: http://package.mapr.com/releases/pub/maprgpg.key
    - enabled: 1
    - gpgcheck: 1
    - protect: 1

maprecosystem:
  pkgrepo:
    - managed
    - humanname: MapR Technologies
    - baseurl: http://package.mapr.com/releases/ecosystem-5.x/redhat/
    - gpgkey: http://package.mapr.com/releases/pub/maprgpg.key
    - enabled: 1
    - gpgcheck: 1
    - protect: 1

mapr-key:
  cmd:
    - run
    - name: rpm --import http://package.mapr.com/releases/pub/maprgpg.key
    - user: root
    - require:
      - pkgrepo: maprtech
      - pkgrepo: maprecosystem

{% endif %}

