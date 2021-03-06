# KUDOS:
#
# https://community.theforeman.org/t/from-kickstart-default-pxelinux-can-i-determine-if-a-host-is-a-vm/5575/5
# https://gist.github.com/devynspencer/99cbcf0b09245e285ee4

# Language, keyboard and timezone
lang en_US
keyboard sg-latin1
timezone Europe/Zurich --isUtc

# Rootpassword will be Welcome1
rootpw $6$saltnpepper$odODCc38aZg5Il/o/pACqxxstCGAjT0PAKU30G68LueylBwYsyVO0v4xtBJH4EU/z1oV1rqNdCQhiWCbt7cOy0 --iscrypted

#platform x86, AMD64, or Intel EM64T
install
reboot
text

# We need network to install and beyond. Set hostname to something else than localhost
network --bootproto dhcp --onboot yes --hostname freshinstall

# include partition scheme
%include /tmp/partitions.ks
%include /tmp/repos.ks

%pre
if [ @host.operatingsystem.major.to_i >= 8 ]; then
cat << EOF > /tmp/repos.ks
url --url="http://mirror.init7.net/centos/$releasever/BaseOS/$basearch/os"
repo --name=base --baseurl=http://mirror.init7.net/centos/$releasever/BaseOS/$basearch/os/
repo --name=appstream --baseurl=http://mirror.init7.net/centos/$releasever/AppStream/$basearch/os/
repo --name=extras --baseurl=http://mirror.init7.net/centos/$releasever/extras/$basearch/os/
repo --name=powertools --baseurl=http://mirror.init7.net/centos/$releasever/PowerTools/$basearch/os/
repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/$releasever/Everything/$basearch
repo --name=plus --baseurl=http://mirror.init7.net/centos/$releasever/centosplus/$basearch/os/
EOF
elif [ @host.operatingsystem.major.to_i = 7 ]; then
cat << EOF > /tmp/repos.ks
url --url=http://mirror.init7.net/centos/$releasever/os/x86_64/
repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/$releasever/x86_64/
repo --name=updates --baseurl=http://mirror.init7.net/centos/$releasever/updates/x86_64/
EOF
fi

#Magic to detect if it's sda or vda to install
if [ -b /dev/vda ]; then
  drive_type=vda
elif [ -b /dev/sda ]; then
  drive_type=sda
fi

#setup disk partitions
cat << EOF > /tmp/partitions.ks
zerombr
bootloader --location=mbr --driveorder=$drive_type --timeout=3
clearpart  --all --initlabel --drives=$drive_type

# Disk partitioning information
part /boot --fstype="ext4" --ondisk=$drive_type --size=1024 --label=boot --fsoptions="rw,nodev,noexec,nosuid"
part /boot/efi --fstype=vfat --size=256 --ondisk=$drive_type

# 30GB physical volume
part pv.01 --grow --fstype="lvmpv" --ondisk=$drive_type --size=1
volgroup system_vg --pesize=4096 pv.01

logvol /        --fstype="ext4"  --size=8192 --vgname=system_vg --name=lv_root
logvol /home    --fstype="ext4"  --size=256 --vgname=system_vg --name=lv_home --fsoptions="rw,nodev,nosuid"
logvol /tmp     --fstype="ext4"  --size=2048 --vgname=system_vg --name=lv_tmp  --fsoptions="rw,nodev,noexec,nosuid"
logvol /var     --fstype="ext4"  --size=4096 --vgname=system_vg --name=lv_var  --fsoptions="rw,nosuid"
logvol /var/log --fstype="ext4"  --size=4096 --vgname=system_vg --name=lv_log  --fsoptions="rw,nodev,noexec,nosuid"
logvol swap     --fstype="swap" --size=2048 --vgname=system_vg --name=lv_swap --fsoptions="swap"

EOF
%end

# Auth settings, ansible user (no pw, therefore locked an no console but with ssh key)
auth --passalgo=sha512 --useshadow
user --name=ansible
sshkey --username=ansible "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCz9Ad3IO8Jmh2ctrHIJBEllWAa7V9M6lbZ8gPTB116SZRjZTN90zeS6NF/q+q+hWLy5Hvhluk5clxO5vyR3VUSsW851OYZNhFs+F+MJ62i9zPmfPcqGowIgLafiAA5HuDPd74R7o9onZXTw5UFUbzyoqamsyvsB+OIGbWgBIQvdCuDAmH+e5u/IG9tiR7jmXzqgxj969+n+2OtYG19Wcg05Lw8uLn8h9uK5PhRV6ib5T5PvUY6GvDqbQO0pN0HEAH/rxJtYpLQGM3ilC5SsWgJEW/oZyqtpTG/KuSYFYZkr2puhMkmRZJf7Pwimjxpyz5wMhfGkuWAde9uHS+NTMzPYgFWzH8ccPOkY0lcGwY7DbIRd0bnV9tljXfK9DlefxWwgpA4TiBp0fx95Pi4yWunONnAkoM06gVGIxr9kGvFQ7rbbr0/7Z9/jseyCR5lPr6cbxpQnyeQKig7aU5dpoEVswHGJ0Nzu5evWs1iiQivb4NuXKJGqcY5Lq/pagnyrwnRFVn5Pvp+tcx6jhUokRIAL6sRUZg2EIto4AMdKH53A3S8Iprw6bSjKZy8JtVHXZjuFLttYtSButL6LHP7Sqjt0/04xlBacSBnOCrM0fPLj3BN5pR7lIoM0k2ObCgudR5LPdJPTnggNEDpnY/Ir08XkjuCjqKKwAJ68xkHrWxiQ== ansible@system"

# More security is better
selinux --enforcing
firewall --enabled --ssh

#skipx and no first boot assistent
skipx
firstboot --disable

# services to be enabled
services --enabled="chronyd"

# basic packageset to be installed. Rest will be taken car of by ansible
%packages
@base
chrony
epel-release
microcode_ctl
open-vm-tools.x86_64
%end

%post
# ansible user gets passwordless sudo
echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 
echo @host.model.to_s 
%end
