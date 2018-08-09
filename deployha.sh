source env.sh

# 配置haproxy模板
echo "============配置haproxy模板=========="
cat > haproxy.cfg <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /var/lib/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    nbproc 1

defaults
    log global
    timeout connect 5000
    timeout client 10m
    timeout server 10m

listen admin_stats
    bind 0.0.0.0:10080
    mode http
    log 127.0.0.1 local0 err
    stats refresh 30s
    stats uri /status
    stats realm welcome login\ Haproxy
    stats auth admin:123456
    stats hide-version
    stats admin if TRUE

listen kube-master
    bind 0.0.0.0:8443
    mode tcp
    option tcplog
    balance source
    server ${MASTER_IPS[0]} ${MASTER_IPS[0]}:6443 check inter 2000 fall 2 rise 2 weight 1
    server ${MASTER_IPS[1]} ${MASTER_IPS[1]}:6443 check inter 2000 fall 2 rise 2 weight 1
    server ${MASTER_IPS[2]} ${MASTER_IPS[2]}:6443 check inter 2000 fall 2 rise 2 weight 1
EOF
cat haproxy.cfg

# 分发haproxy配置文件及启动服务
echo "==========分发haproxy配置文件及启动服务=========="
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    echo "分发haproxy配置文件"
    ssh root@${master_ip} "mkdir -p /etc/haproxy"
    scp haproxy.cfg root@${master_ip}:/etc/haproxy/

    echo "启动haproxy服务"
    ssh root@${master_ip} "
      mkdir -p /var/lib/haproxy
      systemctl enable haproxy
      systemctl restart haproxy
      echo 'wait 3s for haproxy up'
      sleep 3
      systemctl status haproxy | grep Active
      netstat -lnpt | grep haproxy"
    if [ $? -ne 0 ];then echo "启动haproxy服务失败，退出脚本";exit 1;fi
  done

# 编译keepalived
echo "=======编译keepalived======="
cd keepalived-2.0.6
./configure
make
if [ $? -ne 0 ];then echo "编译keepalived失败，退出脚本";exit 1;fi
cd ..

# 创建keepalived systemd unit文件
echo "=========创建keepalived systemd unit文件========="
cat > keepalived.service <<"EOF"
[Unit]
Description=LVS and VRRP High Availability Monitor
After= network-online.target syslog.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/keepalived.pid
KillMode=process
EnvironmentFile=-/etc/sysconfig/keepalived
ExecStart=/usr/local/bin/keepalived $KEEPALIVED_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF
cat keepalived.service

# 创建keepalived启动文件
echo "=========创建keepalived启动文件========="
cat > keepalived.env <<"EOF"
# Options for keepalived. See `keepalived --help' output and keepalived(8) and
# keepalived.conf(5) man pages for a list of all options. Here are the most
# common ones :
#
# --vrrp               -P    Only run with VRRP subsystem.
# --check              -C    Only run with Health-checker subsystem.
# --dont-release-vrrp  -V    Dont remove VRRP VIPs & VROUTEs on daemon stop.
# --dont-release-ipvs  -I    Dont remove IPVS topology on daemon stop.
# --dump-conf          -d    Dump the configuration data.
# --log-detail         -D    Detailed log messages.
# --log-facility       -S    0-7 Set local syslog facility (default=LOG_DAEMON)
#

KEEPALIVED_OPTIONS="-D"

EOF
cat keepalived.env

# keepalived-master配置文件
echo "=========keepalived-master配置文件========="
cat > keepalived-master.conf <<EOF
global_defs {
    router_id lb-master-105
}
vrrp_script check-haproxy {
    script "killall -0 haproxy"
    interval 5
    weight -30
}
vrrp_instance VI-kube-master {
    state MASTER
    priority 120
    dont_track_primary
    interface ${VIP_IF}
    virtual_router_id 68
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        ${MASTER_VIP}
    }
}
EOF
cat keepalived-master.conf

# keepalived-backup配置文件
echo "=========keepalived-backup配置文件========="
cat > keepalived-backup.conf <<EOF
global_defs {
    router_id lb-backup-105
}
vrrp_script check-haproxy {
    script "killall -0 haproxy"
    interval 5
    weight -30
}
vrrp_instance VI-kube-master {
    state BACKUP
    priority 110
    dont_track_primary
    interface ${VIP_IF}
    virtual_router_id 68
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        ${MASTER_VIP}
    }
}
EOF
cat keepalived-backup.conf

# 分发keepalived配置文件及启动
echo "==========分发keepalived配置文件及启动========"
for (( i=0; i < 3; i++ ))
  do
    echo ">>> ${MASTER_IPS[i]}"
    echo "分发keepalived二进制"
    ssh root@${MASTER_IPS[i]} "
      if [ -f /usr/local/bin/keepalived ];then
      systemctl stop keepalived
      rm -f /usr/local/bin/keepalived
      fi"
    scp keepalived-2.0.6/bin/keepalived \
      root@${MASTER_IPS[i]}:/usr/local/bin/

    echo "分发keepalived的systemd unit文件"
    scp keepalived.service \
      root@${MASTER_IPS[i]}:/usr/lib/systemd/system/keepalived.service

    echo "分发keepalived启动文件"
    scp keepalived.env \
        root@${MASTER_IPS[i]}:/etc/sysconfig/keepalived

    echo "分发keepalived配置文件"
    ssh root@${MASTER_IPS[i]} "mkdir -p /etc/keepalived"
    if [ $i -eq 0 ];then
      scp keepalived-master.conf \
        root@${MASTER_IPS[i]}:/etc/keepalived/keepalived.conf
    else
      scp keepalived-backup.conf \
        root@${MASTER_IPS[i]}:/etc/keepalived/keepalived.conf
    fi

    echo "启动keepalived服务，检查服务"
    ssh root@${MASTER_IPS[i]} "
      systemctl daemon-reload
      systemctl enable keepalived
      systemctl restart keepalived"

    echo "验证keepalived服务"
    if [ $i -eq 0 ]
    then
        echo 'wait 10s for setting vip'
        sleep 10
    else
        echo 'wait 3s for keepalived up'
        sleep 3
    fi
    ssh root@${MASTER_IPS[i]} "
      systemctl status keepalived | grep Active
      /usr/sbin/ip addr show ${VIP_IF}
      ping -c 3 ${MASTER_VIP}"
    if [ $? -ne 0 ];then echo "启动keepalived服务失败，退出脚本";exit 1;fi
  done

