# --- START OF SCRIPT ---
#
# NOTE: Nix expressions (${...}) are NOT used in this file.
# Variables are passed to this script by Nix.


# Log a starting message to the kernel message buffer (kmsg), visible via dmesg.
echo "btrfs-rollback-on-boot: Rolling back $SV_WIPE_NAME..." >/dev/kmsg

# --- Mount Btrfs Volumes ---

mkdir $SV_WIPE_DEVICE_TEMP_MOUNT_POINT
mount $SV_WIPE_DEVICE $SV_WIPE_DEVICE_TEMP_MOUNT_POINT
SV_WIPE_PATH="$SV_WIPE_DEVICE_TEMP_MOUNT_POINT$SV_WIPE_PATH_ON_DEVICE"

mkdir $SV_PERSIST_DEVICE_TEMP_MOUNT_POINT
mount $SV_PERSIST_DEVICE $SV_PERSIST_DEVICE_TEMP_MOUNT_POINT
SV_PERSIST_PATH="$SV_PERSIST_DEVICE_TEMP_MOUNT_POINT$SV_PERSIST_PATH_ON_DEVICE"

SNAPSHOTS_DIR="$SV_PERSIST_PATH$SNAPSHOT_PATH_IN_SV_PERSIST"

# --- Previous Subvolume Backup (The "Explosion") ---

if [[ -e $SV_WIPE_PATH ]]; then

    mkdir -p $SNAPSHOTS_DIR

    timestamp=$(date --date="@$(stat -c %Y $SV_WIPE_PATH)" "+%Y-%m-%d_%H:%M:%S")
    SNAPSHOT_NAME="snapshot-$SV_WIPE_NAME-$timestamp" # e.g. "snapshot-root-2026-01-02_19:39:43"
    FULL_SNAPSHOT_PATH="$SNAPSHOTS_DIR/$SNAPSHOT_NAME"


    # SNAPSHOT_PATH="$SNAPSHOTS_DIR/$timestamp"
    
    # if [[ ! -e $SNAPSHOT_PATH ]]; then
    
    #     mv $SV_WIPE_PATH $SNAPSHOT_PATH

    # else
    
    #     btrfs subvolume delete $SV_WIPE_PATH
    # fi


    # This command moves the subvolume to a new location in one atomic Btrfs operation.
    # This is essentially the Btrfs equivalent of 'mv' for a subvolume.
    # It is also much safer than operating on immutable files.
    echo "btrfs-rollback-on-boot: Creating snapshot/backup of old root at $FULL_SNAPSHOT_PATH..." >/dev/kmsg
    btrfs subvolume snapshot -r "$SV_WIPE_PATH" "$FULL_SNAPSHOT_PATH"
    
    # Delete the old, writable subvolume
    echo "btrfs-rollback-on-boot: Deleting old subvolume $SV_WIPE_PATH..." >/dev/kmsg
    btrfs subvolume delete "$SV_WIPE_PATH"
fi

# --- Create new subvolume and unmount ---

btrfs subvolume create $SV_WIPE_PATH

umount $SV_WIPE_DEVICE_TEMP_MOUNT_POINT
umount $SV_PERSIST_DEVICE_TEMP_MOUNT_POINT



# Log a successful completion message to the kernel message buffer.
echo "btrfs-rollback-on-boot: Done rolling back $SV_WIPE_NAME!" >/dev/kmsg

# --- END OF SCRIPT ---