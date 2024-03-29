#!/bin/bash

# Set variables for install prcorss
HOST="toaster"
USER="aidan"

# get disk
while true; do
    read -p "Enter a disk: " DISK1
    read -p "Confirm disk: " DISK2
    if [ "$PASS1" != "$PASS2" ]; then
        echo "Disk names do not match. Please try again."
    else
        DISK=$DISK1
		echo "Disk name confirmed"
		break
    fi
done

# get password
while true; do
    read -s -p "Enter password: " PASS1; echo
    read -s -p "Confirm password: " PASS2; echo
    if [ "$PASS1" != "$PASS2" ]; then
        echo "Passwords do not match. Please try again."
    else
        PASS=$PASS1
		echo "Password confirmed"
		break
    fi
done

# Get the amount of needed swap space
SWAP=$(free -m | awk '/^Mem:/{print $2}')

# Partition disk
echo "Partitioning the disk..."
parted --script $DISK \
	mklabel gpt \
	mkpart ESP fat32 1MiB 513MiB \
	set 1 boot on \
	mkpart primary linux-swap 513MiB $((513 + $SWAP))MiB \
	mkpart primary ext4 $((513 +  $SWAP))MiB 100%

# Format partitions
echo "Formatting the partitions..."
mkfs.fat -F32 ${DISK}1
mkswap ${DISK}2
mkfs.ext4 ${DISK}3

# Mount the filesyste,
echo "Mounting the file systems..."
mount ${DISK}3 /mnt
mount --mkdir ${DISK}1 /mnt/boot
swapon ${DISK}2


# Install the base system
echo "Installing the base system..."
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
echo "Chrooting into the new system..."
arch-chroot /mnt /bin/bash << EOF

# Set the time zone
echo "Setting timezone..."
ln -sf /usr/share/zoneinfo/US/Central /etc/localtime
hwclock --systohc

# Set the hostname
echo "Configuring Network..."
echo $HOST > /etc/hostname
echo '127.0.0.1 localhost' > /etc/hosts
echo '::1 localhost' >> /etc/hosts
echo '127.0.1.1 ${HOST}' >> /etc/hosts

# Generate the locales
echo "Generating locale..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf


# Install and configure systemd-boot
echo "Installing systemd-boot..."
bootctl --path=/boot install
echo "default arch" > /boot/loader/loader.conf
echo "timeout 4" >> /boot/loader/loader.conf
echo "console-mode max" >> /boot/loader/loader.conf
echo "editor no" >> /boot/loader/loader.conf
echo "title Arch Linux" > /boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "options root=/dev/sda3 rw" >> /boot/loader/entries/arch.conf

# Set root password
echo "Setting the root password..."
echo "root:$PASS" | chpasswd

# Create user
echo "Creating user..."
useradd -m -G wheel -s /bin/bash $USER
echo "$USER:$PASS" | chpasswd

# Enable wheel group
sed -i '/^# %wheel ALL=(ALL:ALL) ALL$/s/^# //' /etc/sudoers

# Enable multilib
sed -i '/^\[multilib\]/,/^$/ s/#//' /etc/pacman.conf

# Change max map count
sed -i 's/vm.max_map_count = 65530/vm.max_map_count = 2147483642/' /etc/sysctl.d/80-gamecompatibility.conf

# Install  some basic packages
pacman -Syu --noconfirm sudo efibootmgr networmanager network-manager-applet wireless_tools wpa_supplicant dialog os-probel mtools dosfstools linux-headers base-devel git vim

# enable network manager
systemctl enable NetworManager

# Install AUR healper paru
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

# Install fonts
paru -S --noconfirm ttf-ms-win11-auto 

# Install GPU drivers
paru -S --noconfirm amdgpu-pro-installer

# Install desktop 
pacman -S --noconfirm xorg awesome rofi lightdm lightdm-gtk-greeter xterm

systemctl enable lightdm

# Install additional applications
pacman -S --noconfirm firefox discord steam lutris

# Exit the chroot environment
exit
EOF

# Unmount the file systems
echo "Unmounting the file systems..."
umount -R /mnt

# Reboot the system
echo "Rebooting the system..."
reboot