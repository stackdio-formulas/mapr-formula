{% set mapr_version = pillar.mapr.version %}
{% set mapr_major_version = mapr_version.split('.')[0] | int %}

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
    - name: wget -O - https://package.mapr.com/releases/pub/maprgpg.key | sudo apt-key add -
    - require:
      - file: /etc/apt/sources.list.d/mapr.list

{% elif grains.os_family == 'RedHat' %}

# Set up the MapR yum repositories
maprtech:
  pkgrepo:
    - managed
    - humanname: MapR Technologies
    - baseurl: https://package.mapr.com/releases/v{{ mapr_version }}/redhat/
    - enabled: 1
    - gpgcheck: 1
    - protect: 1

maprecosystem:
  pkgrepo:
    - managed
    - humanname: MapR Technologies
    {% if mapr_major_version >= 6 %}
    - baseurl: https://package.mapr.com/releases/MEP/MEP-{{ mapr_version }}/redhat/
    {% else %}
    - baseurl: https://package.mapr.com/releases/ecosystem-{{ mapr_major_version }}.x/redhat/
    {% endif %}
    - enabled: 1
    - gpgcheck: 1
    - protect: 1

mapr-key:
  cmd:
    - run
    - name: rpm --import https://package.mapr.com/releases/pub/maprgpg.key
    - user: root
    - require:
      - pkgrepo: maprtech
      - pkgrepo: maprecosystem

{% endif %}

