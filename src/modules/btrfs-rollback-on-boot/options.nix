{ inputs, config, lib, ... }:
{
  flake.modules.nixos.btrfs-rollback-on-boot =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.btrfs-rollback-on-boot;
  in
  {
    options.btrfs-rollback-on-boot.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Btrfs root rollback on boot functionality.";
    };


    options.btrfs-rollback-on-boot = {
      
      services = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable Btrfs filesystem management.";
            };

            btrfsDevice = lib.mkOption {
              type = lib.types.str;
              description = "The device containing the root of the Btrfs filesystem.";
            };

            createSnapshots = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to create snapshots before wiping.
              '';
            };

            garbageCollectSnapshots = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether or not to delete snapshots older than
                snapshotRetentionAmountOfDays.
              '';
            };

            snapshotRetentionAmountOfDays = lib.mkOption {
              type = lib.types.int;
              default = 30;
              description = ''
                How many days to retain snapshots for.
              '';
            };
            
            subvolumeToWipe = lib.mkOption {
              description = "The subvolume to wipe on startup.";
              type = lib.types.submodule {
                options = {

                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "The path to the subvolume from the root of the Btrfs filesystem.";
                  };
                };
              };
            };

            subvolumeForPersistence = lib.mkOption {
              description = ''
                The subvolume used for persistence.
              '';
              type = lib.types.submodule {
                options = {

                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "The path to the subvolume from the root of the Btrfs filesystem.";
                  };
                };
              };
            };
          };
        });
      };

      rollbackServiceScripts = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = {};
        internal = true;
        description = "Internal map of service names to their generated rollback scripts.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.boot.initrd.systemd.enable;
          message = ''
            btrfs-rollback-on-boot requires 'boot.initrd.systemd.enable = true;'
          '';
        }
        {
          assertion = config.services.userborn.enable;
          message = ''
            btrfs-rollback-on-boot requires 'services.userborn.enable = true;'

            See https://github.com/NixOS/nixpkgs/issues/6481#issuecomment-3381105884 for more info.

            Also see https://github.com/nikstur/userborn to learn more about Userborn.
          '';
        }
      ];
    };

  };
}

