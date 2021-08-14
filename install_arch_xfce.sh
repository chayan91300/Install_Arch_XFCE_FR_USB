#!/bin/bash
#-*- coding: UTF8 -*-

#--------------------------------------------------#
# Script_Name: install_arch_xfce.sh	                               
#                                                   
# Author:  'dossantosjdf@gmail.com'                 
# Date: dim. 08 août 2021 04:29:15                                             
# Version: 1.0                                      
# Bash_Version: 5.0.17(1)-release                                     
#--------------------------------------------------#
# Description:                                      
#                                                   
#                                                   
# Options:                                          
#                                                   
# Usage: ./install_arch_xfce.sh                                            
#                                                   
# Limits:                                           
#                                                   
# Licence:                                          
#--------------------------------------------------#

set -eu

### Includes ###

### Constants ###

### Fonctions ###

usage() {
  cat << EOF
  
  ___ Script : $(basename "${0}") ___
  
  Le script doit être lancé en tant que root.
  
  Rôle:                                          

  Détail des fonctionnalités :

  Usage:
  ./$(basename "${0}") -[h|v]
  
  ./$(basename "${0}") -d <disque>:<passe chiffrement> -u <nom utilisateur>:<pass utilisateur> -n <hostname>
  
  -h : Affiche cette page.
  -v : Affiche la version.
  
  -n : Nom de la machine.
  -u : Nom utilisateur suivie du mot de passe utilisateur.  Ex: (daniel:****)
  -d : Nom du disque suivie sa passe phrase de chiffrement. Ex: (sda:***************)
  
  Exemples:
  * Pour Installer Arch Linux sur un périphérique physique (hd, ssd, usb):
  sudo "${0}" -d sdb:*************** -u daniel:******** -n Arch
  
EOF
}

version() {
  local ver='1'
  local dat='08/08/21'
  cat << EOF
  
  ___ Script : $(basename "${0}") ___
  
  Version : "${ver}"
  Date : "${dat}"
  
EOF
}

check_disk_name() {
  readonly regex="^[s][d][a-z]$"

  if [[ $disk_name =~ ${regex} ]]
  then
    echo "Disque : /dev/${disk_name}"
  else
    echo "Erreur de saisie !"
    exit 1
  fi
}


installer_conf_timedate() {

timedatectl set-ntp true


}

installer_locale_keyboard() {

# Lang installer
loadkeys fr-pc

sed -i.bak 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen

locale-gen

# Lang system 
sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

echo 'LANG=fr_FR.UTF-8' >> /mnt/etc/locale.conf
echo 'LANGUAGE=fr_FR' >> /mnt/etc/locale.conf
echo 'LC_ALL=C' >> /mnt/etc/locale.conf


echo 'KEYMAP=fr-pc' > /mnt/etc/vconsole.conf

export LANG=fr_FR.UTF-8


} 


system_conf_timedate() {

# Config time zone system
arch-chroot /mnt timedatectl set-timezone Europe/Paris

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime


arch-chroot /mnt hwclock --systohc --utc
}


system_locale_keyboard() {




}


system_partition() {

# Creating Partitions
# Clean and create GPT table
sgdisk --zap-all /dev/"${disk_name}"
sgdisk --clear /dev/"${disk_name}"
sgdisk --verify /dev/"${disk_name}"

# Partition 1 10Mb BIOS Boot
sgdisk --new=1::+10M /dev/"${disk_name}"
sgdisk --typecode=1:ef02 /dev/"${disk_name}"

# Partition 2 250Mb EFI FAT32
sgdisk --new=2::+250M /dev/"${disk_name}"
sgdisk --typecode=2:ef00 /dev/"${disk_name}"

# Partition 3 EXT4
sgdisk --largest-new=3 /dev/"${disk_name}"

# Create a crypted partition
echo "$disk_pass" | cryptsetup -q luksFormat /dev/"${disk_name}"3

# Unlock partition
echo "$disk_pass" | cryptsetup -q open /dev/"${disk_name}"3 cryptroot

# Format crypted partition
# "^has_journal" desable journalizing system
mkfs.ext4 -O "^has_journal" /dev/mapper/cryptroot

# Format partition 2 EFI
mkfs.fat -F32 /dev/"${disk_name}"2

# Mount partitions 2 and 3
mount /dev/mapper/cryptroot /mnt

mkdir /mnt/boot && mount /dev/"${disk_name}"2 /mnt/boot


# Apply partition table configs in fstab
genfstab -U /mnt >> /mnt/etc/fstab

}


system_install_base() {

# System install and dependances
pacstrap /mnt base linux linux-firmware base-devel alsa-utils pacman-contrib grub

}


system_install_video() {


}


system_install_audio() {



}


system_install_other() {



}


system_network() {

# Network config
echo "$host_name" > /mnt/etc/hostname

cat <<EOF>> /mnt/etc/hosts
 
127.0.0.1       localhost
::1             localhost
127.0.1.1       ${host_name}.lan        $host_name
EOF

pacstrap /mnt metworkmanager

# Enable systemd services (NetworkManager and SSHD)
arch-chroot /mnt systemctl enable {NetworkManager,sshd}

# Systemd enable cups,ntpd
arch-chroot /mnt systemctl enable {cups,ntpd} && echo "Réussie" || echo "échec"

}


