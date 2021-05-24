{ prev, final, makeTransWrapper, migrate, ... }:
makeTransWrapper prev.less [ "out" ] (pkg: {
  checkMigrate = ''
    args=()
    if [[ -z "$LESSKEY" ]]; then
      export LESSKEY="''${XDG_CONFIG_HOME:-$HOME/.config}/less"
      args+=(~/.less "$LESSKEY")
    fi
    if [[ -z "$LESSHISTFILE" ]]; then
      export LESSHISTFILE="''${XDG_DATA_HOME:-$HOME/.local/share}/less/history"
      args+=(~/.lesshst "$LESSHISTFILE")
    fi
    [[ "''${#args[@]}" != 0 ]] && ${migrate} "''${args[@]}"
  '';

  command = ''
    mkdir -p $out/bin
    ln -st $out ${pkg}/share
    ln -st $out/bin ${pkg}/bin/lessecho
    for name in less{,key}; do
      makeWrapper ${pkg}/bin/$name $out/bin/$name \
        --run "$checkMigrate"
    done
  '';
})
