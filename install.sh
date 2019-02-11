main() {
	# Use colors, but only if connected to a terminal, and that terminal supports them.
	if which tput >/dev/null 2>&1; then
		ncolors=$(tput colors)
	fi
	if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
	  RED="$(tput setaf 1)"
	  GREEN="$(tput setaf 2)"
	  YELLOW="$(tput setaf 3)"
	  BLUE="$(tput setaf 4)"
	  BOLD="$(tput bold)"
	  NORMAL="$(tput sgr0)"
	else
	  RED=""
	  GREEN=""
	  YELLOW=""
	  BLUE=""
	  BOLD=""
	  NORMAL=""
	fi

	# Only enable exit-on-error after the non-critical colorization stuff,
	# which may fail on systems lacking tput or terminfo
	set -e

	# Prevent the cloned repository from having insecure permissions. Failing to do
	# so causes compinit() calls to fail with "command not found: compdef" errors
	# for users with insecure umasks (e.g., "002", allowing group writability). Note
	# that this will be ignored under Cygwin by default, as Windows ACLs take
	# precedence over umasks except for filesystems mounted with option "noacl".
	umask g-w,o-w

	printf "${BLUE}Cloning pi...${NORMAL}\n"
	type git >/dev/null 2>&1 || {
	  echo "Error: git is not installed"
	  exit 1
	}
	# The Windows (MSYS) Git is not compatible with normal use on cygwin
	if [ "$OSTYPE" = cygwin ]; then
		if git --version | grep msysgit > /dev/null; then
		  echo "Error: Windows/MSYS Git is not supported on Cygwin"
		  echo "Error: Make sure the Cygwin git package is installed and is first on the path"
		  exit 1
		fi
	fi
	env git clone --depth=1 https://github.com/hernanmd/pi.git || {
		printf "Error: git clone of pi repo failed\n"
		exit 1
	}

	# Use /usr/local as default installation path if not set
	dest="$1"
	install_path="${dest=/usr/local}"
	PI_ROOT="${0%/*}"

	install -v -d -m 755 "$install_path"/{bin,libexec/pi,share/man/man1}
	install -m 755 "$PI_ROOT/bin"/* "$install_path/bin"
	install -m 755 "$PI_ROOT/libexec/pi"* "$install_path/libexec/pi"
	# install -m 644 "$PI_ROOT/man/pi.1" "$install_path/share/man/man1"

	printf "${GREEN}"
	echo '            #     '
	echo '           ###    '
	echo '            #     '
	echo '                  '
	echo '   /###   ###     '
	echo '  / ###  / ###    '
	echo ' /   ###/   ##    '
	echo '##    ##    ##    '
	echo '##    ##    ##    '
	echo '##    ##    ##    '
	echo '##    ##    ##    '
	echo '##    ##    ##    '
	echo '#######     ### / '
	echo '######       ##/  '
	echo '##                '
	echo '##                '
	echo '##                '
	echo '##	'
	echo '   ....is now installed!'
	echo 'Please look over pi help to access options.'
	echo ''
	echo 'p.s. If you like this work star it at https://github.com/hernanmd/pi'
	echo ''
	printf "${NORMAL}"
}

main
