{ inputs, config, lib, ... }:
{
  flake.modules.nixos.btrfs-root-wipe =
  { lib, pkgs, ... }:
  let
    rootCleanupScript = ''
      # --- START OF SCRIPT ---
      
      # Log a starting message to the kernel message buffer (kmsg), visible via dmesg.
      echo "Time to 🧨" >/dev/kmsg
      
      # --- Prepare to Access Btrfs Volume ---
      
      # Create a temporary mount point directory. This is needed because the 
      # script runs in initrd, and the Btrfs volume is not yet mounted.
      mkdir /btrfs_tmp
      
      # Mount the main Btrfs volume (which is on the LVM logical volume 'root_vg-root').
      # This mounts the volume's root, allowing access to all its subvolumes 
      # (like 'root', 'persistent', and 'nix').
      mount /dev/mapper/root_vg-root /btrfs_tmp

      # --- Previous Root Subvolume Backup (The "Explosion") ---
  
      # Check if the Btrfs subvolume named 'root' exists under the temporary mount.
      # If it exists, it means a previous system's ephemeral root is present.
      if [[ -e /btrfs_tmp/root ]]; then
          
          # Create the directory structure where old root snapshots will be moved/stored.
          # This path is inside the '/persistent' subvolume, so the backups persist across boots.
          mkdir -p /btrfs_tmp/persistent/old_roots
          
          # Get the creation/modification time of the existing 'root' subvolume 
          # (stat -c %Y gives seconds since epoch) and format it into a YYYY-MM-DD_HH:MM:SS timestamp.
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%d_%H:%M:%S")
          
          # Check if a backup with the exact same timestamp already exists.
          if [[ ! -e /btrfs_tmp/persistent/old_roots/$timestamp ]]; then
            
              # If the timestamp is unique, rename the old 'root' subvolume 
              # to the timestamped backup location. This preserves the previous session's state.
              mv /btrfs_tmp/root "/btrfs_tmp/persistent/old_roots/$timestamp"
          else
            
              # If a backup with that timestamp already exists (e.g., due to a fast reboot),
              # the script deletes the existing 'root' subvolume immediately to ensure 
              # a clean slate, avoiding duplicate backups.
              btrfs subvolume delete /btrfs_tmp/root
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
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          
          # Once all nested subvolumes are deleted, delete the current subvolume ($1).
          btrfs subvolume delete "$1"
      }
      
      # Find the single latest (newest) root backup snapshot in the 'old_roots' directory 
      # (assuming the timestamps mean sorting gives the latest).
      latest_snapshot=$(find /btrfs_tmp/persistent/old_roots/ -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)
      
      # Only proceed with GC if there is at least one snapshot found.
      # This prevents running find on an empty directory and causing potential issues.
      if [ -n "$latest_snapshot" ]; then
          
          # Find all directories (snapshots) in 'old_roots' that are older than 30 days (-mtime +30).
          # | grep -v -e "$latest_snapshot": Excludes the *single newest snapshot* from deletion 
          # regardless of its age, ensuring there's always at least one rollback point.
          for i in $(find /btrfs_tmp/persistent/old_roots/ -mindepth 1 -maxdepth 1 -mtime +30 | grep -v -e "$latest_snapshot"); do

              # Execute the recursive deletion function for the expired, non-latest snapshot.
              delete_subvolume_recursively "$i"
          done
      fi

      # --- Create New Root and Cleanup ---
      
      # Create the new, clean 'root' Btrfs subvolume. This subvolume will be mounted 
      # as the new ephemeral root filesystem ('/') by the rest of the initrd process.
      btrfs subvolume create /btrfs_tmp/root
      
      # Unmount the main Btrfs volume from the temporary mount point.
      umount /btrfs_tmp
      
      # Log a successful completion message to the kernel message buffer.
      echo "Done with 🧨. Au revoir!" >/dev/kmsg
      
      # --- END OF SCRIPT ---
    '';
  in
  {
    fileSystems."/persistent" = {
      neededForBoot = true;
    };

    boot.tmp.cleanOnBoot = true;
    services.lvm.enable = true;
    services.userborn.enable = true;

    # Cleanup / on every boot and resume, see https://grahamc.com/blog/erase-your-darlings/
    boot.initrd.systemd = {
      enable = true;
      extraBin = {
        grep = "${pkgs.gnugrep}/bin/grep";
      };
      services = {
        root-cleanup = {
          wantedBy = ["initrd-root-device.target"];
          wants = ["lvm2-activation.service"];
          # See https://github.com/nix-community/impermanence/issues/250#issuecomment-2603848867
          after = ["lvm2-activation.service" "local-fs-pre.target"];
          before = ["sysroot.mount"];
          # Run on cold boot only, never on resume from hibernation
          unitConfig = {
            ConditionKernelCommandLine = ["!resume="];
            RequiresMountsFor = ["/dev/mapper/root_vg-root"];
          };
          serviceConfig = {
            StandardOutput = "journal+console";
            StandardError = "journal+console";
            Type = "oneshot";
          };
          script = rootCleanupScript;
        };
      };
    };
  };
}

