![](https://github.com/xujintao/deployk8s/blob/master/deployk8s.jpg)

## 感谢
感谢 https://github.com/opsnull/follow-me-install-kubernetes-cluster 作者及其贡献者。  
它是3个节点的集群，为了更清楚的认识k8s，我这里搞了3个master和3个node，那个dev是用来分发的或者说是用来操作集群的。  
如果部署过程中遇到什么问题可以提issues也可以加这个QQ群95786324,  
欢迎帮忙改进和pull request。

## Quick start
### 第1步， 本地开发机  
所有的部署工作都是在开发机(dev)上进行。如果你已经有一个开发机并且坚持想使用自己的dev了，那么就跳过这一步。  
如果没有，那么我已经给你准备好了[dev Vagrantfile](https://github.com/xujintao/deployk8s/blob/master/Vagrantfile)，你需要提供一个centos7的box，如果没有，那么可以点这个[Centos7.5m box](https://vagrantcloud.com/centos/boxes/7/versions/1804.02/providers/virtualbox.box)下载，  如果下载不来，那复制链接地址用迅雷下。

### 第2步，准备6个虚机  
这6个虚机的[cluster Vagrantfile](https://github.com/xujintao/deployk8s/blob/master/vagrant-cluster/Vagrantfile)我也已经准备好了，你需要提供一个centos7的box，如果没有，那么使用第1步的方法去下载个。

### 第3步，把机器都启动起来  
* 把Vagrantfile中的box名与box镜像关联起来
```sh
# vagrant box add centos7 path_to_your_centos7
vagrant box add D:\Box\CentOS-7-x86_64-Vagrant-1804_02.VirtualBox.box
```
* 启动开发机(dev)，自己的开发机自行启动  
```sh
vagrant up dev
```
以后就使用dev来指代开发机。
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
到这一步如果成功了，还是很不容易的，部署工作基本成功了一半。

### 第4步，git clone  
好了好了，正式开始了，现在使用你的ssh工具进到dev里面。
先把脚本clone下来：
```sh
git clone git@github.com:xujintao/deployk8s.git
cd deployk8s
```
然后再准备几样东西（keepalived, haproxy以及docker我已经内置在box里面了）：
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
curl -O https://dl.k8s.io/v1.11.0/kubernetes-server-linux-amd64.tar.gz
```
最后就开始执行脚本进行部署吧。

### 第5步，部署集群环境  
```sh
./deployenv.sh
```

### 第6步，部署keepalived和haproxy高可用  
```sh
./deployha.sh
```

### 第7步，部署CA根证书  
```sh
./deployca.sh
```

### 第8步，部署coreos家的产品
* 7.1部署etcd  
```sh
./deployetcd.sh
```

* 7.2部署flannel网络  
```sh
./deployflannel.sh
```

### 第9步，部署docker  
```sh
./deploydocker.sh
```
以上都是基础设施。

### 第10步，部署k8s全家桶  
* 10.1部署kubectl到dev  
```sh
./deploykubectl.sh
```

* 10.2部署kube-apiserver  
```sh
./deployapiserver.sh
```

* 10.3部署kube-controller-manager  
```sh
./deploycontrollermanager.sh
```

* 10.4部署kube-scheduler  
```sh
./deployscheduler.sh
```

* 10.5部署kubelet  
```sh
./deploykubelet.sh
```

* 10.6部署kube-proxy  
```sh
./deploykubeproxy.sh
```

### 第11步，预留  

### 第12步，部署应用  
```sh
./deployapp.sh
```

## Document
每一步对应的说明。


