#!/usr/bin/env bash

sudo umount /mnt/usb
sudo cryptsetup close cryptusb
lsblk
