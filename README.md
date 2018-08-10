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

### 证书签名请求与RBAC的对应关系  
该命令`kubectl get clusterrolebindings -o wide`可以得到下面这个表格  
可以看到kubernetes预留的subeject被绑定到哪个角色了。subjects就是下面表格中的usr/group/serviceaccounts
| cluster-role-binding | cluster-role | user | group | service-accounts |
| ------ | ------ | ------ | ------ | ------ |
| cluster-admin | cluster-admin |  | system:masters |  |
| system:kube-controller-manager | system:kube-controller-manager | system:kube-controller-manager |  |  |
| system:kube-scheduler | system:kube-scheduler | system:kube-scheduler |  |  |
| system:node | system:node |  |  |  |
| system:node-proxier | system:node-proxier | system:kube-proxy |  |  |
user对应的是证书签名请求中的CN字段的值，group对应的是证书签名请求中的names.O字段。
客户端访问apiserver的时候，先双向验证(authentication)，客户端解码服务器的证书验证ip和根证书，服务器解码客户端的证书然后只验证根证书。
这样tls连接就算建立起来了。接下来服务器再把客户端证书中的CN字段和names.O字段拿过去授权(authorization)，把授权结果返回给客户端。
这是个简化流程，可以这么理解。


* admin的证书签名请求  
因为绑定到cluster-admin（角色）的system:masters(subjects)是个group，  
所以names.O字段的是system:masters，其他随便写(CN字段我是为了方便演示才写的admin，其实它也是可以随便写的)。
```sh
{
    "CN": "admin",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "system:masters",
            "OU": "123"
        }
    ]
}
```

* kube-controller-manager的证书签名请求  
因为绑定到system:kube-controller-manager（角色）的system:kube-controller-manager(subjects)是个user，  
所以CN字段的是system:kube-controller-manager，其他随便写。
```sh
{
    "CN": "system:kube-controller-manager",
    "hosts": [
        "127.0.0.1",
        "${MASTER_IPS[0]}",
        "${MASTER_IPS[1]}",
        "${MASTER_IPS[2]}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "123",
            "OU": "xyz"
        }
    ]
}
```

* kube-scheduler的证书签名请求  
因为绑定到system:kube-scheduler(角色)的system:kube-scheduler(subjects)是个user，  
所以CN字段的是system:kube-scheduler，其他随便写。
```sh
{
    "CN": "system:kube-scheduler",
    "hosts": [
        "127.0.0.1",
        "${MASTER_IPS[0]}",
        "${MASTER_IPS[1]}",
        "${MASTER_IPS[2]}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "123",
            "OU": "xyz"
        }
    ]
}
```

* kubelet的证书签名请求方式1  
使用bootstrap，kubernetes v1.11.0已经预定义了system:node-bootstrap角色，但是没有预定义角色绑定，需要自己去创建。
这种方式我已经在deploykubelet.sh.bak里面实现了。  

* kubelet的证书签名请求方式2  
因为bootstrap搞的太复杂，都是一家人还搞什么区别对待搞什么24小时token还approve什么的。  
没有找到kubelet相关的角色绑定以及角色，看一些文章说预定义的system:node是留给kubelet用的，可是kubernetes v1.11.0预定义的system:node角色绑定
没有实质性的subjects。  
所以我先暂时用system:masters吧，这个subject是预留给管理员的（上面的admin证书签名请求可以看到）  
这个可以参照上面的admin证书签名请求了，也就是把system:masters作为names.O的值，其他随便写。
```sh
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
```

* kube-proxy的证书签名请求  
因为绑定到system:node-proxier(角色)的system:kube-proxy(subject)是个user，（这不一致的名字一看就知道不是同一个人开发的）  
所以CN字段的是system:kube-proxy，其他随便写。
```sh
{
    "CN": "system:kube-proxy",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "123",
            "OU": "xyz"
        }
    ]
}
```

* 一些插件还没搞好