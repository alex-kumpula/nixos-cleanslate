{ inputs, config, lib, pkgs, ... }:
{
  flake.modules.nixos.btrfs-rollback-on-boot =
  { lib, pkgs, config, generatedScripts, ... }: # 💥 1. Accept 'generatedScripts' as an argument

  let 
      cfg = config.btrfs-rollback-on-boot;
      rollbackScriptContent = builtins.readFile ./rollback.sh;
      
      # We still need the script generation logic here to ensure 'cfg.services' is available
      # before the main module logic starts.
      scriptsToGenerate = lib.mapAttrs' (
        name: serviceCfg: lib.nameValuePair name (
          pkgs.writeShellScriptBin "rollback-${name}" ''
            # ... (your variable interpolation here) ...
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
    # 💥 2. Define the internal option's value via _module.args.
    # This value is calculated and provided as a stable argument to all subsequent module evaluation.
    _module.args = {
      generatedScripts = scriptsToGenerate;
    };
    
    # 3. Define the config block, consuming the argument.
    config = lib.mkIf cfg.enable {

      # The internal option is now set by the argument defined above.
      # We use lib.mkForce to ensure this definition wins and is finalized early.
      btrfs-rollback-on-boot.rollbackServiceScripts = lib.mkForce generatedScripts;

      # 4. Consumption: Access the scripts using the provided module argument.
      # This is guaranteed to be the final, correct 'package' type.
      boot.initrd.systemd.extraBin = (
        { grep = "${pkgs.gnugrep}/bin/grep"; } //

        lib.listToAttrs (
          lib.mapAttrsToList (
            name: scriptPackage: {
              name = name;
              # Consume the argument value, which is known to be the correct type (package).
              value = "${generatedScripts.${name}}/bin/rollback-${name}";
            }
          # 💥 Consume the dedicated argument value here.
          ) generatedScripts
        )
      );
    };
  };
}