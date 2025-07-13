#!/bin/bash

echo "Starting Full Linux Cleanup Script"

# Step 1: Get current running kernel
CURRENT_KERNEL=$(uname -r | sed 's/-generic//')
echo "Current kernel: $CURRENT_KERNEL"

# Step 2: Find all old kernels (excluding current)
KERNELS_TO_REMOVE=$(dpkg --list | grep 'linux-image-[0-9]' | awk '{print $2}' | grep -v "$CURRENT_KERNEL")

# Step 3: Remove old kernels if found
if [[ -n "$KERNELS_TO_REMOVE" ]]; then
    echo "Removing old kernels:"
    echo "$KERNELS_TO_REMOVE"
    sudo apt remove --purge $KERNELS_TO_REMOVE -y
else
    echo "No old kernels found."
fi

# Step 4: Clean APT cache and unused packages
echo "Cleaning APT cache and unused packages..."
sudo apt autoremove --purge -y
sudo apt clean
sudo apt autoclean

# Step 5: Clean old Snap revisions
echo "Cleaning old snap revisions..."
sudo snap set system refresh.retain=2
sudo rm -rf /var/lib/snapd/snaps/*.old

# Step 6: Clean thumbnail cache
echo "Cleaning thumbnail cache..."
rm -rf ~/.cache/thumbnails/*

# Step 7: Clean old journal logs
echo "Vacuuming journal logs older than 7 days..."
sudo journalctl --vacuum-time=7d

# Step 8: Flatpak unused packages (optional)
if command -v flatpak &> /dev/null; then
    echo "Cleaning unused Flatpak packages..."
    flatpak uninstall --unused -y
fi

# Step 9: Empty trash
echo "Emptying user trash..."
rm -rf ~/.local/share/Trash/*

echo -e "\nSystem cleanup complete!"
