#!/bin/bash

ISCSI_SRV=nas02.bb.tjpetz.com
IQN=iqn.2000-01.com.synology:nas02.default-target.846be8f8b5d
NFS_BOOT=nas02.bb.tjpetz.com:/volume1/nas02-pxe_boot/pi_boot
ISCSI_SRV_IP=$(nslookup $ISCSI_SRV | grep "Address: " | head -n 1 | cut -d " " -f 2)
SERIAL=$(cat /proc/cpuinfo | grep Serial | head -n 1 | cut -d : -f 2 | sed 's/ 10000000//')
INITIATOR_NAME=$(iscsi-iname)

echo "iSCSI Server: $ISCSI_SRV"
echo "iSCSI Server IP: $ISCSI_SRV_IP"
echo "IQN: $IQN"
echo "Serial: $SERIAL"
echo "Initiator Name: $INITIATOR_NAME"

# I think at this point we want to pause and go to the NAS server create the
# LUN add a Host with the specified Initiator Name and configure the access
# controls to the drive.

sudo iscsiadm --portal $ISCSI_SRV -T $IQN --mode node --login

echo
echo "======================================================"
echo "Configure the LUN on the storage server."
echo "Configure a HOST on the storage server for the Initiator: $INITIATOR_NAME"
read -p "After configuring the storage, press any key to continue..."

# make the file system
sudo mkfs.ext4 -m0 /dev/sda

PART_UUID=$(sudo blkid /dev/sda | cut -d " " -f 2 | sed -e 's/UUID=\"//' -e 's/\"//')

sudo rsync -ahP --exclude /boot --exclude /proc --exclude /run --exclude /sys --exclude /mnt --exclude /media --exclude /tmp —-sparse / /mnt/iscsi/

sudo mkdir /mnt/iscsi/{proc,run,sys,boot,mnt,media,tmp}

# Update configuration files

# update the Initiator Name
sudo sed "s/iqn.*$/$INITIATOR_NAME/" -i /mnt/iscsi/etc/iscsi/initiatorname.iscsi

# update fstab to not mount the SD card and to mount the boot directory via NFS
sudo sed "s/^PARTUUID/#PARTUUID/" -i /mnt/iscsi/etc/fstab
sudo echo "$NFS_BOOT/$SERIAL /boot nfs defaults" | sudo tee -a /mnt/iscsi/etc/fstab

# update/build the initramfs in /boot
cd /boot
sudo update-initramfs -v -k `uname -r` -c

# Now build our NFS mounted /boot and make the machine specific boot directory
sudo mount $NFS_BOOT /mnt/boot
sudo mkdir /mnt/boot/$SERIAL
sudo rsync -a /boot/ /mnt/boot/$SERIAL/

# make up the cmdline.txt
cat << EOF | sudo tee /mnt/boot/$SERIAL/cmdline.txt
console=serial0,115200 console=tty1 ip=dhcp ISCSI_INITIATOR=InitiatorName=$INITIATOR_NAME ISCSI_TARGET_NAME=$IQN ISCSI_TARGET_IP=$ISCSI_SRV_IP ISCSI_TARGET_PORT=3260 ISCSI_TARGET_GROUP=1 rw rootfs=ext4 root=UUID=$PART_UUID elevator=deadline fsck.repair=yes rootwait
EOF

# add the redirect to the initramfs in config.txt
echo "initramfs initrd.img-`uname -r` followkernel" | sudo tee -a /mnt/boot/config.txt
