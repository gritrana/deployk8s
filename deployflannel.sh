source ~/env.sh

# 创建flannel证书签名请求
echo "==========创建flannel证书签名请求========="
cat > flanneld-csr.json <<EOF
{
  "CN": "flanneld",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "4Paradigm"
    }
  ]
}
EOF
ls flanneld-csr.json

# 生成flannel证书和私钥
echo "=========生成flannel证书和私钥========"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes flanneld-csr.json | cfssljson -bare flanneld
ls flanneld*.pem

# 向etcd写入集群Pod网段信息
echo "=========向etcd写入集群Pod网段信息========="
etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=ca.pem \
  --cert-file=flanneld.pem \
  --key-file=flanneld-key.pem \
  set ${FLANNEL_ETCD_PREFIX}/config '{"Network":"'${CLUSTER_CIDR}'", 
"SubnetLen": 24, "Backend": {"Type": "vxlan"}}'

# 创建flanneld的systemd unit文件
echo "=======创建flanneld的systemd unit文件========="
export IFACE=ens33
cat > flanneld.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart=/opt/k8s/bin/flanneld \\
  -etcd-cafile=/etc/kubernetes/cert/ca.pem \\
  -etcd-certfile=/etc/flanneld/cert/flanneld.pem \\
  -etcd-keyfile=/etc/flanneld/cert/flanneld-key.pem \\
  -etcd-endpoints=${ETCD_ENDPOINTS} \\
  -etcd-prefix=${FLANNEL_ETCD_PREFIX} \\
  -iface=${IFACE}
ExecStartPost=/opt/k8s/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS \\
  -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF
ls flanneld.service

# 分发flannel二进制，证书和私钥，flanneld.service，并启动flanneld
echo "=========分发flannel二进制，证书和私钥，flanneld.service，并启动flanneld========"
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    echo "分发flannel二进制文件"
    ssh k8s@${node_ip} "sudo mkdir -p /opt/k8s/bin
                        sudo chown -R k8s:k8s /opt/k8s"
    ssh k8s@${node_ip} "if [ -f /opt/k8s/bin/flanneld ];then
                        sudo systemctl stop flanneld
                        rm -f /opt/k8s/bin/{flanneld,mk-docker-opts.sh}
                        fi"
    scp flannel/{flanneld,mk-docker-opts.sh} k8s@${node_ip}:/opt/k8s/bin/

    echo "分发flannel证书和私钥"
    ssh k8s@${node_ip} "sudo mkdir -p /etc/flanneld/cert
                        sudo chown -R k8s:k8s /etc/flanneld"
    scp flanneld*.pem k8s@${node_ip}:/etc/flanneld/cert/

    echo "分发flanneld.service"
    scp flanneld.service root@${node_ip}:/usr/lib/systemd/system/

    echo "启动flanneld"
    ssh k8s@${node_ip} "sudo systemctl daemon-reload
                        sudo systemctl enable flanneld
                        sudo systemctl start flanneld"
    
    echo "检查启动结果"
    ssh k8s@${node_ip} "sudo systemctl status flanneld | grep Active"

    echo "查看集群Pod网段"
    ssh k8s@${node_ip} "etcdctl \
                        --endpoints=${ETCD_ENDPOINTS} \
                        --ca-file=/etc/kubernetes/cert/ca.pem \
                        --cert-file=/etc/flanneld/cert/flanneld.pem \
                        --key-file=/etc/flanneld/cert/flanneld-key.pem \
                        get ${FLANNEL_ETCD_PREFIX}/config"

    echo "查看已分配的Pod子网段列表"
    ssh k8s@${node_ip} "etcdctl \
                        --endpoints=${ETCD_ENDPOINTS} \
                        --ca-file=/etc/kubernetes/cert/ca.pem \
                        --cert-file=/etc/flanneld/cert/flanneld.pem \
                        --key-file=/etc/flanneld/cert/flanneld-key.pem \
                        ls ${FLANNEL_ETCD_PREFIX}/subnets"

    echo "验证各节点能通过Pod网段互通"
    ssh k8s@${node_ip} "ip addr show flannel.1 | grep -w inet"
  done
