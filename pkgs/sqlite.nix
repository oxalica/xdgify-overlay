{ prev, final, makeTransWrapper, migrate, ... }:
makeTransWrapper prev.sqlite [ "bin" ] (pkg: {
  checkMigrate = ''
    if [[ -z "$SQLITE_HISTORY" ]]; then
      export SQLITE_HISTORY="''${XDG_DATA_HOME:-$HOME/.local/share}/sqlite/history"
      ${migrate} ~/.sqlite_history "$SQLITE_HISTORY"
    fi
  '';
  command = ''
    mkdir -p $bin/bin
    ln -s ${pkg}/share $bin/share
    makeWrapper ${pkg}/bin/sqlite3 $bin/bin/sqlite3 \
      --run "$checkMigrate"
  '';
})
