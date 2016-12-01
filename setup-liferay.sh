#!/bin/bash

# 1 for true
# 0 for false
no_auth=1
repository_protocol='http'
liferay_server='192.168.110.251'
#repository_protocol='https'
#liferay_server='files.liferay.com'

portal_link="${repository_protocol}://${liferay_server}/private/ee/portal"
patchingtool_link="${repository_protocol}://${liferay_server}/private/ee/fix-packs/patching-tool"
patches_link="${repository_protocol}://${liferay_server}/private/ee/fix-packs"

mkdir bundles licenses patches patching-tool tickets &> /dev/null

lrversion() {

  local -r ver_option="$1"

  case "$ver_option" in
    6.1.10) lrver="${ver_option}-ee-ga1-20120217120951450" dwnldver="${ver_option}" ;;
    6.1.20) lrver="${ver_option}-ee-ga2-20120731110418084" dwnldver="${ver_option}" ;;
    6.1.30) lrver="${ver_option%.*}-ee-ga3-sp5-20160201142343123" dwnldver="${ver_option}.5" ;;
    6.2.10) lrver="${ver_option%.*}-ee-sp14-20151105114451508" dwnldver="${ver_option}.15" ;;
    7.0.10) lrver="${ver_option%.*}-sp1-20161027112321352" dwnldver="${ver_option}.1" ;;
    *)      echo "${ver_option} is not a valid version. Available versions are 6.1.10, 6.1.20, 6.1.30, 6.2.10, 7.0.10" ; exit 1 ;;
  esac

  if [[ $ver_option == "7.0.10" ]]; then
    liferay_zip="liferay-dxp-digital-enterprise-tomcat-${lrver}.zip"
    liferay_instance="liferay-dxp-digital-enterprise-${lrver%-*}"
  else
    liferay_zip="liferay-portal-tomcat-${lrver}.zip"
    liferay_instance="liferay-portal-${lrver%-*}"
  fi

    lrver_major="${ver_option%.*}"
    lrversion=${ver_option}
}

create_workspace() {
  readonly workspace="tickets/$1"
  mkdir -p $workspace || exit 1
}

get_liferay_credentials() {

  # place a default.properties file with your liferay user and
  # password like bellow, so we can use it to download patches:
  #
  # download.url=http://files.liferay.com/private/ee/fix-packs/
  # download.user=<your.user>
  # download.password=<your password>
  #
  # then execute "./crypt-decrypt enc" to encrypt your password

  local remove_escapes='sed '"'"'s/\\!/!/g'"'"' | sed '"'"'s/\\\#/#/g'"'"' | sed '"'"'s/\\\=/=/g'"'"' | sed '"'"'s/\\\:/:/g'"'"''

  {
    readonly liferay_user=$(grep 'download.user' default.properties | cut -f2 -d= | eval $remove_escapes)
    #readonly liferay_pass=$(grep 'download.password' default.properties | cut -f2 -d= | eval $remove_escapes)
    readonly liferay_pass=$(./crypt-decrypt dec | eval $remove_escapes)
  } || { 
    echo "ERROR: Set your credentials in the default.properties file!"
    exit 1
  }

}

download(){
  # $1 [progress|quiet] 
  # $2 Download URL
  # $3 Path to download to

  [[ (-z $liferay_user || -z $liferay_pass) && $no_auth -ne 1 ]] && get_liferay_credentials

  case "$1" in
    progress)
      wget -nv --show-progress -c $2 --user="${liferay_user}" --password="${liferay_pass}" -P $3
    ;;
    quiet)
      wget -q -c $2 --user="${liferay_user}" --password="${liferay_pass}" -P $3
    ;;
    *)
      echo "Usage $FUNCNAME [progress|quiet]"
    ;;
  esac

}

download_patching-tool() {
  
  [[ "${lrver_major%.*}" == "7" ]] && rel="-2.0"
 
  if download quiet ${patchingtool_link}/LATEST${rel}.txt /tmp; then

    pt_latest=$(cat /tmp/LATEST${rel}.txt) && rm -f /tmp/LATEST${rel}.txt 

    if [[ ! -e patching-tool/patching-tool-${pt_latest}-internal.zip ]]; then

      echo "Downloading latest version of patching-tool..."
      download progress ${patchingtool_link}/patching-tool-${pt_latest}-internal.zip patching-tool/ \
        || echo "ERROR: Could not download latest version of patching-tool!"

    fi

  else
    echo "ERROR: Could not determine patching-tool latest version!"
  fi

}

