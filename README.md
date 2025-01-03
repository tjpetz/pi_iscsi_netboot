# pi_iscsi_netboot

Scripts to configure a Raspberry Pi 4 to PXE boot with root on an ISCSI drive.

## Update for Raspberry Pi OS (Debian Bookworm)

The layout of the /boot directory changed from Buster to Bookwork.  The main files
needed to boot the system are now in /boot/firmware.  However, when booting via PXE
it's necessary that the files in /boot/firmware exist in the root level of the TFTP
boot directory.

Additionally Bookworm no longer needs a redirect for the initramfs files.  It automatically
identifies and load the initramfs.

## Install on a fresh Raspberry Pi OS image

Use the Raspberry Pi OS imager to build an image on an SD card.  Configure with your default
settings.

Boot with the new SD card.

Make sure you have all the latest upgrades.

```#!/bin/bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git
```

Reboot

Get the configuration scrips from GitHub

```#!/bin/bash
git clone -b bookworm https://github.com/tjpetz/pi_iscsi_netboot.git
```

Configure the boot rom to boot off the network first

```#!/bin/bash
sudo rpi-eeprom-config --apply netboot.conf
```

Run the script to configure the system for iscsi booting

```#!/bin/bash
. pi_iscsi_netboot/config_iscsi_netboot.sh
```

# config_nfs_netboot.sh

Similar to config_iscsi_netboot.sh except that rather than iscsi the root
file system is NFS mounted.

Note, for the root filesyste the NFS server must be identified by IP address
as when the root fs is mounted DNS name resolution is not yet available in that 
phase of the boot process.

