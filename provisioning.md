# Provisioning
```
one@bustermachine:~$ screenfetch
                          ./+o+-       one@bustermachine
                  yyyyy- -yyyyyy+      OS: Ubuntu 18.04 bionic
               ://+//////-yyyyyyo      Kernel: x86_64 Linux 4.15.0-91-generic
           .++ .:/++++++/-.+sss/`      Uptime: 35m
         .:++o:  /++++++++/:--:/-      Packages: 527
        o:+o+:++.`..```.-/oo+++++/     Shell: bash 4.4.20
       .:+o:+o/.          `+sssoo+/    CPU: Intel Core i5-3570K @ 4x 3.8GHz [27.8°C]
  .++/+:+oo+o:`             /sssooo.   GPU: AMD/ATI Tahiti PRO [Radeon HD 7950/8950 OEM / R9 280]
 /+++//+:`oo+o               /::--:.   RAM: 235MiB / 15996MiB
 \+/+o+++`o++o               ++////.
  .++.o+++oo+:`             /dddhhh.
       .+.o+oo:.          `oddhhhh+
        \+.++o+o``-````.:ohdhhhhh+
         `:o+++ `ohhhhhhhhyo++os:
           .o:`.syhhhhhhh/.oo++o`
               /osyyyyyyo++ooo+++/
                   ````` +oo+++o\:
                          `oo++.
```

## Setup static IP
. `ip link` to find interace
. modify `/etc/netplan/50-cloud-init.yaml` to be instead:
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    {{ip link interface goes here}}:
      dhcp4: no
      addresses:
        - {{ip address goes here}}/24
      gateway4: {{gateway goes here}}
      nameservers:
          addresses: [1.1.1.1, 8.8.8.8]
```
. apply changes with `sudo netplan apply`

## Turn off swap
- `sudo swapoff -a`


## Setup DNS or /etc/hosts file
- Make sure localhost is accessible via hostname
- Make sure DNS lets you access master nodes

## Add ssl to ingress via ACME
As this is an internal cluster (for now), the easier way to use `cert-manager` and Let's Encrypt
ACME is to make it temporarily public, register all required certs and then make it private again
afterward. This also requires disabling hsts if you create a certificate for your root FQDN.

The, more proper solution is to use the DNS01 challenge feature of cert-manager. However, this 
requires setting up authentication. 

---

- Fix dns provisioning to be configured via global config and scanning master/nodes
- Allow for multiple masters (high availability)
- Switch back to CephFS and Rook after configuring correctly and understanding Ceph better
---
## Unused
## Rook cephfs storage
- Make sure you have a device attached for OSDs
- It must not have a file system on it
- The nodes should not have anything running on :9091

### Rook cephfs shared file system PVCs not being provisioned:

- To fix `kubectl delete pod -l app=csi-cephfsplugin-provisioner --grace-period=0 --force` restarts
the provisioning pods and creates the PVC correctly