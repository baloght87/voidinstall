#!/bin/bash

echo "Setting up Hungarian keymap..."
sleep 5
loadkeys hu
clear

echo "Checking efivars..."
sleep 5
ls /sys/firmware/efi/efivars
sleep 5
clear

echo "Setting up timedatectl..."
sleep 5
timedatectl set-timezone Europe/Budapest
timedatectl set-ntp true
timedatectl
sleep 5
clear

echo "Overwriting disk with random data for 10 seconds..."
sleep 5
timeout 10s dd if=/dev/urandom of=/dev/sda bs=1M status=progress
lsblk
sleep 5
clear

echo "Fdisk partitioning: creates an 800M EFI partition and the rest is for the LUKS partition..."
sleep 5
(
  echo g;
  echo n;
  echo ;
  echo ;
  echo +800M;
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
sleep 5
clear

echo "Setting up encryption..."
sleep 5
cryptsetup luksFormat --type luks2 /dev/sda2
cryptsetup open /dev/sda2 cryptlvm
pvcreate /dev/mapper/cryptlvm
vgcreate archvolume /dev/mapper/cryptlvm
lvcreate -L 60G archvolume -n root
lvcreate -L 100G archvolume -n home
lvcreate -l 100%FREE archvolume -n backup
lsblk
sleep 5
clear

echo "Creating filesystems..."
sleep 5
mkfs.ext4 /dev/archvolume/root
mkfs.ext4 /dev/archvolume/home
mkfs.ext4 /dev/archvolume/backup
mkfs.fat -F 32 /dev/sda1
sleep 5
clear

echo "Mounting partitions..."
sleep 5
mount /dev/archvolume/root /mnt
mkdir /mnt/{boot,home,backup}
mount /dev/sda1 /mnt/boot
mount /dev/archvolume/home /mnt/home
mount /dev/archvolume/backup /mnt/backup
clear
lsblk
sleep 5
clear

echo "Setting up reflector..."
sleep 5
reflector --country Hungary --sort rate --save /etc/pacman.d/mirrorlist
cat /etc/pacman.d/mirrorlist
sleep 5
clear

echo "Installing the fundamentals..."
sleep 5
pacstrap -K /mnt base linux linux-firmware nano vim intel-ucode sof-firmware lvm2 networkmanager network-manager-applet sudo systemd reflector cryptsetup
sleep 5
clear

echo "Generating fstab..."
sleep 5
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
sleep 5
clear

echo "Chrooting into the system..."
sleep 5
arch-chroot /mnt /bin/bash <<END
clear

echo "Modifying fstab..."
sleep 5
sed -i 's/fmask=0022/fmask=0137/g' /etc/fstab
sed -i 's/dmask=0022/dmask=0027/g' /etc/fstab
cat /etc/fstab
sleep 5
clear

echo "Setting up the timezone..."
sleep 5
ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
hwclock --systohc
clear

echo "Setting up locales..."
sleep 5
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
sed -i 's/#hu_HU.UTF-8 UTF-8/hu_HU.UTF-8 UTF-8/g' /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=hu" > /etc/vconsole.conf
echo arch > /etc/hostname
echo "127.0.0.1		localhost" > /etc/hosts
echo "::1		      localhost" >> /etc/hosts
echo "127.0.1.1		arch.localdomain	arch" >> /etc/hosts
locale-gen
cat /etc/locale.conf
cat /etc/vconsole.conf
cat /etc/hostname
cat /etc/hosts
sleep 5
clear

echo "Modifying mkinitcpio.conf..."
sleep 5
sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt lvm2 filesystems fsck)/g' /etc/mkinitcpio.conf
cat /etc/mkinitcpio.conf
sleep 5
clear

echo "Installing systemd-boot..."
sleep 5
bootctl install

echo "default		arch.conf" > /boot/loader/loader.conf
echo "timeout		3" >> /boot/loader/loader.conf
echo "console-mode	keep" >> /boot/loader/loader.conf
echo "editor		no" >> /boot/loader/loader.conf

