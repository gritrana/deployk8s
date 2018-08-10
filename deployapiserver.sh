source env.sh

# 创建kubernetes证书签名请求
echo "========创建kubernetes证书签名请求========"
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "${MASTER_IPS[0]}",
    "${MASTER_IPS[1]}",
    "${MASTER_IPS[2]}",
    "${MASTER_VIP}",
    "${CLUSTER_KUBERNETES_SVC_IP}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
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
      "OU": "kube-apiserver"
    }
  ]
}
EOF
cat kubernetes-csr.json

# 创建kubernetes证书和私钥
echo "=========创建kubernetes证书和私钥========"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
ls kubernetes*.pem

# 创建加密配置文件
echo "=========创建加密配置文件========"
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
cat encryption-config.yaml

# 创建kube-apiserver systemd unit模板
echo "=======# 创建kube-apiserver systemd unit模板======="
cat > kube-apiserver.service.template <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --anonymous-auth=false \\
  --experimental-encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --advertise-address=##NODE_IP## \\
  --bind-address=##NODE_IP## \\
  --insecure-port=0 \\
  --authorization-mode=Node,RBAC \\
  --runtime-config=api/all \\
  --enable-bootstrap-token-auth \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=${NODE_PORT_RANGE} \\
  --tls-cert-file=/etc/kubernetes/cert/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kubernetes-key.pem \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --kubelet-client-certificate=/etc/kubernetes/cert/kubernetes.pem \\
  --kubelet-client-key=/etc/kubernetes/cert/kubernetes-key.pem \\
  --service-account-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --etcd-cafile=/etc/kubernetes/cert/ca.pem \\
  --etcd-certfile=/etc/kubernetes/cert/kubernetes.pem \\
  --etcd-keyfile=/etc/kubernetes/cert/kubernetes-key.pem \\
  --etcd-servers=${ETCD_ENDPOINTS} \\
  --enable-swagger-ui=true \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/kube-apiserver-audit.log \\
  --event-ttl=1h \\
  --alsologtostderr=true \\
  --logtostderr=false \\
  --log-dir=/var/log/kubernetes \\
  --v=2
Restart=on-failure
RestartSec=60
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
ls kube-apiserver.service.template

# 创建kube-apiserver systemd unit文件
echo "=======创建kube-apiserver systemd unit文件======="
for (( i=0; i < 3; i++ ))
  do
    echo ">>> ${MASTER_NAMES[i]}"
    sed -e "s/##NODE_NAME##/${MASTER_NAMES[i]}/" \
        -e "s/##NODE_IP##/${MASTER_IPS[i]}/" \
        kube-apiserver.service.template > kube-apiserver-${MASTER_IPS[i]}.service
    cat kube-apiserver-${MASTER_IPS[i]}.service
  done

# 分发并启动kube-apiserver
echo "========分发并启动kube-apiserver======="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "分发apiserver二进制（这里有时也会卡一下，停止kube-apiserver需要时间）"
    ssh root@${master_ip} "
      if [ -f /usr/local/bin/kube-apiserver ];then
      systemctl stop kube-apiserver
      rm -f /usr/local/bin/kube-apiserver
      fi"
    scp kubernetes/server/bin/kube-apiserver root@${master_ip}:/usr/local/bin/

    echo "分发证书和私钥"
    ssh root@${master_ip} "mkdir -p /etc/kubernetes/cert"
    scp kubernetes*.pem root@${master_ip}:/etc/kubernetes/cert/

    echo "分发加密配置文件"
    scp encryption-config.yaml root@${master_ip}:/etc/kubernetes/

    echo "分发systemd unit文件"
    scp kube-apiserver-${master_ip}.service \
      root@${master_ip}:/usr/lib/systemd/system/kube-apiserver.service

    echo "启动kube-apiserver服务"
    ssh root@${master_ip} "
      mkdir -p /var/log/kubernetes
      systemctl daemon-reload
      systemctl enable kube-apiserver
      systemctl start kube-apiserver
      echo 'wait 5s for apiserver up'
      sleep 5
      systemctl status kube-apiserver | grep Active
      netstat -lnpt | grep kube-api"

    echo "查看kube-apiserver写入etcd的数据"
    ssh root@${master_ip} "
      ETCDCTL_API=3 etcdctl \
      --endpoints=${ETCD_ENDPOINTS} \
      --cacert=/etc/kubernetes/cert/ca.pem \
      --cert=/etc/etcdctl/cert/etcdctl.pem \
      --key=/etc/etcdctl/cert/etcdctl-key.pem \
      get /registry/ --prefix --keys-only"

    if [ $? -ne 0 ];then echo "启动kube-apiserver失败，退出脚本";exit 1;fi
  done

# 查看集群信息
echo "========查看集群信息========="
kubectl cluster-info

# 查看所有名字空间
echo "========查看所有名字空间========="
kubectl get all --all-namespaces

# 查看各组件状态
echo "========查看各组件状态========="
kubectl get componentstatuses

if [ $? -ne 0 ];then echo "执行kubectl命令失败，退出脚本";exit 1;fi

# 授予 kubernetes 证书访问 kubelet API 的权限
echo "========授予 kubernetes 证书访问 kubelet API 的权限========="
kubectl create clusterrolebinding \
kube-apiserver:kubelet-apis \
--clusterrole=system:kubelet-api-admin \
--user kubernetes
echo "ignore rolebindings alreadyExists"