install_patching-tool() {
  local -r liferay_home="$1"

  download_patching-tool

  if [[ ! -z $pt_latest ]]; then
    rm -rf "$liferay_home/patching-tool"

    echo "Unpacking patching-tool..."
    unzip -qn patching-tool/patching-tool-${pt_latest}-internal.zip -d "$liferay_home"

    ./$liferay_home/patching-tool/patching-tool.sh auto-discovery

    [[ -e default.properties ]] && grep -Ev '^download.' default.properties >> ./$liferay_home/patching-tool/default.properties
  fi
}

install_license() {
  mkdir $workspace/$liferay_instance/deploy

  if [[ "${lrver_major%.*}" == "7" ]]; then
    cp licenses/activation-key-digitalenterprisedevelopment-${lrver_major}-liferaycom.xml $workspace/$liferay_instance/deploy
  else
    cp licenses/license-portaldevelopment-developer-cluster-${lrver_major}*.xml $workspace/$liferay_instance/deploy
  fi
}

download_liferay() {
  if [[ ! -e bundles/$liferay_zip ]]; then
    echo "Downloading Liferay..."
    {
      download progress ${portal_link}/${dwnldver}/$liferay_zip bundles/
    } || {
      echo "ERROR: Could not download Liferay!" ; exit 1
    }
  fi
}

download_patch() {
#  if [[ $nopatch != true ]]; then
#    if [[ -a $1 ]]; then
#      ./$workspace/$liferay_instance/patching-tool/patching-tool.sh download-all "$(pwd)/$1"
#    else
#      ./$workspace/$liferay_instance/patching-tool/patching-tool.sh download "$1"
#    fi
#    ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install
#  fi

  case "$1" in
    de-*)
      case "$1" in
        *-7010)
          if [[ ! -e patches/liferay-fix-pack-${1}.zip ]]; then
            download progress ${patches_link}/7.0.10/de/liferay-fix-pack-${1}.zip patches/
          fi
          cp -v patches/liferay-fix-pack-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *)
          echo "Usage: $FUNCNAME [de-*-7010]"
        ;;
      esac
    ;;
    portal-*)
      case "$1" in
        *-6130)
          if [[ ! -e patches/liferay-fix-pack-${1}.zip ]]; then
            download progress ${patches_link}/6.1.30/portal/liferay-fix-pack-${1}.zip patches/
          fi
          cp -v patches/liferay-fix-pack-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *-6210)
          if [[ ! -e patches/liferay-fix-pack-${1}.zip ]]; then
            download progress ${patches_link}/6.2.10/portal/liferay-fix-pack-${1}.zip patches/
          fi
          cp -v patches/liferay-fix-pack-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *)
          echo "Usage: $FUNCNAME [portal-*-6130|portal-*-6210]"
        ;;
      esac
    ;;
    hotfix-*)
      case "$1" in
        *-6110)
          if [[ ! -e patches/liferay-${1}.zip ]]; then
            download progress ${patches_link}/6.1.10/hotfix/liferay-${1}.zip patches/
          fi
          cp -v patches/liferay-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *-6120)
          if [[ ! -e patches/liferay-${1}.zip ]]; then
            download progress ${patches_link}/6.1.20/hotfix/liferay-${1}.zip patches/
          fi
          cp -v patches/liferay-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *-6130)
          if [[ ! -e patches/liferay-${1}.zip ]]; then
            download progress ${patches_link}/6.1.30/hotfix/liferay-${1}.zip patches/
          fi
          cp -v patches/liferay-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *-6210)
          if [[ ! -e patches/liferay-${1}.zip ]]; then
            download progress ${patches_link}/6.2.10/hotfix/liferay-${1}.zip patches/
          fi
          cp -v patches/liferay-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *-7010)
          if [[ ! -e patches/liferay-${1}.zip ]]; then
            download progress ${patches_link}/7.0.10/hotfix/liferay-${1}.zip patches/
          fi
          cp -v patches/liferay-${1}.zip $workspace/$liferay_instance/patching-tool/patches/
        ;;
        *)
          echo "Usage: $FUNCNAME [hotfix-*-6110|hotfix-*-6120|hotfix-*-6130|hotfix-*-6210|hotfix-*-7010]"
        ;;
      esac
    ;;
    *)
      echo "Usage: $FUNCNAME [de-*|portal-*|hotfix-*]"
    ;;
  esac

}

