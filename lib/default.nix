{ inputs }:

let
  inherit (inputs.nixpkgs) lib;

  mkHost = name: path:
    lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        inputs.home-manager.nixosModules.home-manager
        ../modules/nixos
        (path + "/default.nix")
        ({ config, ... }: {
          networking.hostName = lib.mkDefault name;

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            # Existing dotfiles are renamed to *.hm-bak instead of blocking activation.
            backupFileExtension = "hm-bak";
            extraSpecialArgs = { inherit inputs; };
            sharedModules = [ ../modules/home ];
            users.${config.haywan.user.name} = import (path + "/home.nix");
          };
        })
      ];
    };
in
{
  inherit mkHost;

  # One nixosConfiguration per sub-directory of ./hosts.
  mkHosts = dir:
    lib.mapAttrs (name: _: mkHost name (dir + "/${name}"))
      (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
}
