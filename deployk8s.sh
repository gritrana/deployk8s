date

echo "第5步，部署集群环境"
./deployenv.sh
if [ $? -ne 0 ]
then
  echo "第5步，部署集群环境失败"
  exit
else
  echo "第5步，部署集群环境成功"
  echo -e
fi

echo "第6步，部署keepalived和haproxy高可用"
./deployha.sh
if [ $? -ne 0 ]
then
  echo "第6步，部署keepalived和haproxy高可用失败"
  exit
else
  echo "第6步，部署keepalived和haproxy高可用成功"
  echo -e
fi

echo "第7步，部署CA根证书"
./deployca.sh
if [ $? -ne 0 ]
then
  echo "第7步，部署CA根证书失败"
  exit
else
  echo "第7步，部署CA根证书成功"
  echo -e
fi

echo "第8步，部署coreos家的产品"
echo "8.1部署etcd"
./deployetcd.sh
if [ $? -ne 0 ]
then
  echo "8.1部署etcd失败"
  exit
else
  echo "8.1部署etcd成功"
  echo -e
fi

echo "8.2部署flannel网络"
./deployflannel.sh
if [ $? -ne 0 ]
then
  echo "8.2部署flannel网络失败"
  exit
else
  echo "8.2部署flannel网络成功"
  echo -e
fi

echo "第9步，部署docker"
./deploydocker.sh
if [ $? -ne 0 ]
then
  echo "第9步，部署docker失败"
  exit
else
  echo "第9步，部署docker成功"
  echo -e
fi

echo "第10步，部署k8s全家桶"
echo "10.1部署kubectl到dev"
./deploykubectl.sh
if [ $? -ne 0 ]
then
  echo "10.1部署kubectl失败"
  exit
else
  echo "10.1部署kubectl成功"
  echo -e
fi

echo "10.2部署kube-apiserver"
./deployapiserver.sh
if [ $? -ne 0 ]
then
  echo "10.2部署kube-apiserver失败"
  exit
else
  echo "10.2部署kube-apiserver成功"
  echo -e
fi

echo "10.3部署kube-controller-manager"
./deploycontrollermanager.sh
if [ $? -ne 0 ]
then
  echo "10.3部署kube-controller-manager失败"
  exit
else
  echo "10.3部署kube-controller-manager成功"
  echo -e
fi

echo "10.4部署kube-scheduler"
./deployscheduler.sh
if [ $? -ne 0 ]
then
  echo "10.4部署kube-scheduler失败"
  exit
else
  echo "10.4部署kube-scheduler成功"
  echo -e
fi

echo "10.5部署kubelet"
./deploykubelet.sh
if [ $? -ne 0 ]
then
  echo "10.5部署kubelet失败"
  exit
else
  echo "10.5部署kubelet成功"
  echo -e
fi

echo "10.6部署kube-proxy"
./deploykubeproxy.sh
if [ $? -ne 0 ]
then
  echo "10.6部署kube-proxy失败"
  exit
else
  echo "10.6部署kube-proxy成功"
  echo -e
fi
echo "第10步，部署k8s全家桶成功了"

echo "k8s集群部署完成了，使用kubectl get nodes验证一下"

