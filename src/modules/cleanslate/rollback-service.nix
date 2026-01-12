{ inputs, config, lib, ... }:
{
  flake.modules.nixos.cleanslate =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.cleanslate;
  in
  {
    config = lib.mkIf cfg.enable {

      boot.initrd.systemd.services = lib.mapAttrs' (
        name: serviceCfg: lib.nameValuePair "${name}" {
          
          # wantedBy = ["initrd-root-device.target"];
          wantedBy = ["initrd-root-fs.target"];
          # wants = ["lvm2-activation.service"];
          # See https://github.com/nix-community/impermanence/issues/250#issuecomment-2603848867
          # after = ["lvm2-activation.service" "local-fs-pre.target" "cryptsetup.target"];
          # before = ["sysroot.mount"];
          after = [
            "local-fs-pre.target"
            "initrd-root-fs.target"
          ];
          before = ["sysroot.mount"];
          # Run on cold boot only, never on resume from hibernation
          unitConfig = {
            ConditionKernelCommandLine = ["!resume="];
            RequiresMountsFor = [serviceCfg.btrfsDevice];
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

