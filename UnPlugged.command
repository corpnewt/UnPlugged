#!/bin/bash

# Get the curent directory
args=( "$@" )
dir="$(cd -- "$(dirname "$0" 2>/dev/null)" >/dev/null 2>&1; pwd -P)"
# Set up some default vars
selected_disk=
app_list=
app_count=0
app_path=
app_name=
approach_count=0
approaches=()
using_approach=
base_system=
disk_ident=
mount_point=
target_app=
ia_required=("InstallAssistant.pkg")
ie_required=("BaseSystem.dmg" "BaseSystem.chunklist" "InstallESDDmg.pkg" "InstallInfo.plist" "AppleDiagnostics.dmg" "AppleDiagnostics.chunklist")
old_required=("InstallOS.dmg" "InstallOS.pkg" "InstallMacOSX.dmg" "InstallMacOSX.pkg")
old_target=
install_type="ia"
has_all="TRUE"
pkg_warned=
# Check for caffeinate binary - not present in some older OS versions
[ -e "/usr/bin/caffeinate" ] && got_coffee=1 || got_coffee=0

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
    if [ -z "$drive" ]; then
        pickDisk
        return
    fi
    if [ "$drive" == "q" ]; then
        exit 0
    fi
    if [ "$drive" -eq "$drive" ] 2>/dev/null; then
        if [  "$drive" -le "$driveCount" ] && [  "$drive" -gt 0 ]; then
            drive="${driveArray[ (( $drive-1 )) ]}"
            selected_disk="/Volumes/$drive"
        fi
    fi
    if [ -z "$selected_disk" ]; then
        pickDisk
        return
    fi
}

function findApps () {
    local appList="$( find / -name "Install*.app" -type d -maxdepth 3 2>/dev/null )"
    app_list=
    IFS=$'\n' read -rd '' -a app_list <<<"$appList"
    unset a
    for a in "${app_list[@]}"
    do
        (( app_count++ ))
    done
}

function pickApp () {
    app_path=
    local appCount=0
    echo
    clear 2>/dev/null
    echo Listing any Install macOS applications...
    echo
    for anApp in "${app_list[@]}"
    do
        (( appCount++ ))
        echo "$appCount". "$anApp"
    done
    if [ "$appCount" -le 0 ]; then
        echo - No installers found!
        exit 1
    fi
    echo
    read -r -p "Select the source macOS recovery installer: " app
    if [[ "$app" == "" ]]; then
        pickApp
        return
    fi
    if [ "$app" == "q" ]; then
        exit 0
    fi
    # Make sure it's a number, and within range
    if [ "$app" -eq "$app" ] 2>/dev/null; then
        if [  "$app" -le "$appCount" ] && [  "$app" -gt 0 ]; then
            app_path="${app_list[ (( $app-1 )) ]}"
        fi
    fi
    # Strip trailing slashes
    app_path="$(stripSlash "$app_path")"
    if [ -z "$app_path" ]; then
        pickApp
        return
    fi
}

function stripSlash () {
    local path="$1"
    if [ -z "$path" ]; then
        return
    fi
    # Attempt to remove a trailing slash - if any
    path_check="${path%/}"
    if [ "$path_check" == "$path" ]; then
        echo "$path"
    else
        # A change was made - try again
        echo "$(stripSlash "$path_check")"
    fi
}

