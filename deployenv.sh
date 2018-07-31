source ~/env.sh

# 设置集群环境
echo "=========设置master机器环境========="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "永久关闭firewalld"
    ssh k8s@${master_ip} "sudo systemctl disable firewalld"

    echo "selinux永久使能haproxy"
    ssh k8s@${master_ip} "sudo setsebool -P haproxy_connect_any=1"
  done

echo "=========设置node机器环境========="
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    echo "永久关闭firewalld"
    ssh k8s@${node_ip} "sudo systemctl disable firewalld"

    echo "永久关闭swap分区"
    ssh k8s@${node_ip} "sudo /usr/sbin/swapoff -a
                        sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' \
                        /etc/fstab"
  done
