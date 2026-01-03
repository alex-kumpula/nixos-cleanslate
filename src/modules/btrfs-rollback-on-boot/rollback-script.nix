{ inputs, config, lib, ... }:
{


  # TODO: Make GC a separate service that runs after this one
  # (but does not require it, in case this service fails for some reason)




  flake.modules.nixos.btrfs-rollback-on-boot =
  { inputs, config, lib, pkgs, ... }:
{
  # 1. Define configuration access safely at the top level
  flake.modules.nixos.btrfs-rollback-on-boot =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.btrfs-rollback-on-boot;
      rollbackScriptContent = builtins.readFile ./rollback.sh;
      
      # 2. Extract the script generation logic into a self-contained variable
      generatedScripts = lib.mapAttrs' (
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

  in
  {
    # 3. Define the config block, setting the internal option value here
    config = lib.mkIf cfg.enable {

      btrfs-rollback-on-boot.rollbackServiceScripts = generatedScripts;

      # 4. Consume the generated scripts for extraBin
      # Note: We still reference the config value (cfg.rollbackServiceScripts) 
      # but by deferring the calculation to the `let` block, we help the evaluator.
      boot.initrd.systemd.extraBin = (
        { grep = "${pkgs.gnugrep}/bin/grep"; } //

        lib.listToAttrs (
          lib.mapAttrsToList (
            name: scriptPackage: {
              name = name;
              # scriptPackage is now guaranteed to be the *package* (derivation)
              value = "${scriptPackage}/bin/rollback-${name}"; 
            }
          ) cfg.rollbackServiceScripts
        )
      );

    };
  };
};
}

