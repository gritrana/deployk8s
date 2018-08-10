source env.sh

# 创建kubelet证书签名请求
echo "=========创建kubelet证书签名请求========"
cat > kubelet-csr.json <<EOF
{
    "CN": "kubelet",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "system:masters",
            "OU": "kubelet"
        }
    ]
}
EOF
cat kubelet-csr.json

# 创建kubelet证书和私钥
echo "=======创建kubelet证书和私钥======="
cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=kubernetes kubelet-csr.json | cfssljson -bare kubelet
ls kubelet*.pem

# 创建kubelet kubeconfig文件
echo "=========创建kubelet kubeconfig文件========="
# 配置要访问的集群cluster1（ip和证书）
kubectl config set-cluster cluster1 \
--certificate-authority=/etc/kubernetes/cert/ca.pem \
--server=${KUBE_APISERVER} \
--kubeconfig=kubelet.kubeconfig

# 配置kubelet1用户（证书和私钥）
kubectl config set-credentials kubelet1 \
--client-certificate=/etc/kubernetes/cert/kubelet.pem \
--client-key=/etc/kubernetes/cert/kubelet-key.pem \
--kubeconfig=kubelet.kubeconfig

# 配置context1
kubectl config set-context context1 \
--cluster=cluster1 \
--user=kubelet1 \
--kubeconfig=kubelet.kubeconfig

# 设置context1为当前的context
kubectl config use-context context1 --kubeconfig=kubelet.kubeconfig
cat kubelet.kubeconfig

# 创建kubelet参数配置模板文件
echo "========创建kubelet参数配置模板文件======="
cat > kubelet.config.json.template <<EOF
{
    "kind": "KubeletConfiguration",
    "apiVersion": "kubelet.config.k8s.io/v1beta1",
    "authentication": {
        "x509": {
            "clientCAFile": "/etc/kubernetes/cert/ca.pem"
        },
        "webhook": {
            "enabled": true,
            "cacheTTL": "2m0s"
        },
        "anonymous": {
            "enabled": false
        }
    },
    "authorization": {
        "mode": "Webhook",
        "webhook": {
            "cacheAuthorizedTTL": "5m0s",
            "cacheUnauthorizedTTL": "30s"
        }
    },
    "address": "##NODE_IP##",
    "port": 10250,
    "readOnlyPort": 0,
    "cgroupDriver": "cgroupfs",
    "hairpinMode": "promiscuous-bridge",
    "serializeImagePulls": false,
    "featureGates": {
        "RotateKubeletClientCertificate": true,
        "RotateKubeletServerCertificate": true
    },
    "clusterDomain": "${CLUSTER_DNS_DOMAIN}",
    "clusterDNS": ["${CLUSTER_DNS_SVC_IP}"]
}
EOF
ls kubelet.config.json.template

# 创建kubelet参数配置文件
echo "========创建kubelet参数配置文件========="
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    sed -e "s/##NODE_IP##/${node_ip}/" \
      kubelet.config.json.template > \
      kubelet.config-${node_ip}.json
    cat kubelet.config-${node_ip}.json
  done

# 创建kubelet systemd service模板文件
echo "========创建kubelet systemd service模板文件======="
cat > kubelet.service.template <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet \\
--cert-dir=/etc/kubernetes/cert \\
--kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
--config=/etc/kubernetes/kubelet.config.json \\
--hostname-override=##NODE_NAME## \\
--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest \\
--allow-privileged=true \\
--alsologtostderr=true \\
--logtostderr=false \\
--log-dir=/var/log/kubernetes \\
--v=2
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
ls kubelet.service.template

# 创建kubelet systemd service文件
echo "=========创建kubelet systemd service文件========="
for ((i=0; i<3; i++))
  do
    echo ">>> ${NODE_IPS[i]}"
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" \
      kubelet.service.template > \
      kubelet-${NODE_IPS[i]}.service
    cat kubelet-${NODE_IPS[i]}.service
  done

# 分发并启动kubelet
echo "=========分发并启动kubelet======="
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    echo "分发kubelet二进制文件"
    ssh root@${node_ip} "
      if [ -f /usr/local/bin/kubelet ];then
      systemctl stop kubelet
      rm -f /usr/local/bin/kubelet
      fi"
    scp kubernetes/server/bin/kubelet root@${node_ip}:/usr/local/bin/

    echo "分发kubelet证书和私钥"
    ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert"
    scp kubelet*.pem root@${node_ip}:/etc/kubernetes/cert/

    echo "分发kubelet kubeconfig文件"
    ssh root@${node_ip} "mkdir -p /etc/kubernetes"
    scp kubelet.kubeconfig \
      root@${node_ip}:/etc/kubernetes/kubelet.kubeconfig

    echo "分发kubelet参数配置文件"
    scp kubelet.config-${node_ip}.json \
      root@${node_ip}:/etc/kubernetes/kubelet.config.json

    echo "分发kubelet systemd service文件"
    scp kubelet-${node_ip}.service \
      root@${node_ip}:/usr/lib/systemd/system/kubelet.service

    echo "启动kubelet"
    ssh root@${node_ip} "
      mkdir -p /var/lib/kubelet
      mkdir -p /var/log/kubernetes
      systemctl daemon-reload
      systemctl enable kubelet
      systemctl start kubelet
      echo 'wait 5s for kubelet up'
      sleep 5
      systemctl status kubelet | grep Active
      netstat -lnpt | grep kubelet"

    if [ $? -ne 0 ];then echo "启动kubelet失败，退出脚本";exit 1;fi
  done

