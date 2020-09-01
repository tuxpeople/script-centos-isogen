#!/bin/bash
# create custom bootable iso for CentOS 7 with kickstart

if [ $# -lt 2 ]
then
    echo "Usage1: $0 path2iso path2kickstart"
    exit 1
else
    if [ ! -f $1 ]
    then
        echo "File $1 does not exist!"
        exit 0
    elif [ ! -f $2 ]
    then
        echo "File $2 does not exist!"
        exit 0
    else
        INNAME="$1"
        echo "Source file - $INNAME"
        KSFILE="$2"
        echo "Kickstart file - $KSFILE"
    fi
fi

# original ISO file of CentOS 7
ISO_ORIGINAL=$INNAME

# out file name
OUTNAME=$(basename "$INNAME" | cut -d. -f1)"-KS-UEFI".iso

# working directory
WORK=$PWD/WORK

# Delete possible previous results
rm -rf $WORK

# create a new working directory
echo "Create working directory - $WORK"
mkdir $WORK

# dir to mount original ISO - SRC
SRC=$WORK/SRC

# dir for customised ISO
DST=$WORK/DST

# Dir for mount EFI image
EFI=$WORK/EFI

# mount ISO to SRC dir
echo "Create $SRC"
mkdir $SRC
echo "Mount original $ISO_ORIGINAL to $SRC"
mount -o loop $ISO_ORIGINAL $SRC

# create dir for  ISO customisation
echo "Create dir $DST for customisation"
mkdir $DST

# copy orginal files to destination dir
# use dot after SRC dir (SRC/.) to help copy hidden files also
cp -v -r $SRC/. $DST/

echo "Umount original ISO $SRC"
umount $SRC

# add boot menu grab.cfg for UEFI mode
# It is the second place where boot menu is exists for EFI.
# /images/efiboot.img/{grub.cfg} has the working menu
# /EFI/BOOT/grub.cfg just present (this case has to be discovered)
cp -v $(dirname $0)/cfg/efi-boot-grub.cfg $DST/EFI/BOOT/grub.cfg

# add boot menu with kickstart option to /isolinux (BIOS)
cp -v $(dirname $0)/cfg/isolinux.cfg $DST/isolinux/isolinux.cfg

# put kickstart file custom-ks.cfg to isolinux/ks.cfg
cp -v $KSFILE $DST/isolinux/ks.cfg

# create output directory
OUTPUT=$WORK/OUTPUT
mkdir $OUTPUT

(
    echo "$PWD - Create custom ISO";
    cd $DST;
    genisoimage \
        -V "CentOS 7 x86_64" \
        -A "CentOS 7 x86_64" \
        -o $OUTPUT/$OUTNAME \
        -joliet-long \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot -e images/efiboot.img \
        -no-emul-boot \
        -R -J -v -T \
        $DST \
        > $WORK/out.log 2>&1
)

echo "Isohybrid - make custom iso bootable"
sudo isohybrid --uefi $OUTPUT/$OUTNAME
