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
          image: xujintao/testgin:1.0.0.41
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
# kubectl expose deployment testgin --type=NodePort --port=8080
apiVersion: v1
kind: Service
metadata:
  name: testgin
  labels:
    app: web
spec:
  ports:
    - port: 8080
      targetPort: 8080
      #nodePort: default, see NODE_PORT_RANGE from env.sh
      protocol: TCP
  selector:
    app: web
EOF
cat ${TESTGIN_PATH}/testgin.yaml

# 创建testgin部署并暴露服务
echo "========创建testgin部署并暴露服务========"
kubectl create -f ${TESTGIN_PATH}/testgin.yaml