function pickApproach () {
    using_approach=
    local appCount=0
    echo
    clear 2>/dev/null
    echo "Possible ways to get Install [macOS version].app:"
    echo
    for anApp in "${approaches[@]}"
    do
        (( appCount++ ))
        echo "$appCount". "$anApp"
    done
    if [ "$appCount" -le 0 ]; then
        echo - No possible ways found!
        exit 1
    fi
    echo
    read -r -p "Select the approach you'd like to use: " app
    if [[ "$app" == "" ]]; then
        pickApproach
        return
    fi
    if [ "$app" == "q" ]; then
        exit 0
    fi
    # Make sure it's a number, and within range
    if [ "$app" -eq "$app" ] 2>/dev/null; then
        if [  "$app" -le "$appCount" ] && [  "$app" -gt 0 ]; then
            using_approach="${approaches[ (( $app-1 )) ]}"
        fi
    fi
    # Make sure we got an approach
    if [ -z "$using_approach" ]; then
        pickApproach
        return
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
        install_type="ie" # Check for Catalina and prior
        for f in "${ie_required[@]}"
        do
            if [ -e "$dir/$f" ]; then
                echo "- Found $f"
            else
                has_all="FALSE"
            fi
        done
    fi
    if [ "$has_all" != "TRUE" ]; then
        # Reset our has_all check and install type
        has_all="FALSE"
        install_type="old"
        for f in "${old_required[@]}"
        do
            if [ -e "$dir/$f" ] && [ "$has_all" != "TRUE" ]; then
                # Bail on the first match - only need the one file
                echo "- Found $f"
                has_all="TRUE"
                old_target="$f"
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
    echo Legacy OS X Installers from https://support.apple.com/en-us/102662 require one
    echo of the following:
    echo
    for f in "${old_required[@]}"
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
    if [ -z "$dir" ] || [ ! -e "$dir" ]; then
        pickDir
        return
    fi
    if [ ! -d "$dir" ]; then
        # Got a file instead - try to get the parent dir
        # by getting the length of the file name and
        # gathering a dir substring from index 0 through
        # length of dir - length of file name
        local filename="${dir##*/}"
        local name_len="${#filename}"
        local dir_len="${#dir}"
        dir="${dir:0:$((dir_len - name_len))}"
        if [ ! -d "$dir" ]; then
            # Failsafe just in case something went wrong
            pickDir
            return
        fi
    fi
    # Now check again if we have all files
    echo
    hasAll
    if [ "$has_all" != "TRUE" ]; then
        pickDir
        return
    fi
}

function copyTo () {
    # Caffeinate and copy - exit if the return value is
    # non-zero
    local from="$1" to="$2"
    if [ -z "$from" ] || [ -z "$to" ]; then
        # Missing one or more args
        exit 1
    fi
    if [ -d "$from" ]; then
        # Copying a directory
        if [ "$got_coffee" == "1" ]; then
            caffeinate -d -i cp -R "$from" "$to"
        else
            cp -R "$from" "$to"
        fi
    elif [ -e "$from" ]; then
        # Copying a file
        if [ "$got_coffee" == "1" ]; then
            caffeinate -d -i cp "$from" "$to"
        else
            cp "$from" "$to"
        fi
    else
        # Doesn't exist
        exit 1
    fi
    if [ "$?" != "0" ]; then
        exit $?
    fi
}

function getTemp () {
    # Helper to generate a temp folder name at the passed
    # volume root and ensure it doesn't already exist
    local path="$1"
    path="$(stripSlash "$path")"
    if [ -z "$path" ] || [ ! -d "$path" ]; then
        # We need a valid, non-root, directory path
        return
    fi
    temp_path="$path/macOS-Installer-$(uuidgen)"
    if [ ! -d "$temp_path" ]; then
        # Create it and return the path
        mkdir -p "$temp_path"
        echo "$temp_path"
    else
        echo "$(getTemp)"
    fi
}

function mountAndExploreDmg () {
    echo "- Mounting $base_system..."
    disk_ident="$(hdiutil attach -noverify -nobrowse "$dir/$base_system" | tail -n 1 | cut -d' ' -f1)"
    if [ -z "$disk_ident" ]; then
        echo "--> Failed to mount - aborting..."
        exit 1
    fi
    mount_point="$(diskutil info "$disk_ident" | grep 'Mount Point' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g')"
    if [ -z "$mount_point" ] || [ ! -d "$mount_point" ]; then
        echo "--> Could not locate mount point - aborting..."
        exit 1
    fi
    if [ "$install_type" == "old" ]; then
        echo "- Locating valid install pkg..."
        pkg_path="$(find "$mount_point" -name "Install*.pkg" -type f -maxdepth 1 2>/dev/null | head -n 1)"
        if [ -z "$pkg_path" ] || [ ! -e "$pkg_path" ]; then
            echo "--> Could not locate valid install pkg - aborting..."
            exit 1
        fi
        # Update the dir for copying/linking
        dir="$mount_point"
        # Set our target to the pkg
        old_target="${pkg_path##*/}"
        echo "--> Found $old_target"
        # Ensure that it's valid
        getAppNameFromPkg "$old_target"
    else
        echo "- Locating Install [macOS version].app..."
        # Gather the first hit from the find command
        app_path="$(find "$mount_point" -name "Install*.app" -type d -maxdepth 1 2>/dev/null | head -n 1)"
        if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
            echo "--> Could not locate Install [macOS version].app - aborting..."
            exit 1
        fi
        app_name="${app_path##*/}"
        echo "--> Found $app_name"
    fi
}

