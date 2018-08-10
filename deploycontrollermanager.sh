source env.sh

# 创建controller-manager证书签名请求
echo "==========创建controller-manager证书签名请求=========="
cat > kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
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
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "k8s",
            "OU": "kube-controller-manager"
        }
    ]
}
EOF
cat kube-controller-manager-csr.json

# 生成controller-manager证书和私钥
echo "========生成controller-manager证书和私钥========"
cfssl gencert\
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json\
  | cfssljson -bare kube-controller-manager
ls kube-controller-manager*.pem

# 创建controller-manager kubeconfig文件
echo "==========创建controller-manager kubeconfig文件=========="
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/cert/ca.pem \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=/etc/kubernetes/cert/kube-controller-manager.pem \
  --client-key=/etc/kubernetes/cert/kube-controller-manager-key.pem \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context system:kube-controller-manager \
  --cluster=kubernetes \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig
cat kube-controller-manager.kubeconfig


# 创建controller-manager systemd unit文件
echo "=========创建controller-manager systemd unit文件========="
cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --port=0 \\
  --secure-port=10252 \\
  --bind-address=127.0.0.1 \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/etc/kubernetes/cert/ca.pem \\
  --cluster-signing-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --experimental-cluster-signing-duration=8760h \\
  --root-ca-file=/etc/kubernetes/cert/ca.pem \\
  --service-account-private-key-file=/etc/kubernetes/cert/ca-key.pem\\
  --leader-elect=true \\
  --feature-gates=RotateKubeletServerCertificate=true \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --horizontal-pod-autoscaler-use-rest-clients=true \\
  --horizontal-pod-autoscaler-sync-period=10s \\
  --tls-cert-file=/etc/kubernetes/cert/kube-controller-manager.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kube-controller-manager-key.pem \\
  --use-service-account-credentials=true \\
  --alsologtostderr=true \\
  --logtostderr=false \\
  --log-dir=/var/log/kubernetes \\
  --v=2
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
cat kube-controller-manager.service

# 分发controller-manager及启动
echo "=========分发controller-manager及启动========="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "分发controller-manager二进制"
    ssh root@${master_ip} \
      "if [ -f /usr/local/bin/kube-controller-manager ];then
       systemctl stop kube-controller-manager
       rm -f /usr/local/bin/kube-controller-manager
       fi"
    scp kubernetes/server/bin/kube-controller-manager \
      root@${master_ip}:/usr/local/bin/

    echo "分发证书和私钥"
    ssh root@${master_ip} "mkdir -p /etc/kubernetes/cert"
    scp kube-controller-manager*.pem \
      root@${master_ip}:/etc/kubernetes/cert/

    echo "分发kubeconfig文件"
    scp kube-controller-manager.kubeconfig \
      root@${master_ip}:/etc/kubernetes/

    echo "分发systemd unit文件"
    scp kube-controller-manager.service \
      root@${master_ip}:/usr/lib/systemd/system/

    echo "启动kube-controller-manager服务"
    ssh root@${master_ip} "
       mkdir -p /var/log/kubernetes
       systemctl daemon-reload
       systemctl enable kube-controller-manager
       systemctl start kube-controller-manager
       echo 'wait 5s for controller-mananger up'
       sleep 5
       systemctl status kube-controller-manager | grep Active
       netstat -lnpt | grep kube-con
       curl -s \
       --cacert /etc/kubernetes/cert/ca.pem \
       https://127.0.0.1:10252/metrics | head
       "
    if [ $? -ne 0 ];then echo "启动controller-manager失败，退出脚本";exit 1;fi

  done

# 查看当前的leader
echo "========查看当前的leader========="
kubectl get endpoints kube-controller-manager \
--namespace=kube-system \
-o yaml
if [ $? -ne 0 ];then echo "查看controller-manager的leader失败，退出脚本";exit 1;fi
