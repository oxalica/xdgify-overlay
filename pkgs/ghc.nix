# TODO: Upstream migrates to XDG paths in 9.2.1 or later.
# https://github.com/ghc/ghc/commit/763d28551de32377a1dca8bdde02979e3686f400
{ prev, final, makeTransWrapper, migrate, preload_redirect, ... }:
makeTransWrapper prev.ghc [ "out" ] (pkg: {
  pre = ''
    data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/ghc"
    conf_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    [[ "$data_dir" != *:* && "$conf_home" != *:* ]]
    ${migrate} \
      "$HOME/.ghc/ghci.conf" "$conf_home/.ghci" \
      "$HOME/.ghci" "$conf_home/.ghci" \
      "$HOME/.ghc" "$data_dir"
    mkdir -p "$data_dir"
    export PRELOAD_REDIRECT_PATHS="$HOME/.ghci:$conf_home/.ghci:$HOME/.ghc:$data_dir:"
    export LD_PRELOAD=${preload_redirect}''${LD_PRELOAD:+:}"$LD_PRELOAD"
  '';

  command = ''
    shopt -s extglob
    mkdir -p "$out/bin"
    ln -st "$out" "${pkg}"/!(bin)

    ghci_bin="ghci-${pkg.version}"
    [[ -f "${pkg}/bin/$ghci_bin" ]]
    for f in "${pkg}"/bin/!("$ghci_bin"); do
      if [[ -L "$f" ]]; then
        ln -s "$(readlink "$f")" "$out/bin/$(basename "$f")"
      else
        ln -s "$f" "$out/bin/$(basename "$f")"
      fi
    done

    makeWrapper "${pkg}/bin/$ghci_bin" "$out/bin/$ghci_bin" \
      --run "$pre"
  '';
})
