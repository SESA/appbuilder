# appbuilder

This is the repo for building appliances for the various unikernel
projects in the SESA group.

## Creating Appliance Builder host

Base appliance from here:
https://www.addictivetips.com/ubuntu-linux-tips/get-linux-kernel-5-3-on-debian-10-stable/

These are the commands executed after that:

     10  sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
     11  sudo nano -w /etc/apt/sources.list
     12  sudo apt update
     13  apt search linux-image

We install desktop to ensure that we have ne1000 nic and other device drivers (cloud version is limited set of drivers"

     apt search linux-image | grep buster-backports
     sudo apt install linux-headers-5.5.0-0.bpo.2-amd64

Now checkout this repo and the nbic repo for building appliances

    git clone https://github.com/SESA/appbuilder.git
    git clone https://github.com/jappavoo/nbic.git

Grab the debian kernel source package

Rebuild debian kernel:
https://kernel-team.pages.debian.net/kernel-handbook/ch-common-tasks.html#s-common-official
For the version of the kernel we are using.


In the kernel's directory, get the configs we are using for appliance:
     git clone https://github.com/unikernelLinux/Linux-Configs.git

Inside Linux-Configs/normal-linux:


In Kernel:
cp -r linux-source-5.5 golden-config-5.5

Then copy in the config
sesa@buster:~/Kernels/golden-config-5.5$ cp ../Linux-Configs/normal-linux/golden-config-5.5 .config

Then

    make oldconfig
    
We just picked default for everything.

Then we make the kernel for our config:

    jobs=$(nproc --all)
    make -j$jobs deb-pkg



