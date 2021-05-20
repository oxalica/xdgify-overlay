{
  description = ''
    Wrap programs to respect XDG spec paths.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: let

    overlay = import ./.;

    allSystems = [
      "aarch64-linux"
      "armv6l-linux"
      "armv7a-linux"
      "armv7l-linux"
      "x86_64-linux"
      "x86_64-darwin"
      # "aarch64-darwin"
    ];

  in {
    overlay = final: prev: overlay final prev;
  } // flake-utils.lib.eachSystem allSystems (system: {
    legacyPackages = import nixpkgs {
      inherit system;
      overlays = [ overlay ];
    };
  });
}
