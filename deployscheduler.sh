source env.sh

# 创建scheduler证书签名请求
echo "==========创建scheduler证书签名请求=========="
cat > kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
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
            "OU": "kube-scheduler"
        }
    ]
}
EOF
cat kube-scheduler-csr.json

# 生成scheduler证书和私钥
echo "========生成scheduler证书和私钥========"
cfssl gencert\
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
ls kube-scheduler*.pem

# 创建scheduler kubeconfig文件
echo "==========创建scheduler kubeconfig文件=========="
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/cert/ca.pem \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=/etc/kubernetes/cert/kube-scheduler.pem \
  --client-key=/etc/kubernetes/cert/kube-scheduler-key.pem \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context system:kube-scheduler \
  --cluster=kubernetes \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig
cat kube-scheduler.kubeconfig

# 创建scheduler systemd unit文件
echo "=========创建scheduler systemd unit文件========="
cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --address=127.0.0.1 \\
  --kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
  --leader-elect=true \\
  --alsologtostderr=true \\
  --logtostderr=false \\
  --log-dir=/var/log/kubernetes \\
  --v=2
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
cat kube-scheduler.service

# 分发scheduler及启动
echo "=========分发scheduler及启动========="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "分发scheduler二进制"
    ssh root@${master_ip} \
      "if [ -f /usr/local/bin/kube-scheduler ];then
       systemctl stop kube-scheduler
       rm -f /usr/local/bin/kube-scheduler
       fi"
    scp kubernetes/server/bin/kube-scheduler \
      root@${master_ip}:/usr/local/bin/

    echo "分发证书和私钥"
    ssh root@${master_ip} "mkdir -p /etc/kubernetes/cert"
    scp kube-scheduler*.pem \
      root@${master_ip}:/etc/kubernetes/cert/

    echo "分发kubeconfig文件"
    scp kube-scheduler.kubeconfig \
      root@${master_ip}:/etc/kubernetes/

    echo "分发systemd unit文件"
    scp kube-scheduler.service \
      root@${master_ip}:/usr/lib/systemd/system/

    echo "启动kube-scheduler服务"
    ssh root@${master_ip} "
      mkdir -p /var/log/kubernetes
      systemctl daemon-reload
      systemctl enable kube-scheduler
      systemctl start kube-scheduler
      echo 'wait 5s for scheduler up'
      sleep 5
      systemctl status kube-scheduler | grep Active
      netstat -lnpt | grep kube-sche
      echo '查看metric'
      curl -s http://127.0.0.1:10251/metrics | head"
    if [ $? -ne 0 ];then echo "启动scheduler失败，退出脚本";exit 1;fi

  done

# 查看当前的leader
echo "========查看当前的leader========="
kubectl get endpoints kube-scheduler \
--namespace=kube-system \
-o yaml
if [ $? -ne 0 ];then echo "查看scheduler的leader失败，退出脚本";exit 1;fi