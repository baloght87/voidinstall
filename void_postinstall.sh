#!/bin/bash

echo "Installing man stuff..."
sleep 5
xbps-install -Sy man-db tldr
tldr --update
echo '
***
Done. 
***'
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
clear

echo "Adding a user..."
sleep 5
useradd -m balogh
passwd balogh
usermod -aG wheel,audio,video,network,storage balogh
id balogh
sleep 5
echo '
***
Done. 
***'

echo "Setting up logging..."
sleep 5
xbps-install -Sy socklog-void
ln -s /etc/sv/socklog-unix /var/service
ln -s /etc/sv/nanoklogd /var/service
usermod -aG socklog balogh
id balogh
ls /var/service
sleep 5
echo '
***
Done. 
***'

echo "Installing chrony..."
sleep 5
xbps-install -Sy chrony
ln -s /etc/sv/chronyd /var/service
ls /var/service
sleep 5
echo '
***
Done. 
***'

echo "Setting up acpid..."
sleep 5
xbps-install -Sfy acpid
ln -s /etc/sv/acpid /var/service
ls /var/service
sleep 5
echo '
***
Done. 
***'
#######  Continue Void documentation from "Network" section #####
