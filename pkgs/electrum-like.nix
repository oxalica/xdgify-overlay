{ prev, final, makeTransWrapper, migrate-gui, ... }:
let
  wrap = pkg: bin: makeTransWrapper pkg [ "out" ] (pkg: {
    command = ''
      shopt -s extglob
      mkdir -p $out/bin
      ln -st $out ${pkg}/!(bin|share)
      if [[ -e ${pkg}/share ]]; then
        mkdir -p $out/share/applications
        ln -st $out/share ${pkg}/share/!(applications)
      fi

      makeWrapper ${pkg}/bin/${bin} $out/bin/${bin} \
        --run '${migrate-gui} ~/.${bin} "''${XDG_DATA_HOME:-$HOME/.local/share}/${bin}"' \
        --add-flags "-D" \
        --add-flags '"''${XDG_DATA_HOME:-$HOME/.local/share}/${bin}"' \

      if [[ -e ${pkg}/share/applications/${bin}.desktop ]]; then
        sed -E 's#${pkg}#'"$out"'#' \
          ${pkg}/share/applications/${bin}.desktop \
          > $out/share/applications/${bin}.desktop
      fi
    '';
  });

in
{
  electrum = wrap prev.electrum "electrum";
  electrum-ltc = wrap prev.electrum-ltc "electrum-ltc";
  electron-cash = wrap prev.electron-cash "electron-cash";
}
