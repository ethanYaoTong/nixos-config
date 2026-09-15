{ config, pkgs, ... }:

{
  imports = [
    ../../common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "pc";

  system.stateVersion = "25.11";
}
