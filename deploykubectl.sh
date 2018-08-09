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
cat admin-csr.json

# 生成kubectl证书和私钥
echo "=======生成kubectl证书和私钥========"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes admin-csr.json | cfssljson -bare admin
ls admin*.pem

: '
# 分发kubectl证书和密钥
echo "=======分发kubectl证书和密钥========"
mkdir -p ~/.kube
cp admin*.pem ~/.kube/
ls ~/.kube/
'

# 分发kubectl
echo "========分发kubectl======="
sudo cp kubernetes/server/bin/kubectl /usr/local/bin/
if [ $? -ne 0 ];then echo "分发kubectl失败，退出脚本";exit 1;fi
ls /usr/local/bin/kubectl

# 创建kubeconfig文件
# --certificate-authority参数没法把~/.kube解析成相对路径
# 这里只能使用相对路径下的证书和密钥了，copy的时候需要留意
echo "=========创建kubeconfig文件========="
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=ca.pem \
  --server=${KUBE_APISERVER}

# 设置客户端认证参数
kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem

# 设置上下文参数
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin

# 设置默认上下文
kubectl config use-context kubernetes
cat ~/.kube/config

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


