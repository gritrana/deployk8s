source env.sh

mkdir -p ${CA_PATH}
# 创建CA配置文件
echo "========创建CA配置文件======="
cat > ${CA_PATH}/ca-config.json <<EOF
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
cat ${CA_PATH}/ca-config.json

# 创建CA证书签名请求
echo "========创建CA证书签名请求======="
cat > ${CA_PATH}/ca-csr.json <<EOF
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
cat ${CA_PATH}/ca-csr.json

# 生成CA证书和私钥
echo "=========生成CA证书和私钥========="
cfssl gencert \
-initca ${CA_PATH}/ca-csr.json | cfssljson -bare ${CA_PATH}/ca
ls ${CA_PATH}/ca*.pem
chmod +r ${CA_PATH}/ca-key.pem

# 分发CA证书和私钥到master
echo "=========分发CA证书和私钥到master========="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "分发CA证书和私钥"
    ssh root@${master_ip} "mkdir -p /etc/kubernetes/cert"
    scp ${CA_PATH}/ca*.pem \
      root@${master_ip}:/etc/kubernetes/cert/
    if [ $? -ne 0 ];then echo "分发CA证书和私钥失败，退出脚本";exit 1;fi
  done

# 分发CA证书到node
echo "=========分发CA证书到node========="
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    echo "分发CA证书和私钥"
    ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert"
    scp ${CA_PATH}/ca.pem \
      root@${node_ip}:/etc/kubernetes/cert/
    if [ $? -ne 0 ];then echo "分发CA证书和私钥失败，退出脚本";exit 1;fi
  done

# 分发CA证书和私钥及配置到dev
echo "=========分发CA证书和私钥到dev========="
sudo mkdir -p /etc/kubernetes/cert
sudo cp ${CA_PATH}/ca* /etc/kubernetes/cert/
ls /etc/kubernetes/cert/ca*
