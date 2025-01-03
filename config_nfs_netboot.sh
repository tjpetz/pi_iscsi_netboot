#!/bin/bash

# Configure a system so it will network boot to an nfs root share.  The boot
# partition is on an NFS share which is configured as the source for the PXE boot.
# The SD card will remain in the machine and is configured to boot if the network
# boot fails
#
# History
# 2 Jan 2025 - updated to support Bookworm version of Raspberry Pi OS
# 3 Jan 2025 - converted to support NFS booting rather than iscsi
#

# Install prerequisite packages
sudo apt-get install -y dnsutils

# EDIT: update the following to match your ISCSI server, IQN, and NFS boot share.
SRV_NAME=`hostname`
NFS_SRV=nas03.hs.tjpetz.com
NFS_BOOT=$NFS_SRV:/volume1/nas03-pxe_boot/pi_boot

# compute key system configuration variables.
NFS_SRV_IP=$(nslookup $NFS_SRV | grep "Address: " | head -n 1 | cut -d " " -f 2)
SERIAL=$(cat /proc/cpuinfo | grep Serial | head -n 1 | cut -d : -f 2 | sed 's/ 10000000//')
NFS_ROOT=$NFS_SRV_IF:/volume1/nas03-pxe-boot/nfs_root

echo "SRV_NAME: $SRV_NAME"
echo "NFS Server: $NFS_SRV"
echo "NFS Server IP: $NFS_SRV_IP"
echo "Serial: $SERIAL"
echo "NFS Root: $NFS_ROOT"

# make our mount points
sudo mkdir /mnt/nfs_root
sudo mkdir /mnt/boot

# mount the filesystem
sudo mount $NFS_ROOT /mnt/nfs_root
sudo mkdir /mnt/nfs_root/$SRV_NAME

# sync the root except dynamic directories to the iscsi drive
sudo rsync -axP --exclude /proc --exclude /run --exclude /sys --exclude /mnt --exclude /media --exclude /tmp —-sparse / /mnt/nfs_root/$SRV_NAME
# make the special directories
sudo mkdir /mnt/iscsi/{proc,run,sys,boot,mnt,media,tmp}

# Update configuration files

# update fstab to not mount the SD card and to mount the boot directory via NFS
sudo sed "s/^PARTUUID/#PARTUUID/" -i /mnt/iscsi/etc/fstab
sudo echo "$NFS_BOOT/$SERIAL /boot/firmware nfs defaults" | sudo tee -a /mnt/iscsi/etc/fstab

# make up the cmdline.txt
cat << EOF | sudo tee /mnt/boot/$SERIAL/cmdline.txt
root=/dev/nfs nfsroot=$NFS_ROOT/$SRV_NAME,vers=3 rw ip=dhcp rootwait
EOF

# Build our NFS mounted /boot and make the machine specific boot directory
sudo mount $NFS_BOOT /mnt/boot
sudo mkdir /mnt/boot/$SERIAL
sudo cp -r /boot/firmware/* /mnt/boot/$SERIAL/

# enable SSH
sudo touch /mnt/boot/$SERIAL/ssh

