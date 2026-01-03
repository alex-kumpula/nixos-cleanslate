# --- START OF SCRIPT ---
        
# Log a starting message to the kernel message buffer (kmsg), visible via dmesg.
echo "Time to 🧨" >/dev/kmsg


echo "BTRFS_DEVICE = $BTRFS_DEVICE" # eg. /dev/mapper/root_vg-root
echo "BTRFS_MNT_POINT = $BTRFS_MNT_POINT" # eg. /btrfs_rollback_mounts/root-wipe-service_mount

echo "SV_WIPE_PATH_ON_DEVICE = $SV_WIPE_PATH_ON_DEVICE" # eg. /root
echo "SV_WIPE_NAME = $SV_WIPE_NAME" # eg. root
echo "SV_WIPE_MOUNTED_PATH = $SV_WIPE_MOUNTED_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/root

echo "SV_PERSIST_PATH_ON_DEVICE = $SV_PERSIST_PATH_ON_DEVICE" # eg. /persistent
echo "SV_PERSIST_NAME = $SV_PERSIST_NAME" # eg. persistent
echo "SV_PERSIST_MOUNTED_PATH = $SV_PERSIST_MOUNTED_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/persistent

echo "SNAPSHOT_DIR_MNT_PATH = $SNAPSHOT_DIR_MNT_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/persistent/snapshots




# --- Prepare to Access Btrfs Volume ---

# Create a temporary mount point directory. This is needed because the 
# script runs in initrd, and the Btrfs volume is not yet mounted.
mkdir $BTRFS_MNT_POINT

# Mount the main Btrfs volume (which is on the LVM logical volume 'root_vg-root').
# This mounts the volume's root, allowing access to all its subvolumes 
# (like 'root', 'persistent', and 'nix').
mount $BTRFS_DEVICE $BTRFS_MNT_POINT

# --- Previous Root Subvolume Backup (The "Explosion") ---

# Check if the Btrfs subvolume named 'root' exists under the temporary mount.
# If it exists, it means a previous system's ephemeral root is present.
if [[ -e $SV_WIPE_MOUNTED_PATH ]]; then
    
    # Create the directory structure where old root snapshots will be moved/stored.
    # This path is inside the '/persistent' subvolume, so the backups persist across boots.
    mkdir -p $SNAPSHOT_DIR_MNT_PATH
    
    # Get the creation/modification time of the existing 'root' subvolume 
    # (stat -c %Y gives seconds since epoch) and format it into a YYYY-MM-DD_HH:MM:SS timestamp.
    timestamp=$(date --date="@$(stat -c %Y $SV_WIPE_MOUNTED_PATH)" "+%Y-%m-%d_%H:%M:%S")
    SNAPSHOT_NAME="snapshot-$SV_WIPE_NAME-$timestamp" # e.g. "snapshot-root-2026-01-02_19:39:43"
    FULL_SNAPSHOT_PATH="$SNAPSHOT_DIR_MNT_PATH/$SNAPSHOT_NAME"
    
    # Check if a backup with the exact same timestamp already exists.
    if [[ ! -e $FULL_SNAPSHOT_PATH ]]; then
        
        # If the timestamp is unique, rename the old 'root' subvolume 
        # to the timestamped backup location. This preserves the previous session's state.
        mv $SV_WIPE_MOUNTED_PATH $FULL_SNAPSHOT_PATH
    else
        
        # If a backup with that timestamp already exists (e.g., due to a fast reboot),
        # the script deletes the existing 'root' subvolume immediately to ensure 
        # a clean slate, avoiding duplicate backups.
        btrfs subvolume delete $SV_WIPE_MOUNTED_PATH
    fi
fi

# --- Garbage Collection (GC) for Old Backups ---

# Recursively Garbage Collect: old_roots older than 30 days

# Define a shell function to delete Btrfs subvolumes recursively.
delete_subvolume_recursively() {
    
    # Set the Internal Field Separator to newline only. This is critical for 
    # correctly handling subvolume names that might contain spaces.
    IFS=$'\n'

    # Sanity check: Ensure the path passed as argument ($1) is actually a Btrfs subvolume.
    # Btrfs subvolumes have a special inode number (256). This prevents accidentally 
    # recursing into and deleting non-subvolume directories or the main volume itself.
    if [ $(stat -c %i "$1") -ne 256 ]; then return; fi

    # List all subvolumes nested under the current path ($1) and iterate over them.
    # -o: Print object ID (needed for nested volumes)
    # cut -f 9- -d ' ': Extracts the subvolume path/name (starting from the 9th field).
    for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
        
        # Log the recursive GC action.
        echo "Performing GC on $i" >/dev/kmsg
        
        # Recursively call the function for the nested subvolume.
        delete_subvolume_recursively "$BTRFS_MNT_POINT/$i"
    done
    
    # Once all nested subvolumes are deleted, delete the current subvolume ($1).
    btrfs subvolume delete "$1"
}

# Find the single latest (newest) root backup snapshot in the 'old_roots' directory 
# (assuming the timestamps mean sorting gives the latest).
latest_snapshot=$(find $SNAPSHOT_DIR_MNT_PATH/ -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)

# Only proceed with GC if there is at least one snapshot found.
# This prevents running find on an empty directory and causing potential issues.
if [ -n "$latest_snapshot" ]; then
    
    # Find all directories (snapshots) in 'old_roots' that are older than 30 days (-mtime +30).
    # | grep -v -e "$latest_snapshot": Excludes the *single newest snapshot* from deletion 
    # regardless of its age, ensuring there's always at least one rollback point.
    for i in $(find $SNAPSHOT_DIR_MNT_PATH/ -mindepth 1 -maxdepth 1 -mtime +30 | grep -v -e "$latest_snapshot"); do

        # Execute the recursive deletion function for the expired, non-latest snapshot.
        delete_subvolume_recursively "$i"
    done
fi

# --- Create New Root and Cleanup ---

# Create the new, clean 'root' Btrfs subvolume. This subvolume will be mounted 
# as the new ephemeral root filesystem ('/') by the rest of the initrd process.
btrfs subvolume create $SV_WIPE_MOUNTED_PATH

# Unmount the main Btrfs volume from the temporary mount point.
umount $BTRFS_MNT_POINT

# Log a successful completion message to the kernel message buffer.
echo "Done with 🧨. Au revoir!" >/dev/kmsg

# --- END OF SCRIPT ---