#!/bin/bash

# Set variables for install prcorss
HOST="myarch"

USER="myuser"
PASS="mypass"
ROOTPASS="myrootpass"

DISK=""

SWAP=$(free -m | awk '/^Mem:/{print $2}')

# Calculate partitions
BOOT_START="1"
BOOT_END="513"
SWAP_START=$(BOOT_END)
SWAP_END=$(BOOT_END + $SWAP_SIZE)



# Partition disk
parted --script $DISK \
	mklabel gpt \
	mkpart ESP fat32 1MiB 513MiB \
	mkpart primary linux-swap 513MiB $((513 + $SWAP))MiB \
	mkpart primary ext4 $((513 +  $SWAP))MiB 100%
	
# Format partitions
mkfs.fat -F32 ${DISK}1
mkswap ${DISK}2
mkfs.ext4 ${DISK}3

# Mount root
mount ${DISK}3 /mnt
# Mount boot
mount --mkdir ${DISK}2 /mnt/boot
# Enable swap
swapon ${DISK}2

# Install base system
pacstrap /mnt base base-devel

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Set up system
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/US/Central /etc/localtime; hwclock --systohc"
arch-chroot /mnt /bin/bash -c "echo en_US.UTF-8 UTF-8 > /etc/locale.gen; locale-gen"
arch-chroot /mnt /bin/bash -c "echo LANG=en_US.UTF-8 > /etc/locale.conf"
arch-chroot /mnt /bin/bash -c "echo $HOST > /etc/hostname"
arch-chroot /mnt /bin/bash -c "echo 127.0.0.1 localhost > /etc/hosts"
arch-chroot /mnt /bin/bash -c "echo ::1 localhost >> /etc/hosts"
arch-chroot /mnt /bin/bash -c "echo 127.0.1.1 $HOST.localdomain $HOST >> /etc/hosts"

# Install bootloader (systemd-boot)
arch-chroot /mnt /bin/bash -c "bootctl install --target=x86_64-EFI --EFIDIRECTORY=/boot --bootloader-"

# Create boot entry
echo "title Arch Linux" > /mnt/boot/loader/entries/arch.conf
echo "linux /vimlinuz-linux" >> /mnt/boot/loader/entries/arch.conf
echo "initrd /initramfs-linux.img" >> /mnt/boot/loader/entries/arch.conf
echo "options root=${DISK} rw" >> /mnt/boot/loader/entries/arch.conf


# Set root password
echo "root:$ROOT_PASSWORD" | chroot /mnt chpasswd

# Create user
arch-chroot /mnt /bin/bash -c "useradd -m -G wheel -s /bin/bash $USERNAME"
echo "$USERNAME:$PASSWORD" | chroot /mnt chpasswd

# Enable wheel group
arch-chroot /mnt /bin/bash -c "sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+ALL\)/\1/' /etc/sudoers"

# Install additional packages
arch-chroot /mnt /bin/bash -c "pacman -S --noconfirm vim git openssh"

# Unmount partitions
umount -R /mnt

echo "Installation complete. Rebooting system."
# reboot
