{ inputs, config, lib, ... }:
{
  flake.modules.nixos.btrfs-root-wipe =
  { lib, pkgs, ... }:
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
            
            subvolumeToWipe = lib.mkOption {
              description = "The subvolume to wipe on startup.";
              type = lib.types.submodule {
                options = {

                  device = lib.mkOption {
                    type = lib.types.str;
                    description = "The Btrfs device containing the subvolume.";
                  };

                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "The path to the subvolume from the root of the Btrfs filesystem.";
                  };
                  
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "The name of the subvolume.";
                  };

                  mountPoint = lib.mkOption {
                    type = lib.types.str;
                    description = "The mount point for the subvolume onto your system.";
                  };

                };
              };
            };

            createSnapshots = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to create snapshots before wiping.
                Requires that 'subvolumeForPersistence' is set.
              '';
            };

            subvolumeForPersistence = lib.mkOption {
              description = ''
                The subvolume used for persistence.
                If null, no root snapshots will be created.
              '';
              default = null;
              type = lib.types.nullOr lib.types.submodule {
                options = {

                  device = lib.mkOption {
                    type = lib.types.str;
                    description = "The Btrfs device containing the subvolume.";
                  };

                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "The path to the subvolume from the root of the Btrfs filesystem.";
                  };
                  
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "The name of the subvolume.";
                  };

                  mountPoint = lib.mkOption {
                    type = lib.types.str;
                    description = "The mount point for the subvolume.";
                  };

                };
              };
            };
          };
        });
      };

      rollbackServiceScripts = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        internal = true;
        description = "Internal map of service names to their generated rollback scripts.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = (!config.boot.initrd.systemd.enable);
          message = "btrfs-rollback-on-boot requires 'boot.initrd.systemd.enable = true;'";
        }
      ];
    };

  };
}

