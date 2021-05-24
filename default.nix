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

  less = callOverlay ./pkgs/less.nix;

  sqlite = callOverlay ./pkgs/sqlite.nix;

  weechat-unwrapped = callOverlay ./pkgs/weechat.nix;
}
