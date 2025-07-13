#!/bin/bash

echo "Cleaning old Linux kernels safely..."

# Get current kernel

CURRENT_KERNEL=$(uname -r | sed 's/-generic//')
echo "Current running kernel: $CURRENT_KERNEL"

#Get all installed kernels except the current one
KERNELS_TO_REMOVE=$(dpkg --list |grep 'linux-image-[0-9]' | awk "{print $2}' | grep -v "$CURRENT_KERNEL")

# Show what will be removed
echo -e "\n These kernels will be removed:"
echo "$KERNELS_TO_REMOVE"

# Confirm before proceeding

read -p "Do youu want to proceed with removing them ? [y/N]: " CONFIRM
if [[ "$CONFIRM" =~ ^ [Yy]$ ]]; then
	sudo apt remove --purge $KERNELS_TO_REMOVE -y
	sudo apt autoremove --purge -y
	sudo apt clean
	echo -e "\n Done! Old kernels removed and system cleaned."
else
	echo "Cancelled. No changes made."
fi


