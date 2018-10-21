#!/bin/sh

## Far Manager v3 + some plugins bootstrap script
## Copyright (C) 2015 Przemyslaw Pawelczyk <przemoc@gmail.com>
## The script is licensed under the traditional MIT license.

# Create directory dedicated for Far bootstrapping and go into it.
# Download here busybox-w32:
#  http://frippery.org/files/busybox/busybox.exe
# Download here this script:
#  https://raw.githubusercontent.com/przemoc/far3-bootstrap/master/far3-bootstrap.sh
# Run following command:
#  busybox sh far3-bootstrap.sh
# Run Far from Far.x?? directory and further update plugins using Renewal (via F11).

USER_AGENT=far3-bootstrap/0.2


FAR_VARIANT=${1:-x86}
FAR_DIR="Far.$FAR_VARIANT"

[ "$FAR_VARIANT" = "x86" ] && BITS=32 || BITS=64

# Far
FAR_HOST='http://farmanager.com/'
FAR_DLPAGE="$FAR_HOST"'/download.php?l=en'
PRING_HOST='http://plugring.farmanager.com/'
PRING_INFO='plugin.php?pid='

# Tools
CURL_BASE='https://curl.haxx.se/windows/'
CURL_PATT="curl for $BITS bit"
SZIP_BASE='http://downloads.sourceforge.net/sevenzip/'
SZIP_FILE='7za920.zip'
UNRAR_BASE='http://www.rarlab.com/rar/'
UNRAR_FILE='unrarw32.exe'

# Functions
log() { echo "* $@" >&2; }

exists_or_download() {
	if [ -r "$1" ]; then
		log "File '$1' already exists."
	else
		log "Downloading '$1' from '$2'..."
		curl -RLA "$USER_AGENT" -o "$1" "$2"
	fi
}

exists_or_download_insecure() {
	if [ -r "$1" ]; then
		log "File '$1' already exists."
	else
		log "Downloading '$1' from '$2'..."
		curl -kRLA "$USER_AGENT" -o "$1" "$2"
	fi
}

