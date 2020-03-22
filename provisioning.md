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


## Install dependencies
### dmsetup, , binutils and containerd if not present. Also install opensshclient and git
*(ssh and git packages are optional and )*
```shell
apt-get update && apt-get install -y --no-install-recommends dmsetup openssh-client git binutils
apt-get install -y --no-install-recommends containerd
```

### CNI plugins
```shell
export CNI_VERSION=v0.8.5
export ARCH=$([ $(uname -m) = "x86_64" ] && echo amd64 || echo arm64)
mkdir -p /opt/cni/bin
curl -sSL https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz | tar -xz -C /opt/cni/bin
```

### Install docker for now :( 
`sudo install docker.io`

### Install ignite
```shell
export VERSION=v0.6.3
export GOARCH=$(go env GOARCH 2>/dev/null || echo "amd64")

for binary in ignite ignited; do
    echo "Installing ${binary}..."
    curl -sfLo ${binary} https://github.com/weaveworks/ignite/releases/download/${VERSION}/${binary}-${GOARCH}
    chmod +x ${binary}
    sudo mv ${binary} /usr/local/bin
done
```

### Start containerd 
`systemctl start containerd`

(install weeave cni plugin or another plugin here)
---
## Running the cluster
```shell
ignite run weaveworks/ignite-kubeadm:latest \
    --cpus 2 \
    --memory 2GB \
    --size 20GB \
    --ssh \
    --name master-0
```

`hostnamectl set-hostname $(ignite ps | grep master-0 | cut -f1)`

`CONTROL_PLANE_IP=$(ignite ps | grep master-0 | cut -f9)`

```shell
cat > run/config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  criSocket: /run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.15.0
controlPlaneEndpoint: ${CONTROL_PLANE_IP}
apiServer:
  certSANs:
  - "${HOST_IP}"
EOF
```

```shell
ignite exec master-0 "kubeadm init --config /config.yaml --upload-certs"
JOIN_COMMAND=$(ignite exec master-0 "kubeadm token create --print-join-command")
```


### Create more nodes
```shell
for i in {1..2}; do
  ignite run weaveworks/ignite-kubeadm:latest \
      --cpus 2 \
      --memory 2GB \
      --size 20GB \
      --ssh \
      --name node-${i}
  NODE_HOSTNAME=$(ignite ps  | grep node-${i} | cut -f1)
  NODE_IP=$(ignite ps  | grep node-${i} | cut -f9)
  ignite exec node-${i} hostnamectl set-hostname ${NODE_HOSTNAME}
  ignite exec node-${i} "${JOIN_COMMAND}"
done
```
 
`ignite exec master-0 "cat /etc/kubernetes/admin.conf" > $HOME/master.kube`


### Load balance master(s)
```shell
cat > haproxy.cfg <<EOF
frontend http_front
   bind *:443
   stats uri /haproxy?stats
   default_backend http_back

backend http_back
   balance roundrobin
   option httpchk GET /healthz
   http-check expect string ok
   server master0 ${CONTROL_PLANE_IP}:6443 check check-ssl verify none
EOF
```

```shell
docker run -d -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg -p 6443:443 haproxy:alpine
ufw allow 6443
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable
```



### Add network plugin
`kubectl create -f https://raw.githubusercontent.com/cilium/cilium/1.7.1/install/kubernetes/quick-install.yaml`


### Deploy NGINX Ingress controller with node-port 

`kustomize build ./resources/nginx-ingress | kubectl apply -f -`

Deploy HAProxy on the host with [edge.cfg](haproxy/edge.cfg):

`sudo docker run -d -v $(pwd)/edge.cfg:/usr/local/etc/haproxy/haproxy.cfg -p 80:80 haproxy:alpine`

--- 
## TODO
- Change this to be more declarative for provisoning such as through ansible
- Change the kubectl apply commands to be declared through yaml and kustomize overlays


---
##### Useful commands
Delete all vms
`# ignite vms | cut -f1 | tail -n +2 | xargs ignite rm`

https://blog.scottlowe.org/2019/07/30/adding-a-name-to-kubernetes-api-server-certificate/