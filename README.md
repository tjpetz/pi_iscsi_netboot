# pi_iscsi_netboot

Scripts to configure a Raspberry Pi 4 to PXE boot with root on an ISCSI drive.

## Update for Raspberry Pi OS (Debian Bookworm)

The layout of the /boot directory changed from Buster to Bookwork.  The main files
needed to boot the system are now in /boot/firmware.  However, when booting via PXE
it's necessary that the files in /boot/firmware exist in the root level of the TFTP
boot directory.

Additionally Bookworm no longer needs a redirect for the initramfs files.  It automatically
identifies and load the initramfs.
