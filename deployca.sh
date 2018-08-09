source env.sh

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
cat ca-config.json

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
cat ca-csr.json

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
    ssh root@${master_node_ip} "mkdir -p /etc/kubernetes/cert"
    scp ca-config.json ca*.pem \
      root@${master_node_ip}:/etc/kubernetes/cert/
    if [ $? -ne 0 ];then echo "分发CA证书和私钥失败，退出脚本";exit 1;fi
  done


