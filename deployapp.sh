source env.sh

# 编写testgin部署yaml
echo "========编写testgin部署yaml========"
cat > testgin.yaml << EOF
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
            path: /home/k8s/testgin

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
ls testgin.yaml

# 分发testgin配置文件
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh k8s@${node_ip} "mkdir -p /home/k8s/testgin"
    scp config.json k8s@${node_ip}:/home/k8s/testgin/
  done

# 创建testgin部署并暴露服务
echo "========创建testgin部署并暴露服务========"
kubectl create -f testgin.yaml

