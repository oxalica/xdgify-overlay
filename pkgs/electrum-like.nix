{ prev, final, migrate-gui, ... }:
let
  wrap = pkg: bin: final.runCommandLocal pkg.name {
    nativeBuildInputs = [ final.makeWrapper final.xorg.lndir ];
  } ''
    mkdir -p $out
    lndir ${pkg} $out

    rm $out/bin/${bin}
    makeWrapper ${pkg}/bin/${bin} $out/bin/${bin} \
      --run '${migrate-gui} ~/.${bin} "''${XDG_DATA_HOME:-$HOME/.local/share}/${bin}"' \
      --add-flags "-D" \
      --add-flags '"''${XDG_DATA_HOME:-$HOME/.local/share}/${bin}"' \

    if [[ -e $out/share/applications/${bin}.desktop ]]; then
      rm $out/share/applications/${bin}.desktop
      sed -E 's#${pkg}#'"$out"'#' \
        ${pkg}/share/applications/${bin}.desktop \
        > $out/share/applications/${bin}.desktop
    fi
  '';
in
{
  electrum = wrap prev.electrum "electrum";
  electrum-ltc = wrap prev.electrum-ltc "electrum-ltc";
  electron-cash = wrap prev.electron-cash "electron-cash";
}
