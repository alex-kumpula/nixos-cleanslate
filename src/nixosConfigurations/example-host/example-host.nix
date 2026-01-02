{ inputs, ... }:
{
  flake.nixosConfigurations.example-host = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with inputs.self.modules.nixos; [ 
      example-host
      btrfs-root-wipe
    ];
  };
}