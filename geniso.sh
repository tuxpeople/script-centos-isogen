#!/usr/bin/env bash

version="1.0.0"   # Version of this script
DESTINATIONDIR="/root/seafile/sync/"
KSDIR="/root/git/isogen/ks"

###############################################################################
# 
# SCRIPTNAME
# Description of this script.
# 
# HISTORY
# 
# * DATE - v1.0.0  - First Creation
# 
###############################################################################

###############################################################################
# Here comes the code :-)
###############################################################################
function mainScript() {
  if [ "${cversion}" == "all" ]; then
      dl_7
      dl_8
      dl_8stream
  fi

  if [ "${cversion}" == "7" ]; then
    dl_7
  fi

  if [ "${cversion}" == "8" ]; then
      dl_8
  fi

  if [ "${cversion}" == "8-stream" ]; then
      dl_8stream
  fi
}

function dl_7 () {
    VERSION7="$(curl -s -L http://isoredirect.centos.org/centos/7/isos/x86_64/ | grep NetInstall | grep 'iso"' | sed -e 's/.*-NetInstall-\(.*\)\.iso.*/\1/')"
    NAME="CentOS-7-x86_64-NetInstall-${VERSION7}.iso"
    CENTOSVERSION="7"
    generate_iso
}

function dl_8 () {
    VERSION8="$(curl -s -L http://isoredirect.centos.org/centos/8/isos/x86_64/ | grep 'boot.iso"' | sed -e 's/.*CentOS-\(.*\)-x86_64.*/\1/')"
    NAME="CentOS-${VERSION8}-x86_64-boot.iso"
    CENTOSVERSION="8"
    generate_iso
}

function dl_8stream () {
    STREAMVERSION="$(curl -s -L http://isoredirect.centos.org/centos/8-stream/isos/x86_64/ | grep 'boot.iso"' | sed -e 's/.*x86_64-\(.*\)-boot.*/\1/')"
    NAME="CentOS-Stream-8-x86_64-${STREAMVERSION}-boot.iso"
    CENTOSVERSION="8-stream"
    generate_iso
}