install_patch() {

  if [[ "$1" =~ (de|portal|hotfix)-[0-9]+-[0-9]{4} ]]; then
      download_patch "$1"
      if [[ $? -eq 0 ]]; then
        ./$workspace/$liferay_instance/patching-tool/patching-tool.sh revert
        ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install
      else
        echo "ERROR: Could not download $1!"
      fi
  else
      echo "Usage: $FUNCNAME [de-*|portal-*|hotfix-*]"
  fi
}

install_latest_patch() {

if [[ $nopatch != true ]] && [[ -z $patch ]]; then
  case "$lrversion" in
    7.0.10)
    
      if download quiet ${patches_link}/${lrversion}/de/LATEST.txt /tmp; then
  
        latest_patch=$(cat /tmp/LATEST.txt) && rm -f /tmp/LATEST.txt
  
        if [[ ! -e patches/liferay-fix-pack-de-${latest_patch}-${lrversion//./}.zip ]]; then
  
          echo "Downloading latest patch..."
          install_patch "de-${latest_patch}-${lrversion//./}"

        else

          cp patches/liferay-fix-pack-de-${latest_patch}-${lrversion//./}.zip $workspace/$liferay_instance/patching-tool/patches/
          ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install

        fi
  
      else
        echo "ERROR: Could not determine latest patch version!"
      fi
    
    ;;
    6.1.30|6.2.10)
    
      if download quiet ${patches_link}/${lrversion}/portal/LATEST.txt /tmp; then
  
        latest_patch=$(cat /tmp/LATEST.txt) && rm -f /tmp/LATEST.txt
  
        if [[ ! -e patches/liferay-fix-pack-portal-${latest_patch}-${lrversion//./}.zip ]]; then
  
          echo "Downloading latest patch..."
          install_patch "portal-${latest_patch}-${lrversion//./}"

        else

          cp patches/liferay-fix-pack-portal-${latest_patch}-${lrversion//./}.zip $workspace/$liferay_instance/patching-tool/patches/
          ./$workspace/$liferay_instance/patching-tool/patching-tool.sh install

        fi
  
      else
        echo "ERROR: Could not determine latest patch version!"
      fi
    
    ;;
    *) echo "Warn: Automatic patch download not implemented for this version of Liferay $lrversion" ;;
  esac
fi

}

install_liferay() {
 
  if [[ -d $workspace/$liferay_instance ]]; then
    echo "There's already an instance of Liferay installed on $workspace/$liferay_instance"
  else
    download_liferay
    echo "Unpacking Liferay..."
    unzip -qn bundles/$liferay_zip -d $workspace
    chmod +x $workspace/$liferay_instance/tomcat*/bin/*.sh
    install_license
    install_patching-tool $workspace/$liferay_instance
    install_latest_patch
    cp portal-ext.properties $workspace/$liferay_instance
  fi
   
}

run() {
  if [[ -z $workspace ]]; then
    echo "You must specify a workspace!" 
    exit 1
  fi

  if [[ -z $lrversion ]]; then
    echo "You must specify a Liferay version!"
    exit 1
  fi
  
  install_liferay
  
  if [[ ! -z $dpatch ]]; then
    download_patch $dpatch
  fi

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
  echo -e " -d, --downloadpatch \t Only download a patch to the specified workspace"
  echo -e " -n, --nopatch   \t Don't install the latest patch automatically"
  echo -e " -h, --help      \t Show this message."
}

first_param="${@:1}"
if [[ $# -eq 0 || "${first_param:0:1}" != "-" ]]; then show_usage; exit 1; fi

SHORTOPTS="w:v:p:d:n"
LONGOPTS="workspace:,lrversion:,patch:,downloadpatch:,nopatch,help"

ARGS=$(getopt --name $0 --longoptions="$LONGOPTS" --options="$SHORTOPTS" -- "$@")
eval set -- "$ARGS"

while true; do
  case "$1" in
    -w|--workspace)      create_workspace "$2"	;    shift 2  ;;
    -v|--lrversion)      lrversion "$2"		;    shift 2  ;;
    -p|--patch)          patch="$2"		;    shift 2  ;;
    -d|--downloadpatch)  dpatch="$2"		;    shift 2  ;;
    -n|--nopatch)        nopatch=true		;    shift    ;;
    -h|--help)           show_usage		;    exit 0   ;;
    --)                  shift			;    break    ;;
    *)                   show_usage		;    exit 1   ;;
  esac
done

run
