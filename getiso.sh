#!/usr/bin/env bash
MYDIR=`dirname "$(realpath $0)"`

OUT="/root/seafile/sync"
KSDIR="${MYDIR}/ks"

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
function get_iso () {
  CURDIR=`pwd`
  cd ${tmpDir}

  ISOURL="http://isoredirect.centos.org/centos/${CENTOSVERSION}/isos/x86_64/${NAME}"
  info "Downloading upstream iso ${NAME}"
  wget ${ISOURL} -q -O ${tmpDir}/${NAME}

  info "Checking Checksum"
  if [ ${CENTOSVERSION} == "7" ]; then
      wget http://linuxsoft.cern.ch/centos/${CENTOSVERSION}/isos/x86_64/sha256sum.txt -q -O - | grep ${NAME} > ${tmpDir}/sha256sum.txt
  else
      wget http://linuxsoft.cern.ch/centos/${CENTOSVERSION}/isos/x86_64/CHECKSUM -q -O - | grep ${NAME} > ${tmpDir}/sha256sum.txt
  fi

  if sha256sum -c sha256sum.txt; then
      info "File ${NAME} correctly downloaded"
  else
      die "${NAME} not correctly downloaded."
  fi

  info "Now calling createiso.sh to create custom iso out of it"
  ${MYDIR}/createiso.sh ${tmpDir}/${NAME} ${KSDIR}/minimal-${CENTOSVERSION}.ks.cfg ${OUT}

  rm ${tmpDir}/${NAME}
  cd ${CURDIR}
}

function dl_7 () {
    VERSION7="$(curl -s -L http://isoredirect.centos.org/centos/7/isos/x86_64/ | grep NetInstall | grep 'iso"' | sed -e 's/.*-NetInstall-\(.*\)\.iso.*/\1/')"
    NAME="CentOS-7-x86_64-NetInstall-${VERSION7}.iso"
    CENTOSVERSION="7"
    get_iso
}

function dl_8 () {
    VERSION8="$(curl -s -L http://isoredirect.centos.org/centos/8/isos/x86_64/ | grep 'boot.iso"' | sed -e 's/.*CentOS-\(.*\)-x86_64.*/\1/')"
    NAME="CentOS-${VERSION8}-x86_64-boot.iso"
    CENTOSVERSION="8"
    get_iso
}

function dl_8stream () {
    STREAMVERSION="$(curl -s -L http://isoredirect.centos.org/centos/8-stream/isos/x86_64/ | grep 'boot.iso"' | sed -e 's/.*x86_64-\(.*\)-boot.*/\1/')"
    NAME="CentOS-Stream-8-x86_64-${STREAMVERSION}-boot.iso"
    CENTOSVERSION="8-stream"
    get_iso
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

# Set Flags
quiet=false
printLog=false
verbose=false
force=false
strict=false
debug=false
args=()

if [[ $- == *i* ]]; then
# Set Colors
bold=$(tput bold)
reset=$(tput sgr0)
purple=$(tput setaf 171)
red=$(tput setaf 1)
green=$(tput setaf 76)
tan=$(tput setaf 3)
blue=$(tput setaf 38)
underline=$(tput sgr 0 1)
fi

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
  echo "Usage: ${0##*/} VERSIONS"
  echo ""
  echo "  VERSIONS can be 7 8 8-stream or all"
  echo "  Except of 'all', you can combine them in any order, with whitespace in between:"
  echo "  $(basename $0) 7 8"
  exit 1
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
for VERSION in "$@"; do
  case ${VERSION} in
    all)
      dl_7
      dl_8
      dl_8stream
      ;;

    7)
      dl_7
      ;;

    8)
      dl_8
      ;;

    8-stream)
      dl_8stream
      ;;

    *)
      usage
      break
      ;;
  esac
done

###############################################################################
# Exit cleanly
###############################################################################
safeExit
