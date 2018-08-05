echo "=====执行master私有脚本====="

echo "yum安装keepalived和haproxy"
yum install -y keepalived haproxy

echo "selinux永久使能haproxy"
setsebool -P haproxy_connect_any=1

echo "安装psmisc，不然killall命令没法用"
yum install -y psmisc