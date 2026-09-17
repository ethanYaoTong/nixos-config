{
  description = "Ethan's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, spicetify-nix }:
  let
    mkSystem = host: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/${host}/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit spicetify-nix; };
          home-manager.users.ethant = import ./home.nix;
        }
      ];
    };
  in {
    nixosConfigurations = {
      laptop = mkSystem "laptop";
      pc     = mkSystem "pc";
    };
  };
}
