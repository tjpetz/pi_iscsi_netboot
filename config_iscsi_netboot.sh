#!/bin/bash

# Configure a system so it will network boot to an iscsi drive.  The boot
# partition is on an NFS share which is configured as the source for the PXE boot.
# The SD card will remain in the machine and is configured to boot if the network
# boot fails
#
# History
# 2 Jan 2025 - updated to support Bookworm version of Raspberry Pi OS
#

# Install prerequisite packages
sudo apt-get install -y open-iscsi initramfs-tools dnsutils

# EDIT: update the following to match your ISCSI server, IQN, and NFS boot share.
ISCSI_SRV=nas03.hs.tjpetz.com
IQN=iqn.2000-01.com.synology:nas03.default-target.bf2aa0b3f94
NFS_BOOT=nas03.hs.tjpetz.com:/volume1/nas03-pxe_boot/pi_boot

# compute key system configuration variables.
ISCSI_SRV_IP=$(nslookup $ISCSI_SRV | grep "Address: " | head -n 1 | cut -d " " -f 2)
SERIAL=$(cat /proc/cpuinfo | grep Serial | head -n 1 | cut -d : -f 2 | sed 's/ 10000000//')
INITIATOR_NAME=$(sudo grep ^InitiatorName /etc/iscsi/initiatorname.iscsi | cut -d "=" -f 2)

echo "iSCSI Server: $ISCSI_SRV"
echo "iSCSI Server IP: $ISCSI_SRV_IP"
echo "IQN: $IQN"
echo "Serial: $SERIAL"
echo "Initiator Name: $INITIATOR_NAME"

# Mark iSCSI to rebuild the initramfs
sudo touch /etc/iscsi/iscsi.initramfs

# Login to the iscsi server and then pause.  This will allow the admin
# to create the LUN and HOST records with the correct permissions.
sudo iscsiadm --portal $ISCSI_SRV --mode discovery --type sendtargets
sudo iscsiadm --portal $ISCSI_SRV -T $IQN --mode node --login

echo
echo "======================================================"
echo "Configure the LUN on the storage server."
echo "Configure a HOST on the storage server for the Initiator: $INITIATOR_NAME"
read -p "After configuring the storage, press any key to continue..."

# logout and back in again to make the LUN visible
sudo iscsiadm --portal $ISCSI_SRV -T $IQN --mode node --logout
sudo iscsiadm --portal $ISCSI_SRV -T $IQN --mode node --login

# make the file system
sudo mkfs.ext4 -m0 /dev/sda

# Save the partition UUID
PART_UUID=$(sudo blkid /dev/sda | cut -d " " -f 2 | sed -e 's/UUID=\"//' -e 's/\"//')

# label the file system for convenient reference.
sudo e2label /dev/sda "iscsi_root"

# make our mount points
sudo mkdir /mnt/iscsi
sudo mkdir /mnt/boot

# mount the filesystem
sudo mount /dev/sda /mnt/iscsi
# sync the root except dynamic directories to the iscsi drive
sudo rsync -aP --exclude /boot --exclude /proc --exclude /run --exclude /sys --exclude /mnt --exclude /media --exclude /tmp —-sparse / /mnt/iscsi/
# make the special directories
sudo mkdir /mnt/iscsi/{proc,run,sys,boot,mnt,media,tmp}

# Update configuration files

# update fstab to not mount the SD card and to mount the boot directory via NFS
sudo sed "s/^PARTUUID/#PARTUUID/" -i /mnt/iscsi/etc/fstab
sudo echo "$NFS_BOOT/$SERIAL /boot/firmware nfs defaults" | sudo tee -a /mnt/iscsi/etc/fstab

# Build our NFS mounted /boot and make the machine specific boot directory
sudo mount $NFS_BOOT /mnt/boot
sudo mkdir /mnt/boot/$SERIAL
sudo cp -r /boot/firmware/* /mnt/boot/$SERIAL/

# enable SSH
sudo touch /mnt/boot/$SERIAL/ssh

# make up the cmdline.txt
cat << EOF | sudo tee /mnt/boot/$SERIAL/cmdline.txt
console=serial0,115200 console=tty1 ip=dhcp ISCSI_INITIATOR=$INITIATOR_NAME ISCSI_TARGET_NAME=$IQN ISCSI_TARGET_IP=$ISCSI_SRV_IP ISCSI_TARGET_PORT=3260 ISCSI_TARGET_GROUP=1 rw rootfs=ext4 root=UUID=$PART_UUID elevator=deadline fsck.repair=yes rootwait
EOF

# Build the initramfs
sudo update-initramfs -v -k `uname -r` -c -b /mnt/boot/$SERIAL
