#!/bin/bash

set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit 1
fi

# User-defined variables
HOSTNAME="archlinux"
USERNAME="abc"
PASSWORD="123"
DISK="/dev/vda"
TIMEZONE="Asia/Shanghai"
LOCALE="en_US.UTF-8"
KEYMAP="us"
BOOT_MODE="bios" # Options: "bios"

echo "Starting Arch Linux automated installation..."

# Enable time synchronization
timedatectl set-ntp true

# Disk partitioning (BIOS boot mode with MBR)
echo "Partitioning disk: $DISK"
parted -s "$DISK" mklabel msdos

# Create root partition
parted -s "$DISK" mkpart primary ext4 1MiB 100%
parted -s "$DISK" set 1 boot on
mkfs.ext4 "${DISK}1"

# Mount root partition
mount "${DISK}1" /mnt

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware vim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure the new system
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Configure locale
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set hostname and hosts file
echo "$HOSTNAME" > /etc/hostname
cat <<EOT >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

# Set root password
echo "root:$PASSWORD" | chpasswd

# Install bootloader for BIOS mode
pacman -S --noconfirm grub
grub-install --target=i386-pc $DISK

# Generate GRUB config
grub-mkconfig -o /boot/grub/grub.cfg

# Install a DHCP client
pacman -S --noconfirm dhcpcd
systemctl enable --now dhcpcd

# Install SSH package
pacman -S --noconfirm openssh

# Enable SSH service
systemctl enable sshd
systemctl start sshd


# Create a regular user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

EOF

# Unmount and reboot
umount -R /mnt
echo "Installation complete, rebooting system..."
reboot
