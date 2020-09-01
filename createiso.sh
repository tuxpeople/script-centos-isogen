#!/usr/bin/env bash

version="1.0.0"   # Version of this script

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
  # Do some tests on the arguments
  [ -z "${1}" ] && usage
  [ -z "${2}" ] && die "Not enought arguments"
  [ -z "${3}" ] && die "Not enought arguments"
  [ ! -f ${1} ] && die "Specified ISO image ${1} not found."
  [ ! -f ${2} ] && die "Specified kickstart file ${2} does not exist."
  [ ! -d ${3} ] && die "Specified output directory ${3} does not exist."

  notice "Using ISO ${1} and kickstart ${2} to create a customized ISO in ${3}."

  # check if we have 1G free in /tmp and change into tmpDir
  minfree=1232896
  checkfree /tmp
  CURDIR=`pwd`
  cd ${tmpDir}

  VOLUMENAME=$(file -s ${1} | cut -d"'" -f2)
  UPSTREAMISO=${1}
  KICKSTART=${2}
  OUT=${3}
  SRC=${tmpDir}/upstreamiso
  DST=${tmpDir}/customiso
  EFI=${tmpDir}/efi
  NAME=$(basename $1)

  info "Creating directory ${SRC}"
  mkdir ${SRC}

  info "Mounting upstream iso ${UPSTREAMISO} to ${SRC}"
  mount -o loop ${UPSTREAMISO} ${SRC}

  info "Creating directory ${DST}"
  mkdir ${DST}

  info "Copy iso content from ${SRC} to ${DST}"
  cp -r ${SRC}/* ${DST}

  info "Unmount upstream ISO ${UPSTREAMISO} and removing directory ${SRC}"
  umount ${SRC} && rmdir ${SRC}
  chmod -R u+w ${DST}

  info "Creating directory ${EFI}"
  mkdir ${EFI}

  info "Make efiboot image read-write"
  chmod 644 $DST/images/efiboot.img

  info "Mounting efiboot image to ${EFI}"
  mount -o loop $DST/images/efiboot.img ${EFI}

  info "Adding kickstart to efiboot boot menu"
  LABEL=$(grep "inst.stage2" ${EFI}/EFI/BOOT/grub.cfg | tail -1 | cut -d'=' -f3 |  cut -d' ' -f1 | sed 's/x2/\\x2/g')
  KICKSTARTCFG="inst.ks=hd:LABEL=${LABEL}:/isolinux/ks.cfg"
  sed -i 's|vmlinuz|vmlinuz '$KICKSTARTCFG'|g' ${EFI}/EFI/BOOT/grub.cfg
  cp ${EFI}/EFI/BOOT/grub.cfg ${DST}/EFI/BOOT/grub.cfg

  info "Unmounting efiboot image from ${EFI}"
  umount $EFI/

  info "Make efiboot image read-only again"
  chmod 444 $DST/images/efiboot.img

  info "Adding kickstart to isolinux boot menu"
  ISOLINUXKICKSTARTCFG="inst.stage2=hd:LABEL=${LABEL}:/isolinux/ks.cfg"
  sed -i 's/append\ initrd\=initrd.img/append initrd=initrd.img\ ${ISOLINUXKICKSTARTCFG}/' ${DST}/isolinux/isolinux.cfg

  info "Copy kickstart file ${KICKSTART} to ${DST}/isolinux/ks.cfg"
#  cp ${KSDIR}/minimal-generic.ks ${DST}/isolinux/ks.cfg
  cp ${KICKSTART} ${DST}/isolinux/ks.cfg

  info "Generate new iso"
  cd ${DST}
  #mkisofs -o ${OUT}/Custom-${NAME} -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "${VOLUMENAME}" -R -J  -quiet -T isolinux/. . > /dev/null
  genisoimage \
      -V "${VOLUMENAME}" \
      -A "${VOLUMENAME}" \
      -o ${OUT}/Custom-${NAME} \
      -joliet-long \
      -b isolinux/isolinux.bin \
      -c isolinux/boot.cat \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -input-charset UTF8 \
      -eltorito-alt-boot -e images/efiboot.img \
      -no-emul-boot \
      -R -J -q -T ${DST} > /dev/null

  cd ${CURDIR}
  isohybrid --uefi ${OUT}/Custom-${NAME}
  implantisomd5 ${OUT}/Custom-${NAME} > /dev/null

  notice "Finished. You'll find your new customized ISO in ${3}."
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
logFile="/tmp/${scriptName}.log"

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
# echo usage message
###############################################################################
function usage () {
   echo "Usage: ${0##*/} ISO KICKSTART DESTINATION"
   echo ""
   echo "          ISO : The downloaded ISO file"
   echo "    Kickstart : The kickstart file to use"
   echo "  Destination : Where to save the new custom ISO image"
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
   fs=${1}
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
# Bash will remember & return the highest exitcode in a chain of pipes.
# This way you can catch the error in case mysqldump fails in `mysqldump |gzip`, for example.
###############################################################################
set -o pipefail

###############################################################################
# Run the script
###############################################################################
checking_prereqs
mainScript $1 $2 $3

###############################################################################
# Exit cleanly
###############################################################################
safeExit