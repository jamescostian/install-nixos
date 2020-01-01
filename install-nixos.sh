#!/usr/bin/env bash
#  _____ _               _        
# /  __ \ |             | |       
# | /  \/ |__   ___  ___| | _____ 
# | |   | '_ \ / _ \/ __| |/ / __|
# | \__/\ | | |  __/ (__|   <\__ \
#  \____/_| |_|\___|\___|_|\_\___/

if ! efibootmgr > /dev/null; then
	echo "Your machine does not have EFI on right now! I cannot proceed."
	echo "You may want to try turning off CSM in your BIOS"
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR! You must run this as root!"
  exit 2
fi

while true; do
	curl -sS 1.1.1.1 > /dev/null && break
	read -p "Connect to internet (WiFi control is in the bottom right), then press ENTER "
done

# ______ _     _      _____                 _   _                 
# |  _  (_)   | |    |  _  |               | | (_)                
# | | | |_ ___| | __ | | | |_   _  ___  ___| |_ _  ___  _ __  ___ 
# | | | | / __| |/ / | | | | | | |/ _ \/ __| __| |/ _ \| '_ \/ __|
# | |/ /| \__ \   <  \ \/' / |_| |  __/\__ \ |_| | (_) | | | \__ \
# |___/ |_|___/_|\_\  \_/\_\\__,_|\___||___/\__|_|\___/|_| |_|___/

while true; do
	if [[ "$(lsblk -e1,7 --noheadings | wc -l)" == "1" ]]; then
		DEVICE="$(lsblk -e1,7 --noheadings --output=NAME)"
		break
	elif [[ "$(lsblk -e1,7 --noheadings --nodeps | wc -l)" == "1" ]]; then
		echo "There's only 1 device to install to (/dev/$(lsblk -e1,7 --noheadings --nodeps))."
		echo "But that device has partitions on it (and probably some files too!)."
		echo "If you proceed, those files will all be gone FOREVER!"
		DEVICE="$(lsblk -e1,7 --noheadings --nodeps)"
		break
	else
		echo "Which device would you like to install to?"
		echo
		lsblk -e1,7 --nodeps --noheadings --output="NAME,SIZE" | awk '{print $1 "\t\t(" $2 ")" }' 
		echo
		read -p "Type the name: " DEVICE
		if lsblk -e1,7 --nodeps --noheadings --output="NAME" | grep $DEVICE > /dev/null; then
			if [[ "$(lsblk -e1,7 /dev/$DEVICE --noheadings | wc -l)" == "1" ]]; then
				break
			else
				echo "That device already has partitions! There may be files on them!"
				echo "If you proceed, those files will all be gone FOREVER!"
				break
			fi
		else
			echo "I can't find that device. Did you mistype it?"
			echo "Please type it correctly, and don't include the size in parenthesis at the end"
		fi
	fi
done
DEVICE="/dev/$DEVICE"

