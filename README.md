# Appbuilder

This is the repo for building appliances for the various unikernel
projects in the SESA group.  

This is based on the [nbic](https://github.com/jappavoo/nbic) work done for kittyhawk. It lets you create a image with a customized ramfs for running an individual application.  Basically the set of tools creates a chroot environment, run your app inside it, and then it looks at what files were accessed, and copies just those into the ramfs required.  This allows you to create a full function appliance with all the required files automatically.  Their experience is that it is generally tiny for most applications.
Note, this depends on a standard debian environment.

For extracting data out, we will NSF to mount a remote file system where we put the data; note to avoid perturbing results, we would want to  mount NSF just at the very end of the whole thing.

Philosophy is that we will have everything in appliances, including the environment to build appliances and unikernels, so we can spin these suckers up.  There is *no* durable file system attached at all, we just use ramfs for everything.  We can publish the resulting appliances to a webservice, or dump them over NFS,

To simplify our lives, we will have one booting appliance and have a script in it that will download an image and kexec to it.   

## Where stuff is

The base image you need for this is in a shared google drive called

[SESAAppBuilder](https://www.cs.bu.edu/~jappavoo/Resources/vms/AppBuilder.tar.bz2).
Inside you will find the base vm image along with the iso used to install it.

```
    debian-<ver>-amd64-netinst.iso  debian-<ver>-amd64.img
```

All the work to build images will be done from within a VM instance started with this image.
The work you do within the VM will be done as the "sesa" and "root" user, and both "root" and "sesa" have the non-secure sesa password.

This repo is checked out in the VM, as well as the nbic environment, but please push back changes that will be valuable.

In files, you can see the script run by nbic to initialize an environment, and the default init file run by an appliance.  Will discuss the interesting features of these files [below](#using).

Unders scripts we have:
- bootAppBuildVM: a simple script to run the app builder VM that you download from google drive
- ssh2AppBuildVM: a script to log into the VM

## Starting the AppBuilder VM

Once you have downloaded and unpacked the Appbuilder VM you can start it using the the script bootAppBuilderVM.  Eg.
```
$ scripts/bootAppBuilderVM  debian-12.7.0-amd64.img
```

The window you run this command should turn into the console for for your VM instance.
At this point you should be able to log in using the sesa user.  If you don't have the password you will need to talk to someone
in the know.

## Accessing the VM instance and copying files

You can use the thin wrapper scripts to simplify your access to the vm instance.

### ssh to vm

`sshAppBuilderVM` is a simple script that invokes ssh for you to access the VM.  It assumes that bootAppBuilderVM was used to launch it, which
creates a port tunnel between a fixed localhost and port 22 of the vm.  Eg.

```
$ scripts/ssh2AppBuildVM 
sesa@127.0.0.1's password: 
Linux appbuilder 6.1.0-25-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.106-3 (2024-08-26) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Wed Oct  2 14:57:17 2024 from 192.168.1.2
sesa@appbuilder:~$
```

There is nothing magically to the script is nothing more than:
```
#!/bin/bash
#set -x
APPBUILDER_SSHLOCAL=${APPBUILDER_SSHLOCAL:-"127.0.0.1:2222"}
APPBUILDER_USER=${APPBUILDER_USER:-"sesa"}

port=${APPBUILDER_SSHLOCAL##*:}
host=${APPBUILDER_SSHLOCAL%%:*}

set -u

ssh -p $port ${APPBUILDER_USER}@${host} $@

```

### copying files to and from the vm

Similar to sshing there is a script, `scripts/scpAppBuildVM`, that simplifies copying
files between your host and the VM. Eg.

```
$ scripts/scpAppBuildVM README.md localhost:
sesa@localhost's password: 
README.md                                     100%   11KB   5.8MB/s   00:00    
$ scripts/scpAppBuildVM localhost:README.md /tmp/foo
sesa@localhost's password: 
README.md                                     100%   11KB   8.7MB/s   00:00    
$
```

# 


Examples or stuff not yet done:
- mkapp: which is bogus, but will include some of the stuff describe below to create a new apps
- runApp: right you specify an app directory and it attempts to run a kvm instance with the kernel, initrd and cmdline in the directory
          the expectation is that you copy the correct things your want into an appdir and then simlink to the necessary files.
	  See the example in Appliances/apps/genricApp
	  and usage string of runApp when run with no arguments




## Building appliances

If you want to add new packages/software you do this by running chroot environment against the reference root

I think you would just:

    nd buster-reference-root
    This will drop you into a root shell running against the reference root (we have prepped it with the latest debain and packages for the 5.5 series of kernels)
    run apt-get on whatever you want
    Then exit from the shell
    Note if you did complicated installs or stuff that start processes.  You must clean up.  In this case your better off rebooting your vm

Once you have the stuff installed, want to create a new cpios:

    nbic -d buster-reference-root -o Appliances/cpios/XXX.cpio

Where buster-reference-root is the base file system and XXX is the name of the new appliances file system. After you hit return you are in the chroot file system, anything you type will be in the new file system.  Then exit and you will find a new cpio.  Note, we recommend that you copy out the "cmds" from the root directory that has a set of base programs that are used by init.

Or you can simply merge your new cpio with the bash.cpio to ensure that you have the necessary base contents

Please place new cpios in the cpios directory and create appliances in the apps dir.

You should create a new appliance in the apps directory, putting in your commmand line and kernel.




## Creating Appliance Builder host You can safely ignore this

Details you don't need unless you are trying to build your own appBuilderVM

If you need to rebuild the AppBuilderVM the following is a guide.  A common reason for this might be to upgrade to a new distro release.

### Build the base VM image


1.Use the `scripts/installAppBuildVM <path to install CD/iso> [path of vm disk image to create]`. This script creates a bootable disk image.
> Eg. `scripts/installAppBuilderVM debian-12.7.0-amd64-netinst.iso`

It has several built in defaults that you can overide.
      - If no image path is specified it will create the disk image in the directory that you run the command in with the the same name as the iso with `.img` appended to it.
      - VM Memory size used during install.  Default is 2048 Kb. Set MEMORY env variable to overide.  Eg.
         - `MEMORY=4096 scripts/installAppBuilderVM debian-12.7.0-amd64-netinst.iso`
      - Target disk image size can be set by overriding `IMGSIZE`.  The default is 200G. Eg.
      	 - `IMGSIZE=420G scripts/installAppBuilderVM debian-12.7.0-amd64-netinst.iso`
      - Simiarlarly for the type of the disk image can be set with IMGTYPE.  The default is QCOW2. Eg.
         - `IMGTYPE=raw scripts/installAppBuilderVM debian-12.7.0-amd64-netinst.iso`
	 
2. At this point you need to complete the install and then start it up and complete the setup.
   Eg. once installed you would start it up with something like:
       - `APPBUILDER_MEMORY=8G scripts/bootAppBuildVM AppBuildVM/debian-12.7.0-amd64.img`
       - The log in via ssh eg. `scripts/ssh2AppBuildVM`

### Basic Setup

We will want this repo in the VM -- it also includes some scripts to help easy
the setup process.  The next few steps must be done by hand on the vm.

```
sudo apt update
sudo apt install ssh git
ssh-keygen
git clone https://github.com/SESA/appbuilder.git
appbuilder/scripts/basicVMsetup
```

Assuming successfull clone you can now use the scripts in appbuilder/scripts to
help complete the setup.  Please note this are not very complicated and if
you have any problems look at the scripts and do the steps by hand correcting
any thing that goes wrong.


### Kernels Setup

Note: To build a kernel you will need to start the VM with enough memory eg. APPBUILDER_MEMORY=8G scripts/bootAppBuildVM

The goal is to  leave in the AppBuilderVM the infrastructure for building Kernels that are compatible with the application software
you will use in your appliances.  This allows an app developer, know exactly what kernel they are packaging with their app and to configure and
compiler customer kernels as they see fit.  The instructions below are to build a default app kernel that is the same as the kernel used to
boot the AppBuilderVM -- as you may have noticed this is all assuming a debian distro.  

The following is based on https://kernel-team.pages.debian.net/kernel-handbook/ch-common-tasks.html

1. find out what the kernel source version available is: `apt search linux-source`
2. assuming you are running the stable version you can use the script: `setupKernels`
   - 
```
sudo apt install linux-source build-dep linux
[[ ! -d ~/Kernels ]] && mkdir ~/Kernels
cd ~/Kernels

[[ ! -d linux-source-$(uname -r) ]] && \
  tar xaf /usr/src/linux-source-$(uname -r).tar.xz

# use system config as basis for our kernel build
cp  /boot/config-$(uname -r) .config

# turn off module signing... I think this is right
scripts/config --disable MODULE_SIG
scripts/config --set-str SYSTEM_TRUSTED_KEYS ''
scripts/config --disable SYSTEM_TRUSTED_KEYRING
scripts/config --disable MODULE_SIG_ALL
scripts/config --set-str MODULE_SIG_KEY ''

# set parallelism
export MAKEFLAGS=-j$(nproc)

make oldconfig
make clean
make bindeb-pkg
```




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



 79  ls
   80  history
   81  cd ..
   82  ls
   83  ifconfig
   84  sudo apt-get install net-tools
   85  ifconfig
   86  ifconfig
   87  sudo ifconfig
   88  ls
   89  dpkg -i linux-image-5.5.17_5.5.17-1_amd64.deb
   90  sudo dpkg -i linux-image-5.5.17_5.5.17-1_amd64.deb
   91  sudo cp /etc/fstab /etc/fstab.orig
   92  sudo vi /etc/fstab
   93  sudo shutdown -r now
   94  history
   95  echo "after reboot needed to fix interfaces file since new kernel has different name for ethernet iface"
   96  diff /etc/network/interfaces /etc/network/interfaces.orig
   97  echo "< allow-hotplug enp0s3
   98  < iface enp0s3 inet dhcp"
   99  history
  100  cat /etc/mtab
  101  ls
  102  head nbic/README
  103  grep deboo  nbic/README
  104  sudo cdebootstrap buster buster-reference-root
  105  ls
  106  cd buster-reference-root/
  107  ls
  108  cd etc
   109  ks
  110  ls
  111  cd apt/
  112  ls
  113  cat sources.list
  114  #cp sources.list sources.list.orig
  115  ls -l
  116  sudo cp sources.list sources.list.orig
  117  sudo vi sources.list
  118  echo "deb http://deb.debian.org/debian buster-backports main" >> sources.list
  119  sudo bash -c 'echo "deb http://deb.debian.org/debian buster-backports main" >> sources.list'
  120  diff sources.list sources.list.orig
  121  cat sources.list
  122  cd ..
  123  ls
  124  sudo cp ../appbuilder/files/chroot .
  125  sudo cp ../appbuilder/files/init .
  126  ls
  127  cat chroot
  128  cd ..
  129  ls
  130  nd buster-reference-root
  131  vi .profile
  132  exit
  133  nbic
    134  ls
  135  history
  136  echo "running nd on reference root to do apt update for pick backports so that linux 5.5 kernel packages can be pickup"
  137  ls
  138  grep nd nbic/README
  139  nd buster-reference-root/
  140  ls
  141  sudo cp /etc/apt/sources.list buster-reference-root/etc/apt
  142  nd buster-reference-root/
  143  ls
  144  history
  145  echo "used nd to get into reference root and then did an apt-update against new sources list and then did an apt-get build-dep linux to install all dependencies for compiling a linux kernel"
  146  ls
  147  history | grep apt
  148  ls
  149  sudo shutdown now
  150  history

At this point a clean reference root, with first attempt at init
script.


sesa@buster:~$ ls
appbuilder  Applicances  buster-reference-root  Kernels  nbic
sesa@buster:~$ cd buster-reference-root/
sesa@buster:~/buster-reference-root$ ls
bin   chroot  etc   init  lib32  libx32  mnt  proc  run   srv  tmp  var
boot  dev     home  lib   lib64  media   opt  root  sbin  sys  usr


