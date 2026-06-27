#!/bin/bash

cp /home/balogh/Documents/kulon_orarend_lib.ods /mnt/usb/Utolso_modositas_wo_mentett/Home_dok/
cp /home/balogh/Documents/Hataridok.txt /mnt/usb/Utolso_modositas_wo_mentett/Home_dok/
cp /home/balogh/Documents/talajminta.kdbx /mnt/usb/Utolso_modositas_wo_mentett/Home_dok/
echo "Utolsó gyors mentés ideje:" > /mnt/usb/Utolso_modositas_wo_mentett/mentes_idopontja.txt
echo "$(date)" >> /mnt/usb/Utolso_modositas_wo_mentett/mentes_idopontja.txt
echo "Fast save completed!"
