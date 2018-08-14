source env.sh

# 设置dev环境
echo "========解压cfssl========="
# curl -O https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
sudo cp cfssl_linux-amd64 /usr/local/bin/cfssl
# curl -O https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
sudo cp cfssljson_linux-amd64 /usr/local/bin/cfssljson
# curl -O https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
sudo cp cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
if [ $? -ne 0 ];then exit 1; fi
sudo chmod +x /usr/local/bin/cfssl*
ls /usr/local/bin/cfssl*

echo "========解压keepalived v2.0.6========"
# curl -O curl -O http://www.keepalived.org/software/keepalived-2.0.6.tar.gz
mkdir -p ${KEEPALIVED_PATH}
tar -xzvf keepalived-2.0.6.tar.gz
if [ $? -ne 0 ];then exit 1; fi
# 编译keepalived
echo "=======编译keepalived v2.0.6======="
cd keepalived-2.0.6
./configure
make
if [ $? -ne 0 ];then echo "编译keepalived失败，退出脚本";exit 1;fi
cd ..
cp keepalived-2.0.6/bin/keepalived ${KEEPALIVED_PATH}/
rm -rf keepalived-2.0.6

echo "========解压etcd v3.3.8========="
# curl -O https://github.com/coreos/etcd/releases/download/v3.3.8/etcd-v3.3.8-linux-amd64.tar.gz
mkdir -p ${ETCD_PATH}
tar -xzvf etcd-v3.3.8-linux-amd64.tar.gz \
etcd-v3.3.8-linux-amd64/etcd*
if [ $? -ne 0 ];then exit 1; fi
cp etcd-v3.3.8-linux-amd64/etcd* ${ETCD_PATH}/
rm -rf etcd-v3.3.8-linux-amd64

echo "========解压flannel v0.10.0========="
#curl -O https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz
mkdir -p ${FLANNEL_PATH}
tar -xzvf flannel-v0.10.0-linux-amd64.tar.gz -C ${FLANNEL_PATH}
if [ $? -ne 0 ];then exit 1; fi

echo "========解压kubernetes v1.11.0========="
# 要使用其它版本的kubernetes 请到https://github.com/kubernetes/kubernetes/releases 查看
# 对应的版本的CHANGELOG.md. 找到对应的链接下载
# curl -O https://dl.k8s.io/v1.11.0/kubernetes-server-linux-amd64.tar.gz

tar -xzvf kubernetes-server-linux-amd64.tar.gz \
kubernetes/server/bin/kube* \
--exclude=kubernetes/server/bin/{*.tar,*.docker_tag}
if [ $? -ne 0 ];then exit 1; fi

mkdir -p ${KUBECTL_PATH}
cp kubernetes/server/bin/{kubectl,kubeadm} ${KUBECTL_PATH}/

mkdir -p ${APISERVER_PATH}
cp kubernetes/server/bin/kube-apiserver ${APISERVER_PATH}/

mkdir -p ${CONTROLLER_MANAGER_PATH}
cp kubernetes/server/bin/kube-controller-manager ${CONTROLLER_MANAGER_PATH}/

mkdir -p ${SCHEDULER_PATH}
cp kubernetes/server/bin/kube-scheduler ${SCHEDULER_PATH}/

mkdir -p ${KUBELET_PATH}
cp kubernetes/server/bin/kubelet ${KUBELET_PATH}/

mkdir -p ${KUBEPROXY_PATH}
cp kubernetes/server/bin/kube-proxy ${KUBEPROXY_PATH}/
rm -rf kubernetes

echo "======验证StrictHostKeyChecking======"
if [ -f ~/.ssh/known_hosts ]; then
rm -rf ~/.ssh/known_hosts
fi
for ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${ip}"
    ssh root@${ip} echo "skip host authenticity"
  done
if [ $? -ne 0 ];then echo "验证失败，退出脚本";exit 1;fi

echo "=======创建调试脚本======="
cat > getlog-master.sh <<EOF
sed -n -e '/Keepalived/p' /var/log/messages > keepalived.log
sed -n -e '/haproxy/p' /var/log/messages > haproxy.log
EOF
ls getlog-master.sh

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
        ssh root@${MASTER_IPS[i]} "
          if [ \"\`sed -n -e '/${MASTER_IPS[j]}\s\+${MASTER_NAMES[j]}/p' \
            /etc/hosts\`\" ]
          then
            echo 'skip'
          else
            echo '追加${MASTER_IPS[j]} ${MASTER_NAMES[j]}'
            echo '${MASTER_IPS[j]} ${MASTER_NAMES[j]}' >> /etc/hosts
          fi
          "
      done
  done
if [ $? -ne 0 ];then echo "设置master机器环境失败，退出脚本";exit 1;fi


# 设置node机器环境
echo "=========设置node机器环境========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${NODE_IPS[i]}"

    echo "修改hosts"
    for ((j=0; j<3; j++))
      do
        ssh root@${NODE_IPS[i]} "
          if [ \"\`sed -n -e '/${NODE_IPS[j]}\s\+${NODE_NAMES[j]}/p' \
            /etc/hosts\`\" ]
          then
            echo 'skip'
          else
            echo '追加${NODE_IPS[j]} ${NODE_NAMES[j]}'
            echo '${NODE_IPS[j]} ${NODE_NAMES[j]}' >> /etc/hosts
          fi
          "
      done
  done
if [ $? -ne 0 ];then echo "设置node机器环境失败，退出脚本";exit 1;fi

rm -rf getlog-master.sh
