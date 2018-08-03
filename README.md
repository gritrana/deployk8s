deploy k8s manually  
![](https://github.com/xujintao/deployk8s/blob/master/deployk8s.jpg)

## 感谢
感谢 https://github.com/opsnull/follow-me-install-kubernetes-cluster 作者及其贡献者。  
它是3个节点的集群，为了更清楚的认识k8s，我这里搞了3个master和3个node。

## Quick start
第1步， 本地开发机  
所有的部署工作都是在本地开发机上进行。如果你本地已经有一个开发机了，那么就跳过这一步。  
如果没有，那么我已经给你准备好了[dev Vagrantfile](https://github.com/xujintao/deployk8s/blob/master/Vagrantfile)，你需要提供一个centos7的box，如果没有，那么可以点这个[Centos7.5m box](https://vagrantcloud.com/centos/boxes/7/versions/1804.02/providers/virtualbox.box)下载，  如果下载不来，那复制链接地址用迅雷下。

第2步，准备6个虚机  
这6个虚机的[cluster Vagrantfile](https://github.com/xujintao/deployk8s/blob/master/vagrant-cluster/Vagrantfile)我也已经准备好了，你需要提供一个centos7的box，如果没有，那么使用第1步的方法去下载个。

第3步，把机器都启动起来  
* 把Vagrantfile中的box名与box镜像关联起来
```sh
vagrant box add centos7 path_to_centos7
```
* 启动本地开发机，自己的开发机自行启动  
```sh
vagrant up dev
```
以后就使用dev来指代本地开发机。
图方便我已经把不安全的公钥添加到集群机器的/root/.ssh/authorized_keys中了，为了让root能从dev远程登录到集群机器，需要把insecure_private_key弄到dev的~/.ssh/id_rsa中，可以scp，也可以使用其他方式。

* 启动集群  
```sh
vagrant up master1
vagrant up master2
vagrant up master3
vagrant up node1
vagrant up node2
vagrant up node3
```
这一步如果成功了，那么基本就成功了一半。

第4步，git clone  
```sh
git clone git@github.com:xujintao/deployk8s.git
cd deployk8s
```

第5步，部署集群环境  
```sh
# 下载cfssl
curl -O https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -O https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
curl -O https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64

# 下载etcd v3.3.8
curl -O https://github.com/coreos/etcd/releases/download/v3.3.8/etcd-v3.3.8-linux-amd64.tar.gz

# 下载flannel v0.10.0
curl -O https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz

# 下载kubernetes v1.11.0
curl -O https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz

# 下载kubernetes v1.11.0
curl -O https://dl.k8s.io/v1.11.0/kubernetes-server-linux-amd64.tar.gz

./deployenv.sh
```

第6步，部署ca  
```sh
./deployca.sh
```

第7步，部署etcd
```sh
./deployetcd.sh
```

第8步，部署flannel网络
```sh
./deployflannel.sh
```

第9步，部署docker
```sh
./deploydocker.sh
```

第10步，部署ha高可用
```sh
./deployha.sh
```

第11步，部署kube-apiserver
```sh
./deployapiserver.sh
```

第12步，部署kube-controller-manager
```sh
./deploycontrollermanager.sh
```

第13步，部署kube-scheduler
```sh
./deployscheduler.sh
```

第14步，部署kubelet
```sh
./deploykubelet.sh
```

第15步，部署kube-proxy
```sh
./deploykubeproxy.sh
```

第16步，部署应用
```sh
./deployapp.sh
```

## Document
每一步对应的说明。


