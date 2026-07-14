#!/usr/bin/env bash
lsblk
sudo cryptsetup open /dev/sda cryptusb
sudo mount /dev/mapper/cryptusb /mnt/usb
lsblk