while true; do
	echo -e "\nWhen Linux runs out of RAM, everything goes to shit."
	echo "Swap (using another device as extra ram) helps avoid that catastrophe."
	# TODO: Should I tell them the truth? Do people even know what a gibibyte is?
	read -p "How many gigabytes of swap do you want? (e.g. 1) " SWAP_SIZE
	
	if [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
		break
	else
		echo "Invalid swap size!"
	fi
done
if [[ "$SWAP_SIZE" == "0" ]]; then
	echo "Invalid - I'll give you 1GiB of swap"
	SWAP_SIZE="1G"
else
	SWAP_SIZE="$SWAP_SIZE"'G'
fi

if [[ "$DEVICE" == "/dev/nvme"* ]]; then
	PARTITION="$DEVICE"p
else
	PARTITION="$DEVICE"
fi

echo -e "\nDo you want full-disk encryption? On the downside, it requires you to type a"
echo "separate password every time you turn on your computer in order to decrypt it"
echo "but in exchange for the hassle it can keep you safe from attackers."
read -p "Would you like full-disk encryption? (y/n) " -n 1 ENABLE_ENCRYPTION
if [[ "$ENABLE_ENCRYPTION" == "y" || "$ENABLE_ENCRYPTION" == "Y" ]]; then
	export ENABLE_ENCRYPTION="y" # Custom scripts can just read this and check if it's set to "y"
	echo -e "\nGreat! I'll let you type in a password - it won't show up on the screen."
	while true; do
		read -sp "Enter the password you want to type when turning on your machine: " ENCRYPTION_PASSWORD
		echo
		read -sp "Now enter it one more time, just in case you made a typo: " ENCRYPTION_PASSWORD_CONFIRMATION
		echo
		if [[ "$ENCRYPTION_PASSWORD_CONFIRMATION" == "$ENCRYPTION_PASSWORD" ]]; then
			break;
		else
			echo -e "INCORRECT! You typed in 2 different passwords! Make up your mind!\n"
		fi
	done
fi

echo -e "\nOk, I will install to $DEVICE with a swap size of $SWAP_SIZE"iB
echo "WARNING: THIS WILL WIPE EVERYTHING ON $DEVICE"
read -p "Are you sure about this? Press Ctrl+C to cancel or ENTER to continue "

#  _____                _        ______          _   _ _   _                 
# /  __ \              | |       | ___ \        | | (_) | (_)                
# | /  \/_ __ ___  __ _| |_ ___  | |_/ /_ _ _ __| |_ _| |_ _  ___  _ __  ___ 
# | |   | '__/ _ \/ _` | __/ _ \ |  __/ _` | '__| __| | __| |/ _ \| '_ \/ __|
# | \__/\ | |  __/ (_| | ||  __/ | | | (_| | |  | |_| | |_| | (_) | | | \__ \
#  \____/_|  \___|\__,_|\__\___| \_|  \__,_|_|   \__|_|\__|_|\___/|_| |_|___/

# If they already attempted an installation, they may have mounted some partitions - unmount them in order to be able to partition the drive!
umount -q /mnt/boot 2> /dev/null
umount -q /mnt 2> /dev/null
# Delete any previous partitions
if [[ ! -z "$(parted $DEVICE -- print | awk '/^ / {print $1}')" ]]; then
	for part in $(parted $DEVICE -- print | awk '/^ / {print $1}'); do
		parted $DEVICE -- rm $part 2> /dev/null
	done
fi
# Use GPT
yes | parted $DEVICE -- mklabel gpt > /dev/null  2> /dev/null
# Actually create the partitions
if [[ -z "$ENCRYPTION_PASSWORD" ]]; then
	# No encryption password - make a plain data partition and a swap partition
	parted $DEVICE -- mkpart primary 512MiB -"$SWAP_SIZE"iB > /dev/null 2> /dev/null
	yes ignore | parted $DEVICE -- mkpart primary linux-swap -"$SWAP_SIZE"iB 100% > /dev/null 2> /dev/null
	BOOT_PARTITION_NUM=3
else
	# Encryption was requested - don't make a normal swap partition, make it inside of LUKS
	parted $DEVICE -- mkpart primary 512MiB 100% > /dev/null 2> /dev/null
	parted $DEVICE -- set 1 lvm on 2> /dev/null
	BOOT_PARTITION_NUM=2
fi
parted $DEVICE -- mkpart ESP fat32 1MiB 512MiB > /dev/null 2> /dev/null
parted $DEVICE -- set $BOOT_PARTITION_NUM boot on > /dev/null 2> /dev/null

#  _____                _        ______ _ _                     _                     
# /  __ \              | |       |  ___(_) |                   | |                    
# | /  \/_ __ ___  __ _| |_ ___  | |_   _| | ___  ___ _   _ ___| |_ ___ _ __ ___  ___ 
# | |   | '__/ _ \/ _` | __/ _ \ |  _| | | |/ _ \/ __| | | / __| __/ _ \ '_ ` _ \/ __|
# | \__/\ | |  __/ (_| | ||  __/ | |   | | |  __/\__ \ |_| \__ \ ||  __/ | | | | \__ \
#  \____/_|  \___|\__,_|\__\___| \_|   |_|_|\___||___/\__, |___/\__\___|_| |_| |_|___/
#                                                      __/ |                          
#                                                     |___/                           
if [[ ! -z "$ENCRYPTION_PASSWORD" ]]; then
	# First, make the luks container
	echo -n $ENCRYPTION_PASSWORD | cryptsetup luksFormat "$PARTITION"1 - 2> /dev/null
	echo -n $ENCRYPTION_PASSWORD | cryptsetup luksOpen "$PARTITION"1 nixos-luks - 2> /dev/null
	# Next, setup LVM within it
	pvcreate /dev/mapper/nixos-luks 2> /dev/null
	vgcreate nixos-lvm /dev/mapper/nixos-luks 2> /dev/null
	lvcreate -L "$SWAP_SIZE" -n swap nixos-lvm 2> /dev/null
	lvcreate -l 100%FREE -n nixos nixos-lvm 2> /dev/null
	mkfs.ext4 -L nixos /dev/nixos-lvm/nixos > /dev/null
	mkswap -L swap /dev/nixos-lvm/swap > /dev/null
else
	mkfs.ext4 -L nixos "$PARTITION"1 > /dev/null
	mkswap -L swap "$PARTITION"2 > /dev/null
fi
mkfs.fat -F 32 -n boot "$PARTITION$BOOT_PARTITION_NUM" > /dev/null

# ___  ___                  _   
# |  \/  |                 | |  
# | .  . | ___  _   _ _ __ | |_ 
# | |\/| |/ _ \| | | | '_ \| __|
# | |  | | (_) | |_| | | | | |_ 
# \_|  |_/\___/ \__,_|_| |_|\__|

set -e
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/disk/by-label/swap

#  _   _ _      _____ _____   _____              __ _       
# | \ | (_)    |  _  /  ___| /  __ \            / _(_)      
# |  \| |___  _| | | \ `--.  | /  \/ ___  _ __ | |_ _  __ _ 
# | . ` | \ \/ / | | |`--. \ | |    / _ \| '_ \|  _| |/ _` |
# | |\  | |>  <\ \_/ /\__/ / | \__/\ (_) | | | | | | | (_| |
# \_| \_/_/_/\_\\___/\____/   \____/\___/|_| |_|_| |_|\__, |
#                                                      __/ |
#                                                     |___/ 
nixos-generate-config --root /mnt
set +e

echo -e "\n\n\nThe informational and warning messages above can be ignored safely."
CLONED_FROM_DOTFILES=false
while true; do
	read -p "Would you like to clone a NixOS configuration from git? (y/n) " -n 1 EXISTING
	echo
	if [[ "$EXISTING" == "y" || "$EXISTING" == "Y" || "$EXISTING" == "yes" ]]; then
		echo "I need a URL to clone - everything in it will be moved to /mnt/etc/nixos"
		echo "and /mnt/etc/nixos will become /etc/nixos after this installation is done."
		echo "Please provide a URL for git-clone. There are shorthands for popular hosts:"
		echo "  gh:user/repo  ->  https://github.com/user/repo.git"
		echo "  gl:user/repo  ->  https://gitlab.com/user/repo.git"
		echo
		echo "You need a configuration.nix file checked into that repo for this to work."
		echo "Alternatively, if you have an etc/nixos folder or nixos folder in your root,"
		echo "then the files in that folder will be used instead"
		echo "If you don't have one, hit ENTER without typing anything else."
		echo "Otherwise, type the git URL below:"
		read -p "" GIT_URL
		if [[ "$GIT_URL" == "gh:"* ]]; then
			GIT_URL="$(echo $GIT_URL | sed 's~^gh:~https://github.com/~')"'.git'
		elif [[ "$GIT_URL" == "gl:"* ]]; then
			GIT_URL="$(echo $GIT_URL | sed 's~^gl:~https://gitlab.com/~')"'.git'
		fi
		cd /mnt/etc/nixos
		echo "Loading..."
		nix-env -i "$(nix-env -qa git | head -1)"
		git clone $GIT_URL cloned_dotfiles
		if [[ "$?" != "0" ]]; then
			echo "ERROR CLONING! Did you get the right URL?" echo "Did you have the right authentication?"
			continue
		fi
		mv configuration.nix default-configuration.nix
		cd cloned_dotfiles
		if [[ -d etc/nixos ]]; then
			cd etc/nixos
		elif [[ -d nixos ]]; then
			cd nixos
		fi
		find . -type d -exec mkdir -p /mnt/etc/nixos/{} \; # Recreate directory structure
		find . -type f -exec cp -i {} /mnt/etc/nixos/{} \; # Copy files from this directory to /mnt/etc/nixos
		rm -Rf /mnt/etc/nixos/cloned_dotfiles # Delete the originally cloned stuff; you can clone it again later on if you want
		CLONED_FROM_DOTFILES=true
		echo -e "\n\nDone cloning"
		cd /mnt/etc/nixos
		if [[ -f /mnt/etc/nixos/setup.sh ]] || [[ -f /mnt/etc/nixos/setup ]]; then
			echo "Running your setup script..."
			export RUNNING_FROM_NIXOS_INSTALLER=true
			if [[ -f /mnt/etc/nixos/setup.sh ]]; then
				/mnt/etc/nixos/setup.sh
			else
				/mnt/etc/nixos/setup
			fi
		fi
		echo
		echo
		break
	else
		break
	fi
done

if [[ "$ENABLE_ENCRYPTION" == "y" ]]; then
	sed -i '/^}\s*$/,$d' /mnt/etc/nixos/configuration.nix
	ENCRYPTED_UUID=$(lsblk --output=UUID --noheadings /dev/disk/by-label/nixos)
	echo "  boot.initrd.luks.devices = [{" >> /mnt/etc/nixos/configuration.nix
	echo "    name = \"nixos\";" >> /mnt/etc/nixos/configuration.nix
	echo "    device = \"/dev/disk/by-uuid/$ENCRYPTED_UUID\";" >> /mnt/etc/nixos/configuration.nix
	echo "    preLVM = true;" >> /mnt/etc/nixos/configuration.nix
	echo "  }];" >> /mnt/etc/nixos/configuration.nix
	echo "}" >> /mnt/etc/nixos/configuration.nix
fi


echo -e "\n\n\nYou may want to adjust the configuration in /mnt/etc/nixos - if you know what"
read -p "you're doing. When you are ready, press ENTER to install from the configuration"

if nixos-install; then
	echo -e "\n\n"
	read -p "Remove the installation media (USB, CD, etc) and then hit ENTER to reboot"
	reboot
else
	echo -e "\nnixos-install exited with an error code. Check its output above!"
	echo "If you think it's safe, reboot. If not, figure it out!"
fi
