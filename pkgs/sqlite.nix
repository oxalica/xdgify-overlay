{ prev, final, migrate, ... }:
let
  wrap = pkg: final.runCommandLocal pkg.name {
    nativeBuildInputs = [ final.makeWrapper ];
  } ''
    mkdir -p $out/bin
    ln -s ${pkg}/share $out/share
    makeWrapper ${pkg}/bin/sqlite3 $out/bin/sqlite3 \
      --run '${migrate} ~/.sqlite_history "''${XDG_DATA_HOME:-$HOME/.local/share}/sqlite/history"' \
      --run 'export SQLITE_HISTORY="''${SQLITE_HISTORY:-"''${XDG_DATA_HOME:-$HOME/.local/share}/sqlite/history"}"'
  '';
in
{
  sqlite-interactive = wrap (prev.sqlite.override { interactive = true; });
  sqlite = let
    bin = wrap prev.sqlite // {
      inherit (prev.sqlite) dev out debug;
      inherit bin;
    };
  in bin;
}
