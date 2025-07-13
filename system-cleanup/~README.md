 Linux System Cleanup Script

Automated cleanup utility for removing junk files, old kernels, and optimizing Linux systems.

 Description
This Bash script automates routine Linux maintenance tasks to:

Remove old/unused kernels
Clean package caches (APT, Snap)
Prune thumbnail/junk files
Vacuum system logs
Optional Flatpak cleanup
 
 Features

✅ Kernel Cleanup: Safely removes outdated kernels while preserving the current one
✅ Package Manager Optimization: Cleans APT/Snap caches and orphaned packages
✅ Space Recovery: Deletes thumbnails, old logs, and trash contents
✅ Modular Design: Easy to extend with new cleanup modules

How to use:

Make executable:

chmod +x full-cleanup.sh

Run as root/admin:

sudo ./full-cleanup.sh

⚠️ Requirements
Linux (Debian/Ubuntu-based recommended)
Bash (v4.0+)
Sudo/root privileges

📝 Notes
Always review the script before execution
Backup critical data before system-wide cleanup
Tested on Ubuntu 20.04+/Debian 11
