#!/bin/bash

echo "LUKS key setup..."
dd bs=1 count=64 if=/dev/urandom of=/boot/volume.key
cryptsetup luksAddKey /dev/sda2 /boot/volume.key
chmod 000 /boot/volume.key
chmod -R g-rwx,o-rwx /boot
echo "voidvm  /dev/sda2  /boot/volume.key  luks" >> /etc/crypttab
echo 'install_items+=" /boot/volume.key /etc/crypttab "' > /etc/dracut.conf.d/10-crypt.conf
cat /etc/crypttab
sleep 3
cat /etc/dracut.conf.d/10-crypt.conf
echo '
***
Done. 
***'
sleep 8
clear

#echo "Setting up a swap file..."
#sleep 5
#dd if=/dev/zero of=/swapfile bs=1M count=8192
#chmod 600 /swapfile
#mkswap /swapfile
#swapon /swapfile
#echo "/swapfile none swap sw 0 0" >> /etc/fstab
#cat /etc/fstab
#swapon --show
#echo '
#***
#Done. 
#***'
#sleep 5
#clear

echo "Installing man stuff..."
sleep 5
xbps-install -Sy man-db tldr
tldr --update
echo '
***
Done. 
***'
sleep 5
clear

echo "Installing microcode..."
sleep 5
xbps-install -Sy void-repo-nonfree
xbps-install -Sy intel-ucode
xbps-reconfigure -fa
echo '
***
Done. 
***'
sleep 5
clear

echo "Adding a user..."
sleep 5
useradd -m balogh
passwd balogh
usermod -aG wheel,audio,video,network,storage balogh
id balogh
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up logging..."
sleep 5
xbps-install -Sy socklog-void
ln -s /etc/sv/socklog-unix /var/service
ln -s /etc/sv/nanoklogd /var/service
usermod -aG socklog balogh
id balogh
ls /var/service
echo '
***
Done. 
***'
sleep 5
clear

echo "Changing rc.conf and sshd_config files..."
sleep 5
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "CGROUP_MODE=unified" >> /etc/rc.conf
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up fstrim..."
lsblk --discard
sleep 5
xbps-install -Sy cronie
ln -s /etc/sv/cronie /var/service
cat << EOF | sudo tee /etc/cron.weekly/fstrim
#!/bin/bash

fstrim /
EOF

chmod u+x /etc/cron.weekly/fstrim
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up apparmor..."
sleep 5
xbps-install -Sy apparmor
echo '
***
Done. 
***'
sleep 5
clear

echo "Installing chrony..."
sleep 5
xbps-install -Sy chrony
ln -s /etc/sv/chronyd /var/service
ls /var/service
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up acpid..."
sleep 5
xbps-install -Sfy acpid
ln -s /etc/sv/acpid /var/service
ls /var/service
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up nftables..."
sleep 5
xbps-install -Sy nftables runit-nftables
ln -s /etc/sv/nftables /var/service
cat << EOF | sudo tee /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority 0;
		policy drop;
		iif lo accept
		ct state established,related accept
		ct state invalid drop
		# Allow DHCP requests and responses
		udp sport 67 udp dport 68 accept
		udp sport 68 udp dport 67 accept
		ip protocol icmp accept
		ip6 nexthdr icmpv6 accept
		# Limit the rate of new connection attempts to any port
		ct state new limit rate over 25/second burst 50 packets drop
		udp dport { 3478, 3479, 19302-19309, 10000-20000 } accept
		log prefix "nftables-dropped: " level info limit rate 5/minute
	}
	chain forward {
		type filter hook forward priority 0;
		policy drop;
	}
	chain output {
		type filter hook output priority 0;
		policy accept;
	}
}
EOF
nft -f /etc/nftables.conf
nft list ruleset
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up sysctl parameters..."
sleep 5
cat << EOF | sudo tee /etc/sysctl.conf
# See sysctl.conf(5)
# Do not act as a router
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
# SYN flood protection
net.ipv4.tcp_syncookies = 1
# Disable ICMP redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

fs.protected_fifos = 2
fs.protected_regular = 2

kernel.kptr_restrict = 2
kernel.sysrq = 0

net.ipv4.conf.all.rp_filter = 1

net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

net.ipv4.conf.default.accept_source_route = 0

net.core.bpf_jit_harden = 2


fs.suid_dumpable = 0
EOF
sysctl --system
echo '
***
Done. 
***'
sleep 5
clear

echo "Installing clamav, rkhunter, btop, htop, bat..."
sleep 5
xbps-install -Sfy clamav rkhunter btop htop bat wget
freshclam
cat << EOF | sudo tee -a /etc/rkhunter.conf
SCRIPTWHITELIST=/usr/bin/egrep
SCRIPTWHITELIST=/usr/bin/fgrep
SCRIPTWHITELIST=/usr/bin/ldd

WEB_CMD=wget
EOF
rkhunter --config-check
rkhunter --update
echo '
***
Done. 
***'
sleep 5
clear

echo "Setting up graphical session (Intel)..."
sleep 5
xbps-install -Sfy mesa-dri xorg-minimal vulkan-loader mesa-vulkan-intel intel-video-accel
echo '
***
Done. 
***'
sleep 5
clear

echo "Installing fonts and icon themes..."
sleep 5
xbps-install -Sfy dejavu-fonts-ttf noto-fonts-ttf nerd-fonts adwaita-icon-theme papirus-icon-theme
echo '
***
Done. 
***'
sleep 5
clear

echo "Installing Desktop portals and KDE Plasma..."
sleep 5
xbps-install -Sfy xdg-desktop-portal xdg-desktop-portal-kde dbus kde-plasma sddm kate konsole dolphin firefox
ln -s /etc/sv/sddm /var/service
echo '
***
Done. 
***'
sleep 5
clear

echo "Installing Pipewire..."
sleep 5
xbps-install -Sfy alsa-utils pipewire wireplumber pavucontrol alsa-pipewire
mkdir -p /etc/pipewire/pipewire.conf.d
ln -s /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
ln -s /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
mkdir -p /etc/alsa/conf.d
ln -s /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d
ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d
echo '
***
Done. 
***'
sleep 5
xbps-reconfigure -fa
clear
echo "Check /etc/default/grub (apparmor=1 security=apparmor) and /etc/default/apparmor! Then 'update-grub'! Finally, enable dbus"
