{
  config,
  ...
}:
{
  flake.modules.nixos.example-host = 
  { config, pkgs, ... }: 
  {
    btrfs-rollback-on-boot.enable = true;
    boot.initrd.systemd.enable = true;
    services.userborn.enable = true;

    btrfs-rollback-on-boot.services = {
    
      # Define a service to manage the main root subvolume
      "root-wipe-service" = {
        
        # Optional: Explicitly enable this specific service (default is true)
        enable = true;

        btrfsDevice = "/dev/mapper/root_vg-root"; 
        
        # Optional: Control whether snapshots are created (default is true)
        createSnapshots = true;
        
        # --- Configuration for the Subvolume to be Wiped (The Root) ---
        subvolumeToWipe = {
          
          # The path to the subvolume from the Btrfs root (ID 5)
          path = "/root"; 
          
          # A simple name for internal reference (used in temp mount point names)
          name = "root"; 
        };
        
        # --- Configuration for the Persistence Subvolume (Snapshot Storage) ---
        subvolumeForPersistence = {

          # The path to the persistence subvolume from the Btrfs root (ID 5)
          path = "/persistent"; 
          
          # A simple name for internal reference
          name = "persistent"; 
        };
      };
      
      # You could define another service here if you had a separate volatile 
      # subvolume (e.g., for /tmp or Nix store) that needed wiping.
      # "tmp-wipe-service" = { ... };

    };
  };
}