echo "title	Arch Linux" > /boot/loader/entries/arch.conf
echo "linux	/vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "initrd	/intel-ucode.img" >> /boot/loader/entries/arch.conf
echo "initrd	/initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "options	rd.luks.name=$(blkid -s UUID -o value /dev/sda2)=cryptlvm root=/dev/archvolume/root rw" >> /boot/loader/entries/arch.conf

mkinitcpio -P
clear
cat /boot/loader/loader.conf
sleep 3
cat /boot/loader/entries/arch.conf
sleep 3
clear

echo "Enabling services..."
sleep 5
systemctl enable systemd-boot-update
bootctl update
systemctl enable NetworkManager
clear

echo "Setting up a user..."
sleep 5
useradd -m balogh
usermod -aG wheel balogh
usermod -aG audio,video,input,storage,network balogh
id balogh
sleep 5
clear

echo "Creating zram..."
sleep 5
pacman -S --noconfirm zram-generator
mkdir -p /etc/systemd/zram-generator.conf.d
echo "[zram0]" > /etc/systemd/zram-generator.conf.d/zram.conf
echo "zram-size = ram / 2" >> /etc/systemd/zram-generator.conf.d/zram.conf
echo "compression-algorithm = zstd" >> /etc/systemd/zram-generator.conf.d/zram.conf
echo "swap-priority = 100" >> /etc/systemd/zram-generator.conf.d/zram.conf

systemctl daemon-reexec
systemctl start /dev/zram0
systemctl enable fstrim.timer
lsblk
sleep 5
clear

echo "Setting up Secure boot..."
sleep 5
pacman -S --noconfirm sbctl
clear
sbctl create-keys
sbctl enroll-keys --microsoft
sbctl enroll-keys --microsoft
sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
sbctl sign -s /boot/vmlinuz-linux
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sbctl verify
sleep 5
clear

mkdir -p /etc/pacman.d/hooks
echo "[Trigger]" > /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Type = Path" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Target = /boot/vmlinuz-linux" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Target = /boot/EFI/Linux/*.efi" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Target = /boot/EFI/systemd/*.efi" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Target = /boot/EFI/BOOT/*.EFI" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "[Action]" >> /etc/pacman.d/hooks/99-sbctl-sign.hook	
echo "Description = Signing kernels with sbctl..." >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "When = PostTransaction" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
echo "Exec = /usr/bin/sbctl sign-all" >> /etc/pacman.d/hooks/99-sbctl-sign.hook
clear
cat /etc/pacman.d/hooks/99-sbctl-sign.hook
sleep 5
mkinitcpio -P
sbctl verify
pacman -Syu
sbctl sign-all
sleep 5
clear

echo "Setting up kernel parameters..."
sleep 5

echo "# Do not act as a router" > /etc/sysctl.d/90-network.conf
echo "net.ipv4.ip_forward = 0" >> /etc/sysctl.d/90-network.conf
echo "net.ipv6.conf.all.forwarding = 0" >> /etc/sysctl.d/90-network.conf
echo "# SYN flood protection" >> /etc/sysctl.d/90-network.conf
echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.d/90-network.conf
echo "# Disable ICMP redirect" >> /etc/sysctl.d/90-network.conf
echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.d/90-network.conf
echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.d/90-network.conf
echo "net.ipv4.conf.all.secure_redirects = 0" >> /etc/sysctl.d/90-network.conf
echo "net.ipv4.conf.default.secure_redirects = 0" >> /etc/sysctl.d/90-network.conf
echo "net.ipv6.conf.all.accept_redirects = 0" >> /etc/sysctl.d/90-network.conf
echo "net.ipv6.conf.default.accept_redirects = 0" >> /etc/sysctl.d/90-network.conf
echo "# Do not send ICMP redirects" >> /etc/sysctl.d/90-network.conf
echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.d/90-network.conf
echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.d/90-network.conf

sysctl --system
sleep 5
clear
cat /etc/sysctl.d/90-network.conf
sleep 5
clear

mkinitcpio -P
END
clear
echo "Go back to chroot! Change root and balogh password! Visudo!"
echo "Reboot the system! Enable Secure boot in BIOS!"

