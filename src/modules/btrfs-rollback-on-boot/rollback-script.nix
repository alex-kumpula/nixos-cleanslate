{ inputs, config, lib, ... }:
{
  flake.modules.nixos.btrfs-root-wipe =
  { lib, pkgs, ... }:
  let 
      cfg = config.btrfs-rollback-on-boot;
  in
  {
    config = lib.mkIf cfg.enable {

      boot.initrd.systemd = {
        extraBin = {
          grep = "${pkgs.gnugrep}/bin/grep";
        };
      };

      btrfs-rollback-on-boot = {
        rollbackServiceScripts = lib.mapAttrs' (
          name: serviceCfg: lib.nameValuePair name (
            
            pkgs.writeShellScriptBin "rollback" ''
              # --- START OF SCRIPT ---

              SV_WIPE_DEVICE="${serviceCfg.subvolumeToWipe.device}"
              SV_WIPE_PATH_ON_DEVICE="${serviceCfg.subvolumeToWipe.path}"
              SV_WIPE_NAME="${serviceCfg.subvolumeToWipe.name}"
              SV_WIPE_DEVICE_TEMP_MOUNT_POINT="/subvolume-$SV_WIPE_NAME-mount_dir"
              

              # TODO: Handle what to do if subvolumeForPersistence is null in the NixOS config
              # (...or just make subvolumeForPersistence required)
              SV_PERSIST_DEVICE="${serviceCfg.subvolumeForPersistence.device}"
              SV_PERSIST_PATH_ON_DEVICE="${serviceCfg.subvolumeForPersistence.path}"
              SV_PERSIST_NAME="${serviceCfg.subvolumeForPersistence.name}"
              SV_PERSIST_DEVICE_TEMP_MOUNT_POINT="/subvolume-$SV_PERSIST_NAME-mount_dir"
              

              # TODO: Make "old_roots" not hard-coded

              # TODO: Make GC a separate service that runs after this one
              # (but does not require it, in case this service fails for some reason)

              # TODO: apply userborn.enable (see old config)
              # OR make a warning if it isnt enabled. Be sure to
              # link to the relevant github issue.

              
              # Log a starting message to the kernel message buffer (kmsg), visible via dmesg.
              echo "Time to 🧨" >/dev/kmsg
              



              # --- Prepare to Access Btrfs Volumes ---
              
              mkdir $SV_WIPE_DEVICE_TEMP_MOUNT_POINT
              mount $SV_WIPE_DEVICE $SV_WIPE_DEVICE_TEMP_MOUNT_POINT
              SV_WIPE_PATH = "$SV_WIPE_DEVICE_TEMP_MOUNT_POINT$SV_WIPE_PATH_ON_DEVICE"

              mkdir $SV_PERSIST_DEVICE_TEMP_MOUNT_POINT
              mount $SV_PERSIST_DEVICE $SV_PERSIST_DEVICE_TEMP_MOUNT_POINT
              SV_PERSIST_PATH = "$SV_PERSIST_DEVICE_TEMP_MOUNT_POINT$SV_PERSIST_PATH_ON_DEVICE"

              # --- Previous Root Subvolume Backup (The "Explosion") ---
          
              if [[ -e $SV_WIPE_PATH ]]; then

                  mkdir -p $SV_PERSIST_PATH/old_roots
                
                  timestamp=$(date --date="@$(stat -c %Y $SV_WIPE_PATH)" "+%Y-%m-%d_%H:%M:%S")
                  
                  if [[ ! -e $SV_PERSIST_PATH/old_roots/$timestamp ]]; then
                  
                      mv $SV_WIPE_PATH "$SV_PERSIST_PATH/old_roots/$timestamp"

                  else
                  
                      btrfs subvolume delete $SV_WIPE_PATH
                  fi
              fi

              # --- Create New Root and Cleanup ---
              
              btrfs subvolume create $SV_WIPE_PATH
              
              umount $SV_WIPE_DEVICE_TEMP_MOUNT_POINT
              umount $SV_PERSIST_DEVICE_TEMP_MOUNT_POINT



              # Log a successful completion message to the kernel message buffer.
              echo "Done with 🧨. Au revoir!" >/dev/kmsg
              
              # --- END OF SCRIPT ---
            ''
          )

        ) cfg.services;
      };

    };
  };
}

