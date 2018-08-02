source env.sh

# 设置集群环境
echo "=========设置master机器环境========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${MASTER_IPS[i]}"
    echo "修改hosts，追加${MASTER_IPS[i]} ${MASTER_NAMES[i]}"
    ssh root@${MASTER_IPS[i]} \
      "echo '${MASTER_IPS[i]} ${MASTER_NAMES[i]}' >> /etc/hosts"
  done

echo "=========设置node机器环境========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${NODE_IPS[i]}"
    echo "修改hosts，追加${NODE_IPS[i]} ${NODE_NAMES[i]}"
    ssh root@${NODE_IPS[i]} \
      "echo '${NODE_IPS[i]} ${NODE_NAMES[i]}' >> /etc/hosts"
  done
