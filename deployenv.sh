source ~/env.sh

# 设置集群环境
echo "=========设置所有机器环境========="
for master_node_ip in ${MASTER_NODE_IPS[@]}
  do
    echo ">>> ${master_node_ip}"
    ssh k8s@${master_node_ip} "sudo setsebool -P haproxy_connect_any=1
                               sudo systemctl disable firewalld"
  done
