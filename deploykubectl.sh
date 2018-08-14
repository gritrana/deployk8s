source env.sh

# 创建证书签名请求
cat > ${KUBECTL_PATH}/admin-csr.json <<EOF
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
cat ${KUBECTL_PATH}/admin-csr.json

# 生成kubectl证书和私钥
echo "=======生成kubectl证书和私钥========"
cfssl gencert \
-ca=/etc/kubernetes/cert/ca.pem \
-ca-key=/etc/kubernetes/cert/ca-key.pem \
-config=/etc/kubernetes/cert/ca-config.json \
-profile=kubernetes \
${KUBECTL_PATH}/admin-csr.json | \
cfssljson -bare ${KUBECTL_PATH}/admin
if [ $? -ne 0 ];then echo "生成kubectl证书和私钥失败，退出脚本";exit 1;fi
chmod +r ${KUBECTL_PATH}/admin-key.pem
ls ${KUBECTL_PATH}/admin*.pem

# 创建kubeconfig文件
cat > ${KUBECTL_PATH}/kubectl.kubeconfig << EOF
apiVersion: v1
clusters:
- name: cluster1
  cluster:
    certificate-authority: /etc/kubernetes/cert/ca.pem
    server: ${KUBE_APISERVER}
contexts:
- name: context1
  context:
    cluster: cluster1
    user: admin
current-context: context1
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate: /etc/kubectl/cert/admin.pem
    client-key: /etc/kubectl/cert/admin-key.pem
EOF
cat ${KUBECTL_PATH}/kubectl.kubeconfig

# 分发kubectl二进制
echo "========分发kubectl二进制======="
sudo cp ${KUBECTL_PATH}/kubectl /usr/local/bin/
if [ $? -ne 0 ];then echo "分发kubectl二进制失败，退出脚本";exit 1;fi
ls /usr/local/bin/kubectl

# 分发kubectl证书和密钥
echo "=======分发kubectl证书和密钥========"
sudo mkdir -p /etc/kubectl/cert
sudo cp ${KUBECTL_PATH}/admin*.pem /etc/kubectl/cert/
if [ $? -ne 0 ];then echo "分发kubectl证书和私钥失败，退出脚本";exit 1;fi
ls /etc/kubectl/cert/admin*.pem

# 分发kubeconfig文件
echo "=======分发kubectl kubeconfig文件========"
cp ${KUBECTL_PATH}/kubectl.kubeconfig ~/.kube/config
if [ $? -ne 0 ];then echo "分发kubectl kubeconfig文件失败，退出脚本";exit 1;fi

: '不使用kubectl工具创建kubeconfig文件
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
'

: '没有必要把kubectl部署到集群中
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


