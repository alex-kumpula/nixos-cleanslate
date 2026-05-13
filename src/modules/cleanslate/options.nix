{ inputs, config, lib, ... }:
{
  flake.modules.nixos.cleanslate =
  { lib, pkgs, config, ... }:
  let 
      cfg = config.cleanslate;
  in
  {
    options.cleanslate.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Btrfs root rollback on boot functionality.";
    };


    options.cleanslate = {
      
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
              description = ''
                The device containing the Btrfs filesystem.
                This must be set.
              '';
            };

            createSnapshots = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to create snapshots before wiping.
              '';
            };

            snapshotOutputPath = lib.mkOption {
              type = lib.types.str;
              default = "/root-snapshots";
              description = ''
                The path to store the snapshots. 
                Relative to the root of the persistent subvolume.
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

            pristineBootSnapshot = lib.mkOption {
              type = lib.types.submodule {
                options = {

                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = ''
                      Enable taking a snapshot of / immediately after boot.
                    '';
                  };

                  snapshotPath = lib.mkOption {
                    type = lib.types.str;
                    default = "/pristine-boot";
                    description = ''
                      The path to store the snapshot. 
                      Relative to the root of the persistent subvolume.
                    '';
                  };

                };
              };
              default = {
                enable = true;
                snapshotPath = "/pristine-boot";
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
            cleanslate requires 'boot.initrd.systemd.enable = true;'
          '';
        }
      ];

      warnings = lib.optional (!config.services.userborn.enable) ''
        cleanslate works best with 'services.userborn.enable = true;'

        Without userborn, user directories inside /home may not be created automatically,
        and may need to be created by the root user.

        See:
          https://github.com/NixOS/nixpkgs/issues/6481#issuecomment-3381105884
          https://github.com/nikstur/userborn

        This may be fixed in the future by:
          https://github.com/NixOS/nixpkgs/pull/223932
      '';

    };

  };
}

