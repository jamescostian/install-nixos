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
	echo
	echo "When Linux runs out of RAM, everything goes to shit."
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
	SWAP_SIZE="1GiB"
else
	SWAP_SIZE="$SWAP_SIZE"'GiB'
fi

if [[ "$DEVICE" == "/dev/nvme"* ]]; then
	PARTITION="$DEVICE"p
else
	PARTITION="$DEVICE"
fi

echo
echo "Ok, I will install to $DEVICE with a swap size of $SWAP_SIZE"
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
for part in $(parted $DEVICE -- print | awk '/^ / {print $1}'); do
	parted $DEVICE -- rm $part
done
yes | parted $DEVICE -- mklabel gpt > /dev/null
parted $DEVICE -- mkpart primary 512MiB -"$SWAP_SIZE" > /dev/null
yes ignore | parted $DEVICE -- mkpart primary linux-swap -"$SWAP_SIZE" 100% > /dev/null
parted $DEVICE -- mkpart ESP fat32 1MiB 512MiB > /dev/null
parted $DEVICE -- set 3 boot on > /dev/null

#  _____                _        ______ _ _                     _                     
# /  __ \              | |       |  ___(_) |                   | |                    
# | /  \/_ __ ___  __ _| |_ ___  | |_   _| | ___  ___ _   _ ___| |_ ___ _ __ ___  ___ 
# | |   | '__/ _ \/ _` | __/ _ \ |  _| | | |/ _ \/ __| | | / __| __/ _ \ '_ ` _ \/ __|
# | \__/\ | |  __/ (_| | ||  __/ | |   | | |  __/\__ \ |_| \__ \ ||  __/ | | | | \__ \
#  \____/_|  \___|\__,_|\__\___| \_|   |_|_|\___||___/\__, |___/\__\___|_| |_| |_|___/
#                                                      __/ |                          
#                                                     |___/                           
mkfs.ext4 -L nixos "$PARTITION"1 > /dev/null
mkswap -L swap "$PARTITION"2 > /dev/null
mkfs.fat -F 32 -n boot "$PARTITION"3 > /dev/null

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

echo
echo
echo
echo "The informational and warning messages above can be ignored safely."
CLONED_FROM_DOTFILES=false
while true; do
	read -p "Would you like to clone a NixOS configuration from git? (y/n) " -n 1 EXISTING
	echo
	if [[ "$EXISTING" == "y" ]]; then
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
		echo
		echo
		echo "Done cloning"
		cd /mnt/etc/nixos
		break
	else
		break
	fi
done

echo
echo
echo
echo "You may want to adjust the configuration in /mnt/etc/nixos"
echo
if [[ "$CLONED_FROM_DOTFILES" == "true" ]]; then
	# Move the useDHCP lines from configuration.nix to hardware-configuration.nix, as they are machine-dependent
	sed -i 's~\}\s*$~g~' /mnt/etc/nixos/hardware-configuration.nix
	cat /mnt/etc/nixos/default-configuration.nix | grep networking | grep useDHCP >> /mnt/etc/nixos/hardware-configuration.nix
	if ! grep hostName /mnt/etc/nixos/configuration.nix | grep -v '^\s*#';
		read -p "What would you like your hostname to be? " NIXOS_HOSTNAME
		if [[ "$NIXOS_HOSTNAME" != "" ]]; then
			echo "  networking.hostName = \"$NIXOS_HOSTNAME\";" >> /mnt/etc/nixos/hardware-configuration.nix
		fi
	fi
	echo "}" >> /mnt/etc/nixos/hardware-configuration.nix
fi
read -p "When you are ready, press ENTER to install from the configuration "

if nixos-install; then
	if [[ -f /mnt/etc/nixos/setup.sh ]] || [[ -f /mnt/etc/nixos/setup ]]; then
		read -p "Would you like to run the setup script? (y/n) " -n 1 RUN_SETUP
		if [[ "$RUN_SETUP" == "y" ]]; then
			export RUNNING_FROM_NIXOS_INSTALLER
			if [[ -f /mnt/etc/nixos/setup.sh ]]; then
				/mnt/etc/nixos/setup.sh
			else
				/mnt/etc/nixos/setup
			fi
		fi
	fi
	reboot
else
	echo
	echo
	echo "nixos-install exited with an error code. Check its output above!"
	echo "If you think it's safe, reboot. If not, figure it out!"
fi
