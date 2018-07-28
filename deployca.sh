source ~/env.sh

# 创建CA配置文件
echo "========创建CA配置文件======="
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
ls ca-config.json

# 创建CA证书签名请求
echo "========创建CA证书签名请求======="
cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
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
ls ca-csr.json

# 生成CA证书和私钥
echo "=========生成CA证书和私钥========="
cfssl gencert \
  -initca ca-csr.json | cfssljson -bare ca
ls ca*.pem

# 分发CA证书和私钥
echo "=========分发CA证书和私钥========="
for master_node_ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${master_node_ip}"
    echo "分发CA证书和私钥"
    ssh k8s@${master_node_ip} "sudo mkdir -p /etc/kubernetes/cert
                               sudo chown -R k8s:k8s /etc/kubernetes"
    scp ca-config.json ca*.pem k8s@${master_node_ip}:/etc/kubernetes/cert/
  done


