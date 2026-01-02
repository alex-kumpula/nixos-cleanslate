{ inputs, config, lib, ... }:
{
  flake.modules.nixos.btrfs-root-wipe =
    { lib, ... }:
    {
      options.btrfs-root-wipe = {
        mainDisk = lib.mkOption {
          type = lib.types.str;
          default = "/dev/vda";
          description = "The main disk device.";
        };
      };
    };
}