function expandFullError () {
    name="$(sw_vers -productName)"
    prod="$(sw_vers -productVersion)"
    build="$(sw_vers -buildVersion)"
    echo
    clear 2>/dev/null
    echo "The pkgutil binary in this recovery env does not support the --expand-full"
    echo "switch."
    echo
    echo "Currently running $name $prod ($build)."
    echo
    if [ "$install_type" != "old" ]; then
        echo "There was no fallback BaseSystem.dmg or RecoveryImage.dmg located in the"
        echo "selected directory, and no macOS installer app located locally."
        echo
        echo "Without a dmg or installer application, this script cannot continue."
    else
        echo "This script cannot continue."
    fi
    echo
    echo "Aborting..."
    exit 1
}

function pkgWarn () {
    if [ ! -z "$pkg_warned" ]; then
        # Already been warned - don't warn again
        return
    fi
    local pkgname="$1"
    if [ -z "$pkgname" ]; then
        pkgname="the selected pkg"
    fi
    name="$(sw_vers -productName)"
    prod="$(sw_vers -productVersion)"
    build="$(sw_vers -buildVersion)"
    echo 
    clear 2>/dev/null
    echo "!! Could not extract required info from $pkgname !!"
    echo "!! That could indicate that it may be corrupt, or is missing files !!"
    echo
    echo "Some recovery environments have odd issues (macOS 13, for instance) which limit"
    echo "the information pkgutil can obtain.  In those cases, as long as the .pkg copy"
    echo "process completed correctly, you should be fine continuing."
    echo
    echo "Currently running $name $prod ($build)."
    echo
    while true; do
        read -r -p "Do you wish to continue? [y/n]: " yn
        case $yn in
            [Yy]* ) break;;
            [NnQq]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    # If we got here - we're continuing.  Prevent multiple prompts
    pkg_warned="TRUE"
}

function getAppNameFromPkg () {
    local pkgname="$1"
    local skipset="$2"
    if [ -z "$pkgname" ]; then
        pkgname="InstallAssistant.pkg"
    fi
    app_temp="$(pkgutil --payload-files "$dir/$pkgname" 2>/dev/null | grep -iE "(?i)^.*/Install[^/]+\.app$")"
    if [ "$?" != "0" ] || [ -z "$app_temp" ]; then
        # Got an error - or didn't get a .app
        pkgWarn "$pkgname"
    elif [ -z "$skipset" ] || [ "$skipset" == "FALSE" ]; then
        # Only update the app_name/display_app if not skipping
        app_name="${app_temp##*/}"
        display_app="$app_name"
    fi
}

function expandPkgAndExtractApp () {
    local pkgname="$1"
    if [ -z "$pkgname" ]; then
        pkgname="InstallAssistant.pkg"
    fi
    # First we use the undocumented --expand-full flag for pkgutil
    # to fully expand the install .pkg to the temp dir
    # Caffeinate this process as it can take awhile
    echo "- Expanding $pkgname - may take some time..."
    # Ensure we have an app name to look for
    getAppNameFromPkg "$pkgname"
    if [ "$got_coffee" == "1" ]; then
        caffeinate -d -i pkgutil --expand-full "$dir/$pkgname" "$temp/InstallPackage"
    else
        pkgutil --expand-full "$dir/$pkgname" "$temp/InstallPackage"
    fi
    if [ "$?" != "0" ]; then
        echo "Something went wrong - aborting..."
        exit 1
    fi
    # Find the Install [macOS version].app
    echo "- Locating $display_app..."
    app_path="$(find "$temp/InstallPackage" -name "Install*.app" -type d 2>/dev/null | head -n 1)"
    if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
        echo "--> Could not locate $display_app - aborting..."
        exit 1
    fi
    app_name="${app_path##*/}"
    echo "--> Found $app_name"
    target_app="$temp"/"$app_name"
    echo "- Moving files into place..."
    mv "$app_path" "$target_app"
    echo "- Cleaning up..."
    rm -rf "$temp/InstallPackage"
}

function strEndsWith () {
    local str="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    local end="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    if [ -z "$str" ] || [ -z "$end" ]; then
        echo "0"
        return
    fi
    # Get the length of the str and end
    str_len="${#str}"
    end_len="${#end}"
    # Make sure our end isn't larger
    if [ "$str_len" -ge "$end_len" ]; then
        # Now we extract the end of str and compare
        check="${str:$((str_len-end_len)):$str_len}"
        if [ "$check" == "$end" ]; then
            # We have a match!
            echo "1"
            return
        fi
    fi
    # No match or str is too short, bail
    echo "0"
}

