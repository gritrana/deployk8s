echo "Please set utf8 if Chinese garbled under minGW"
echo "=====执行公共脚本====="

echo "允许root用户远程公钥认证"
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cp /home/vagrant/.ssh/authorized_keys /root/.ssh/

echo "将yum的base源设置为aliyun"
if [ -z "`sed -n -e '/aliyun.*CentOS-7/p' /etc/yum.repos.d/CentOS-Base.repo`" ]; then
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
curl -o /etc/yum.repos.d/CentOS-Base.repo \
    http://mirrors.aliyun.com/repo/Centos-7.repo
fi

echo "禁用fastmirror插件"
sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf

echo "yum安装net-tools（centos7.5的box没有net-bools）"
yum install -y net-tools

echo "yum安装vim"
yum install -y vim
echo "alias vi=vim" >> /root/.bashrc

echo "永久关闭firewalld"
systemctl disable firewalld

echo "设置CST时区"
timedatectl set-timezone Asia/Shanghai

echo "重启依赖系统时间的服务"
systemctl restart rsyslog
systemctl restart crond