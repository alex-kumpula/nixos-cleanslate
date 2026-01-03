{ inputs, config, lib, ... }:
{


  # TODO: Make GC a separate service that runs after this one
  # (but does not require it, in case this service fails for some reason)




  flake.modules.nixos.btrfs-rollback-on-boot =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.btrfs-rollback-on-boot;

      rollbackScriptContent = builtins.readFile ./rollback.sh;
  in
  
  {
    config = lib.mkIf cfg.enable {

      btrfs-rollback-on-boot = {
        rollbackServiceScripts = lib.mapAttrs' (
          name: serviceCfg: lib.nameValuePair name (
            
            pkgs.writeShellScriptBin "rollback-${name}" ''
              #
              # --- Variables interpolated by Nix ---
              #

              SV_WIPE_DEVICE="${serviceCfg.subvolumeToWipe.device}"
              SV_WIPE_PATH_ON_DEVICE="${serviceCfg.subvolumeToWipe.path}"
              SV_WIPE_NAME="${serviceCfg.subvolumeToWipe.name}"
              SV_WIPE_DEVICE_TEMP_MOUNT_POINT="/subvolume-$SV_WIPE_NAME-mount_dir"
              
              SV_PERSIST_DEVICE="${serviceCfg.subvolumeForPersistence.device}"
              SV_PERSIST_PATH_ON_DEVICE="${serviceCfg.subvolumeForPersistence.path}"
              SV_PERSIST_NAME="${serviceCfg.subvolumeForPersistence.name}"
              SV_PERSIST_DEVICE_TEMP_MOUNT_POINT="/subvolume-$SV_PERSIST_NAME-mount_dir"

              SNAPSHOT_PATH_IN_SV_PERSIST="/snapshots"

            '' + rollbackScriptContent
          )

        ) cfg.services;
      };

      # 2. Extract the generated scripts and add them to extraBin
      # We use lib.mapAttrs to transform the attribute set into the required format.
      # The result is merged with the existing 'extraBin' set (which contains 'grep').
      boot.initrd.systemd.extraBin = (
        { grep = "${pkgs.gnugrep}/bin/grep"; } // # Start with existing bins

        # Map over the generated scripts to create the key/value pairs needed for extraBin.
        # extraBin expects { binName = packagePath; }
        lib.mapAttrs (
          name: scriptPackage: {
            # The key (bin name) should be something descriptive, e.g., 'rollback-rootfs'
            # We extract the path to the executable *inside* the package.
            "${name}" = "${scriptPackage}/bin/rollback-${name}";
          }
        ) cfg.rollbackServiceScripts
      );

    };
  };
}

