source ~/env.sh

# 设置集群环境
echo "=========设置master机器环境========="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "yum安装keepalived和haproxy"
    yum install -y keepalived haproxy

    echo "永久关闭firewalld"
    ssh root@${master_ip} "systemctl disable firewalld"

    echo "selinux永久使能haproxy"
    ssh root@${master_ip} "setsebool -P haproxy_connect_any=1"
  done

echo "=========设置node机器环境========="
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    echo "yum安装docker"
    yum install -y yum-utils \
      device-mapper-persistent-data lvm2
    yum-config-manager --add-repo \
      https://download.docker.com/linux/centos/docker-ce.repo
    yum install docker-ce-18.03.0.ce

    echo "永久关闭firewalld"
    ssh root@${node_ip} "systemctl disable firewalld"

    echo "永久关闭swap分区"
    ssh root@${node_ip} "/usr/sbin/swapoff -a
                         cp /etc/fstab /etc/fstab.bak
                         sed -i '/ swap / s/^\(.*\)$/#\1/g' \
                         /etc/fstab"
  done
