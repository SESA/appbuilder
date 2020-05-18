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
[SESAAppBuilder](https://drive.google.com/drive/u/0/folders/10GYMi65Ikn2eYitcCgnaGde25ldxBOxm).
Inside there the base image all the work has been done in is called:

    debian10.4.base.img

Just download that image to get eveything running. The work is done as "sesa", and both "root" and "sesa" have the non-secure sesa password.

The files and scripts are all checked out in the VM, as well as the nbic environment, but please push back changes that will be valuable.

In files, you can see the script run by nbic to initialize an environment, and the default init file run by an appliance.  Will discuss the interesting features of these files [below](#using).

Unders scripts we have:
- bootAppBuildVM: a simple script to run the app builder VM that you download from google drive
- ssh2AppBuildVM: a script to log into the VM

Examples or stuff not yet done:
- mkapp: which is bogus, but will include some of the stuff describe below to create a new apps
- runApp: right you specify an app directory and it attempts to run a kvm instance with the kernel, initrd and cmdline in the directory
          the expectation is that you copy the correct things your want into an appdir and then simlink to the necessary files.
	  See the example in Appliances/apps/genricApp
	  and usage string of runApp when run with no arguments



When you log into the vm key directories as sesa user are:
 - appbuilder : this repo
 - nics : a checkout of the nics github repo
 - cmds  - a file of commands you want to run in the chroot environment, see [below](#Using).
 - Appliances : the appliances should go here:
 - cpios: a set of cpio file systems that can be converted into ram file systems - you can easily merge/add edit these using cpios-unpack...
   - apps: should put here for each appliance the command line used to run it, the kernel, and the cpios it should use.
  - buster-reference-root : the root file system that is used to generate the appliance cpios/initramfs

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


## <a name="using"></a>Using an appliance

To run your appliance you should have the program invoked by a script
called "run" in the app directory of the root file system. Just copy
your appliances out of the appliance builder, zip up your ram file
system, and run kvm, e.g, for an appliance called bash

    mkdir myApp
    scp -r -P 2222 sesa@127.0.0.1:Appliances/cpios/bash.cpio myApp
    cd myApp
    gzip -9 bash.cpio
    ln -s bash.cpio.gz initrd
    do the same for your kernel and command line arguments
    cd ..
    runApp myApp


If you look at the buster-reference-root file system, you will see an "app" directory.  Please put in that app directory any application specific code you want to execute.  The init script is designed to automatically run the following files from this directory:
- "prerun" suff  you want before your appliance
- "run": run your appliances
- "postrun" stuff, e.g., to copy your data output

Init is customized by a set of arguments you add to kernel command line.  
  - appCmd: ":" seperated set of commands. These are run after prerun and befure run phase.
  - appEnd: can be halt (default), reboot, or sshd
  - appDebug: will stop on a shell before running prerun
  - appArgs: arguments that are passed to run

Examples:

     appCmds='ls /app:ifconfig eth0 ..:mount ..'
     scp -r -P 2222 sesa@127.0.0.1:Appliances/cpios/bash.cpio .
     kvm -serial stdio -kernel vmlinuz-5.5.17  -initrd bash.cpio.gz -append "console=ttyS0"
     kvm -serial stdio -kernel vmlinuz-5.5.17  -initrd bash.cpio.gz -append "console=ttyS0 appDebug"
     kvm -serial stdio -kernel vmlinuz-5.5.17  -initrd bash.cpio.gz -append "console=ttyS0 appEnd=bash"
     kvm -serial stdio -kernel vmlinuz-5.5.17  -initrd bash.cpio.gz -append "console=ttyS0 appEnd='bash'"
     kvm -serial stdio -kernel vmlinuz-5.5.17  -initrd bash.cpio.gz -append "console=ttyS0 appCmds='mkdir --help:ls :'"
     kvm -serial stdio -kernel vmlinuz-5.5.17  -initrd bash.cpio.gz -append "console=ttyS0 appEnd='bash' appCmds='mkdir --help:ls:ls /app:'"

     runApp does the above for you

## Kernel construction

In the kvm builder VM there is all the infrastructure to compile the 5.5 series kernels with our configs.

Call me for details.

You should build your kernels and copy them out for your apps


## Creating Appliance Builder host You can safely ignore this

Details you don't need unless you are trying to build your own appBuilderVM

The script directory also has a set of scripts you should not need to use unless you are creating your own app builder.
- installAppBuildVM: command used to create the VM from iso

Base appliance from here:
https://www.addictivetips.com/ubuntu-linux-tips/get-linux-kernel-5-3-on-debian-10-stable/

Rest of this section, you can pretty much ignore, its not up to date, but copied a bunch of history into this.

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


