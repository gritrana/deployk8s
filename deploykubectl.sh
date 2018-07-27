source ~/env.sh

# 创建证书签名请求
cat > admin-csr.json <<EOF
{
  "CN": "admin",
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
      "O": "system:masters",
      "OU": "4Paradigm"
    }
  ]
}
EOF

# 生成kubectl证书和私钥
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes admin-csr.json | cfssljson -bare admin
ls admin*

# 创建kubeconfig文件
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=ca.pem \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kubectl.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --kubeconfig=kubectl.kubeconfig

# 设置上下文参数
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=kubectl.kubeconfig

# 设置默认上下文
kubectl config use-context kubernetes --kubeconfig=kubectl.kubeconfig

: '
没有必要把kubectl部署到集群中
# 分发kubeconfig文件
for master_node_ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${master_node_ip}"
    echo "分发kubectl"
    ssh k8s@${master_node_ip} "sudo mkdir -p /opt/k8s/bin && sudo chown -R k8s:k8s /opt/k8s"
    scp kubernetes/client/bin/kubectl k8s@${master_node_ip}:/opt/k8s/bin/

    echo "分发kubectl证书及私钥"
    scp admin*.pem k8s@${master_node_ip}:~/
    
    echo "分发kubectl配置文件"
    ssh k8s@${master_node_ip} "mkdir -p ~/.kube"
    scp kubectl.kubeconfig k8s@${master_node_ip}:~/.kube/config
  done
'