# Gather some info to figure out how to proceed
# Let's look for "expand-full" in pkgutil itself
cat /usr/sbin/pkgutil | grep -i "expand-full" >/dev/null 2>&1
[ "$?" == "0" ] && can_expand_full=1 || can_expand_full=0
findApps
echo
clear 2>/dev/null
hasAll
if [ "$has_all" != "TRUE" ]; then
    pickDir
fi
if [ -e "$dir/BaseSystem.dmg" ]; then
    base_system="BaseSystem.dmg"
elif [ -e "$dir/RecoveryImage.dmg" ]; then
    base_system="RecoveryImage.dmg"
fi

# Here we should be able to list the options for the user
# based on what we discovered above.
# Let's create a few task items to outline.
mount_basesystem=0
expand_installassistant=0

if [ "$install_type" == "ia" ]; then
    # Ensure the pkg is valid and resolves to an Install app
    getAppNameFromPkg "InstallAssistant.pkg" "TRUE"
    # Prompt for any approaches we can use if > 1
    if [ "$can_expand_full" == "1" ]; then
        approaches+=("Fully expand InstallAssistant.pkg - slower, but no risk of app mismatch")
        (( approach_count++ ))
    fi
    if [ ! -z "$base_system" ]; then
        approaches+=("Extract the Install [macOS version].app from $base_system")
        (( approach_count++ ))
    fi
    if [ "$app_count" -gt 0 ]; then
        if [ "$app_count" == "1" ]; then
            # We only found one - use its name
            temp_path="$(stripSlash "${app_list[0]}")"
            temp_name="${temp_path##*/}"
            approaches+=("Choose the locally discovered $temp_name")
        else
            approaches+=("Choose a locally discovered Install [macOS version].app ($app_count total)")
        fi
        (( approach_count++ ))
    fi
    if [ "$approach_count" -le 0 ]; then
        expandFullError
    fi
    if [ "$approach_count" -gt 1 ]; then
        # Show a menu and let the user pick one
        pickApproach
    else
        # Only one to choose from - use that
        using_approach="${approaches[0]}"
    fi
    # Let's set up the tasks for our selected approach based on
    # the first letter of the text
    if [ "${using_approach:0:1}" == "F" ]; then
        expand_installassistant=1
        # Scrape the app name from the pkg itself
        getAppNameFromPkg "InstallAssistant.pkg"
    elif [ "${using_approach:0:1}" == "E" ]; then
        mount_basesystem=1
    elif [ "${using_approach:0:1}" == "C" ]; then
        # Check if we only got one app - and if so, just use that
        # - else just prompt
        if [ "$app_count" == "1" ]; then
            app_path="$(stripSlash "${app_list[0]}")"
        else
            pickApp
        fi
        # Resolve the name as well
        app_name="${app_path##*/}"
    fi
elif [ "$install_type" == "old" ]; then
    # We have to have --expand-full support for this
    if [ "$can_expand_full" != "1" ]; then
        expandFullError
    fi
    # Clear the base_sytem var as we may use it for our purposes
    base_system=
    # Check if we can scrape for the application name in the pkg
    if [ "$(strEndsWith "$old_target" ".pkg")" == "1" ]; then
        # Scrape the app name from the pkg itself
        getAppNameFromPkg "$old_target"
    else
        # It's a dmg - save it as the base_system
        base_system="$old_target"
        mount_basesystem=1
    fi
else
    # Only one remaining approach to use here
    mount_basesystem=1
fi

pickDisk

# Resolve our display name before listing the summary
[ -z "$app_name" ] && display_app="Install [macOS version].app" || display_app="$app_name"
# Walk our task list and outline what we'll be doing
echo
clear 2>/dev/null
echo Task Summary:
echo
if [ "$mount_basesystem" == "1" ] || [ "$install_type" == "old" ]; then
    if [ "$mount_basesystem" == "1" ]; then
        echo "- Mount $base_system"
    fi
    if [ "$install_type" == "old" ]; then
        if [ "$(strEndsWith "$old_target" ".pkg")" == "1" ]; then
            # The .pkg is the target - use its value
            echo "- Expand $old_target to a temp folder on $selected_disk"
        else
            echo "- Expand the .pkg within to a temp folder on $selected_disk"
        fi
    else
        echo "- Copy $display_app to a temp folder on $selected_disk"
    fi
