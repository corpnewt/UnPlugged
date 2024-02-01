#!/bin/bash

# Get the curent directory
args=( "$@" )
dir="${0%/*}"
selected_disk=
install_app=
ia_required=("InstallAssistant.pkg")
ie_required=("BaseSystem.dmg" "BaseSystem.chunklist" "InstallESDDmg.pkg" "InstallInfo.plist" "AppleDiagnostics.dmg" "AppleDiagnostics.chunklist")
install_type="ia"
has_all="TRUE"

function pickDisk () { 
    selected_disk=
    local driveList="$( cd /Volumes/; ls -1 | grep "^[^.]" )"
    unset driveArray
    IFS=$'\n' read -rd '' -a driveArray <<<"$driveList"
    local driveCount=0
    local driveIndex=0

    echo
    clear 2>/dev/null
    echo Listing available volumes...
    echo
    for aDrive in "${driveArray[@]}"
    do
        (( driveCount++ ))
        echo "$driveCount". "$aDrive"
    done
    if [ "$driveCount" -le 0 ]; then
        echo - No volumes found!
        exit 1
    fi
    driveIndex=$(( driveCount-1 ))
    echo
    read -r -p "Select the target install volume: " drive
    if [[ "$drive" == "" ]]; then
        pickDisk
    fi
    if [ "$drive" == "q" ]; then
        exit 0
    fi
    if [ "$drive" -eq "$drive" ] 2>/dev/null; then
        if [  "$drive" -le "$driveCount" ] && [  "$drive" -gt "0" ]; then
            drive="${driveArray[ (( $drive-1 )) ]}"
            selected_disk="/Volumes/$drive"
        fi
    fi
    if [ "$selected_disk" == "" ]; then
        pickDisk
    fi
}

function pickApp () {
    install_app=
    local appList="$( find / -name "Install*.app" -type d -maxdepth 3 2>/dev/null )"
    unset appArray
    IFS=$'\n' read -rd '' -a appArray <<<"$appList"
    local appCount=0
    local appIndex=0

    echo
    clear 2>/dev/null
    echo Listing any Install macOS applications....
    echo
    for anApp in "${appArray[@]}"
    do
        (( appCount++ ))
        echo "$appCount". "$anApp"
    done
    if [ "$appCount" -le 0 ]; then
        echo - No installers found!
        exit 1
    fi
    appIndex=$(( appCount-1 ))
    echo
    read -r -p "Select the source macOS recovery installer: " app
    if [[ "$app" == "" ]]; then
        pickApp
    fi
    if [ "$app" == "q" ]; then
        exit 0
    fi
    if [ "$app" -eq "$app" ] 2>/dev/null; then
        if [  "$app" -le "$appCount" ] && [  "$app" -gt "0" ]; then
            app="${appArray[ (( $app-1 )) ]}"
            install_app="$app"
        fi
    fi
    if [ "$install_app" == "" ]; then
        pickApp
    fi
}

function hasAll () {
    has_all="TRUE"
    install_type="ia"
    echo Locating full installer files...
    for f in "${ia_required[@]}"
    do
        if [ -e "$dir/$f" ]; then
            echo "- Found $f"
        else
            has_all="FALSE"
        fi
    done

    if [ "$has_all" != "TRUE" ]; then
        # Reset our has_all check and install type
        has_all="TRUE"
        install_type="ie"
        for f in "${ie_required[@]}"
        do
            if [ -e "$dir/$f" ]; then
                echo "- Found $f"
            else
                has_all="FALSE"
            fi
        done
    fi
}

function pickDir () {
    dir=
    echo
    clear 2>/dev/null
    echo Missing required files!
    echo
    echo Big Sur and newer require:
    echo
    for f in "${ia_required[@]}"
    do
        echo - "$f"
    done
    echo
    echo Catalina and prior require:
    echo
    for f in "${ie_required[@]}"
    do
        echo - "$f"
    done
    echo
    read -r -p "Type the path to the folder containing the installer files: " dir
    # First remove any escapes in the passed path
    dir="$(echo $dir | sed 's|\\||g')"
    if [ "$dir" == "q" ]; then
        exit 0
    fi
    if [ "$dir" == "" ] || [ ! -d "$dir" ]; then
        pickDir
    fi
    # Now check again if we have all files
    echo
    hasAll
    if [ "$has_all" != "TRUE" ]; then
        pickDir
    fi
}

pickApp

