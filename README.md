# UnPlugged
Bash script to help build and run an offline installer in recovery.

***

## Prerequisites

* [UnPlugged](https://github.com/corpnewt/UnPlugged)
* [gibMacOS](https://github.com/corpnewt/gibMacOS) - or a .dmg/.pkg from the "older versions" linked [here](https://support.apple.com/en-us/102662)
* [macrecovery.py](https://github.com/acidanthera/OpenCorePkg/tree/master/Utilities/macrecovery) (or [gibMacRecovery](https://github.com/corpnewt/gibMacRecovery))
* A 16+ GB USB drive
* Your EFI set up by following the [Dortania guide](https://dortania.github.io/OpenCore-Install-Guide/)
* If you're installing Sonoma or later, make sure to read [this section](#notes-for-sonoma-and-later)!

***

## Pre-Install Steps

1. Download **_the same_** version of macOS via both `gibMacOS` and `macrecovery.py`

    ◦ i.e. If you want to download Ventura, make sure you get Ventura from both `gibMacOS` and `macrecovery.py`

    ◦ They just need to be the same **major** version (i.e. Ventura with Ventura), it **_does not_** need to be the exact same point release (i.e. 13.x.y and 13.x.y)

    ◦ Beta and Apple Silicon specific builds from `gibMacOS` may not work correctly - and may result in an error stating "This version of macOS is not authorized for installation."

3. Format your USB with 2 partitions:
   
    ◦ A FAT32 partition of ~750MB to 1GB (enough to accommodate the EFI and com.apple.recovery.boot folders)

    ◦ An ExFAT partition of the remaining space (needs to be enough to accommodate the files downloaded from `gibMacOS`)

4. Copy your EFI folder and the com.apple.recovery.boot folder over to the FAT32 partition
5. Copy the files downloaded from gibMacOS to the ExFAT partition

    ◦ You'll be `cd`ing to this partition later - so it may make sense to label it something easy to type like `UnPlugged`

6. Copy `UnPlugged.command` to the ExFAT partition as well
7. **_Eject the USB drive_** - this ensures any pending cached writes are applied and can help prevent corrupt or incomplete file copies
8. Boot into the recovery environment

<details>
<summary>Example USB Structure</summary>

After formatting and copying things to their respective locations, your USB should look something like this:
```
USB Drive
|-> 750+MB FAT32 Partition (named OPENCORE or similar)
|   |-> EFI
|   \-> com.apple.recovery.boot
|       |-> BaseSystem.dmg
|       \-> BaseSystem.chunklist
\-> 15+GB ExFAT Partition (named UnPlugged or similar)
    |-> Files from gibMacOS (InstallAssistant.pkg, InstallESDDmg.pkg, etc)
    \-> UnPlugged.command
```
</details>

***

## Recovery Environment Steps

1. Open Disk Utility
2. Enable View -> Show All Devices
3. Format the target **device** (not the volume) for your macOS version

     ◦ Sierra and prior should be macOS Extended (Journaled) with a GUID Partition Map

     ◦ High Sierra and newer should be APFS with a GUID Parititon Map

5. Quit Disk Utility
6. Open Terminal
7. Type `cd /Volumes/[your ExFAT volume name]`

    ◦ You can get a list of all volumes with `ls /Volumes`

    ◦ Make sure to replace `[your ExFAT volume name]` with the name of the volume containing gibMacOS files and `UnPlugged.command`

    ◦ e.g. If you named the volume `UnPlugged`, you would do `cd /Volumes/UnPlugged`

8. Type `./UnPlugged.command` to launch the script

    ◦ If that does not work - you can type `bash UnPlugged.command`

***

## UnPlugged.command Steps

1. The script will assess available approaches for locating the `Install [macOS version].app` needed, and may prompt you to choose from a list of two or more of the following:
   
    ◦ `Fully expand InstallAssistant.pkg - slower, but no risk of app mismatch` - if leveraging InstallAssistant.pkg on a recovery env where `pkgutil` supports the `--expand-full` switch (most do)
   
    ◦ `Extract the Install [macOS version].app from BaseSystem.dmg` - if a BaseSystem.dmg or RecoveryImage.dmg is detected next to InstallAssistant.pkg
   
    ◦ `Choose a locally discovered Install [macOS version].app` - if any installers were detected locally
   
2. The script should auto-detect the required files - but if it does not, it will prompt for the path to them here
3. The script will then prompt asking for the target volume - this is the volume that you just created in Disk Utility.  The one where you intend to install macOS
4. Then you'll be presented with a task list - and asked if you want to continue - type `y` and enter
5. The script will build the full install app and launch it from the Terminal for you - continue the rest of the install as normal

    ◦ Make sure to leave the Terminal open - do not quit it, as doing so will also quit the installer.

***

## Notes for Sonoma and Later

It seems the Sonoma+ BaseSystem.dmg recovery environment does not allow mounting FAT32 or ExFAT volumes at all.  To work around this using UnPlugged requires a couple extra steps.

You'll need to use an earlier BaseSystem.dmg|.chunklist downloaded via `macrecovery.py` in your com.apple.recovery.boot folder (Monterey works fine with FAT32 and ExFAT volumes).  You'll also need to download Sonoma's BaseSystem.dmg via `macrecovery.py` and place that alongside the files downloaded with `gibMacOS` if you don't intend to expand the InstallAsisstant.pkg directly.  The end result should look something like the following:

```
USB Drive
|-> 750+MB FAT32 Partition (named OPENCORE or similar)
|   |-> EFI
|   \-> com.apple.recovery.boot
|       |-> BaseSystem.dmg (for Monterey)
|       \-> BaseSystem.chunklist (for Monterey)
\-> 15+GB ExFAT Partition (named UnPlugged or similar)
    |-> InstallAssistant.pkg (for Sonoma+)
    |-> BaseSystem.dmg (for Sonoma+, if not expanding the .pkg directly)
    \-> UnPlugged.command
```

When prompted to select where you would like to get the `Install [macos Version].app` from, selecting `Extract the Install [macOS version].app from BaseSystem.dmg` will leverage the provided BaseSystem.dmg.

The rest of the process should be the same as with prior OS versions.


<details>
<summary>Note: There *are* ways to manually mount the ExFAT volume in Sonoma+ recovery</summary>

You can use the following approach to locate your ExFAT volume's identifier and manually mount it if you're familiar with the command line:

```sh
# Show a list of all the physically connected disks and their
# volumes:
diskutil list physical
# Create a folder where you'd like to mount the ExFAT volume,
# the directory name must be unique, and not already exist:
mkdir /Volumes/UnPlugged
# Mount the ExFAT volume at that location - replace "diskXsY" with
# your ExFAT volume's identifier:
/sbin/mount_exfat /dev/diskXsY /Volumes/UnPlugged
```

You should also be able to mount the FAT32 volume by performing the above steps using `/sbin/mount_msdos` instead of `/sbin/mount_exfat`.

</details>
