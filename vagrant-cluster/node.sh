echo "=====执行node私有脚本====="

echo "yum安装docker"
yum install -y yum-utils \
    device-mapper-persistent-data lvm2
yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-18.03.0.ce

echo "永久关闭swap分区"
/usr/sbin/swapoff -a
if [ -z "`sed -n -e '/^#.*swap.*/p' /etc/fstab`" ]; then
cp /etc/fstab /etc/fstab.bak
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
fi