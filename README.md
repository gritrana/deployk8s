![](https://github.com/xujintao/deployk8s/blob/master/deployk8s.jpg)

## 感谢
感谢 https://github.com/opsnull/follow-me-install-kubernetes-cluster 作者及其贡献者。  
它是3个节点的集群，为了更清楚的认识k8s，我这里搞了3个master和3个node，那个dev是用来分发的或者说是用来操作集群的。  
如果部署过程中遇到什么问题可以提issues也可以加这个QQ群95786324  
改进和pull request将会被欢迎

## Quick start
### 第1步， 本地开发机  
所有的部署工作都是在开发机(dev)上进行的。我已经准备好了[dev Vagrantfile](https://github.com/xujintao/deployk8s/blob/master/Vagrantfile)，
你需要提供一个centos7的box，如果没有，那么可以点这个[Centos7.5 box](https://vagrantcloud.com/centos/boxes/7/versions/1804.02/providers/virtualbox.box)下载，  
如果下载不来，那就复制链接地址用迅雷下。

### 第2步，准备6个虚机  
这6个虚机的[cluster Vagrantfile](https://github.com/xujintao/deployk8s/blob/master/vagrant-cluster/Vagrantfile)我也已经准备好了，也是使用的第1步的centos7的box。

### 第3步，把机器都启动起来  
* 把Vagrantfile中的box名与box镜像关联起来
```sh
# vagrant box add centos7 path_to_your_centos7
# 例如：
vagrant box add D:\Box\CentOS-7-x86_64-Vagrant-1804_02.VirtualBox.box
```
* 启动开发机(dev)  
```sh
vagrant up dev
```
以后就使用dev来指代开发机了。  
图方便我已经把不安全的公钥添加到集群机器的/root/.ssh/authorized_keys中了，  
为了让root能从dev远程登录到集群机器，需要把insecure_private_key弄到dev的~/.ssh/id_rsa中，可以scp，如果使用的是xshell那就用xshell自带的sftp

* 启动集群  
```sh
vagrant up master1
vagrant up master2
vagrant up master3
vagrant up node1
vagrant up node2
vagrant up node3
# 可以直接vagrant up来启动所有机器
```
到这一步如果成功了，还是很不容易的，部署工作基本成功了一半。

### 第4步，git clone  
好了好了，正式开始了，现在使用你的ssh工具进到dev里面。
先把脚本clone下来：
```sh
git clone git@github.com:xujintao/deployk8s.git
cd deployk8s
```
然后再准备几样东西（haproxy以及docker我已经内置在box里面了）：
```sh
# 下载cfssl
curl -O https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -O https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
curl -O https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64

# 下载keepalived v2.0.6
curl -O http://www.keepalived.org/software/keepalived-2.0.6.tar.gz

# 下载etcd v3.3.8
curl -O https://github.com/coreos/etcd/releases/download/v3.3.8/etcd-v3.3.8-linux-amd64.tar.gz

# 下载flannel v0.10.0
curl -O https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz

# 下载kubernetes v1.11.0
curl -O https://dl.k8s.io/v1.11.0/kubernetes-server-linux-amd64.tar.gz
```
最后就开始执行脚本进行部署吧。

### 第5~10步，部署集群  
```sh
./deployk8s.sh 2>&1 | tee deployk8s.log
```
这个部署脚本会打印出日志，通过日志来定位哪里出了问题。

### 第11步，预留  

### 第12步，部署自己的应用（这是可选的）  
比如我自己的一个docker镜像：
```sh
./deployapp.sh | tee deployapp.log
```

## Document
每一步对应的说明。


