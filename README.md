# appbuilder

This is the repo for building appliances for the various unikernel
projects in the SESA group.

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
