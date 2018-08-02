source ~/env.sh

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
    echo "分发keepalive配置文件"
    ssh root@${MASTER_IPS[i]} "mkdir -p /etc/keepalived"
    if [ $i -eq 0 ];then
      scp keepalived-master.conf \
        root@${MASTER_IPS[i]}:/etc/keepalived/keepalived.conf
    else
      scp keepalived-backup.conf \
        root@${MASTER_IPS[i]}:/etc/keepalived/keepalived.conf
    fi

    echo "启动keepalived服务，检查服务"
    ssh root@${MASTER_IPS[i]} "yum install -y keepalived
                               systemctl enable keepalived
                               systemctl restart keepalived
                               systemctl status keepalived \
                               | grep Active
                               /usr/sbin/ip addr show ${VIP_IF}
                               ping -c 1 ${MASTER_VIP}"
  done

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
    ssh root@${master_ip} "yum install -y haproxy
                           systemctl enable haproxy
                           mkdir -p /var/lib/haproxy
                           systemctl restart haproxy
                           systemctl status haproxy | grep Active
                           netstat -lnpt | grep haproxy"
  done

