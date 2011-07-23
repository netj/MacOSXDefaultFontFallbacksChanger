#!/usr/bin/env bash
# A script for changing Mac OS X's default fonts
# Author: Jaeho Shin <netj@sparcs.org>
# Created: 2011-07-22
# Version: 1.0

# Specify sets of substitutions between these two lines of hashes:
### H: 함초롬 고딕 & 바탕 #####################################################
## Download fonts from http://j.mp/oYUqdu
## Keep zip archive at ~/.fonts/HCR/Hamchorom-LVT.20101002.zip
## Change font AppleGothic=HCR Dotum
## Change font AppleMyungjo=HCR Batang
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
pause() { read -t${1:-1} || true; }
hr() { echo -------------------------------------------------------------------------------; }
indent() { sed '/^-/! s/^/  /'; }

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

# the main loop
interact() {
    # listen to user for what to do
    {
        hr
        echo  Mac OS X Default Font Fallbacks Changer $Version
        hr
        list-fontsets
        hr
        echo  R: Reset to Original settings
        echo  Q: Quit
        hr
    } | indent
    read -n1 -p "Press key: " key
    echo
    echo

    key=$(tr a-z A-Z <<<"$key") # ignoring case of input key,
    case $key in
        Q) # bye bye
            exit
            ;;
        R) # revert modifications
            echo Reverting to original settings...
            for plist in "${Plists[@]}"; do
                if [ -e "$plist.orig" ]; then
                    sudo cp -pfv "$plist.orig" "$plist"
                fi
            done
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
                echo "$key: Undefined key" >&2
                echo
                return
            fi
            # give user a chance to abort
            read -n1 -p "Continue to change as above? (y or n) "; echo; echo
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
                echo Downloading fonts from $URL...
                curl -LR -C - -o "$LocalName" "$URL" || true
                unzip -o "$LocalName"
                echo Installing fonts to /System/Library/Fonts/...
                find . -name '*.[ot]t[fc]' -exec sudo install -vm a=r {} /System/Library/Fonts/ \; -exec rm -f {} \;
                )
            fi
            # modify plist files
            echo Changing default font fallbacks...
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
            echo Now reboot or restart your apps to use "$fontset".
            pause 3
            exit
            ;;
    esac
}
while true; do interact; done
