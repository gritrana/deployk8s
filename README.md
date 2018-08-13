![](https://github.com/xujintao/deployk8s/blob/master/deployk8s.jpg)

## 感谢
感谢 https://github.com/opsnull/follow-me-install-kubernetes-cluster 作者及其贡献者。  
它是3个节点的集群，为了更清楚的认识k8s。
我这里搞了3个master和3个node，那个dev是用来分发的或者说是用来操作集群的。  
如果部署过程中遇到什么问题可以提issues也可以加这个QQ群95786324  

注意：当前分支部署的是kubernetes v1.11.0，kubernetes版本更新很快1天1个版本，高版本与低版本会有比较大的区别，问题也总是出在上面。  
欢迎issues和pull request

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
vagrant box add centos7 D:\\Box\\CentOS-7-x86_64-Vagrant-1804_02.VirtualBox.box

# 或者：
vagrant box add centos7 /d/Box/CentOS-7-x86_64-Vagrant-1804_02.VirtualBox.box
```
* 启动开发机(dev)  
```sh
vagrant up dev
```
以后就使用dev来指代开发机了。

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
好了好了，正式开始了。

> 注意：这里其实还是蛮复杂的，我建议用xshell。
> 比如使用xshell登录dev，使用xftp复制insecure_private_key还有curl下载的那几个文件到dev。
> 我自己就是用的xshell，下面那些命令行是我为了说明过程才写的。

* 使用你的ssh工具登录到dev。  
```sh
ssh -i ~/.vagrant.d/insecure_private_key \
vagrant@192.168.0.2
```

* 复制insecure_private_key。
图方便我已经把不安全的公钥添加到集群机器的/root/.ssh/authorized_keys中了，  
所以为了让root能从dev远程登录到集群机器，**需要把insecure_private_key弄到dev的~/.ssh/id_rsa中**。  
```sh
scp -i ~/.vagrant.d/insecure_private_key \
~/.vagrant.d/insecure_private_key \
vagrant@192.168.0.2:~/.ssh/id_rsa
```
这个id_rsa的权限是644，需要改为600，在dev机中执行：
```sh
chmod 600 ~/.ssh/id_rsa
```

**注意：下面所有的操作都是在dev上进行的**。
* 准备几样东西（haproxy以及docker我已经内置在box里面了）：
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

* 把脚本clone下来：
```sh
git clone https://github.com/xujintao/deployk8s.git
cd deployk8s
```

最后就开始执行脚本进行部署吧。

### 第5~10步，一键部署集群  
```sh
./deployk8s.sh 2>&1 | tee deployk8s.log
```
等大概10分钟  
如果没什么问题的话，到这里，集群部署就算成功了。如果有问题，可以通过日志来定位哪里出了问题。
这个步骤可以是可以重复进行的。

### 第11步，预留给插件（可选）  

### 第12步，部署自己的应用（可选）  
比如我自己的一个docker镜像：
```sh
./deployapp.sh
```

## Document  

### 1.证书签名请求与RBAC的对应关系  
该命令`kubectl get clusterrolebindings -o wide`可以得到下面这个表格  
可以看到kubernetes预留的subjects被绑定到哪个角色了。subjects就是下面表格中的usr/group/serviceaccounts

| cluster-role-binding | cluster-role | user | group | service-accounts |
| ------ | ------ | ------ | ------ | ------ |
| cluster-admin | cluster-admin |  | system:masters |  |
| system:kube-controller-manager | system:kube-controller-manager | system:kube-controller-manager |  |  |
| system:kube-scheduler | system:kube-scheduler | system:kube-scheduler |  |  |
| system:node | system:node |  |  |  |
| system:node-proxier | system:node-proxier | system:kube-proxy |  |  |

user对应的是证书签名请求中的CN字段的值，group对应的是证书签名请求中的names.O字段。  
> 客户端访问apiserver的时候，先双向认证(authentication)，客户端解码服务器的证书验证ip和根证书，服务器解码客户端的证书然后只验证根证书。
没什么问题的话，tls连接就算建立起来了。

> 授权(authorization)是在应用层完成的，基于上面的tls连接，客户端在发http请求的时候会把自己证书中的CN字段和names.O字段打包到http头的kv对中，
比如authenrization: user=xxx; group=xxx，api服务器收到http请求后把它取出来拿过去授权，授权成功就把rest结果返回给客户端，授权失败就返回Unauthorized。

因为k8s的authentication和authorization花样太多了，这里只是冰山一角的简化流程，可以这么理解。

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
            "ST": "Shanghai",
            "L": "Shanghai",
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
            "ST": "Shanghai",
            "L": "Shanghai",
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

* kubelet的证书签名请求方式1(默认)  
使用node授权方式，这个不是RBAC授权。
```sh
{
    "CN": "system:node:##NODE_NAME##",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "system:nodes",
            "OU": "kubelet"
        }
    ]
}
```
这里CN必须是system:node:<节点名>，names.O必须是system:nodes。
根据文档[Using Node Authorization](https://kubernetes.io/docs/reference/access-authn-authz/node/)最后一段的说明，这里我大概翻译一下：
> kubernetes v1.6的时候，如果api-server启动参数里面的authorization-mode值是RBAC的话，那么启动以后，system:nodes组(subjects)是自动绑定到system:node集群角色的。

> kubernets v1.7的时候，这种上面那种自动绑定(RBAC)被弃用了（虽然被弃用，但是还是能用的，只是提示deprecated），因为node authorization完成了同样的功能而且还能限制secret和configmap的方法权限。如果api-server启动参数里面的authorization-mode值是Node和RBAC的话，那么启动以后，就不会自动创建system:nodes组到system:node集群角色的绑定。意思就是说如果authorization-mode值仅仅是RBAC的话，api-server还是会自动创建这种绑定的。

> 然而到了v1.8的时候，这种绑定就不再自动创建了，说到做到。（如果你去issues里面看，会发现很多人升级到1.8以后kubelet就出问题）。当然了，虽然绑定不存在了，但是system:node集群角色还是在的，这是为了兼容绑定到该角色的其他subjects。  

我这里使用的是v1.11.0，我api-server启动参数里面的authorization-mode值是Node和RBAC，我使用node授权方式来对kubelet进行授权，不使用RBAC授权就不需要system:node集群角色，这个没有毛病。

* kubelet的证书签名请求方式2  
我想了想，对于kubelet我还想使用RBAC，那么我必须自己创建一个集群角色绑定，我懒我连绑定都不想创建，我使用了system:masters这个组  
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
names.O字段的值是system:masters，CN随便写。这个也行的。

* kubelet的证书签名请求方式3  
因为认证(authentication)用的是bootstrap token，所以kubelet连证书和密钥都不需要创建。
大佬们起kubelet都是用的bootstrap方式，可是我觉得bootstrap搞的太复杂，都是一家人还搞什么区别对待搞什么24小时token还approve什么的。为了能approve证书签名请求，为2个组创建了4个集群角色绑定，太复杂了。所以这个我照抄的他们的。

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