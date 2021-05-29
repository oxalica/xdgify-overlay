final: prev:
let
  util = import ./util.nix final prev;
  callOverlay = path: import path {
    inherit final prev;
    inherit (util) migrate makeTransWrapper preload_redirect;
  };

  defaultPkgs = rec {
    inherit (callOverlay ./pkgs/electrum-like.nix) electrum electrum-ltc electron-cash;

    less = callOverlay ./pkgs/less.nix;

    sqlite = callOverlay ./pkgs/sqlite.nix;

    inherit (callOverlay ./pkgs/vim.nix) vim vim_configurable xxd;

    unixtools = prev.unixtools // { inherit xxd; };

    weechat-unwrapped = callOverlay ./pkgs/weechat.nix;
  };

  nonDefaultPkgs = {
    ghc = callOverlay ./pkgs/ghc.nix;
  };

in
defaultPkgs // {
  xdgify-overlay = defaultPkgs // nonDefaultPkgs // {
    enable-migrate = true;
    migrate-gui-flavor = "kdialog";
  };
}
