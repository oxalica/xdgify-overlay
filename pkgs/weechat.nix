{ final, prev, makeTransWrapper, migrate, ... }:
makeTransWrapper prev.weechat-unwrapped [ "out" ] (pkg: {
  checkMigrate = ''
    if [[ -z "$WEECHAT_HOME" ]]; then
      export WEECHAT_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/weechat"
      ${migrate} ~/.weechat "$WEECHAT_HOME"
    fi
  '';
  command = ''
    shopt -s extglob
    mkdir -p $out/bin
    ln -st $out ${pkg}/!(bin)
    for name in weechat{,-headless}; do
      makeWrapper "${pkg}/bin/$name" "$out/bin/$name" \
        --run "$checkMigrate"
    done
    ln -s weechat $out/bin/weechat-curses
  '';
})
