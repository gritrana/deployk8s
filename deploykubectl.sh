source env.sh

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
ls admin*.pem

# 分发kubectl
sudo cp kubernetes/server/bin/kubectl /usr/local/bin/

# 创建kubeconfig文件
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=ca.pem \
  --server=${KUBE_APISERVER}

# 设置客户端认证参数
kubectl config set-credentials admin \
  --client-certificate=.kube/admin.pem \
  --client-key=.kube/admin-key.pem 

# 设置上下文参数
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin

# 设置默认上下文
kubectl config use-context kubernetes

# 分发kubectl证书和密钥
cp admin*.pem .kube/

: '
没有必要把kubectl部署到集群中
# 分发kubeconfig文件
for master_node_ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${master_node_ip}"
    echo "分发kubectl"
    ssh root@${master_node_ip} "mkdir -p /usr/local/bin"
    scp kubernetes/client/bin/kubectl root@${master_node_ip}:/usr/local/bin/

    echo "分发kubectl证书及私钥"
    scp admin*.pem root@${master_node_ip}:~/
    
    echo "分发kubectl配置文件"
    ssh root@${master_node_ip} "mkdir -p ~/.kube"
    scp kubectl.kubeconfig root@${master_node_ip}:~/.kube/config
  done
'