function generate_iso () {
  notice "Starting process for Centos ${CENTOSVERSION}."
  minfree=1232896
  checkfree /tmp

  CURDIR=`pwd`
  [ -d ${tmpDir} ] || mkdir ${tmpDir}
  cd ${tmpDir}

  ISOURL="http://isoredirect.centos.org/centos/${CENTOSVERSION}/isos/x86_64/${NAME}"
  info "Downloading upstream iso"
  wget ${ISOURL} -q -O ${tmpDir}/${NAME}
  VOLUMENAME=$(file -s ${tmpDir}/${NAME} | cut -d"'" -f2)

  info "Checking Checksum"
  if [ ${CENTOSVERSION} == "7" ]; then
    wget http://linuxsoft.cern.ch/centos/${CENTOSVERSION}/isos/x86_64/sha256sum.txt -q -O - | grep ${NAME} > ${tmpDir}/sha256sum.txt
  else
    wget http://linuxsoft.cern.ch/centos/${CENTOSVERSION}/isos/x86_64/CHECKSUM -q -O - | grep ${NAME} > ${tmpDir}/sha256sum.txt
  fi

  cd ${tmpDir}
  if sha256sum -c sha256sum.txt; then
    info "File correctly downloaded"
  else
    cd ${CURDIR}
    die "${NAME} not correctly downloaded."
  fi
  cd ${tmpDir}

  info "Mounting upstream iso"
  mkdir ${tmpDir}/upstreamiso
  mount -o loop ${tmpDir}/${NAME} ${tmpDir}/upstreamiso

  info "Copy iso content"
  mkdir ${tmpDir}/customiso
  cp -r ${tmpDir}/upstreamiso/* ${tmpDir}/customiso
  umount ${tmpDir}/upstreamiso && rmdir ${tmpDir}/upstreamiso
  chmod -R u+w ${tmpDir}/customiso

  info "Copy kickstart"
#  cp ${KSDIR}/minimal-generic.ks ${tmpDir}/customiso/isolinux/ks.cfg
  cp ${KSDIR}/minimal-${CENTOSVERSION}.ks.cfg ${tmpDir}/customiso/isolinux/ks.cfg
  sed -i 's/append\ initrd\=initrd.img/append initrd=initrd.img\ ks\=cdrom:\/ks.cfg/' ${tmpDir}/customiso/isolinux/isolinux.cfg

  info "Generate new iso"
  cd ${tmpDir}/customiso
  mkisofs -o ${DESTINATIONDIR}/Custom-${NAME} -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "${VOLUMENAME}" -R -J  -quiet -T isolinux/. . > /dev/null
  cd ${CURDIR}
  isohybrid ${DESTINATIONDIR}/Custom-${NAME}
  implantisomd5 ${DESTINATIONDIR}/Custom-${NAME} > /dev/null

  rm -rf ${tmpDir}

  notice "Finished process for Centos ${CENTOSVERSION}."
  echo ""
}

###############################################################################
# Cleanup if bad exits trapped
###############################################################################
function trapCleanup() {
  echo ""
  # Delete temp files, if any
  if [ -d "${tmpDir}" ] ; then
  rm -r "${tmpDir}"
  fi
  die "Exit trapped. In function: '${FUNCNAME[*]}'"
}

###############################################################################
# Cleanup on exit
###############################################################################
function safeExit() {
  # Delete temp files, if any
  if [ -d "${tmpDir}" ] ; then
  rm -r "${tmpDir}"
  fi
  trap - INT TERM EXIT
  exit
}

###############################################################################
# Set base variables
###############################################################################
scriptName=$(basename "$0")
prereqs=(sha256sum wget mkisofs isohybrid implantisomd5 curl file)

# Set Flags
quiet=false
printLog=false
verbose=false
force=false
strict=false
debug=false
args=()

# Set Colors
bold=$(tput bold)
reset=$(tput sgr0)
purple=$(tput setaf 171)
red=$(tput setaf 1)
green=$(tput setaf 76)
tan=$(tput setaf 3)
blue=$(tput setaf 38)
underline=$(tput sgr 0 1)

# Set Temp Directory
tmpDir="/tmp/${scriptName}.$RANDOM.$RANDOM.$RANDOM.$$"
(umask 077 && mkdir "${tmpDir}") || {
  die "Could not create temporary directory! Exiting."
}

# Logging
# -----------------------------------
# Log is only used when the '-l' flag is set.
logFile="/tmp/${scriptBasename}.log"

# Print help if no arguments were passed.
# Uncomment to force arguments when invoking the script
# -------------------------------------
[[ $# -eq 0 ]] && set -- "-h"

###############################################################################
# Prettier outputs
###############################################################################
function _alert() {
  if [ "${1}" = "error" ]; then local color="${bold}${red}"; fi
  if [ "${1}" = "warning" ]; then local color="${red}"; fi
  if [ "${1}" = "success" ]; then local color="${green}"; fi
  if [ "${1}" = "debug" ]; then local color="${purple}"; fi
  if [ "${1}" = "header" ]; then local color="${bold}${tan}"; fi
  if [ "${1}" = "input" ]; then local color="${bold}"; fi
  if [ "${1}" = "info" ] || [ "${1}" = "notice" ]; then local color=""; fi
  # Don't use colors on pipes or non-recognized terminals
  if [[ "${TERM}" != "xterm"* ]] || [ -t 1 ]; then color=""; reset=""; fi

  # Print to console when script is not 'quiet'
  if ${quiet}; then return; else
   echo -e "$(date +"%r") ${color}$(printf "[%7s]" "${1}") ${_message}${reset}";
  fi

  # Print to Logfile
  if ${printLog} && [ "${1}" != "input" ]; then
  color=""; reset="" # Don't use colors in logs
  echo -e "$(date +"%m-%d-%Y %r") $(printf "[%7s]" "${1}") ${_message}" >> "${logFile}";
  fi
}

function die ()     { local _message="${*} Exiting."; echo -e "$(_alert error)"; safeExit;}
function error ()   { local _message="${*}"; echo -e "$(_alert error)"; }
function warning ()   { local _message="${*}"; echo -e "$(_alert warning)"; }
function notice ()  { local _message="${*}"; echo -e "$(_alert notice)"; }
function info ()    { local _message="${*}"; echo -e "$(_alert info)"; }
function debug ()   { local _message="${*}"; echo -e "$(_alert debug)"; }
function success ()   { local _message="${*}"; echo -e "$(_alert success)"; }
function input()    { local _message="${*}"; echo -n "$(_alert input)"; }
function header()   { local _message="== ${*} ==  "; echo -e "$(_alert header)"; }
function verbose()  { if ${verbose}; then debug "$@"; fi }

###############################################################################
# Argument parsing
###############################################################################
while [[ $1 = -?* ]]; do
   case $1 in
    -7) cversion=7 ;;
    -8) cversion=8 ;;
    -0) cversion=8-stream ;;
    -a) cversion=all ;;
    -h) usage ;;
    -d) debug=true ;;
    -v) verbose=true ;;
    -q) quiet=true ;;
    -a) strict=true ;;
    -l) printLog=true ;;
    -z) echo "$(basename $0) ${version}"; safeExit ;;
    *) die "invalid option: '$1'." ;;
   esac
   shift
done

###############################################################################
# echo usage message
###############################################################################
function usage () {
   [[ -n ${DEBUG} ]] && set -x
   echo "Usage: ${0##*/}"
   echo "     -7 : Create ISO for CentOS Version 7"
   echo "     -8 : Create ISO for CentOS Version 8"
   echo "     -0 : Create ISO for CentOS Version 8-stream"
   echo "     -a : Create ISO for all three versions"
   echo "     -l : Print log to file"
   echo "     -q : Quiet (no output)"
   echo "     -s : Exit script with null variables.  i.e 'set -o nounset'"
   echo "     -v : Output more information. (Items echoed to 'verbose')"
   echo "     -d : Runs script in BASH debug mode (set -x)"
   echo "     -h : Display this help and exit"
   echo "     -h : display this help message"
   echo "     -z : display version and exit"
   exit 1
}

