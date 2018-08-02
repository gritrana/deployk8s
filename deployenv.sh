source env.sh

# 设置集群环境
echo "=========设置master机器环境========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${MASTER_IPS[i]}"
    for ((j=0; j<3; j++))
      do
        echo "修改hosts，追加${MASTER_IPS[j]} ${MASTER_NAMES[j]}"
        ssh root@${MASTER_IPS[i]} \
          "echo '${MASTER_IPS[j]} ${MASTER_NAMES[j]}' >> /etc/hosts"
#          "if [ -z `awk '/$MASTER_IPS[j] $MASTER_NAMES[j]/' /etc/hosts` ];then
#           echo '${MASTER_IPS[j]} ${MASTER_NAMES[j]}' >> /etc/hosts
#           fi"
      done
  done

echo "=========设置node机器环境========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${NODE_IPS[i]}"
    for ((j=0; j<3; j++))
      do
        echo "修改hosts，追加${NODE_IPS[j]} ${NODE_NAMES[j]}"
        ssh root@${NODE_IPS[i]} \
          "echo '${NODE_IPS[j]} ${NODE_NAMES[j]}' >> /etc/hosts"
      done
  done

