source env.sh

# 创建etcd证书签名请求
echo "=========创建etcd证书签名请求========"
cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${MASTER_IPS[0]}",
    "${MASTER_IPS[1]}",
    "${MASTER_IPS[2]}"
  ],
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
cat etcd-csr.json

# 创建etcd证书和私钥
echo "=========创建etcd证书和私钥========"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes etcd-csr.json | cfssljson -bare etcd
ls etcd*.pem

# 创建etcdctl证书签名请求
echo "=========创建etcdctl证书签名请求========"
cat > etcdctl-csr.json <<EOF
{
  "CN": "etcdctl",
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
cat etcdctl-csr.json

# 创建etcdctl证书和私钥
echo "=========创建etcdctl证书和私钥========"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes etcdctl-csr.json | cfssljson -bare etcdctl
ls etcdctl*.pem

# 创建etcd的systemd unit模板文件
echo "=========创建etcd的systemd unit模板文件========"
cat > etcd.service.template <<EOF 
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/local/bin/etcd \\
  --data-dir /var/lib/etcd \\
  --name ##NODE_NAME## \\
  --cert-file /etc/etcd/cert/etcd.pem \\
  --key-file /etc/etcd/cert/etcd-key.pem \\
  --trusted-ca-file /etc/kubernetes/cert/ca.pem \\
  --peer-cert-file /etc/etcd/cert/etcd.pem \\
  --peer-key-file /etc/etcd/cert/etcd-key.pem \\
  --peer-trusted-ca-file /etc/kubernetes/cert/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-peer-urls https://##NODE_IP##:2380 \\
  --initial-advertise-peer-urls https://##NODE_IP##:2380 \\
  --listen-client-urls https://##NODE_IP##:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls https://##NODE_IP##:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${ETCD_NODES} \\
  --initial-cluster-state new
Restart=on-failure
RestartSec=60
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
cat etcd.service.template

# 根据模板创建各systemd unit文件
echo "==========根据模板创建各systemd unit文件========="
for (( i=0; i < 3; i++ ))
  do
    echo ">>> ${ETCD_NAMES[i]}"
    sed -e "s/##NODE_NAME##/${ETCD_NAMES[i]}/" \
        -e "s/##NODE_IP##/${MASTER_IPS[i]}/" \
           etcd.service.template > etcd-${MASTER_IPS[i]}.service
    cat etcd-${MASTER_IPS[i]}.service
  done

# 分发并启动etcd
echo "=========分发并启动etcd=========="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "分发etcd"
    ssh root@${master_ip} "
      if [ -f /usr/local/bin/etcd ];then
      systemctl stop etcd
      rm -f /usr/local/bin/etcd
      fi"
    scp etcd-v3.3.8-linux-amd64/etcd root@${master_ip}:/usr/local/bin/
    
    echo "分发etcd证书和私钥"
    ssh root@${master_ip} "mkdir -p /etc/etcd/cert"
    scp etcd.pem etcd-key.pem root@${master_ip}:/etc/etcd/cert/

    echo "分发etcd的systemd unit文件"
    scp etcd-${master_ip}.service \
      root@${master_ip}:/usr/lib/systemd/system/etcd.service
    
    echo "启动etcd，首次启动这里会卡一段时间，不过不要紧"
    ssh root@${master_ip} "
      mkdir -p /var/lib/etcd
      systemctl daemon-reload
      systemctl enable etcd
      systemctl start etcd &
      systemctl status etcd | grep Active"
    if [ $? -ne 0 ];then echo "启动etcd失败，退出脚本";exit 1;fi
  done

# 分发etcdctl并验证etcd
echo "==========分发etcdctl==========="
for master_node_ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${master_node_ip}"
    echo "分发etcdctl"
    scp etcd-v3.3.8-linux-amd64/etcdctl \
      root@${master_node_ip}:/usr/local/bin/

    echo "分发etcdctl证书和私钥"
    ssh root@${master_node_ip} "mkdir -p /etc/etcdctl/cert"
    scp etcdctl*.pem root@${master_node_ip}:/etc/etcdctl/cert/

    echo "${master_node_ip}验证etcd"
    ssh root@${master_node_ip} "
      ETCDCTL_API=3 etcdctl \
      --endpoints=${ETCD_ENDPOINTS} \
      --cacert=/etc/kubernetes/cert/ca.pem \
      --cert=/etc/etcdctl/cert/etcdctl.pem \
      --key=/etc/etcdctl/cert/etcdctl-key.pem \
      endpoint health"
    if [ $? -ne 0 ];then echo "分发etcdctl失败，退出脚本";exit 1;fi
  done

# 也发一份etcdctl二进制到本地
echo "=========也发一份etcdctl二进制到dev========="
sudo cp etcd-v3.3.8-linux-amd64/etcdctl /usr/local/bin/
if [ $? -ne 0 ];then echo "分发etcdctl到dev失败，退出脚本";exit 1;fi
ls /usr/local/bin/etcdctl

