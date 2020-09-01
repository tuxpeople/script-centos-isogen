#!/bin/bash

BASE="http://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-NetInstall-2003.iso"

echo "Checking for prereqs"
yum install -y -q isomd5sum genisoimage wget

echo "Downloading netinstalll.iso"
mkdir ./tmp
wget ${BASE} -q -O ./tmp/centos-base.iso

echo "Mounting netinstall.iso"
mkdir ./tmp/bootiso
mount -o loop ./tmp/centos-base.iso ./tmp/bootiso

echo "Copy iso content"
mkdir ./tmp/bootcustom
cp -r ./tmp/bootiso/* ./tmp/bootcustom
umount ./tmp/bootiso && rmdir ./tmp/bootiso
chmod -R u+w ./tmp/bootcustom

echo "Copy kickstart"
cp ks/minimal.ks.cfg.partselec ./tmp/bootcustom/isolinux/ks.cfg
sed -i 's/append\ initrd\=initrd.img/append initrd=initrd.img\ ks\=cdrom:\/ks.cfg/' ./tmp/bootcustom/isolinux/isolinux.cfg

echo "generate new iso"
cd ./tmp/bootcustom
mkisofs -quiet -o ../boot.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "CentOS 7 x86_64" -R -J -v -T isolinux/. .
cd ../../
implantisomd5 ./tmp/boot.iso
mv ./tmp/boot.iso /root/seafile/sync/custom-centos-7-select.iso
rm -rf ./tmp