elif [ "$expand_installassistant" == "1" ]; then
    echo "- Expand InstallAssistant.pkg to a temp folder on $selected_disk"
elif [ ! -z "$app_name" ]; then
    echo "- Copy $app_name to a temp folder on $selected_disk"
fi
echo "- Set up SharedSupport in $display_app/Contents/"
if [ "$got_coffee" == "1" ]; then
    echo "- Caffeinate and launch $display_app"
else
    echo "- Launch $display_app"
fi
echo
while true; do
    read -r -p "Do you wish to continue? [y/n]: " yn
    case $yn in
        [Yy]* ) break;;
        [NnQq]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Actually perform the tasks
echo
clear 2>/dev/null
echo Executing tasks...
echo
# Get a destination temp folder
temp="$(getTemp "$selected_disk")"
if [ -z "$temp" ] || [ ! -d "$temp" ]; then
    echo "Failed to create temp folder - aborting..."
    exit 1
fi
if [ "$expand_installassistant" == "1" ]; then
    expandPkgAndExtractApp "InstallAssistant.pkg"
else
    # Ensure we mount the BaseSystem.dmg/RecoveryImage.dmg
    # as needed
    if [ "$mount_basesystem" == "1" ]; then
        mountAndExploreDmg
    fi
    if [ "$install_type" == "old" ]; then
        # We've mounted our dmg at this point - so our
        # old target should be updated.
        expandPkgAndExtractApp "$old_target"
    else
        # Not expanding the InstallAssistant.pkg - let's copy our app over
        # and then our files
        if [ -z "$app_name" ]; then
            echo "No $display_app was specified - aborting..."
            exit 1
        fi
        target_app="$temp"/"$app_name"
        echo "- Copying $app_name to $temp..."
        copyTo "$app_path" "$target_app"
    fi
fi
echo - Creating "$app_name"/Contents/SharedSupport...
mkdir -p "$target_app/Contents/SharedSupport"
echo - Linking and copying files to SharedSupport...
if [ "$install_type" == "ia" ]; then
    for f in "${ia_required[@]}"
    do
        if [ "$f" == "InstallAssistant.pkg" ]; then
            echo "--> $f -- SharedSupport.dmg"
            ln -s "$dir/$f" "$target_app/Contents/SharedSupport/SharedSupport.dmg"
        else
            echo "--> $f"
            ln -s "$dir/$f" "$target_app/Contents/SharedSupport/$f"
        fi
    done
elif [ "$install_type" == "old" ]; then
    # We need to copy the target package to shared support.
    # There's only one - so skip list iteration
    # Even if old_target was originally a dmg, it's been updated
    # per mountAndExploreDmg - same with dir
    echo "--> $old_target -- InstallESD.dmg"
    copyTo "$dir/$old_target" "$target_app/Contents/SharedSupport/InstallESD.dmg"
else
    for f in "${ie_required[@]}"
    do
        if [ "$f" == "InstallInfo.plist" ]; then
            # Skip this so we can handle it more specifically
            continue
        elif [ "$f" == "InstallESDDmg.pkg" ]; then
            echo "--> $f -- InstallESD.dmg"
            ln -s "$dir/$f" "$target_app/Contents/SharedSupport/InstallESD.dmg"
        else
            echo "--> $f"
            ln -s "$dir/$f" "$target_app/Contents/SharedSupport/$f"
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
        echo "$line" >> "$target_app/Contents/SharedSupport/InstallInfo.plist"
    done < "$dir/InstallInfo.plist"
fi
# Clean up after ourselves if needed
if [ ! -z "$mount_point" ] && [ "$install_type" != "old" ]; then
    echo "- Unmounting $base_system..."
    hdiutil detach "$mount_point" >/dev/null 2>&1
fi
# Make sure the required files/dirs exist
if [ -z "$app_name" ] || [ -z "$target_app" ] || [ ! -d "$target_app" ]; then
    echo
    echo Something went wrong - aborting...
    exit 1
fi
if [ "$got_coffee" == "1" ]; then
    echo - Caffeinating and launching "$app_name"...
    echo
    echo ! Note:  It may take some time to start - be patient !
    echo
    caffeinate -d -i "$target_app"/Contents/MacOS/Install* 2>/dev/null &
else
    echo - Launching "$app_name"...
    echo
    echo ! Note:  It may take some time to start - be patient !
    echo
    "$target_app"/Contents/MacOS/Install* 2>/dev/null &
fi
