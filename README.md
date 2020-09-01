# CentOS Image generator (and downloader)

Generates auto-install ISOs for CentOS. May also work for RedHat.

## Generate a ISO with included kickstart file
Usage example:

    ./createiso.sh /tmp/CentOS-7-x86_64-NetInstall-2003.iso /home/user/ks/minimal-7.ks.cfg /home/user/isos/

The script needs three options:
1. The downloaded upstream ISO
2. Your kickstart file
3. The ouput directory

If your kickstart uses `url` as install source, NetInstall ISO is sufficient.

PLEASE: Use absolute paths for all three parameters.

## What if you need to download the upstream iso?
There is a second script, called `getiso.sh`. You need to edit that script prior to using it.

This script is meant to be a one-stop-shop for downloading the upstream iso and forward it directly to the createiso.sh.

What you need:
1. Create a directory containing your kickstart file(s). I suggest to have one per CentOS version, because for `url` and update repos, paths are different between CentOS 7 and 8. But you can use the same for 8 and 8-Stream (you can symlink them). For this script, the kickstart files need to be named as follows: `minimal-${CENTOSVERSION}.ks.cfg`. (e.g.: `minimal-7.ks.cfg` for CentOS 7). Otherwise you need to change the line, where createiso.sh gets called.
2. Configure the variables `OUT` and `KSDIR` in the head of the script. `OUT` meant to be the dir where you want to get your custom iso files (used as parameter for the createiso.sh). `KSDIR` is the directory with your kickstart file(s) in it. Please use absolute paths for both.

Now call the script. This example is for CentOS 7:

    ./getiso.sh 7
    
As you can see, usage is `scriptname VERSIONS`. VERSIONS can be `7`, `8`, `8-stream` or `all`. `all` means all three of the other. Except for `all`, you can combine them in any order, with whitespace in between. Example to make custom images for CentOS 7 and 8:

    ./getiso.sh 7 8

## Acknowledgments
- https://gist.github.com/vkanevska/fd624f708cde7d7c172a576b10bc6966
