#!/usr/bin/env bash

clear
echo "Setting up Hungarian keymap..."
sleep 5
loadkeys hu
echo '
***
Done. 
***'
sleep 5
clear

echo "Checking efivars..."
sleep 5
ls /sys/firmware/efi/efivars
echo '
***
Done. 
***'
sleep 5
clear

echo "Overwriting disk with random data for 10 seconds..."
sleep 5
timeout 10s dd if=/dev/urandom of=/dev/sda bs=1M status=progress
lsblk
echo '
***
Done. 
***'
sleep 5
clear

echo "Fdisk partitioning: creates a 1G EFI partition and the rest is for the LUKS partition..."
sleep 5
(
  echo g;
  echo n;
  echo ;
  echo ;
  echo +1G;
  echo n;
  echo ;
  echo ;
  echo ;
  echo t;
  echo 1;
  echo 1;
  echo w;
) | fdisk /dev/sda

clear
lsblk
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up encryption..."
sleep 5
cryptsetup luksFormat --type luks2 /dev/sda2
cryptsetup luksOpen --persistent --allow-discards /dev/sda2 voidvm
vgcreate voidvm /dev/mapper/voidvm
lvcreate -L 150G voidvm -n root
lvcreate -l 100%FREE voidvm -n home
lsblk
echo '
***
Done. 
***'
sleep 5
clear

echo "Creating filesystems..."
sleep 5
mkfs.ext4 -L root /dev/voidvm/root
mkfs.ext4 -L home /dev/voidvm/home
mkfs.vfat /dev/sda1
echo '
***
Done. 
***'
sleep 5
clear

echo "Mounting partitions..."
sleep 5
mount /dev/voidvm/root /mnt
mkdir -p /mnt/home
mount /dev/voidvm/home /mnt/home
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
clear
lsblk
echo '
***
Done. 
***'
sleep 5
clear

echo "Copy the RSA keys from the installation medium to the target root directory..."
sleep 5
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
echo '
***
Done. 
***'
sleep 5
clear

echo "Installing the base system..."
sleep 5
x86_64 xbps-install -Sfy -R https://repo-default.voidlinux.org/current -r /mnt base-system cryptsetup limine lvm2 nano git
echo '
***
Done. 
***'
sleep 5
clear

echo "Generating fstab..."
sleep 5
xgenfstab -U /mnt > /mnt/etc/fstab
cat /mnt/etc/fstab
echo '
***
Done. 
***'
sleep 8
clear

echo "Chrooting into the system..."
sleep 5
xchroot /mnt <<END

echo "Setting up root permissions..."
sleep 5
chown root:root /
chmod 755 /
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up the hostname..."
sleep 5
echo voidvm > /etc/hostname
cat /etc/hostname
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up system locale and timezone..."
sleep 5
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
echo "KEYMAP=hu" > /etc/vconsole.conf
xbps-reconfigure -f glibc-locales
ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
echo '
***
Done. 
***'
sleep 5
clear

echo "Limine configuration..."
sleep 5
cd /boot
mkdir -p EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI EFI/BOOT/
echo "timeout: 3" > EFI/BOOT/limine.conf
echo "editor_enabled: no" >> EFI/BOOT/limine.conf
echo "/VOID ($(uname -r | sed 's/.\{5\}$//'))" >> EFI/BOOT/limine.conf
echo "   protocol: linux" >> EFI/BOOT/limine.conf
echo "   kernel_path: boot():/vmlinuz" >> EFI/BOOT/limine.conf
echo "   module_path: boot():/initramfs" >> EFI/BOOT/limine.conf
echo "   cmdline: rd.lvm.vg=voidvm root=/dev/voidvm/root rd.luks.uuid=$(blkid -o value -s UUID /dev/sda2) rw nowatchdog loglevel=4" >> EFI/BOOT/limine.conf
ls >> EFI/BOOT/limine.conf
cd ~
echo '
***
Done. 
***'
sleep 5
clear

END
clear
echo '





'
echo "Go back to chroot! Change root password! 'chown root:root /'! 'chmod 755 /'! Edit /boot/EFI/BOOT/limine.conf'! /etc/fstab! 'xbps-reconfigure -fa'"
