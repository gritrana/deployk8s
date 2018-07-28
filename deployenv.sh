source ~/env.sh



# 设置集群环境
echo "=========设置集群环境========="
for master_node_ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${master_node_ip}"
   # echo "添加/opt/k8s/bin到PATH"
   # ssh k8s@${master_node_ip} "echo 'export PATH=$PATH:/opt/k8s/bin' >> /home/k8s/.bashrc" #如何解决$PATH替换的问题？
    
    echo "关闭firewalld"
    ssh k8s@${master_node_ip} "sudo systemctl stop firewalld"

    # 修复tarting proxy admin_stats: cannot bind socket [0.0.0.0:10080]
    # 临时关闭selinux或者设置setsebool haproxy_connect_any=1
    echo "临时关闭selinux"
    ssh k8s@${master_node_ip} "sudo setenforce 0"
  done
