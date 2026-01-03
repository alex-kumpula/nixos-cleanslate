# --- START OF SCRIPT ---
#
# NOTE: Nix expressions (${...}) are NOT used in this file.
# Variables are passed to this script by Nix.


# Log a starting message to the kernel message buffer (kmsg), visible via dmesg.
echo "btrfs-rollback-on-boot: Rolling back $SV_WIPE_NAME..." >/dev/kmsg

# --- Mount Btrfs Volumes ---

echo "THIS IS A TEST logger"

echo "BTRFS_DEVICE = $BTRFS_DEVICE" # eg. /dev/mapper/root_vg-root
echo "BTRFS_MNT_POINT = $BTRFS_MNT_POINT" # eg. /btrfs_rollback_mounts/root-wipe-service_mount

echo "SV_WIPE_PATH_ON_DEVICE = $SV_WIPE_PATH_ON_DEVICE" # eg. /root
echo "SV_WIPE_NAME = $SV_WIPE_NAME" # eg. root
echo "SV_WIPE_MOUNTED_PATH = $SV_WIPE_MOUNTED_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/root

echo "SV_PERSIST_PATH_ON_DEVICE = $SV_PERSIST_PATH_ON_DEVICE" # eg. /persistent
echo "SV_PERSIST_NAME = $SV_PERSIST_NAME" # eg. persistent
echo "SV_PERSIST_MOUNTED_PATH = $SV_PERSIST_MOUNTED_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/persistent

echo "SNAPSHOT_DIR_MNT_PATH = $SNAPSHOT_DIR_MNT_PATH" # eg. /btrfs_rollback_mounts/root-wipe-service_mount/persistent/snapshots

# Mount the BTRFS filesystem root
mkdir -p $BTRFS_MNT_POINT
echo "Attempting to mount BTRFS device $BTRFS_DEVICE at $BTRFS_MNT_POINT..."
if ! mount $BTRFS_DEVICE $BTRFS_MNT_POINT; then
    echo "ERROR: Failed to mount BTRFS device $BTRFS_DEVICE at $BTRFS_MNT_POINT."
    exit 1
else
    echo "Succesfully mounted BTRFS device $BTRFS_DEVICE at $BTRFS_MNT_POINT."
fi

# Check if the mounted subvolume directory exists
if [[ -d $SV_WIPE_MOUNTED_PATH ]]; then

    mkdir -p $SNAPSHOT_DIR_MNT_PATH

    # Get the timestamp of the wipe subvolume (when it was last modified)
    timestamp=$(date --date="@$(stat -c %Y $SV_WIPE_MOUNTED_PATH)" "+%Y-%m-%d_%H:%M:%S")

    SNAPSHOT_NAME="snapshot-$SV_WIPE_NAME-$timestamp" # e.g. "snapshot-root-2026-01-02_19:39:43"
    FULL_SNAPSHOT_PATH="$SNAPSHOT_DIR_MNT_PATH/$SNAPSHOT_NAME"

    echo "SNAPSHOT_NAME = $SNAPSHOT_NAME"
    echo "FULL_SNAPSHOT_PATH = $FULL_SNAPSHOT_PATH"

    LOCAL_SNAPSHOT_PATH="$BTRFS_MNT_POINT/old-root-temp-snapshot"

    echo "Attempting to create local read-only snapshot for backup..."
    if ! btrfs subvolume snapshot -r "$SV_WIPE_MOUNTED_PATH" "$LOCAL_SNAPSHOT_PATH"; then
        echo "ERROR: Local snapshot creation failed for $SV_WIPE_MOUNTED_PATH."
        exit 1
    fi

    echo "Attempting to atomically rename (move) the old subvolume to $FULL_SNAPSHOT_PATH..."
    if mv "$SV_WIPE_MOUNTED_PATH" "$FULL_SNAPSHOT_PATH"; then
        echo "Successfully renamed old subvolume to $FULL_SNAPSHOT_PATH. Rollback complete."
    else
        echo "ERROR: Renaming (mv) of $SV_WIPE_MOUNTED_PATH failed. Deleting local snapshot."
        # If mv fails, delete the local snapshot to clean up
        btrfs subvolume delete "$LOCAL_SNAPSHOT_PATH" || true
        exit 1
    fi



    # echo "Attempting to create a snapshot of the subvolume at $SV_WIPE_MOUNTED_PATH..."
    # if btrfs subvolume snapshot -r "$SV_WIPE_MOUNTED_PATH" "$FULL_SNAPSHOT_PATH"; then
    #     echo "Successfully created snapshot for $SV_WIPE_MOUNTED_PATH. The snapshot is located at $FULL_SNAPSHOT_PATH."
    # else    
    #     echo "ERROR: Snapshot creation failed for $SV_WIPE_MOUNTED_PATH."
    #     # exit 1
    # fi

    # echo "Attempting to delete the subvolume at $SV_WIPE_MOUNTED_PATH..."
    # if btrfs subvolume delete "$SV_WIPE_MOUNTED_PATH"; then
    #     echo "Deletion of $SV_WIPE_MOUNTED_PATH was a success."
    # else
    #     echo "ERROR: Deletion of $SV_WIPE_MOUNTED_PATH failed."
    #     exit 1
    # fi
fi

# --- Create new subvolume and unmount ---

echo "Attempting to recreate a new subvolume at $SV_WIPE_MOUNTED_PATH..."
if btrfs subvolume create "$SV_WIPE_MOUNTED_PATH"; then
    echo "Subvolume creation succeeded for $SV_WIPE_MOUNTED_PATH."
else
    echo "ERROR: Subvolume creation failed for $SV_WIPE_MOUNTED_PATH."
    exit 1
fi

umount $BTRFS_MNT_POINT
echo "btrfs-rollback-on-boot: Done rolling back $SV_WIPE_NAME!"


# --- END OF SCRIPT ---