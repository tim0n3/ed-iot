version: 1
reporting:
    hook:
        type: webhook
        endpoint: https://console.cloud.google.com/artifacts/python/energydrive-analytics/europe-west3/ed-lodout?project=energydrive-analytics
early-commands:
    - ping -c1 8.8.8.8
locale: en_US
keyboard:
    layout: gb
    variant: dvorak
//network:
//    network:
//        version: 2
//        ethernets:
//            enp0s25:
//               dhcp4: yes
//            enp3s0: {}
//            enp4s0: {}
//        bonds:
//            bond0:
//                dhcp4: yes
//                interfaces:
//                    - enp3s0
//                    - enp4s0
//                parameters:
//                    mode: active-backup
//                    primary: enp3s0
storage:
    layout:
        name: lvm
storage:
    layout:
        name: attached
        match: sda1
        config:
        - type: disk
          id: sda1
        - type: partition
identity:
    hostname: [Device-id]
    username: pi
    password: raspberry
ssh:
    install-server: yes
    authorized-keys:
      - $key
    allow-pw: no
packages:
    - libreoffice
user-data:
    disable_root: false
late-commands:
    - sed -ie 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=30/' /target/etc/default/grub
error-commands:
    - tar c /var/log/installer | nc 192.168.0.1 1000
apt:
  sources:
    ddebs.list:
      source: |
        deb http://ddebs.ubuntu.com $RELEASE main restricted universe multiverse
        deb http://ddebs.ubuntu.com $RELEASE-updates main restricted universe multiverse
        deb http://ddebs.ubuntu.com $RELEASE-security main restricted universe multiverse
        deb http://ddebs.ubuntu.com $RELEASE-proposed main restricted universe multiverse
        deb https:/
