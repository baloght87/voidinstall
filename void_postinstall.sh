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

echo "#######  Continue Void documentation from 'Network' section #####"
