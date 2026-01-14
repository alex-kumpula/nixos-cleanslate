{ inputs, config, lib, ... }:
{
  flake.modules.nixos.cleanslate =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.cleanslate;
      rollbackScriptContent = builtins.readFile ./rollback.sh;
  in
  
  {
    config = lib.mkIf cfg.enable {

      cleanslate = {
        rollbackServiceScripts = lib.mapAttrs' (
          name: serviceCfg: lib.nameValuePair name (
            
            pkgs.writeShellScriptBin "${name}" (
              ''
                #
                # --- Variables interpolated by Nix ---
                #

                SERVICE_NAME="${name}"

                BTRFS_MNT_POINT="/btrfs_rollback_mounts/${name}_mount"
                # BTRFS_MNT_POINT="/btrfs_temp"

                # Subvolume to wipe
                SV_WIPE_PATH_ON_DEVICE="${serviceCfg.subvolumeToWipe.path}"
                SV_WIPE_MOUNTED_PATH="$BTRFS_MNT_POINT$SV_WIPE_PATH_ON_DEVICE"
                
                # Subvolume for persistence
                SV_PERSIST_PATH_ON_DEVICE="${serviceCfg.subvolumeForPersistence.path}"
                SV_PERSIST_MOUNTED_PATH="$BTRFS_MNT_POINT$SV_PERSIST_PATH_ON_DEVICE"

                SNAPSHOT_OUTPUT_PATH="${serviceCfg.snapshotOutputPath}"
                SNAPSHOT_DIR_MNT_PATH="$BTRFS_MNT_POINT$SV_PERSIST_PATH_ON_DEVICE$SNAPSHOT_OUTPUT_PATH"

                CREATE_SNAPSHOTS=${if serviceCfg.createSnapshots then "true" else "false"}
                GARBAGE_COLLECT_SNAPSHOTS=${if serviceCfg.garbageCollectSnapshots then "true" else "false"}
                SNAPSHOT_RETENTION_NUM_DAYS=${builtins.toString serviceCfg.snapshotRetentionAmountOfDays}
                

              '' + rollbackScriptContent
            )
          )

        ) cfg.services;
      };

      boot.initrd.systemd.extraBin = (
        { 
          grep = "${pkgs.gnugrep}/bin/grep"; 
          logger = "${pkgs.util-linux}/bin/logger";
        } // 
        # Map over the generated scripts to create the key/value pairs needed for extraBin.
        lib.listToAttrs (
          lib.mapAttrsToList (
            name: scriptPackage: {
              name = name;
              value = "${scriptPackage}/bin/${name}";
            }
          ) cfg.rollbackServiceScripts
        )
      );

    };
  };
}

