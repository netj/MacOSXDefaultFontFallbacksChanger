#!/usr/bin/env bash
# A script for changing Mac OS X's default fonts
# Author: Jaeho Shin <netj@sparcs.org>
# Created: 2011-07-22
# Version: 1.1

# Specify sets of substitutions between these two lines of hashes:
### H: 함초롬 돋움 & 바탕 #####################################################
## Download fonts from http://ftp.ktug.or.kr/KTUG/hcr-lvt/Hamchorom-LVT.zip
## Keep zip archive at ~/.fonts/HCR/Hamchorom-LVT.zip
## Change font AppleGothic=HCR Dotum LVT
## Change font AppleMyungjo=HCR Batang LVT
###############################################################################
### N: 나눔 고딕 & 명조 #######################################################
## Change font AppleGothic=Nanum Gothic
## Change font AppleMyungjo=Nanum Myeongjo
###############################################################################
# No need to modify below this line, unless you know what you're doing.

set -eu
# sanitize environment
PATH=/usr/bin:/bin
clear

# some vocabularies
error() { echo "$@" >&2; }
pause() { read -t${1:-5} || true; }
hr() { echo -------------------------------------------------------------------------------; }
indent() { sed '/^-/! s/^/  /'; }
ProductName=$(sw_vers -productName)
ProductVersion=$(sw_vers -productVersion)
show-warning() {
    echo   "  WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
    echo   "  WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
    echo   "  WARNING                                                         WARNING"
    echo   "  WARNING   무슨 일이 생길 지 모르니 섣불리 진행하지 마십시오!!!  WARNING"
    printf "  WARNING   이 도구는 %14s에서 시험해보지 않았습니다!  WARNING\n" "$ProductName $ProductVersion"
    echo   "  WARNING   컴퓨터를 더 이상 못 쓰는 상태로 만들 수도 있습니다!!  WARNING"
    echo   "  WARNING                                                         WARNING"
    printf "  WARNING   This tool has not been tested on: %14s !!  WARNING\n" "$ProductName $ProductVersion"
    echo   "  WARNING   Your system may become unusable after modifications!  WARNING"
    echo   "  WARNING   DO NOT PROCEED UNLESS YOU KNOW WHAT YOU ARE DOING!!!  WARNING"
    echo   "  WARNING                                                         WARNING"
    echo   "  WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
    echo   "  WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
    hr
}

# fontsets embedded in comments
list-fontsets() {
    sed -ne '/^### [A-Z0-9]: .* ####*$/,/^####*$/ { /^### / { s/^### //; s/ ####*$//g; p; }; }' <"$0"
}
fontset() {
    local key=$1
    if grep -q '^### '"$key"': ' "$0"; then
        sed -ne '/^### '"$key"': /,/^####*$/ { /^## / s/^## //p; }' <"$0"
    else
        false
    fi
}
substitute() { vimcmds+=("+%s/$1/$2/g"); }
compile-fontset() {
    local line= i=0
    while read line; do
        case $line in
            "Download fonts from "*)
                echo "URL=${line#Download fonts from }"
                ;;
            "Keep zip archive at "*)
                echo "LocalPath=${line#Keep zip archive at }"
                ;;
            "Change font "*)
                local patt=${line#Change font }
                echo "substitute '${patt%%=*}' '${patt#*=}'"
                ;;
            *)
                error "Syntax error for $key: $line" >&2
                exit 2
                ;;
        esac
        let i++
    done
    if [ $i -eq 0 ]; then
        echo "Empty rules for $key:" >&2
        exit 2
    fi
}

# property lists that control the default font fallbacks
Plists=(
/System/Library/Frameworks/ApplicationServices.framework/Versions/Current/Frameworks/CoreText.framework/Versions/Current/Resources/DefaultFontFallbacks.plist
/System/Library/Frameworks/AppKit.framework/Versions/Current/Resources/NSFontFallbacks.plist
/System/Library/Frameworks/AppKit.framework/Versions/Current/Resources/NSKnownFonts.plist
/System/Library/Frameworks/AppKit.framework/Versions/Current/Resources/RTFFontFamilyMappings.plist
)
# version of this script
Version=$(sed -ne '/^# Version: / s/^[^:]*: //p' <"$0")

