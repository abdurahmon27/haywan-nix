{
  description = "haywan-nix — a simple, modular NixOS + Home Manager setup (Hyprland, Gruvbox)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      lib = import ./lib { inherit inputs; };
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      # Every folder in ./hosts becomes a machine:
      #   sudo nixos-rebuild switch --flake .#<folder-name>
      nixosConfigurations = lib.mkHosts ./hosts;

      # Reuse the modules from your own flake:
      #   imports = [ haywan-nix.nixosModules.default ];
      nixosModules.default = ./modules/nixos;
      homeModules.default = ./modules/home;

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [ nixpkgs-fmt nil ];
        };
      });
    };
}
