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




## --- Prepare to Access Btrfs Volume ---

# Create a temporary mount point directory.
mkdir -p $BTRFS_MNT_POINT
echo "Created mount point directory: $BTRFS_MNT_POINT"

# Mount the main Btrfs volume
echo "Attempting to mount $BTRFS_DEVICE at $BTRFS_MNT_POINT..."
mount $BTRFS_DEVICE $BTRFS_MNT_POINT
echo "Successfully mounted Btrfs volume."

## --- Previous Root Subvolume Backup (The "Explosion") ---

echo "Checking for existing subvolume to wipe at $SV_WIPE_MOUNTED_PATH..."
if [[ -e $SV_WIPE_MOUNTED_PATH ]]; then
    
    echo "Existing subvolume found. Preparing backup structure."
    # Create the directory structure where old root snapshots will be moved/stored.
    mkdir -p $SNAPSHOT_DIR_MNT_PATH
    echo "Ensured snapshot directory exists: $SNAPSHOT_DIR_MNT_PATH"
    
    # Get the creation/modification time of the existing 'root' subvolume
    timestamp=$(date --date="@$(stat -c %Y $SV_WIPE_MOUNTED_PATH)" "+%Y-%m-%d_%H:%M:%S")
    SNAPSHOT_NAME="snapshot-$SV_WIPE_NAME-$timestamp"
    FULL_SNAPSHOT_PATH="$SNAPSHOT_DIR_MNT_PATH/$SNAPSHOT_NAME"
   
    echo "Generated Snapshot Path: $FULL_SNAPSHOT_PATH"
    
    # Check if a backup with the exact same timestamp already exists.
    if [[ ! -e $FULL_SNAPSHOT_PATH ]]; then
        
        echo "Atomic rename (mv) starting: $SV_WIPE_MOUNTED_PATH -> $FULL_SNAPSHOT_PATH"
        # If the timestamp is unique, rename the old 'root' subvolume
        # to the timestamped backup location.
        mv $SV_WIPE_MOUNTED_PATH $FULL_SNAPSHOT_PATH
        echo "Rename successful. Old subvolume saved."
    else
        
        echo "Duplicate timestamp found. Deleting old subvolume: $SV_WIPE_MOUNTED_PATH"
        # If a backup with that timestamp already exists,
        # the script deletes the existing 'root' subvolume immediately.
        btrfs subvolume delete $SV_WIPE_MOUNTED_PATH
        echo "Deletion successful."
    fi
else
    echo "Subvolume to wipe ($SV_WIPE_NAME) not found. Skipping backup."
fi

## --- Garbage Collection (GC) for Old Backups ---

echo "Starting Garbage Collection for old snapshots..."

# Recursively Garbage Collect: old_roots older than 30 days

# Define a shell function to delete Btrfs subvolumes recursively.
delete_subvolume_recursively() {
    
    echo "Processing for recursive deletion: $1" >/dev/kmsg
    # Set the Internal Field Separator to newline only.
    IFS=$'\n'

    # Sanity check: Ensure the path passed as argument ($1) is actually a Btrfs subvolume.
    if [ $(stat -c %i "$1") -ne 256 ]; then return; fi

    echo "Found nested subvolumes under $1..." >/dev/kmsg
    # List all subvolumes nested under the current path ($1) and iterate over them.
    for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
        
        # Log the recursive GC action.
        echo "Performing GC on nested subvolume: $i" >/dev/kmsg
        
        # Recursively call the function for the nested subvolume.
        delete_subvolume_recursively "$BTRFS_MNT_POINT/$i"
    done
    
    echo "Deleting subvolume: $1" >/dev/kmsg
    # Once all nested subvolumes are deleted, delete the current subvolume ($1).
    btrfs subvolume delete "$1"
    echo "Deletion of $1 complete." >/dev/kmsg
}

# Find the single latest (newest) root backup snapshot
latest_snapshot=$(find $SNAPSHOT_DIR_MNT_PATH/ -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)

# Only proceed with GC if there is at least one snapshot found.
if [ -n "$latest_snapshot" ]; then
    echo "Latest snapshot found: $latest_snapshot. Checking for expired backups."
    
    # Find all directories (snapshots) in 'old_roots' that are older than 30 days.
    for i in $(find $SNAPSHOT_DIR_MNT_PATH/ -mindepth 1 -maxdepth 1 -mtime +30 | grep -v -e "$latest_snapshot"); do

        echo "Found expired subvolume for deletion: $i"
        # Execute the recursive deletion function for the expired, non-latest snapshot.
        delete_subvolume_recursively "$i"
        echo "Expired subvolume deletion complete."
    done
else
    echo "No snapshots found in $SNAPSHOT_DIR_MNT_PATH. Skipping garbage collection."
fi

## --- Create New Root and Cleanup ---

echo "Attempting to create new subvolume at $SV_WIPE_MOUNTED_PATH..."
# Create the new, clean 'root' Btrfs subvolume.
btrfs subvolume create $SV_WIPE_MOUNTED_PATH
echo "New subvolume created successfully."
    
echo "Unmounting $BTRFS_MNT_POINT..."
# Unmount the main Btrfs volume from the temporary mount point.
umount $BTRFS_MNT_POINT
echo "Unmount successful."

# Log a successful completion message to the kernel message buffer.
echo "Done with 🧨. Au revoir! Rollback sequence finished." >/dev/kmsg

# --- END OF SCRIPT ---