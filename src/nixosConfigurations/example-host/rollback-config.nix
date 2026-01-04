{
  config,
  ...
}:
{
  flake.modules.nixos.example-host = 
  { config, pkgs, ... }: 
  {
    btrfs-rollback-on-boot.enable = true;

    # Needed as the rollback service is an initrd systemd service.
    boot.initrd.systemd.enable = true;

    # Needed to ensure user home directories are properly made.
    # See this issue: https://github.com/NixOS/nixpkgs/issues/6481#issuecomment-3381105884
    # May be fixed in the future by: https://github.com/NixOS/nixpkgs/pull/223932
    services.userborn.enable = true;

    btrfs-rollback-on-boot.services = {
    
      # Define a service to manage the main root subvolume
      "root-wipe-service" = {
        
        # Optional: Explicitly enable this specific service (default is true)
        enable = true;

        btrfsDevice = "/dev/mapper/root_vg-root"; 

        snapshotOutputPath = "/root-snapshots";
        
        # Optional: Control whether snapshots are created (default is true)
        createSnapshots = true;

        garbageCollectSnapshots = false;

        snapshotRetentionAmountOfDays = 2;
        
        # --- Configuration for the Subvolume to be Wiped (The Root) ---
        subvolumeToWipe = {
          
          # The path to the subvolume from the Btrfs root (ID 5)
          path = "/root";
        };
        
        # --- Configuration for the Persistence Subvolume (Snapshot Storage) ---
        subvolumeForPersistence = {

          # The path to the persistence subvolume from the Btrfs root (ID 5)
          path = "/persistent"; 
        };
      };
      
      # You could define another service here if you had a separate volatile 
      # subvolume (e.g., for /tmp or Nix store) that needed wiping.
      # "tmp-wipe-service" = { ... };

    };
  };
}