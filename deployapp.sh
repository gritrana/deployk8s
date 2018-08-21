source env.sh

mkdir -p ${TESTGIN_PATH}
# 编写testgin的配置文件
cat > ${TESTGIN_PATH}/config.json <<EOF
{
    "db":{
        "name": "mysql",
        "user": "root",
        "password": "1234",
        "ip": "127.0.0.1",
        "port": 3306,
        "table":"test"
    },

    "etcd":{
        "ip": "192.168.6.201",
        "port": 2379
    },

    "serverA":{
        "ip": "192.168.6.200",
        "port": 1701
    }
}
EOF
cat ${TESTGIN_PATH}/config.json

# 分发testgin配置文件
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /root/testgin"
    scp ${TESTGIN_PATH}/config.json \
    root@${node_ip}:/root/testgin/
  done

# 编写testgin部署yaml
echo "========编写testgin部署yaml========"
cat > ${TESTGIN_PATH}/testgin.yaml << EOF
---
# 创建deployment
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  #namespace: mynamespace1
  name: testgin
  labels:
    app: web
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: testgin
        image: xujintao/testgin:1.0.49
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: my-config
          mountPath: /etc/testgin
        args: [/etc/testgin/config.json]
      
      volumes:
      - name: my-config
        hostPath:
          path: /root/testgin

---
# 暴露deployment

# NODE_PORT_RANGE is [8400, 9000]
# 插件使用[8401, 8499]
# 应用使用[8501, 8599]
# 其它预留着

# SERVICE_CIDR is 10.254.0.0/16
# 插件使用[10.254.0.1, 10.254.0.255]
# 应用使用[10.254.1.1, 10.254.1.255]
# 其它预留

# kubectl expose deployment testgin --type=NodePort --port=8080
apiVersion: v1
kind: Service
metadata:
  name: testgin
  labels:
    app: web
spec:
  selector:
    app: web
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 8501
    protocol: TCP
  clusterIP: 10.254.1.1
  type: NodePort

---
# 使用ingress插件来管理服务
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: testgin
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: ingress.testgin.com
    http:
      paths:
      - backend:
          serviceName: testgin
          servicePort: 8080

EOF
cat ${TESTGIN_PATH}/testgin.yaml

# 创建testgin部署并暴露服务
echo "========创建testgin部署并暴露服务========"
kubectl apply -f ${TESTGIN_PATH}/testgin.yaml

