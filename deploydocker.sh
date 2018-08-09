source env.sh

# 创建docker systemd service文件
echo "========创建docker systemd service文件========"
cat > docker.service <<"EOF"
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service flanneld.service
Wants=network-online.target flanneld.service

[Service]
Type=notify
EnvironmentFile=-/run/flannel/docker
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd $DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF
cat docker.service

# 分发docker systemd service文件和启动
echo "========分发docker systemd service文件和启动========"
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    echo "分发docker.service"
    scp docker.service root@${node_ip}:/usr/lib/systemd/system/

    echo "启动docker"
    ssh root@${node_ip} "
      systemctl stop firewalld
      systemctl disable firewalld
      systemctl daemon-reload
      systemctl enable docker
      systemctl restart docker
      echo 'wait 3s for docker up'
      sleep 3
      systemctl status docker | grep Active
      /usr/sbin/ip addr show flannel.1
      /usr/sbin/ip addr show docker0"
    if [ $? -ne 0 ];then echo "启动docker失败，退出脚本";exit 1;fi
  done
