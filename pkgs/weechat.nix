{ final, prev, makeTransWrapper, migrate, ... }:
makeTransWrapper prev.weechat-unwrapped [ "out" ] (pkg: {
  command = ''
    shopt -s extglob
    mkdir -p $out/bin
    ln -st $out ${pkg}/!(bin)
    pre='
if [[ -z "$WEECHAT_HOME" ]]; then
  export WEECHAT_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/weechat"
  ${migrate} ~/.weechat "$WEECHAT_HOME"
fi'
    for name in weechat{,-headless}; do
      makeWrapper "${pkg}/bin/$name" "$out/bin/$name" \
        --run "$pre"
    done
    ln -s weechat $out/bin/weechat-curses
  '';
})
