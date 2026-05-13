{ inputs, config, lib, ... }:
{
  flake.modules.nixos.cleanslate =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.cleanslate;
  in
  {
    config = lib.mkIf cfg.enable {

      systemd.services = lib.mapAttrs' (
        name: serviceCfg: 
          lib.nameValuePair "${name}-pristine-boot-snapshot" {

            description = "Create a read‑only snapshot of the pristine boot root for change detection";
            after = [ "multi-user.target" "local-fs.target" ];
            requires = [ "multi-user.target" ];
            wantedBy = [ "multi-user.target" ];

            unitConfig.ConditionPathIsMountPoint = "/";

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = false;
              ExecStart = pkgs.writeShellScript "pristine-boot-snapshot" ''
                set -euo pipefail
                SNAPSHOT_TARGET="${serviceCfg.pristineBootSnapshot.snapshotPath}"

                mkdir -p "$(dirname "$SNAPSHOT_TARGET")"

                if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$SNAPSHOT_TARGET" &>/dev/null; then
                  ${pkgs.btrfs-progs}/bin/btrfs subvolume delete -R "$SNAPSHOT_TARGET"
                fi
                ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r / "$SNAPSHOT_TARGET"

                echo "Pristine boot snapshot created at $SNAPSHOT_TARGET"
              '';
            };

          }

      ) cfg.services;

    };
  };
}

