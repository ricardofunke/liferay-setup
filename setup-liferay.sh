#!/bin/bash

portal_link='https://files.liferay.com/private/ee/portal'
patchingtool_link='https://files.liferay.com/private/ee/fix-packs/patching-tool'
patches_link='https://files.liferay.com/private/ee/fix-packs'

mkdir bundles licenses patches patching-tool tickets &> /dev/null

lrversion() {

  local -r ver_option="$1"

  case "$ver_option" in
    6.1.10) lrver="${ver_option}-ee-ga1-20120217120951450" dwnldver="${ver_option}" ;;
    6.1.20) lrver="${ver_option}-ee-ga2-20120731110418084" dwnldver="${ver_option}" ;;
    6.1.30) lrver="${ver_option}-ee-ga3-20130812170130063" dwnldver="${ver_option}.1" ;;
    6.2.10) lrver="${ver_option}.1-ee-ga1-20131126141110470" dwnldver="${ver_option}.1" ;;
    *)      echo "${ver_option} is not a valid version. Available versions are 6.1.10, 6.1.20, 6.1.30, 6.2.10" ; exit 1 ;;
  esac

  liferay_zip="liferay-portal-tomcat-${lrver}.zip"
  liferay_instance="liferay-portal-${lrver%-*}"
  lrver_major="${ver_option%.*}"
  lrversion=${ver_option}
}

create_workspace() {
  declare -gr workspace="tickets/$1"
  mkdir -p $workspace || exit 1
}

get_liferay_credentials() {

  local remove_escapes='sed '"'"'s/\\!/!/g'"'"' | sed '"'"'s/\\\#/#/g'"'"' | sed '"'"'s/\\\=/=/g'"'"' | sed '"'"'s/\\\:/:/g'"'"''

  liferay_user=$(grep 'download.user' default.properties | cut -f2 -d= | eval $remove_escapes)
  liferay_pass=$(grep 'download.password' default.properties | cut -f2 -d= | eval $remove_escapes)

}

download_patching-tool() {
  
  if get_liferay_credentials; then
  
    if wget -q ${patchingtool_link}/LATEST.txt --user="${liferay_user}" --password="${liferay_pass}" -P /tmp; then

      pt_latest=$(cat /tmp/LATEST.txt) && rm -f /tmp/LATEST.txt 

      if [[ ! -e patching-tool/patching-tool-${pt_latest}-internal.zip ]]; then

        echo "Downloading latest version of patching-tool..."
        wget -nv --show-progress -c ${patchingtool_link}/patching-tool-${pt_latest}-internal.zip --user="${liferay_user}" --password="${liferay_pass}" -P patching-tool/ \
          || echo "ERROR: Could not download latest version of patching-tool!"

      fi

    else
      echo "ERROR: Could not determine patching-tool latest version!"
    fi
 
  fi 

}

install_patching-tool() {
  local -r liferay_home="$1"

  download_patching-tool

  pt_latest_local=$(ls -1 patching-tool/ | sort -nr | head -n1)
  if [[ ! -z $pt_latest_local ]]; then
    rm -rf "$liferay_home/patching-tool"

    echo "Unpacking patching-tool..."
    unzip -qn patching-tool/$pt_latest_local -d "$liferay_home"

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

download_liferay() {
  if [[ ! -e bundles/$liferay_zip ]]; then
    if get_liferay_credentials; then
      echo "Downloading Liferay..."
      wget -nv --show-progress -c ${portal_link}/${dwnldver}/$liferay_zip --user="${liferay_user}" --password="${liferay_pass}" -P bundles/ || exit 1
    else
      echo "Warn: Could not obtain your Liferay credentials!"
    fi
  fi
}

install_patch() {
  if [[ $nopatch != true ]]; then
    if [[ -a $1 ]]; then
      ./$workspace/$liferay_instance/patching-tool/patching-tool.sh download-all "$(pwd)/$1"
    else
      ./$workspace/$liferay_instance/patching-tool/patching-tool.sh download "$1"
    fi
    ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install
  fi
}

install_latest_patch() {

if [[ $nopatch != true ]] && [[ -z $patch ]]; then
  case "$lrversion" in
    6.1.30|6.2.10)
      if get_liferay_credentials; then
    
        if wget -q ${patches_link}/${lrversion}/portal/LATEST.txt --user="${liferay_user}" --password="${liferay_pass}" -P /tmp; then
    
          latest_patch=$(cat /tmp/LATEST.txt) && rm -f /tmp/LATEST.txt
    
          if [[ ! -e patches/liferay-fix-pack-portal-${latest_patch}-${lrversion//./}.zip ]]; then
    
            echo "Downloading latest patch..."
            wget -nv --show-progress -c ${patches_link}/${lrversion}/portal/liferay-fix-pack-portal-${latest_patch}-${lrversion//./}.zip --user="${liferay_user}" --password="${liferay_pass}" -P patches/ 

            if [[ $? -eq 0 ]]; then
              cp patches/liferay-fix-pack-portal-${latest_patch}-${lrversion//./}.zip $workspace/$liferay_instance/patching-tool/patches/
              ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install
            else
              echo "ERROR: Could not download latest patch!"
            fi

          else

            cp patches/liferay-fix-pack-portal-${latest_patch}-${lrversion//./}.zip $workspace/$liferay_instance/patching-tool/patches/
            ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install

          fi
    
        else
          echo "ERROR: Could not determine latest patch version!"
        fi
    
      fi
    ;;
    *) echo "Warn: Automatic patch download not implemented for this version of Liferay $lrversion" ;;
  esac
fi

}

install_liferay() {
  if [[ -d $workspace/$liferay_instance ]]; then
    echo "There's already an instance of Liferay installed on $workspace/$liferay_instance"
    echo "Nothing to do. Exiting..."
    exit 1
  fi
  
  download_liferay
  echo "Unpacking Liferay..."
  unzip -qn bundles/$liferay_zip -d $workspace
  install_license
  install_patching-tool $workspace/$liferay_instance
  install_latest_patch
}

run() {
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
  echo -e " -w, --workspace \t Specify the new workspace to work on, eg. smiles-11"
  echo -e " -v, --lrversion \t Specify the Liferay Version, eg. 6.2.10"
  echo -e " -p, --patch     \t Specify a patch to install eg. portal-40-6210 (multiple patches must"
  echo -e "                 \t   be separated by commas and inside quotation marks, this option also"
  echo -e "                 \t   supports a patchinfo.txt file)"
  echo -e " -n, --nopatch   \t Don't install the latest patch automatically"
  echo -e " -h, --help      \t Show this message."
}

first_param="${@:1}"
if [[ $# -eq 0 || "${first_param:0:1}" != "-" ]]; then show_usage; exit 1; fi

SHORTOPTS="w:v:p:n"
LONGOPTS="workspace:,lrversion:,patch:,nopatch,help"

ARGS=$(getopt --name $0 --longoptions="$LONGOPTS" --options="$SHORTOPTS" -- "$@")
eval set -- "$ARGS"

while true; do
  case "$1" in
    -w|--workspace)      create_workspace "$2"	;    shift 2  ;;
    -v|--lrversion)      lrversion "$2"		;    shift 2  ;;
    -p|--patch)          patch="$2"		;    shift 2  ;;
    -n|--nopatch)        nopatch=true		;    shift    ;;
    -h|--help)           show_usage		;    exit 0   ;;
    --)                  shift			;    break    ;;
    *)                   show_usage		;    exit 1   ;;
  esac
done

run
