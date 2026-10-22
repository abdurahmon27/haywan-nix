{
  description = "haywan-nix — a simple, modular NixOS + Home Manager setup (Hyprland, Gruvbox)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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

      # `default` is for working on this repo. The rest are toolchains for other
      # projects: put one line in the project's .envrc and direnv loads it on `cd`:
      #   use flake ~/Developer/haywan-nix#node24
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          default = pkgs.mkShell { packages = with pkgs; [ nixpkgs-fmt nil ]; };
          node24 = pkgs.mkShell { packages = with pkgs; [ nodejs_24 pnpm yarn ]; };
          node22 = pkgs.mkShell { packages = with pkgs; [ nodejs_22 pnpm yarn ]; };
          go = pkgs.mkShell { packages = with pkgs; [ go gopls golangci-lint ]; };
          # uv picks the Python version from the project's pyproject / .python-version.
          python = pkgs.mkShell {
            packages = with pkgs; [ python3 uv ];
            UV_PYTHON_DOWNLOADS = "automatic";
          };
        });
    };
}
