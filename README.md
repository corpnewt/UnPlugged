# UnPlugged
Bash script to help build and run an offline installer in recovery.

***

## Prerequisites

* [UnPlugged](https://github.com/corpnewt/UnPlugged)
* [gibMacOS](https://github.com/corpnewt/gibMacOS)
* [macrecovery.py](https://github.com/acidanthera/OpenCorePkg/tree/master/Utilities/macrecovery) (or [gibMacRecovery](https://github.com/corpnewt/gibMacRecovery))
* A 16+ GB USB drive
* Your EFI set up by following the [Dortania guide](https://dortania.github.io/OpenCore-Install-Guide/)

## Pre-Install Steps

1. Download **_the same_** version of macOS via both `gibMacOS` and `macrecovery.py`

    ◦ i.e. If you want to download Ventura, make sure you get Ventura from both `gibMacOS` and `macrecovery.py`

3. Format your USB with 2 partitions:
   
    ◦ A FAT32 partition of ~750MB to 1GB (enough to accommodate the EFI and com.apple.recovery.boot folders)

    ◦ An ExFAT partition of the remaining space (needs to be enough to accommodate the files downloaded from `gibMacOS`)

4. Copy your EFI folder and the com.apple.recovery.boot folder over to the FAT32 partition
5. Copy the folder containing the files downloaded from gibMacOS to the ExFAT partition

    ◦ You'll be `cd`ing to this folder later - so it may make sense to label it something easy to type like `macOS`

6. Copy `UnPlugged.command` to that same folder on the ExFAT partition
7. Boot into the install environment

## Recovery Environment Steps

1. Open Disk Utility
2. Enable View -> Show All Devices
3. Format the target **device** (not the volume) for your macOS version

     ◦ Sierra and prior should be macOS Extended (Journaled) with a GUID Partition Map

     ◦ High Sierra and newer should be APFS with a GUID Parititon Map

4. Quit Disk Utility
5. Open Terminal
6. Type `cd /Volumes/[your ExFAT volume name]/macOS`

    ◦ You can get a list of all volumes with `ls /Volumes`

    ◦ Make sure to replace `macOS` with the name of the folder containing the gibMacOS files and `UnPlugged.command`

7. Type `./UnPlugged.command` to launch the script

    ◦ If that does not work - you can type `bash UnPlugged.command`

## UnPlugged.command Steps

1. The script will list any detected `Install macOS [version].app` directories - select the one that matches the intended OS version to install (in most cases there will only be one detected)
2. The script should auto-detect the required files - but if it does not, it will prompt for the path to them here
3. The script will then prompt asking for the target volume - this is the volume that you just created in Disk Utility.  The one where you intend to install macOS
4. Then you'll be presented with a task list - and asked if you want to continue - type `y` and enter
5. The script will build the full install app and launch it from the Terminal for you - continue the rest of the install as normal

## Sonoma Notes

It seems the Sonoma BaseSystem.dmg recovery environment does not allow mounting FAT32 or ExFAT volumes at all.  To work around this using UnPlugged requires a couple extra steps.

You'll need to use an earlier BaseSystem.dmg|.chunklist downloaded via `macrecovery.py` in your com.apple.recovery.boot folder (Ventura works fine with FAT32 and ExFAT volumes).  You'll also need to download Sonoma's BaseSystem.dmg via `macrecovery.py` and place that alongside the files downloaded with `gibMacOS`.  The end result should look something like the following:

```
USB Drive
|-> 800MB FAT32 Partition (named OPENCORE or similar)
|   |-> EFI
|   \-> com.apple.recovery.boot
|       |-> BaseSystem.dmg (for Ventura)
|       \-> BaseSystem.chunklist (for Ventura)
\-> 15+GB ExFAT Partition (named UnPlugged or similar)
    |-> InstallAssistant.pkg (for Sonoma)
    |-> BaseSystem.dmg (for Sonoma)
    \-> UnPlugged.command
```

In order for `UnPlugged.command` to be able to find the `Install macOS Sonoma.app`, you'll need to mount the BaseSystem.dmg for it using `hdiutil` from the terminal.  Assuming the above USB drive layout, and assuming the ExFAT volume is named `UnPlugged`, you can accomplish that with the following command in the terminal:

```
hdiutil attach -noverify /Volumes/UnPlugged/BaseSystem.dmg
```

Make sure you replace `/Volumes/UnPlugged/BaseSystem.dmg` with the path to your .dmg if you're using a different volume name or directory layout.  The `-noverify` argument just prevents verifying the .dmg's checksum in order to speed up mounting.  You can omit that if you want the .dmg verified.

The rest of the process should be the same as with prior OS versions.
