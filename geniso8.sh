#!/bin/bash

WORKDIR="/root/git/isogen"
DESTINATIONDIR="/root/seafile/sync/"

checking_prereqs () {
    echo "Checking if all necessary programs are found."
    for i in sha256sum wget mkisofs isohybrid implantisomd5 curl file; do
        if ! command -v $i &> /dev/null; then
            echo "$i could not be found"
            exit
        fi
    done
}

generate_iso () {
    CURDIR=`pwd`
    cd ${WORKDIR}

    ISOURL="http://isoredirect.centos.org/centos/${CENTOSVERSION}/isos/x86_64/${NAME}"
    echo "Downloading upstream iso"
    mkdir ${WORKDIR}/tmp
    wget ${ISOURL} -q -O ${WORKDIR}/tmp/${NAME}
    VOLUMENAME=$(file -s ${WORKDIR}/tmp/${NAME} | cut -d"'" -f2)

    echo "Checking Checksum"
    if [ ${CENTOSVERSION} == "7" ]; then
        wget http://linuxsoft.cern.ch/centos/${CENTOSVERSION}/isos/x86_64/sha256sum.txt -q -O - | grep ${NAME} > ${WORKDIR}/tmp/sha256sum.txt
    else
        wget http://linuxsoft.cern.ch/centos/${CENTOSVERSION}/isos/x86_64/CHECKSUM -q -O - | grep ${NAME} > ${WORKDIR}/tmp/sha256sum.txt
    fi

    cd ${WORKDIR}/tmp
    if sha256sum -c sha256sum.txt; then
        echo "File correctly downloaded"
    else
        echo "${NAME} not correctly downloaded."
        echo "Cleaning up and exiting now..."
        rm -rf ${WORKDIR}/tmp
        cd ${CURDIR}
        exit 1
    fi
    cd ${WORKDIR}

    echo "Mounting upstream iso"
    mkdir ${WORKDIR}/tmp/upstreamiso
    mount -o loop ${WORKDIR}/tmp/${NAME} ${WORKDIR}/tmp/upstreamiso

    echo "Copy iso content"
    mkdir ${WORKDIR}/tmp/customiso
    cp -r ${WORKDIR}/tmp/upstreamiso/* ${WORKDIR}/tmp/customiso
    umount ${WORKDIR}/tmp/upstreamiso && rmdir ${WORKDIR}/tmp/upstreamiso
    chmod -R u+w ${WORKDIR}/tmp/customiso

    echo "Copy kickstart"
#    cp ks/minimal-generic.ks ${WORKDIR}/tmp/customiso/isolinux/ks.cfg
    cp ks/minimal-${CENTOSVERSION}.ks.cfg ${WORKDIR}/tmp/customiso/isolinux/ks.cfg
    sed -i 's/append\ initrd\=initrd.img/append initrd=initrd.img\ ks\=cdrom:\/ks.cfg/' ${WORKDIR}/tmp/customiso/isolinux/isolinux.cfg

    echo "Generate new iso"
    cd ${WORKDIR}/tmp/customiso
    mkisofs -o ../boot.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "${VOLUMENAME}" -R -J  -quiet -T isolinux/. . > /dev/null
    cd ${WORKDIR}
    isohybrid ${WORKDIR}/tmp/boot.iso
    implantisomd5 ${WORKDIR}/tmp/boot.iso
    mv ${WORKDIR}/tmp/boot.iso ${DESTINATIONDIR}/Custom-${NAME}
    rm -rf ${WORKDIR}/tmp

    cd ${CURDIR}
}

dl_7 () {
    VERSION7="$(curl -s -L http://isoredirect.centos.org/centos/7/isos/x86_64/ | grep NetInstall | grep 'iso"' | sed -e 's/.*-NetInstall-\(.*\)\.iso.*/\1/')"
    NAME="CentOS-7-x86_64-NetInstall-${VERSION7}.iso"
    CENTOSVERSION="7"
    generate_iso
}

dl_8 () {
    VERSION8="$(curl -s -L http://isoredirect.centos.org/centos/8/isos/x86_64/ | grep 'boot.iso"' | sed -e 's/.*CentOS-\(.*\)-x86_64.*/\1/')"
    NAME="CentOS-${VERSION8}-x86_64-boot.iso"
    CENTOSVERSION="8"
    generate_iso
}

dl_8stream () {
    STREAMVERSION="$(curl -s -L http://isoredirect.centos.org/centos/8-stream/isos/x86_64/ | grep 'boot.iso"' | sed -e 's/.*x86_64-\(.*\)-boot.*/\1/')"
    NAME="CentOS-Stream-8-x86_64-${STREAMVERSION}-boot.iso"
    CENTOSVERSION="8-stream"
    generate_iso
}

checking_prereqs

for VERSION in "$@"; do
    if [ "${VERSION}" == "--help" ]; then
	    echo "$(basename $0) (VERSIONS)"
	    echo "     Where VERSIONS can be 7 8 8-stream or all"
        echo "     Except of 'all', you can combine them in any order, with whitespace in between:"
        echo "     $(basename $0) 7 8"
        break
    fi

    if [ "${VERSION}" == "all" ]; then
        dl_7
        dl_8
        dl_8stream
    fi

    if [ "${VERSION}" == "7" ]; then
	    dl_7
    fi

    if [ "${VERSION}" == "8" ]; then
        dl_8
    fi

    if [ "${VERSION}" == "8-stream" ]; then
        dl_8stream
    fi
done
