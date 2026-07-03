#!/bin/bash

clear
echo "Setting up a swap file..."
sleep 5
dd if=/dev/zero of=/swapfile bs=1M count=8192
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab
cat /etc/fstab
ls -l
echo '
***
Done. 
***'
sleep 5
clear

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
xbps-reconfigure -f intel-ucode
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

echo "Check /etc/default/grub and /etc/default/apparmor! Then 'update-grub'!"
echo "#######  Continue Void documentation from 'Graphics Drivers' section #####"
