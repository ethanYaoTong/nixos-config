{ config, pkgs, ... }:

{
  imports = [
    ../../common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "laptop";

  system.stateVersion = "25.11";
}