extract() { # ARCHIVE [FILE]...
	ARC=$1
	shift
	log "Extracting $@ from '$ARC'"
	EXT=$(echo ${ARC##*.} | tr A-Z a-z)
	if [ "$EXT" = "zip" ]; then
		unzip -o "$ARC" "$@"
	elif [ "$EXT" = "7z" ]; then
		7za x -r -y "$ARC" "$@"
	elif [ "$EXT" = "rar" ]; then
		unrar x -o+ "$ARC" "$@"
	fi
}

extract_no_path() { # ARCHIVE [FILE]
	ARC=$1
	shift
	log "Extracting $@ from '$ARC'"
	EXT=$(echo ${ARC##*.} | tr A-Z a-z)
	if [ "$EXT" = "zip" ]; then
		unzip -jo "$ARC" "$@"
	elif [ "$EXT" = "7z" ]; then
		7za e -r -y "$ARC" "$@"
	elif [ "$EXT" = "rar" ]; then
		unrar e -o+ "$ARC" "$@"
	fi
}

download_and_extract_curl() {
	CURL_PATH=$(wget -U "$USER_AGENT" -O- "$CURL_BASE" | sed "/$CURL_PATT/!d;s,.*href=\",,;s,\".*,,")
	CURL_FILE=${CURL_PATH##*/}
	CURL_DIR=$(echo "${CURL_FILE%.zip}" | sed 's,_[0-9]*,,')
	log "Downloading '$CURL_FILE' from '$CURL_BASE$CURL_PATH'..."
	wget -U "$USER_AGENT" -O "$CURL_FILE" "$CURL_BASE$CURL_PATH"
	extract_no_path "$CURL_FILE" "${CURL_DIR}/bin/curl.exe" "${CURL_DIR}/bin/curl-ca-bundle.crt"
}

download_plugring() { # PID [PATTERN]
	PLUGIN_INFO="$(curl -RLA "$USER_AGENT" "$PRING_HOST$PRING_INFO$1" | sed \
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

download_renewal_plugins() { # XML
	VAR=$(echo $FAR_VARIANT | sed 's,x,,')
	PLUGINS_INFO="$(cat "$1" | sed \
 -e '/<mod /,/<\/mod>/!d;' \
 -e '/<\/\?\(mod\|dl....'"$VAR"'\)/!d;' \
 -e 's,^[ \t]*,,;' \
 -e 's,\r$,,;' \
)"
	GUIDS="$(echo "$PLUGINS_INFO" \
 | sed '/^[ \t]*<mod guid="/!d;s,,,;s,".*,,' \
 | grep -v '{E3299E7A-1A22-47DD-B270-663BD2B74BCD}' \
)"
	for GUID in $GUIDS; do
		PLUGIN_INFO="$(echo "$PLUGINS_INFO" | sed '/<mod guid="'$GUID'">/,/<\/mod>/!d')"
		PLUGIN_FLST="$(echo "$PLUGIN_INFO" | sed '/dlpage/!d;s,<[^>]*>,,g')"
		PLUGIN_PATT="$(echo "$PLUGIN_INFO" | sed '/dlrgex/!d;s,<[^>]*>,,g;s,\\d,[0-9],g;s,^,[a-z]+:,;s,zip$,[0-9a-z]+,')"
		PLUGIN_URL="$(curl -kRLA "$USER_AGENT" "$PLUGIN_FLST" | egrep -o "$PLUGIN_PATT" | sort -rnt. | sed 1q)"
		PLUGIN_FILE="${PLUGIN_URL##*/}"
		exists_or_download_insecure "$PLUGIN_FILE" "$PLUGIN_URL" && \
		RENEWAL_PLUGINS="$RENEWAL_PLUGINS $PLUGIN_FILE"
	done

	echo "$RENEWAL_PLUGINS"
}

# Start

export PATH="$PWD;$PATH"

download_and_extract_curl

FAR_FILES="$(curl -RLA "$USER_AGENT" "$FAR_DLPAGE" | sed \
 -e '/Stable builds/,/Nightly builds/!d;' \
 -e '/^[ \t]*<\(b>\|a \)/!d;' \
 -e '/^[ \t]*<b>/{s,,,;s,</b>,,}' \
 -e '/^[ \t]*<a .*href="/{s,,,;s,".*,,}' \
 -e '/^files\/$/d'
)"
FAR_DLFILE="$(echo "$FAR_FILES" | grep "\.$FAR_VARIANT\.[^.]*\.7z$")"
FAR_FILE="${FAR_DLFILE##*/}"

log "Far Manager stable builds files"
echo "$FAR_FILES"

exists_or_download "$FAR_FILE" "$FAR_HOST$FAR_DLFILE"
exists_or_download "$SZIP_FILE" "$SZIP_BASE$SZIP_FILE"
exists_or_download "$UNRAR_FILE" "$UNRAR_BASE$UNRAR_FILE"
extract "$SZIP_FILE" 7za.exe
"$UNRAR_FILE" -s2

RENEWAL=$(download_plugring 925 $FAR_VARIANT)
PORTADEV=$(download_plugring 933 $FAR_VARIANT)
INTCHECKER=$(download_plugring 893 $FAR_VARIANT)
RESEARCH="$(exists_or_download "RESearch.rar" \
 "http://www.kostrom.spb.ru/FILES/RESearch.rar" && echo RESearch.rar)"

( mkdir -p "$FAR_DIR" && cd "$FAR_DIR" \
  && extract ../"$FAR_FILE" \
  && cd Plugins \
  && extract ../../"$INTCHECKER" \
  && extract ../../"$PORTADEV" \
  && extract ../../"$RENEWAL" \
  && ( mkdir -p RESearch && cd RESearch \
       && extract ../../../"$RESEARCH" \
       && rm "RESearch.dll"  "RESearch x64.dll" \
             "RESearchU.dll" "RESearchU x64.dll" \
       && ( [ "$FAR_VARIANT" = "x86" ] && rm "RESearchU3 x64.dll" || rm "RESearchU3.dll" ) \
     ) \
)

RPLUGINS="$(download_renewal_plugins "$FAR_DIR/Plugins/Renewal/Renewal.xml")"

( cd "$FAR_DIR/Plugins" \
  && for PLUGIN in $RPLUGINS; do extract ../../$PLUGIN; done \
)
