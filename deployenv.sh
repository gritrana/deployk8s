source env.sh

# 设置dev环境
echo "========解压cfssl========="
# curl -O https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
sudo cp cfssl_linux-amd64 /usr/local/bin/cfssl
# curl -O https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
sudo cp cfssljson_linux-amd64 /usr/local/bin/cfssljson
# curl -O https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
sudo cp cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
if [ $? -ne 0 ];then exit; fi
sudo chmod +x /usr/local/bin/cfssl*
ls /usr/local/bin/cfssl*

echo "========解压etcd v3.3.8========="
# curl -O https://github.com/coreos/etcd/releases/download/v3.3.8/etcd-v3.3.8-linux-amd64.tar.gz
tar -xzvf etcd-v3.3.8-linux-amd64.tar.gz
if [ $? -ne 0 ];then exit; fi

echo "========解压flannel v0.10.0========="
#curl -O https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz
mkdir -p flannel
tar -xzvf flannel-v0.10.0-linux-amd64.tar.gz -C flannel
if [ $? -ne 0 ];then exit; fi

echo "========解压kubernetes v1.11.0"
# 要使用其它版本的kubernetes 请到https://github.com/kubernetes/kubernetes/releases 查看
# 对应的版本的CHANGELOG.md. 找到对应的链接下载
# curl -O https://dl.k8s.io/v1.11.0/kubernetes-server-linux-amd64.tar.gz
tar -xzvf kubernetes-server-linux-amd64.tar.gz
if [ $? -ne 0 ];then exit; fi

echo "=======创建调试脚本======="
cat > getlog-master.sh <<EOF
sed -n -e '/Keepalived/p' /var/log/messages > keepalived.log
sed -n -e '/haproxy/p' /var/log/messages > haproxy.log
EOF
ls getlog-master.sh

echo "======验证StrictHostKeyChecking======"
for ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${ip}"
    ssh root@${ip} echo "should skip host authenticity"
  done
if [ $? -ne 0 ];then
echo "验证失败，退出脚本"
exit
fi

# 设置master机器环境
echo "=========设置master机器环境========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${MASTER_IPS[i]}"
    echo "分发调试脚本"
    scp getlog-master.sh root@${MASTER_IPS[i]}:~/getlog.sh
    ssh root@${MASTER_IPS[i]} "chmod +x getlog.sh"

    echo "修改hosts"
    for ((j=0; j<3; j++))
      do
        echo "修改hosts，追加${MASTER_IPS[j]} ${MASTER_NAMES[j]}"
        ssh root@${MASTER_IPS[i]} \
          "echo '${MASTER_IPS[j]} ${MASTER_NAMES[j]}' >> /etc/hosts"
#          "if [ -z `awk '/$MASTER_IPS[j] $MASTER_NAMES[j]/' /etc/hosts` ];then
#           echo '${MASTER_IPS[j]} ${MASTER_NAMES[j]}' >> /etc/hosts
#           fi"
      done
  done

# 设置node机器环境
echo "=========设置node机器环境========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${NODE_IPS[i]}"

    echo "修改hosts"
    for ((j=0; j<3; j++))
      do
        echo "修改hosts，追加${NODE_IPS[j]} ${NODE_NAMES[j]}"
        ssh root@${NODE_IPS[i]} \
          "echo '${NODE_IPS[j]} ${NODE_NAMES[j]}' >> /etc/hosts"
      done
  done