###############################################################################
# Check if all the pre-reqs are installed
###############################################################################
function checking_prereqs () {
  info "Checking if all necessary programs are found."
  for i in "${prereqs[@]}"; do
    if ! command -v $i &> /dev/null; then
      die "$i could not be found"
    fi
  done
}

###############################################################################
# switch to logfiles if not startet from interactive shell
###############################################################################
function set_log () {
   (tty < /dev/tty) > /dev/null 2>&1
   if [[ $? -ne 0 ]]; then
    exec 1>> ${logfile}
    exec 2>> ${logfile}
   fi
}

###############################################################################
# check for free space in Filesystem
###############################################################################
function checkfree () {
   fs=$1
   typeset -i actfree=0
   actfree=$(df -k ${fs} | tail -1 | awk '{print $4}')
   if (( actfree > minfree ))
   then
    return 0
   else
    die "not enough free disk space in ${fs}"
   fi
}

###############################################################################
# Check if root startet this script
###############################################################################
function checkroot () {
    [[ -n ${DEBUG} ]] && set -x
    id | /bin/grep '^[^=]*=0(' >/dev/null 2>&1
    if [ $? != 0 ]; then
        die "Only root can use this Script (uid=0)"
    fi
}

###############################################################################
# Trap bad exits with cleanup function
###############################################################################
trap trapCleanup EXIT INT TERM

###############################################################################
# Set IFS to preferred implementation
###############################################################################
IFS=$' \n\t'

###############################################################################
# Exit on error. Append '||true' when you run the script if you expect an error.
###############################################################################
set -o errexit

###############################################################################
# Run in debug mode, if set
###############################################################################
if ${debug}; then set -x ; fi

###############################################################################
# Exit on empty variable
###############################################################################
if ${strict}; then set -o nounset ; fi

###############################################################################
# Bash will remember & return the highest exitcode in a chain of pipes.
# This way you can catch the error in case mysqldump fails in `mysqldump |gzip`, for example.
###############################################################################
set -o pipefail

###############################################################################
# Run the script
###############################################################################
checking_prereqs
mainScript

###############################################################################
# Exit cleanly
###############################################################################
safeExit