clear 2>/dev/null
echo Using: "$install_app"
echo
echo Verifying if app is already a full installer...
if [ -d "$install_app/Contents/SharedSupport" ]; then
    echo - Already a full installer!
    exit 1
fi
echo - Not a full installer
echo

hasAll

if [ "$has_all" != "TRUE" ]; then
    pickDir
fi

pickDisk

# At this point, we have our install app, SharedSupport folder
# and our target volume.  Let's copy the .app to the target
# volume (if needed), then copy the SharedSupport folder to 
# Install macOS [version].app/Contents/SharedSupport and start
# the installer.
echo
clear 2>/dev/null
echo Task Summary:
echo
app_name="${install_app##*/}"
if [[ "$install_app" =~ ^"$selected_disk" ]]; then
    echo - Leave "$app_name" in place
else
    if [ -d "$selected_disk/$app_name" ]; then
        echo - Delete existing "$selected_disk"/"$app_name"
    fi
    echo - Copy "$app_name" to "$selected_disk"
fi
echo - Set up SharedSupport in "$app_name"/Contents/
echo - Caffeinate and launch "$app_name"
echo
while true; do
    read -r -p "Do you wish to continue? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Actually perform the tasks
echo
clear 2>/dev/null
echo Executing tasks...
echo
if [[ ! "$install_app" =~ ^"$selected_disk" ]]; then
    if [ -d "$selected_disk/$app_name" ]; then
        echo - Deleting existing "$selected_disk"/"$app_name"
        rm -rf "$selected_disk/$app_name"
    fi
    echo - Copying "$app_name" to "$selected_disk"...
    cp -R "$install_app" "$selected_disk"
fi
echo - Creating "$app_name"/Contents/SharedSupport...
mkdir -p "$selected_disk/$app_name/Contents/SharedSupport"
echo - Copying files to SharedSupport - may take some time...
if [ "$install_type" == "ia" ]; then
    for f in "${ia_required[@]}"
    do
        if [ "$f" == "InstallAssistant.pkg" ]; then
            echo "--> $f -- SharedSupport.dmg"
            cp "$dir/$f" "$selected_disk/$app_name/Contents/SharedSupport/SharedSupport.dmg"
        else
            echo "--> $f"
            cp "$dir/$f" "$selected_disk/$app_name/Contents/SharedSupport/$f"
        fi
    done
else
    for f in "${ie_required[@]}"
    do
        if [ "$f" == "InstallInfo.plist" ]; then
            # Skip this so we can handle it more specifically
            continue
        elif [ "$f" == "InstallESDDmg.pkg" ]; then
            echo "--> $f -- InstallESD.dmg"
            cp "$dir/$f" "$selected_disk/$app_name/Contents/SharedSupport/InstallESD.dmg"
        else
            echo "--> $f"
            cp "$dir/$f" "$selected_disk/$app_name/Contents/SharedSupport/$f"
        fi
    done
    # Now we need to read the InstallInfo.plist and echo the lines to
    # the target file, but skip chunklistURL and chunklistid in the
    # Payload Info key - and update the id and URL keys
    echo "--> InstallInfo.plist (patching)"
    got_payload="FALSE"
    skip_next=
    while read -r line; do
        if [ "$skip_next" != "" ]; then
            skip_next=
            continue 
        fi
        # Check for <key>Payload Image Info</key>
        if [ "$line" == "<key>Payload Image Info</key>" ]; then
            got_payload="TRUE"
        elif [ "$got_payload" == "TRUE" ]; then
            if [ "$line" == "</dict>" ]; then
                got_payload="FALSE"
            elif [ "$line" == "<key>chunklistURL</key>" ] || [ "$line" == "<key>chunklistid</key>" ]; then
                skip_next="TRUE"
                continue
            elif [ "$line" == "<string>InstallESDDmg.pkg</string>" ]; then
                line="<string>InstallESD.dmg</string>"
            elif [ "$line" == "<string>com.apple.pkg.InstallESDDmg</string>" ]; then
                line="<string>com.apple.dmg.InstallESD</string>"
            fi
        fi
        echo "$line" >> "$selected_disk/$app_name/Contents/SharedSupport/InstallInfo.plist"
    done < "$dir/InstallInfo.plist"
fi
echo - Caffeinating and launching "$app_name"...
echo
echo ! Note:  It may take some time to start - be patient !
echo
caffeinate -d -i "$selected_disk"/"$app_name"/Contents/MacOS/Install* 2>/dev/null &
