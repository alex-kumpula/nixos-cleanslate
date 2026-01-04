{
  ...
}:
{
  flake.modules.nixos.example-host = 
  { ... }: 
  {
    hardware.facter.reportPath = ./facter.json;
  };
}