# check compatibility with current Mac OS X version
IsCompatible=false
if [ x"$ProductName" = x"Mac OS X" ]; then
    case $ProductVersion in
        10.7|10.7.*) # Lion will probably remain compatible after minor updates
            IsCompatible=true
            ;;
        *) # unsure about other versions, display warning
            ;;
    esac
fi

# the main loop
interact() {
    # listen to user for what to do
    {
        hr
        echo  Mac OS X 기본 글꼴 설정 변경 도구 / Default Font Fallbacks Changer $Version
        hr
        $IsCompatible || show-warning
        list-fontsets
        hr
        echo  R: 원상복구 / Reset to Original settings
        echo  Q: 종료     / Quit
        hr
    } | indent
    read -n1 -p "키를 누르세요 / Press key: " key
    echo
    echo

    key=$(tr a-z A-Z <<<"$key") # ignoring case of input key,
    case $key in
        Q) # bye bye
            exit
            ;;
        R) # revert modifications
            echo 원상복구중 / Reverting to original settings...
            for plist in "${Plists[@]}"; do
                if [ -e "$plist.orig" ]; then
                    sudo cp -pfv "$plist.orig" "$plist"
                fi
            done
            echo 원래 설정을 쓰려면 재시동하거나 응용프로그램을 다시 띄웁니다.
            echo 경고: /System/Library/Fonts/ 아래에 일부 파일이 남아있을 수 있습니다.
            echo Now reboot or restart your apps to use the Original settings.
            echo Warning: You may need to remove files from /System/Library/Fonts/ by hand.
            pause
            exit
            ;;
        *)
            # display details
            if fontset=$(list-fontsets | grep "^$key: "); then
                fontset=${fontset#$key: }
                {
                    hr
                    echo "$fontset"
                    hr
                    fontset "$key"
                    hr
                } | indent
            else
                echo "$key: 잘못된 키 / Undefined key" >&2
                echo
                return
            fi
            # give user a chance to abort
            read -n1 -p "위 설정을 진행할까요? Continue to change as above? (y or n) "; echo; echo
            case $REPLY in [yY]) true ;; *) return ;; esac
            
            # read the rules for fontset
            URL= LocalPath= vimcmds=()
            eval "$(fontset "$key" | compile-fontset)"
            # download and install ttfs
            if [ -n "$URL" -a -n "$LocalPath" ]; then
                (
                LocalDir=`dirname "$LocalPath"`
                LocalName=`basename "$LocalPath"`
                mkdir -p "$LocalDir"
                cd "$LocalDir"
                echo 글꼴 받는 중 / Downloading fonts from $URL...
                completeFlag="$LocalName.complete"
                if [ -e "$completeFlag" ]; then
                    # avoid downloading twice if we have a complete one
                    rm -f "$completeFlag"
                    curl -L -Rz "$LocalName" -o "$LocalName" "$URL" || curl -L -R -o "$LocalName" "$URL"
                else
                    # otherwise, try resuming the previous one
                    curl -L -R -C - -o "$LocalName" "$URL" || curl -L -R -o "$LocalName" "$URL"
                fi
                touch "$completeFlag"
                unzip -o "$LocalName"
                echo 글꼴 설치 중 / Installing fonts to /System/Library/Fonts/...
                find . -name '*.[ot]t[fc]' -exec sudo install -vm a=r {} /System/Library/Fonts/ \; -exec rm -f {} \;
                )
            fi
            # modify plist files
            echo 기본 글꼴 설정을 변경합니다 / Changing default font fallbacks...
            for plist in "${Plists[@]}"; do
                if [ -e "$plist.orig" ]; then
                    # XXX following line prevents combination of independent changes :(
                    # however, this lets users to change fontsets without resetting to original
                    sudo cp -pf "$plist.orig" "$plist"
                else
                    sudo cp -npv "$plist" "$plist.orig"
                fi
                echo " $plist"
                sudo vim +"set nobackup" "$plist" "${vimcmds[@]}" +wq
            done
            echo "$fontset"을 쓰려면 재시동하거나 응용프로그램을 다시 시작 하십시오.
            echo Now reboot or restart your apps to use "$fontset".
            pause 7
            exit
            ;;
    esac
}
while true; do interact; done
