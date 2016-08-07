#!/bin/bash

# Set colors
unset ALL_OFF BOLD BLUE GREEN RED YELLOW
ALL_OFF="\e[1;0m"
BOLD="\e[1;1m"
BLUE="${BOLD}\e[1;34m"
GREEN="${BOLD}\e[1;32m"
RED="${BOLD}\e[1;31m"
YELLOW="${BOLD}\e[1;33m"
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW

msg() {
  (( QUIET )) && return
  local mesg=$1; shift
  printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&1
}

msg2() {
  (( QUIET )) && return
  local mesg=$1; shift
  printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&1
}

warning() {
  local mesg=$1; shift
  printf "${YELLOW}==> $(gettext "WARNING:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
  local mesg=$1; shift
  printf "${RED}==> $(gettext "ERROR:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

if [ $# -eq 0 ]
then
  error "Usage: $0 repository-name"
  exit 1
fi

BASEDIR="$(dirname "$(readlink -f $1)"/$1)"
REPO_NAME="$(basename "${BASEDIR}/$1")"
KEYID="B250F0D3"
EXITCODE=0

# Set current directory as the same of the script
pushd "${BASEDIR}" > /dev/null
for _dir in *
do
  if [ -d "${_dir}" -a "${_dir}" != 'cache' ]
  then
    pushd "${_dir}" > /dev/null
    msg "Adding architecture ${_dir}"
    # Clear any previous database file
    rm -f "${REPO_NAME}".db.* "${REPO_NAME}".files.*
    # Sign all the files
    msg2 "Checking signatures..."
    for _file in *.xz
    do
      if [ -f "${_file}.sig" ]
      then
        # Signature exists, verify it
        #gpg --quiet --verify "${_file}.sig" 2> /dev/null || EXITCODE=$?
        if (( ! EXITCODE )); then
          msg2 "Signature verified for file ${_file}."
        else
          error "Signature was NOT valid for file ${_file}!"
          exit 1
        fi
      else
        # Signature missing, create signature file
        msg2 "Creating missing signature for file ${_file}."
        gpg --quiet --detach-sign --use-agent --no-armor --local-user ${KEYID} "${_file}"
      fi
    done

    # Update the repository
    msg2 "Updating repository..."
    repo-add --quiet --sign --key ${KEYID} "${REPO_NAME}.db.tar.gz" *.xz
    cp --remove-destination "${REPO_NAME}.db.tar.gz" "${REPO_NAME}.db"
    cp --remove-destination "${REPO_NAME}.db.tar.gz.sig" "${REPO_NAME}.db.sig"
    cp --remove-destination "${REPO_NAME}.files.tar.gz" "${REPO_NAME}.files"
    cp --remove-destination "${REPO_NAME}.files.tar.gz.sig" "${REPO_NAME}.files.sig"
    # Remove old files and signatures
    rm -f *.old *.old.sig
    popd > /dev/null
  fi
done

popd > /dev/null

