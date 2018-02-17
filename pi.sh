#!/bin/bash
#
# pi - Pharo Install - A MIT-pip-like library for Pharo Smalltalk 
#
# Listing supports SmalltalkHub and GitHub. 
# 	SmalltalkHub listing requires libxml2 (xmllint command)
#	GitHub listing requires jq command (it will be downloaded if not present)
# Installs currently supported for:
# 	Metacello Configurations from Catalog (command line handler: get) 
# 	SmalltalkHub (command line handler: config)
#
# It works with curl or wget
# Tested on Pharo 5.0 under Windows 8.1

# Install BioSmalltalk stable
#   pi install  biosmalltalk
# Install BioSmalltalk developement
#   pi devinstall biosmalltalk 

#################################
## Pharo Download Settings
#################################
PHARO_VERSION=61
PI_VERSION=0.1
IMAGENAME="Pharo.image"
STHUB_URL="http://smalltalkhub.com/"
LIST_FILE="index.html"
SILENT_MODE=1
PLATFORM="Unknown"

#################################
## Helper Functions
#################################

function echo_line () {
	[ "$SILENT_MODE" == 1 ] && echo -n $1
}

function echo_nline () {
	[ "$SILENT_MODE" == 1 ] && echo $1
}

# Returns 0 if command was found in the current system, 1 otherwise
function cmdExists () {
    type "$1" &> /dev/null ;
	return $?
}

function trim_both () {
	echo $(echo -e "${1}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
}

# Search argument XPATH expression in HTML file
function xpath() {
	if [ $# -ne 2 ]; then
		echo "Usage: xpath xpath file"
		return 1
	fi
	xmllint --nonet --html --shell $2 <<< "cat $1" | sed '/^\/ >/d;/^\ /d'
}

function findPlatform () {
	# Find our platform
	echo_line "Current platform is: "
	if [ -f /etc/issue ]; then 
		PLATFORM=$(cat /etc/issue)
	else
		PLATFORM=$(uname -a)
		#lsb_release -i
	fi
}

function setDownloadApp () {
	echo_line "Checking for wget or curl..."
	if cmdExists wget ; then
		echo_nline "wget found..."
		D_APP="wget --no-check-certificate"
		D_LIST_PARAMS="-O ${LIST_FILE}"
		D_PHARO_PARAMS="-O-"
	elif cmdExists curl ; then
			echo_nline "curl found..."
			D_APP="curl"
			D_LIST_PARAMS="-o "$LIST_FILE
			D_PHARO_PARAMS=""
		else
			echo_nline "I require wget or curl, but it's not installed. (brew install wget?) Aborting."
			exit 1
	fi
}

function checkLibXML () {
	echo_line "Checking for xmllint..."
	if ! cmdExists xmllint; then
		echo_nline "not found (install libxml2 or msys-libxml2 as required)"
		exit 1
	else
		echo_nline "found"
	fi
}

function versionString () {
	echo "pi - Pharo Install [version $PI_VERSION]"
}

function printHelp () {
	echo "pi - Pharo Install [version $PI_VERSION]

PI is a tool for installing Pharo Smalltalk packages.

The options include:
		listGH			List packages found in GitHub
		listSH			List packages found in SmalltalkHub
		countSH			Report how many packages were found in SmalltalkHub
		image			Fetch the latest stable Pharo (VM + Image).
		examples		Show usage examples
		version 		Show program version
		install <pkgname>	Install pkgname to the image found in the current working directory. Download the image if not found.

Pharo Install project home page: https://github.com/hernanmd/pi
To report bugs or get some help check: https://github.com/hernanmd/pi/issues
This software is licensed under the MIT License.
"
}

function examples () {
	echo "
List all packages:
$0 list

List GitHub packages:
$0 listGH

List SmalltalkHub packages:
$0 listSH

List catalog configurations:
$0 list catalog

Install multiple packages:
$0 install Diacritics ISO3166 StringExtensions"
}

#################################
## Pharo Installation Functions
#################################

# For Debian, Slackware and Ubuntu
function apt_install () {
	sudo dpkg --add-architecture i386
	sudo apt-get update
	sudo apt-get install libc6:i386 libssl1.0.0:i386 libfreetype6:i386
}

# For ElementaryOS
function ppa_install () {
	add-apt-repository ppa:pharo/stable
	apt-get update
	apt-get install pharo-vm-desktop
}

# For CentOS
function yum_install () {
	yum install ld-linux.so.2 glibc-devel.i686 glibc-static.i686 glibc-utils.i686 libX11.i686 libX11-devel.i686 mesa-libGL.i686 mesa-libGL-devel.i686 libICE.i686 libICE-devel.i686 libSM.i686
}

function installPharo () {
	if [[ $PLATFORM  == "elementary*" ]];
	then
		echo_nline "Found Elementary OS"
		ppa_install
	fi
	if [[ $PLATFORM == "CentOS*" ]];
	then
		echo_nline "Found CentOS"
		echo $PLATFORM
		yum_install
	fi
}

#################################
## Packages Installation Functions
#################################

function dlStHubPkgNames () {
	setDownloadApp
	local LIST_URL=$STHUB_URL"list"
	$D_APP $D_LIST_PARAMS $LIST_URL
}

function dlGitHubPkgNames () {
	setDownloadApp
	local GH_TOPICS="https://api.github.com/search/repositories?per_page=100&q=topic:pharo"
	# local GH_HEADER="Accept: application/vnd.github.mercy-preview+json"
	local GH_PLFILE="pharo.js"
	$D_APP $GH_TOPICS -O $GH_PLFILE
	if ! cmdExists jq; then
		# wget http://stedolan.github.io/jq/download/linux32/jq (32-bit system)
		echo_line "Trying to download jq..."
		case "$OSTYPE" in
			solaris*) 
				echo_line "Solaris seems not supported by jq. See https://stedolan.github.io/jq/ for details" 
				;;
			darwin*)  
				$D_APP https://github.com/stedolan/jq/releases/download/jq-1.5/jq-osx-amd64
				chmod +x ./jq
				;; 
			linux*)   
				$D_APP http://stedolan.github.io/jq/download/linux64/jq
				chmod +x ./jq
				;;
			bsd*)     
				echo_line "BSD seems not supported by jq. See https://stedolan.github.io/jq/ for details" 
				;;
			msys*)    
				$D_APP -O jq.exe https://github.com/stedolan/jq/releases/download/jq-1.5/jq-win64.exe 
				;;
			*) 
				echo "unknown: $OSTYPE" 
				;;
		esac
		echo_line "download ok"
	fi
	PKGS=$(jq '.items[].full_name' $GH_PLFILE)
}

