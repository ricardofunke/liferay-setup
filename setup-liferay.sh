#!/bin/bash

mkdir bundles licenses patches patching-tool tickets &> /dev/null

lrversion() {

  local -r ver_option="$1"

  case "$ver_option" in
    6.1.10) lrver=${ver_option} ;;
    6.1.20) lrver="${ver_option}-ee-ga2-20120731110418084" ;;
    6.1.30) lrver="${ver_option}-ee-ga3-20130812170130063" ;;
    6.2.10) lrver="${ver_option}.1-ee-ga1-20131126141110470" ;;
    *)      echo "${ver_option} is not a valid version. Available versions are 6.1.10, 6.1.20, 6.1.30, 6.2.10" ; exit 1 ;;
  esac

  liferay_zip="liferay-portal-tomcat-${lrver}.zip"
  liferay_instance="liferay-portal-${lrver%-*}"
  lrver_major="${ver_option%.*}"
}

create_workspace() {
  declare -gr workspace="tickets/$1"
  mkdir -p $workspace || exit 1
}

install_patching-tool() {
  local -r liferay_home="$1"
  pt_latest_version=$(ls -1 patching-tool/ | sort -nr | head -n1)
  if [[ ! -z $pt_latest_version ]]; then
    rm -rf "$liferay_home/patching-tool"
    unzip patching-tool/$pt_latest_version -d "$liferay_home"
    ./$liferay_home/patching-tool/patching-tool.sh auto-discovery

    # place a default.properties file with your liferay user and
    # password like bellow, so we can use it to download patches:
    #
    # download.url=http://files.liferay.com/private/ee/fix-packs/
    # download.user=<your.user>
    # download.password=<your password>
    [[ -e default.properties ]] && cat default.properties >> ./$liferay_home/patching-tool/default.properties
  fi
}

install_license() {
  mkdir $workspace/$liferay_instance/deploy
  cp licenses/license-portaldevelopment-developer-cluster-${lrver_major}*.xml $workspace/$liferay_instance/deploy
}

install_liferay() {
  unzip bundles/$liferay_zip -d $workspace
  install_license
  install_patching-tool $workspace/$liferay_instance
}

install_patch() {
  if [[ $nopatch != true ]]; then
    if [[ -a $1 ]]; then
      ./$workspace/$liferay_instance/patching-tool/patching-tool.sh download-all $1
    else
      ./$workspace/$liferay_instance/patching-tool/patching-tool.sh download $1
    fi
    ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install
  fi
}

main() {
  if [[ -z $workspace ]]; then
    echo "You must specify a workspace!"
    exit 1
  fi

  install_liferay

  if [[ ! -z $patch ]]; then
    install_patch $patch
  fi
}

show_usage() {
  echo "Usage: $0 <options>"
  echo
  echo "Options:"
  echo -e " -w, --workspace \t\t\t Specify the new workspace to work on, eg. smiles-11"
  echo -e " -v, --lrversion \t\t\t Specify the Liferay Version, eg. 6.2.10"
  echo -e " -p, --patch     \t\t\t Specify a patch to install eg. portal-40-6210"
  echo -e " -n, --nopatch   \t\t\t Don't install the latest patch automatically (not implemented yet)"
  echo -e " -h, --help      \t\t\t Show this message."
}

first_param="${@:1}"
if [[ $# -eq 0 || "${first_param:0:1}" != "-" ]]; then show_usage; exit 1; fi

SHORTOPTS="w:v:p:n"
LONGOPTS="workspace:,lrversion:,patch:,nopatch,help"

ARGS=$(getopt --name $0 --longoptions="$LONGOPTS" --options="$SHORTOPTS" -- "$@")
eval set -- "$ARGS"

while true; do
  case "$1" in
    -w|--workspace)      create_workspace "$2"  ;    shift 2  ;;
    -v|--lrversion)      lrversion "$2"         ;    shift 2  ;;
    -p|--patch)          patch="$2"             ;    shift 2  ;;
    -n|--nopatch)        nopatch=true           ;    shift    ;;
    -h|--help)           show_usage             ;    exit 0   ;;
    --)                  shift                  ;    break    ;;
    *)                   show_usage             ;    exit 1   ;;
  esac
done

main
