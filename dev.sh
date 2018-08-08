echo "Please set utf8 if Chinese garbled under minGW"

echo "不认证主机公钥"
sed -i 's/^#\s\+StrictHostKeyChecking ask/StrictHostKeyChecking no/' \
/etc/ssh/ssh_config

echo "将yum的base源设置为aliyun"
if [ -z "`sed -n -e '/aliyun.*CentOS-7/p' /etc/yum.repos.d/CentOS-Base.repo`" ]; then
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
curl -o /etc/yum.repos.d/CentOS-Base.repo \
http://mirrors.aliyun.com/repo/Centos-7.repo
fi

echo "禁用fastmirror插件"
sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf

echo "yum安装git"
yum install -y git

echo "yum安装vim"
yum install -y vim

echo "yum安装gcc等(用来编译keepalived)"
yum install -y gcc openssl-devel libnl3-devel net-snmp-devel libnfnetlink-devel

echo "设置CST时区"
timedatectl set-timezone Asia/Shanghai

echo "重启依赖系统时间的服务"
systemctl restart rsyslog
systemctl restart crond