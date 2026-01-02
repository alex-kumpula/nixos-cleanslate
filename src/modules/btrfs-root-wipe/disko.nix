{ inputs, ... }:
{
  flake-file.inputs = {
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  imports = [
    inputs.disko.flakeModules.default
  ];

  flake.modules.nixos.btrfs-root-wipe = {
    imports = [
      inputs.disko.nixosModules.default
    ];
  };
}