#!/usr/bin/env bash

get_rc_file() {
  case ${SHELL##*/} in
  bash)
    DVM_RC_FILE="$HOME/.bashrc"
    ;;
  zsh)
    DVM_RC_FILE="$HOME/.zshrc"
    ;;
  *)
    DVM_RC_FILE="$HOME/.profile"
    ;;
  esac
}

add_nvm_into_rc_file() {
  local is_dvm_defined

  get_rc_file

  is_dvm_defined=$(grep DVM_DIR < "$DVM_RC_FILE")

  if [ -n "$is_dvm_defined" ]
  then
    return
  fi

  echo "
# Deno Version Manager
export DVM_DIR=\"\$HOME/.dvm\"
export DVM_BIN=\"\$DVM_DIR/bin\"
export PATH=\"\$PATH:\$DVM_BIN\"
[ -f \"\$DVM_DIR/dvm.sh\" ] && alias dvm=\"\$DVM_DIR/dvm.sh\"
[ -f \"\$DVM_DIR/bash_completion\" ] && . \"\$DVM_DIR/bash_completion\"
" >> "$DVM_RC_FILE"
}

get_latest_version() {
  local request_url
  local response
  local field

  case "$DVM_SOURCE" in
  gitee)
    request_url="https://gitee.com/api/v5/repos/ghosind/dvm/releases/latest"
    field="6"
    ;;
  github|*)
    request_url="https://api.github.com/repos/ghosind/dvm/releases/latest"
    field="4"
    ;;
  esac

  if [ ! -x "$(command -v curl)" ]
  then
    echo "Curl is required."
    exit 1
  fi

  if ! response=$(curl -s "$request_url")
  then
    echo "Failed to get the latest DVM version."
    exit 1
  fi

  DVM_LATEST_VERSION=$(echo "$response" | grep tag_name | cut -d '"' -f $field)
}

install_latest_version() {
  local git_url
  local cmd

  case "$DVM_SOURCE" in
  gitee)
    git_url="https://gitee.com/ghosind/dvm.git"
    ;;
  github|*)
    git_url="https://github.com/ghosind/dvm.git"
    ;;
  esac

  if [ ! -x "$(command -v git)" ]
  then
    echo "git is require."
    exit 1
  fi

  cmd="git clone -b $DVM_LATEST_VERSION $git_url $DVM_DIR"

  if ! ${cmd}
  then
    echo "failed to download DVM."
    exit 1
  fi
}

set_dvm_dir() {
  if [ ! -d "$DVM_DIR" ]
  then
    mkdir -p "$DVM_DIR"
  else
    echo "directory $DVM_DIR is existed."
    exit 1
  fi
}

install_dvm() {
  set_dvm_dir

  DVM_SCRIPT_DIR=${0%/*}

  if [ -f "$DVM_SCRIPT_DIR/dvm.sh" ] &&
    [ -d "$DVM_SCRIPT_DIR/.git" ] &&
    [ -f "$DVM_SCRIPT_DIR/bash_completion" ]
  then
    # Copy all files to DVM_DIR
    cp -R "$DVM_SCRIPT_DIR/". "$DVM_DIR"
  else
    get_latest_version
    install_latest_version
  fi

  add_nvm_into_rc_file

  echo "DVM has been installed, please restart your terminal or run \`source $DVM_RC_FILE\` to apply changes."
}

set_default() {
  DVM_DIR="$HOME/.dvm"
  DVM_SOURCE="github"
}

print_help() {
  printf "DVM install script

Usage: install.sh [-r <github|gitee>] [-d <dvm_dir>]

Options:
  -r <github|gitee>   Set the repository server, default github.
  -d dir              Set the dvm install directory, default ~/.dvm.
  -h                  Print help.

Example:
  install.sh -r github -d ~/.dvm
"
}

set_default

while getopts "hr:d:" opt
do
  case "$opt" in
  h)
    print_help
    exit 0
    ;;
  r)
    if [ "$OPTARG" != "github" ] && [ "$OPTARG" != "gitee" ]
    then
      print_help
      exit 1
    fi
    DVM_SOURCE="$OPTARG"
    ;;
  d)
    if [ -z "$OPTARG" ]
    then
      print_help
      exit 1
    fi

    DVM_DIR="$OPTARG"
    ;;
  *)
    ;;
  esac
done

install_dvm
