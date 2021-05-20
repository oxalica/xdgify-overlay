final: prev:
let
  inherit (import ./migrate.nix final prev) migrate migrate-gui;
  outputs = map (path: import path {
    inherit final prev migrate migrate-gui;
  }) (import ./pkgs);
in
  builtins.foldl' (x: y: x // y) {} outputs // {
    xdgify-overlay = {
      enable-migrate = true;
      migrate-gui-flavor = "kdialog";
    };
  }
