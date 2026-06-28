#!/bin/bash

echo "Installing man stuff..."
sleep 5
xbps-install -Sfy man-db man-pages tldr
tldr --update
echo '
***
Done. 
***'
clear

