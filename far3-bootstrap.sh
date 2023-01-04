#!/bin/sh
# SPDX-License-Identifier: MIT

## Far Manager v3 + some plugins bootstrap script
## Copyright (C) 2015-2021 Przemyslaw Pawelczyk <przemoc@gmail.com>
##
## This script is licensed under the terms of the MIT license.
## https://opensource.org/licenses/MIT

# Download zip, extract its content and go into newly created directory:
#  https://github.com/przemoc/far3-bootstrap/zipball/master
# On Windows run:
#  far3-bootstrap.cmd
# On Linux run:
#  far3-bootstrap.sh
# Run Far from Far.x?? directory and further update plugins using Renewal (via F11).

set -e

USER_AGENT=far3-bootstrap/0.6

FAR_VARIANT=${1:-x86}
FAR_DIR="Far.$FAR_VARIANT"

[ "$FAR_VARIANT" = "x86" ] && BITS=32 || BITS=64

# Far
FAR_HOST='http://farmanager.com/'
FAR_DLPAGE="$FAR_HOST"'/download.php?l=en'
PRING_HOST='http://plugring.farmanager.com/'
PRING_INFO='plugin.php?pid='

# Tools
CURL_BASE='https://curl.se/windows/'
CURL_PATT="curl for $BITS-bit"
SZIPR_BASE='https://www.7-zip.org/'
SZIPR_HTML='download.html'
SZIPR_PATT='7zr\.exe'
SZIP_BASE='https://www.7-zip.org/'
SZIP_PATT='7z[0-9]*\.exe'
UNRAR_BASE='http://www.rarlab.com/rar/'
UNRAR_FILE='unrarw32.exe'

# Sites
FARPLUGS_BASE='https://sourceforge.net/projects/farplugs/'

# Functions
log() { echo "* $@" >&2; }

exists_or_download() {
	if [ -r "$1" ]; then
		log "File '$1' already exists."
	else
		log "Downloading '$1' from '$2'..."
		curl -gRLA "$USER_AGENT" -o "$1" "$2"
	fi
}

exists_or_download_insecure() {
	if [ -r "$1" ]; then
		log "File '$1' already exists."
	else
		log "Downloading '$1' from '$2'..."
		curl -gkRLA "$USER_AGENT" -o "$1" "$2"
	fi
}

