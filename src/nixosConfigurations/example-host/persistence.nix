{ inputs, config, lib, ... }:
{
  flake.modules.nixos.example-host =
    { lib, pkgs, ... }:
    {
      imports = [
        inputs.impermanence.nixosModules.impermanence
      ];

      environment.persistence."/persistent/system" = {
        enable = true;
        hideMounts = true;
        directories = [
          "/var/lib/nixos"                # To persist NixOS state 
          "/var/lib/systemd/coredump"     # To persist coredumps 
          "/var/lib/systemd/timers"       # To persist timer states 
          "/var/lib/udisks2"              # To persist USB device authorizations
          "/var/log"                      # To persist logs 
          "/home"                         # To persist user data 
        ];
        files = [
          "/etc/machine-id" # You may need to delete this file manually once to get it regenerated
          # "/var/lib/logrotate.status" # TODO: doesn't play nicely with the service yet
        ];
      };

      fileSystems."/persistent" = {
        neededForBoot = true;
      };
    };
}

