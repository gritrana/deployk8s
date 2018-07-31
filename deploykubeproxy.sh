source env.sh

# 创建kube-proxy证书签名请求
echo "=========创建kube-proxy证书签名请求========"
cat > kube-proxy-csr.json <<EOF
{
    "CN": "system:kube-proxy",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "k8s",
            "OU": "4Paradigm"
        }
    ]
}
EOF
ls kube-proxy-csr.json

# 创建kube-proxy证书和私钥
echo "=======创建kube-proxy证书和私钥======="
cfssl gencert \
-ca=/etc/kubernetes/cert/ca.pem \
-ca-key=/etc/kubernetes/cert/ca-key.pem \
-config=/etc/kubernetes/cert/ca-config.json \
-profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
ls kube-proxy*.pem

# 创建kube-proxy kubeconfig文件
echo "=========创建kube-proxy kubeconfig文件========="
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/cert/ca.pem \
--server=${KUBE_APISERVER} \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy \
--client-certificate=/etc/kubernetes/cert/kube-proxy.pem \
--client-key=/etc/kubernetes/cert/kube-proxy-key.pem \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
--cluster=kubernetes \
--user=kube-proxy \
--kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
ls kube-proxy.kubeconfig

# 创建kube-proxy配置模板
echo "=========创建kube-proxy配置模板========"
cat > kube-proxy.config.yaml.template <<EOF
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: ##NODE_IP##
clientConnection:
  kubeconfig: /etc/kubernetes/kube-proxy.kubeconfig
clusterCIDR: ${CLUSTER_CIDR}
healthzBindAddress: ##NODE_IP##:10256
hostnameOverride: ##NODE_NAME##
kind: KubeProxyConfiguration
metricsBindAddress: ##NODE_IP##:10249
mode: "iptables"
EOF
ls kube-proxy.config.yaml.template

# 创建kube-proxy配置文件
echo "=========创建kube-proxy配置文件========"
for ((i=0; i < 3; i++))
  do
    echo ">>> ${NODE_IPS[i]}"
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" \
        -e "s/##NODE_IP##/${NODE_IPS[i]}/" \
        kube-proxy.config.yaml.template > \
        kube-proxy-${NODE_IPS[i]}.config.yaml
    ls kube-proxy-${NODE_IPS[i]}.config.yaml
  done

# 创建kube-proxy systemd service文件
echo "========创建kube-proxy systemd service文件========="
cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=/var/lib/kube-proxy
ExecStart=/opt/k8s/bin/kube-proxy \\
--config=/etc/kubernetes/kube-proxy.config.yaml \\
--alsologtostderr=true \\
--logtostderr=false \\
--log-dir=/var/log/kubernetes \\
--v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
ls kube-proxy.service

# 分发kube-proxy并启动
echo "=======分发kube-proxy并启动========"
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    echo "分发kube-proxy二进制文件"
    ssh k8s@${node_ip} "sudo mkdir -p /opt/k8s/bin
                        sudo chown -R k8s:k8s /opt/k8s
                        if [ -f /opt/k8s/bin/kube-proxy ];then
                        sudo systemctl stop kube-proxy
                        rm -f /opt/k8s/bin/kube-proxy
                        fi"
    scp kubernetes/server/bin/kube-proxy \
      k8s@${node_ip}:/opt/k8s/bin/
    
    echo "分发kube-proxy证书和私钥"
    ssh k8s@${node_ip} "sudo mkdir -p /etc/kubernetes/cert
                        sudo chown -R k8s:k8s /etc/kubernetes"
    scp kube-proxy*.pem k8s@${node_ip}:/etc/kubernetes/cert/

    echo "分发kube-proxy kubeconfig文件"
    ssh k8s@${node_ip} "sudo mkdir -p /etc/kubernetes
                        sudo chown -R k8s:k8s /etc/kubernetes"
    scp kube-proxy.kubeconfig k8s@${node_ip}:/etc/kubernetes/

    echo "分发kube-proxy配置文件"
    scp kube-proxy-${node_ip}.config.yaml \
      k8s@${node_ip}:/etc/kubernetes/kube-proxy.config.yaml

    echo "分发kube-proxy systemd service文件"
    scp kube-proxy.service \
      root@${node_ip}:/usr/lib/systemd/system/

    echo "启动kube-proxy"
    ssh k8s@${node_ip} "sudo mkdir -p /var/lib/kube-proxy
                        sudo mkdir -p /var/log/kubernetes
                        sudo chown -R k8s:k8s /var/log/kubernetes
                        sudo systemctl daemon-reload
                        sudo systemctl enable kube-proxy
                        sudo systemctl start kube-proxy
                        sudo systemctl status kube-proxy \
                        | grep Active
                        sudo netstat -lnpt | grep kube-pro"
  done