extract() { # ARCHIVE [FILE]...
	ARC=$1
	shift
	log "Extracting $@ from '$ARC'"
	EXT=$(echo ${ARC##*.} | tr A-Z a-z)
	if   [ "$EXT" = "7z" ] || [ "$EXT" = "exe" ] || [ "$EXT" = "zip" ]; then
		7z x -r -aoa "$ARC" "$@"
	elif [ "$EXT" = "rar" ]; then
		unrar x -o+ "$ARC" "$@"
	fi
}

extract_no_path() { # ARCHIVE [FILE]
	ARC=$1
	shift
	log "Extracting $@ from '$ARC'"
	EXT=$(echo ${ARC##*.} | tr A-Z a-z)
	if   [ "$EXT" = "7z" ] || [ "$EXT" = "exe" ] || [ "$EXT" = "zip" ]; then
		7z e -r -aoa "$ARC" "$@"
	elif [ "$EXT" = "rar" ]; then
		unrar e -o+ "$ARC" "$@"
	fi
}

unzip_no_path() { # ARCHIVE [FILE]
	ARC=$1
	shift
	log "Unzipping $@ from '$ARC'"
	unzip -jo "$ARC" "$@" || busybox unzip -jo "$ARC" "$@"
}

download_and_extract_curl() {
	CURL_PATH=$(wget -U "$USER_AGENT" -O- "$CURL_BASE" | sed "/$CURL_PATT/!d;s,.*href=\",,;s,\".*,,")
	CURL_FILE=${CURL_PATH##*/}
	CURL_DIR=${CURL_FILE%.zip}
	log "Downloading '$CURL_FILE' from '$CURL_BASE$CURL_PATH'..."
	wget -U "$USER_AGENT" -O "$CURL_FILE" "$CURL_BASE$CURL_PATH"
	unzip_no_path "$CURL_FILE" "${CURL_DIR}/bin/curl.exe" "${CURL_DIR}/bin/curl-ca-bundle.crt"
}

download_and_extract_7zip() {
	SZIPR_PATH=$(curl -gRLA "$USER_AGENT" "$SZIPR_BASE$SZIPR_HTML" | sed "/$SZIPR_PATT/!d;s,.*href=\",,;s,\".*,," | head -1)
	SZIPR_FILE=${SZIPR_PATH##*/}
	exists_or_download "$SZIPR_FILE" "$SZIPR_BASE$SZIPR_PATH"
	SZIP_PATH=$(curl -gRLA "$USER_AGENT" "$SZIP_BASE" | sed "/$SZIP_PATT/!d;s,.*href=\",,;s,\".*,," | head -1)
	SZIP_FILE=${SZIP_PATH##*/}
	exists_or_download "$SZIP_FILE" "$SZIP_BASE$SZIP_PATH"
	7zr e -r -aoa "$SZIP_FILE" 7z.exe 7z.dll
}

download_plugring() { # PID [PATTERN]
	PLUGIN_INFO="$(curl -gRLA "$USER_AGENT" "$PRING_HOST$PRING_INFO$1" | sed \
 -e '/.*\(Version\|Far version\|Filename\|<a href="download.php?\)/!d;s,,\1,;'  \
 -e 's,</td></tr>,,;' \
 -e '/^<a /{s,<[^"]*",Url=,;s,">.*,,};' \
 -e 's,<.*>,=,;' \
 -e '/^Far v/s, ,,;' \
 | grep 'Farversion=3' -B1 -A2 \
)"
	PLUGIN_VER="$(echo "$PLUGIN_INFO" | sed '/^Version=/!d;s,,,' | tail -1)"
	PLUGIN_INFO="$(echo "$PLUGIN_INFO" | grep "^Version=$PLUGIN_VER$" -A3 | \
 grep "Filename=.*$2" -B2 -A1 | tail -4)"
	PLUGIN_FILE="$(echo "$PLUGIN_INFO" | sed '/^Filename=/!d;s,,,')"
	PLUGIN_URL="$(echo "$PLUGIN_INFO" | sed '/^Url=/!d;s,,'"$PRING_HOST"',')"
	exists_or_download "$PLUGIN_FILE" "$PLUGIN_URL"
	echo "$PLUGIN_FILE"
}

download_farplugs_plugins() {
	curl -gRL -A "$USER_AGENT" -o farplugs.rss "${FARPLUGS_BASE}rss"
	# sort -V depends on strverscmp() that is not always present, so...
	sed '/ *<link>/!d;s,,,;s,</link>.*,,;/_'"$FAR_VARIANT"'/!d' farplugs.rss \
		| sed -r 's,^([^0-9]*)([0-9]*[^0-9.])?(.*),\2\3@.\1,' \
		| sort -nrt . -k 1,1 -k 2,2 -k 3,3 -k 4,4 -k 5,5 -k 6,6 \
		| sort -st @ -k 2,2 \
		| sed -r 's,^(.*)@\.(.*),\2\1,' \
		>farplugs.txt
	URLS=$(cat farplugs.txt)
	for PLUGIN_URL in $URLS; do
		PLUGIN_FILE=${PLUGIN_URL%/download}
		PLUGIN_FILE=${PLUGIN_FILE##*/}
		PLUGIN_NAME=${PLUGIN_FILE%%_*}
		[ "$PLUGIN_NAME" != "$PLUGIN_NAME_PREV" ] || continue
		exists_or_download "$PLUGIN_FILE" "$PLUGIN_URL"
		PLUGIN_NAME_PREV=$PLUGIN_NAME
		echo "$PLUGIN_FILE"
	done
}

# Start

if [ "$PATH" != "${PATH#*;}" ]; then
	export PATH="$PWD;$PATH"
else
	export PATH="$PWD:$PATH"
fi

curl --version || download_and_extract_curl
download_and_extract_7zip

FAR_FILES="$(curl -gRLA "$USER_AGENT" "$FAR_DLPAGE" \
 | sed \
 -e '/Stable builds/,/Nightly builds/!d;' \
 -e '/^[ \t]*<li>/!d;' \
 -e 's,<a ,\n,g;' \
 | sed \
 -e '/^class="body_link" href="/!d;s,,,;s,".*,,;' \
)"/
FAR_DLFILE="$(echo "$FAR_FILES" | grep "\.$FAR_VARIANT\.[^.]*\.7z$")"
FAR_FILE="${FAR_DLFILE##*/}"

log "Far Manager stable builds files"
echo "$FAR_FILES"

exists_or_download "$FAR_FILE" "$FAR_HOST$FAR_DLFILE"
exists_or_download "$UNRAR_FILE" "$UNRAR_BASE$UNRAR_FILE"
extract "$UNRAR_FILE" unrar.exe

FARPLUGS=$(download_farplugs_plugins)
INTCHECKER=$(download_plugring 893 $FAR_VARIANT)
RESEARCH=$(download_plugring 246)

( mkdir -p "$FAR_DIR" && cd "$FAR_DIR" \
  && extract ../"$FAR_FILE" \
)

( cd "$FAR_DIR/Plugins" \
  && for PLUGIN in $FARPLUGS; do extract ../../$PLUGIN; done \
  && extract ../../"$INTCHECKER" \
  && ( mkdir -p RESearch && cd RESearch \
       && extract ../../../"$RESEARCH" \
       && ( [ "$FAR_VARIANT" = "x86" ] && rm "RESearchU3 x64.dll" || rm "RESearchU3.dll" ) \
     ) \
)
