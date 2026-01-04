# --- START OF SCRIPT ---
        
# Log a starting message to the kernel message buffer (kmsg), visible via dmesg.
echo "$SERVICE_NAME: Starting btrfs rollback..." >/dev/kmsg

echo "BTRFS_DEVICE = $BTRFS_DEVICE" # eg. /dev/mapper/root_vg-root
echo "BTRFS_MNT_POINT = $BTRFS_MNT_POINT" # eg. /btrfs_rollback_mounts/root-wipe-service_mount

echo "SV_WIPE_PATH_ON_DEVICE = $SV_WIPE_PATH_ON_DEVICE" # eg. /root
echo "SV_WIPE_NAME = $SV_WIPE_NAME" # eg. root
echo "SV_WIPE_MOUNTED_PATH = $SV_WIPE_MOUNTED_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/root

echo "SV_PERSIST_PATH_ON_DEVICE = $SV_PERSIST_PATH_ON_DEVICE" # eg. /persistent
echo "SV_PERSIST_MOUNTED_PATH = $SV_PERSIST_MOUNTED_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/persistent

echo "SNAPSHOT_DIR_MNT_PATH = $SNAPSHOT_DIR_MNT_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/persistent/snapshots

echo "CREATE_SNAPSHOTS = $CREATE_SNAPSHOTS"
echo "GARBAGE_COLLECT_SNAPSHOTS = $GARBAGE_COLLECT_SNAPSHOTS"
echo "SNAPSHOT_RETENTION_NUM_DAYS = $SNAPSHOT_RETENTION_NUM_DAYS"


## --- Prepare to Access Btrfs Volume ---

# Create a temporary mount point directory.
mkdir -p $BTRFS_MNT_POINT
echo "Created mount point directory: $BTRFS_MNT_POINT"

# Mount the main Btrfs volume
echo "Attempting to mount $BTRFS_DEVICE at $BTRFS_MNT_POINT..."
mount $BTRFS_DEVICE $BTRFS_MNT_POINT
echo "Successfully mounted Btrfs volume."

## --- Previous Subvolume Rollback ---

echo "Checking for existing subvolume to wipe at $SV_WIPE_MOUNTED_PATH..."
if [[ -e $SV_WIPE_MOUNTED_PATH ]]; then
    
    if $CREATE_SNAPSHOTS; then

        echo "Existing subvolume found. Preparing backup structure."
        # Create the directory structure where old root snapshots will be moved/stored.
        mkdir -p $SNAPSHOT_DIR_MNT_PATH
        echo "Ensured snapshot directory exists: $SNAPSHOT_DIR_MNT_PATH"
        
        # Get the creation/modification time of the existing 'root' subvolume
        timestamp=$(date --date="@$(stat -c %Y $SV_WIPE_MOUNTED_PATH)" "+%Y-%m-%d_%H:%M:%S")
        SNAPSHOT_NAME="snapshot-$timestamp"
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
            # This should be safe because the same timestamp means there
            # were no changes.
            btrfs subvolume delete -R $SV_WIPE_MOUNTED_PATH
            echo "Deletion successful."
        fi
    else
        echo "Snapshot skipped. Deleting old subvolume directly: $SV_WIPE_MOUNTED_PATH"
        btrfs subvolume delete -R $SV_WIPE_MOUNTED_PATH
        echo "Deletion successful."
    fi
else
    echo "Subvolume to wipe ($SV_WIPE_MOUNTED_PATH) not found. Skipping backup."
fi

## --- Garbage Collection (GC) for old snapshots ---

if $GARBAGE_COLLECT_SNAPSHOTS; then
    echo "Starting Garbage Collection for snapshots older than $SNAPSHOT_RETENTION_NUM_DAYS days..."
    # Find the single latest (newest) snapshot
    latest_snapshot=$(find $SNAPSHOT_DIR_MNT_PATH/ -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)

    # Only proceed with GC if there is at least one snapshot found
    if [ -n "$latest_snapshot" ]; then
        echo "Latest snapshot found: $latest_snapshot. Checking for expired backups."
        
        # Find all directories (snapshots) that are older than SNAPSHOT_RETENTION_NUM_DAYS days
        for i in $(find $SNAPSHOT_DIR_MNT_PATH/ -mindepth 1 -maxdepth 1 -mtime +$SNAPSHOT_RETENTION_NUM_DAYS | grep -v -e "$latest_snapshot"); do

            echo "Found expired subvolume for deletion: $i"
            # Recursively delete the expired, non-latest snapshot
            btrfs subvolume delete -R "$i"
            echo "Expired subvolume deletion complete."
        done
    else
        echo "No snapshots found in $SNAPSHOT_DIR_MNT_PATH. Skipping garbage collection."
    fi
else
    echo "Garbage Collection skipped because it is disabled."
fi

## --- Create New Subvolume and Cleanup ---

echo "Attempting to create new subvolume at $SV_WIPE_MOUNTED_PATH..."
# Create the new, clean Btrfs subvolume.
btrfs subvolume create $SV_WIPE_MOUNTED_PATH
echo "New subvolume created successfully."
    
echo "Unmounting $BTRFS_MNT_POINT..."
# Unmount the main Btrfs volume from the temporary mount point.
umount $BTRFS_MNT_POINT
echo "Unmount successful."

# Log a successful completion message to the kernel message buffer.
echo "$SERVICE_NAME: Finished btrfs rollback sequence!" >/dev/kmsg

# --- END OF SCRIPT ---