{
  config,
  ...
}:
{
  flake.modules.nixos.example-host = 
  { ... }: 
  {
    # Enables the whole module
    btrfs-rollback-on-boot.enable = true;

    # Needed as the rollback service is an initrd systemd service.
    boot.initrd.systemd.enable = true;

    # Needed to ensure user home directories are properly made.
    # See this issue: https://github.com/NixOS/nixpkgs/issues/6481#issuecomment-3381105884
    # May be fixed in the future by: https://github.com/NixOS/nixpkgs/pull/223932
    services.userborn.enable = true;

    # Define rollback services
    btrfs-rollback-on-boot.services = {
    
      # Define a service to manage the main root subvolume
      "root-wipe-service" = {
        
        # Optional: Explicitly enable/disable this specific service (default is true)
        enable = true;

        # The device the btrfs filesystem is on
        btrfsDevice = "/dev/mapper/root_vg-root"; 

        # The directory in the persistent subvolume (subvolumeForPersistence)
        # to store snapshots in
        snapshotOutputPath = "/root-snapshots";
        
        # Optional: Whether snapshots are created or not (default is true)
        createSnapshots = true;

        # Optional: Whether old snapshots are deleted or not (default is true)
        garbageCollectSnapshots = false;

        # If garbage collection is enabled, how long to keep old snapshots for
        # in number of days. (default is 30)
        snapshotRetentionAmountOfDays = 30;
        
        # Configuration for the subvolume to be wiped
        subvolumeToWipe = {
          # Path relative to the root of the btrfs filesystem
          path = "/root";
        };
        
        # Configuration for the subvolume used for persistence
        # (storing snapshots)
        subvolumeForPersistence = {
          # Path relative to the root of the btrfs filesystem
          path = "/persistent"; 
        };
      };
    

      # You can define multiple rollback services
    };
  };
}