function fetchStHubPkgNames () {
	echo_line "Checking package list file..."
	if [ ! -f $LIST_FILE ]; then
		echo_nline "not found"
		echo_nline "Downloading packages list..."
		dlStHubPkgNames
	else
		echo_nline "found $LIST_FILE"
	fi
	PKGS=$(xpath "//a[@class=\"project\"]/text()" $LIST_FILE)
}

# Install from Catalog
function pkgCatalogInstall () {
	PKGNAME=$1
	./pharo $IMAGENAME get $PKGNAME 
	return $?
}

# Install from STHub
# Currently uses exact match for package names
function pkgSHInstall () {
	PKGNAME=$1
	fetchStHubPkgNames
	FOUND=$(echo "$PKGS" | grep -w $PKGNAME)
	PKGCOUNT=$(echo "$FOUND" | wc -l)
	if [ "$PKGCOUNT" -gt 1 ]; then
		echo "Found $PKGCOUNT packages with the name $PKGNAME. Listing follows..."
		cat -n <<< "$FOUND"	
		return 1
		# select_package "$FOUND"
	else
		echo "Selected package: $FOUND"
		IFS=/ read p USER <<< "$FOUND"
		REPOURL=$STHUB_URL"mc/"$USER/$PKGNAME
		echo "Repository: $REPOURL"
	fi
	./pharo $IMAGENAME config $REPOURL "ConfigurationOf"$PKGNAME --printVersion
	return $?
}

# Read argument packages and install from their repositories
function install_packages () {
	until [ -z "$1" ]; do
		echo -n "Trying to install from Catalog..."
		if ! pkgCatalogInstall $1; then
			echo "not found"
			echo "Trying to install from SmalltalkHub..."
			if ! pkgSHInstall $1; then
				echo "not found"
			else
				echo "done"
			fi
		else
			echo "done"
		fi
		shift
	done		
}
		
	
#################################
## Pharo Installation Section
#################################

function dlPharo () {
	echo -n "Checking Pharo installation already present..."
	if [ ! -f $IMAGENAME ]; then
		echo "not found"
		setDownloadApp	
		echo "Downloading Pharo (stable version)..."
#		exec $D_APP $D_PHARO_PARAMS get.pharo.org/$PHARO_VERSION+vm | bash
		exec $D_APP $D_PHARO_PARAMS get.pharo.org | bash
	else
		echo "found $IMAGENAME in the current directory"
	fi

	if [ ! -f pharo ]; then
		echo "Try again. Pharo was not downloaded correctly, exiting"
		exit 1
	fi
}

#################################
## Main Section
#################################

case $1 in
	listgh | listGH | LISTGH )
		SILENT_MODE=0
		dlGitHubPkgNames
		echo "$PKGS"
		;;
	listsh | listSH | LISTSH ) 
		SILENT_MODE=0
		checkLibXML		
		fetchStHubPkgNames
		echo "$PKGS"
		;;
	help | h ) 
		SILENT_MODE=0
		printHelp
		;;		
	countSH | COUNTSH )
		SILENT_MODE=0
		checkLibXML
		fetchStHubPkgNames
		echo -e "$PKGS" | wc -l
		echo " packages found"
		;;
	install | INSTALL )
		SILENT_MODE=1
		dlPharo
		install_packages "${@:2}"
		;;
	image | IMAGE )
		SILENT_MODE=1
		findPlatform
		installPharo
		;;
	version )
		versionString
		;;
	examples | EXAMPLES ) 
		examples && exit 0
		;;
	* ) 
	echo $"Usage: $0 {list|listGH|listSH|countGH|countSH|image|examples|install <pkgname>}"
	exit 1
esac

