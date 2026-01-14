{ inputs, config, lib, ... }:
{
  flake.modules.nixos.cleanslate =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.cleanslate;
  in
  {
    config = lib.mkIf cfg.enable {

      boot.initrd.systemd.mounts =
        lib.mapAttrsToList (name: serviceCfg: 
        let 
          mnt = "/btrfs_rollback_mounts/${name}_mount";
        in 
        {
          what  = serviceCfg.btrfsDevice;
          where = mnt;
          type  = "btrfs";
          options = "rw";
          wantedBy = [ "initrd.target" ];
        }) cfg.services;


      boot.initrd.systemd.services = lib.mapAttrs' (
        name: serviceCfg: 
        let
          mountUnit =
            lib.replaceStrings [ "/" ] [ "-" ]
              (lib.removePrefix "/" "/btrfs_rollback_mounts/${name}_mount")
            + ".mount";
        in
        lib.nameValuePair "${name}" {
     
          enableStrictShellChecks = false;

          wantedBy = [ "initrd-root-device.target" ];
          before   = [ "sysroot.mount" ];

          requires = [ mountUnit ];
          after    = [ mountUnit ];

          unitConfig = {
            # Run on cold boot only, never on resume from hibernation
            ConditionKernelCommandLine = [ "!resume=" ];
          };

          serviceConfig = {
            ExecStart = "${cfg.rollbackServiceScripts.${name}}/bin/${name}";
            StandardOutput = "journal";
            StandardError = "journal";
            Type = "oneshot";
          };

        }

      ) cfg.services;

    };
  };
}

