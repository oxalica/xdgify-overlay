final: prev:
let
  util = import ./util.nix final prev;
  callOverlay = path: import path {
    inherit final prev;
    inherit (util) migrate migrate-gui makeTransWrapper;
  };
in
{
  xdgify-overlay = {
    enable-migrate = true;
    migrate-gui-flavor = "kdialog";
  };

  inherit (callOverlay ./pkgs/electrum-like.nix) electrum electrum-ltc electron-cash;

  sqlite = callOverlay ./pkgs/sqlite.nix;
}