system_grub_config() {

# Install and config Grub
arch-chroot /mnt grub-install --target=i386-pc --boot-directory=/boot /dev/"${disk_name}"

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --boot-directory=/boot --removable --recheck

# UUID of crypted partition 
uuid_part3=$(blkid /dev/"${disk_name}"3 -s UUID -o value)

# Config to Grub boot with crypted partition 
sed -i.bak "s/loglevel=3 quiet/loglevel=3 quiet cryptdevice=UUID=${uuid_part3}:cryptroot root=\/dev\/mapper\/cryptroot/" /mnt/etc/default/grub

# Change Grub background
cp background.png /mnt/boot/grub/ || grub_background=false

$grub_background && sed -i 's/#GRUB_BACKGROUND="\/path\/to\/wallpaper"/GRUB_BACKGROUND="\/boot\/grub\/background.png"/' /mnt/etc/default/grub

# Update grub configs
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

}


system_user_conf() {

# Create new user
arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,scanner "$username_name"
arch-chroot /mnt bash -c "echo ${username_name}:${username_pass} | chpasswd"

# Config sudoers file
sed -i.bak 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers

# Check syntax
arch-chroot /mnt visudo --check

}


system_other_options() {

# No adapt to hardware the network interface name
arch-chroot /mnt ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules

#Systemdd journal in RAM
sed -i 's/#Storage=auto/Storage=volatile/' /mnt/etc/systemd/journald.conf

# no Overfill RAM systemd limit to 50M
sed -i 's/#RuntimeMaxUse=/RuntimeMaxUse=50M/' /mnt/etc/systemd/journald.conf

# Netbook pad support
pacstrap /mnt xf86-input-synaptics

# Battery stats support
pacstrap /mnt acpi

pacstrap /mnt systemctl enable acpid

# Microcodes support
pacstrap /mnt amd-ucode   # CPU AMD
pacstrap /mnt intel-ucode # CPU Intel

}


system_graphical_install() {

# Install Xorg and GPU support
pacstrap /mnt xorg xorg-drivers

# xfce and lightdm install
pacstrap /mnt xfce4 xfce4-goodies lightdm lightdm-{gtk-greeter,gtk-greeter-settings}

#Not work
# Xorg french config
arch-chroot /mnt localectl set-x11-keymap fr pc105  ##############################

# Systemd enable lightdm
arch-chroot /mnt systemctl enable lightdm && echo "Réussie" || echo "échec"

}


system_other_install() {

# Install others apps
pacstrap /mnt network-manager-applet leafpad capitaine-cursors arc-{gtk-theme,icon-theme} xdg-user-dirs-gtk git archlinux-wallpaper gnome-icon-theme-extras libreoffice-still-fr hunspell-fr firefox-{i18n-fr,ublock-origin} vlc ntp ffmpegthumbnailer vim nano openssh dosfstools ntfs-3g gvfs exfat-utils man-db man-pages man-pages-fr bash-completion

# Audio supports
pacstrap /mnt pulseaudio pavucontrol bluez pulseaudio-{alsa,bluetooth} alsa-utils blueman

# Printer supports
pacstrap /mnt foomatic-{db,db-ppds,db-gutenprint-ppds,db-nonfree,db-nonfree-ppds} gutenprint xsane system-config-printer

# Device use MTP
pacstrap /mnt gvfs-mtp mtpfs

# Fonts
pacstrap /mnt noto-fonts noto-fonts-{cjk,emoji,extra} ttf-{dejavu,roboto,ubuntu-font-family,bitstream-vera,liberation,arphic-uming,baekmuk} xorg-fonts-type1 sdl_ttf gsfonts

# Support 32 bits apps
sed -i.bak '/#\[multilib\]/,/#Include/ s/#//' /mnt/etc/pacman.conf

}


conf_ramfs() {

# Config mkinitcpio HOOKS
sed -i.bak 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev block keyboard keymap encrypt filesystems fsck)/g' /mnt/etc/mkinitcpio.conf

arch-chroot /mnt mkinitcpio -p linux

}

#### Main ####

# User
user_pass=''

# Disque name and crypt pass
disk_crypt=''

# Hostname and root pass
host_name=''

# Grub
grub_background=''


if [[ $(id -u) -ne 0 ]]
then
  echo "Le script doit être lancé en tant que root"
  usage
  exit 1
fi


while getopts "hvd:u:n:" argument
do
  case "${argument}" in
    h)
      usage
      exit 1
      ;;
    v)
      version
      exit 1
      ;;
    d)
      readonly disk_crypt="${OPTARG}"
      ;;
    u)
      readonly user_pass="${OPTARG:=userx:usertemppass}"
      ;;
    n)
      readonly host_name="${OPTARG:=Arch}"
      ;;      
    :)
      echo "L'option nécessite un argument."
      usage
      exit 1
      ;;
    \?)
      echo "Option invalide !"
      usage
      exit 1
      ;;
    *)
      exit 1
      ;;
  esac
done


# User
username_name="$(echo "$user_pass" | cut -d: -f1)"
username_pass="$(echo "$user_pass" | cut -d: -f2)"

# Disque name and crypt pass
disk_name="$(echo "$disk_crypt" | cut -d: -f1)"
disk_pass="$(echo "$disk_crypt" | cut -d: -f2)"


# Exit install
umount --recursive /mnt && shutdown now