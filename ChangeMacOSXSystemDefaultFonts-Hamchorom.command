#!/usr/bin/env bash
# A script for changing Mac OS X's default fonts
# Author: Jaeho Shin <netj@sparcs.org>
# Created: 2011-07-22

# Specify substitutions between these two lines of hashes:
###############################################################################
URL=http://ftp.ktug.or.kr/KTUG/hcr-lvt/Hamchorom-LVT.zip
LocalPath=~/.fonts/HCR/Hamchorom-LVT.zip
## AppleGothic=HCR Dotum LVT
## AppleMyungjo=HCR Batang LVT
###############################################################################
# No need to modify below this line, unless you know what you're doing.

set -eu
# property lists to modify
plists=(
/System/Library/Frameworks/ApplicationServices.framework/Versions/Current/Frameworks/CoreText.framework/Versions/Current/Resources/DefaultFontFallbacks.plist
/System/Library/Frameworks/AppKit.framework/Versions/Current/Resources/NSFontFallbacks.plist
/System/Library/Frameworks/AppKit.framework/Versions/Current/Resources/NSKnownFonts.plist
/System/Library/Frameworks/AppKit.framework/Versions/Current/Resources/RTFFontFamilyMappings.plist
)

# prepare substitution commands
echo Mac OS X System Font Substitutions:
vimcmds=()
rules=$(sed -n <"$0" '/^####*$/,/^####*$/ { /^## / s/^## //p }')
while read rule; do
    patt=${rule%%=*}
    repl=${rule#$patt=}
    echo -e " Use \`$repl'\t instead of \`$patt'."
    vimcmds+=("+%s/$patt/$repl/g")
done <<<"$rules"
echo

# listen to user for what to do
read -n1 -p "Press \`y' to modify your system, or
      \`r' to reset previous modifications, or
      any other key to abort: "
echo
echo
case $REPLY in
    [yY])
        # download and install ttfs
        (
        LocalDir=`dirname "$LocalPath"`
        LocalName=`basename "$LocalPath"`
        mkdir -p "$LocalDir"
        cd "$LocalDir"
        echo Downloading fonts from $URL...
        curl -R -C - -o "$LocalName" "$URL" || true
        unzip -o "$LocalName"
        echo Installing fonts to /System/Library/Fonts/...
        find . -name '*.tt[fc]' -exec sudo install -vm a=r {} /System/Library/Fonts/ \; -exec rm -f {} \;
        )
        # modify plist files
        echo Modifying font mappings...
        for plist in "${plists[@]}"; do
            if [ -e "$plist.orig" ]; then
                sudo cp -pf "$plist.orig" "$plist"
            else
                sudo cp -npv "$plist" "$plist.orig"
            fi
            echo " $plist"
            sudo vim +"set nobackup" "$plist" "${vimcmds[@]}" +wq
        done
        ;;
    [rR]) # revert substitutions
        echo Reverting changes...
        for plist in "${plists[@]}"; do
            if [ -e "$plist.orig" ]; then
                sudo cp -pfv "$plist.orig" "$plist"
            fi
        done
        echo Warning: Previously installed fonts remain in /System/Library/Fonts/.
        ;;
esac