{ inputs, config, lib, ... }:
{
  flake.modules.nixos.btrfs-rollback-on-boot =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.btrfs-rollback-on-boot;
  in
  {
    config = lib.mkIf cfg.enable {

      boot.initrd.systemd.services = lib.mapAttrs' (
        name: serviceCfg: lib.nameValuePair "btrfs-rollback-${name}" {
          
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
            ExecStart = "${cfg.rollbackServiceScripts.${name}}/bin/rollback-${name}";
            StandardOutput = "journal+console";
            StandardError = "journal+console";
            Type = "oneshot";
          };

        }

      ) cfg.services;

    };
  };
}

