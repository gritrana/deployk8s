Vagrant.configure(2) do |config|

  # 设置dev虚机环境（下面还要写dev.vm，好扯淡）
  config.vm.define "dev" do |dev|

    # 设置虚拟机的Box
    dev.vm.box = "centos7"

    # 设置虚拟机的主机名
    dev.vm.hostname = "dev"
    
    # 设置虚拟机的IP
    dev.vm.network "private_network", ip: "192.168.0.2"

    # VirtaulBox相关配置
    dev.vm.provider "virtualbox" do |vb|

        # 设置虚拟机的内存大小
        vb.memory = 512

        # 设置虚拟机的CPU个数
        vb.cpus = 1
    end

    # 挂载失败了，mount: unknown filesystem type 'vboxsf'
    # config.vm.synced_folder ".", "/home/vagrant/deployk8s"
    # 使用默认挂载

    # 使用shell脚本进行软件安装和配置
    dev.vm.provision "shell", inline: <<-SHELL

      echo "不用认证主机公钥"
      sudo sed -i 's/#\s\+StrictHostKeyChecking ask/StrictHostKeyChecking no/' \
        /etc/ssh/ssh_config

      echo "yum安装git"
      sudo yum install -y git

      echo "yum安装vim"
      sudo yum install -y vim
      echo alias vi=vim >> ~/.bashrc

    SHELL
  end

  # ssh配置
  config.ssh.username = "vagrant"
  config.ssh.private_key_path = "~/.vagrant.d/insecure_private_key"
  config.ssh.insert_key = false

end