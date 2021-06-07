{ prev, final, makeTransWrapper, migrate, ... }:
let
  initStr = ''
    if empty($XDG_CACHE_HOME)
      let $XDG_CACHE_HOME=$HOME."/.cache"
    endif
    if empty($XDG_CONFIG_HOME)
      let $XDG_CONFIG_HOME=$HOME."/.config"
    endif
    if empty($XDG_DATA_HOME)
      let $XDG_DATA_HOME=$HOME."/.local/share"
    endif

    set directory=$XDG_CACHE_HOME/vim/swap
    set backupdir=$XDG_CACHE_HOME/vim/backup
    set undodir=$XDG_CACHE_HOME/vim/undo
    set runtimepath=$XDG_DATA_HOME/vim,$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after,$XDG_DATA_HOME/vim/after
    set viminfofile=$XDG_CACHE_HOME/vim/viminfo

    let g:coc_config_home=$XDG_CONFIG_HOME."/vim"
    let g:coc_data_home=$XDG_DATA_HOME."/vim"
  '';

  # This loads init scripts, but some paths are modified.
  # See `:help initialization` in vim.
  initFile = final.writeText "xdgify-vim-init.vim" (initStr + ''
    if filereadable($XDG_CONFIG_HOME."/vim/vimrc")
      let $MYVIMRC=$XDG_CONFIG_HOME."/vim/vimrc"
    endif
    if !empty($VIMINIT)
      set nocompatible
      execute $VIMINIT
    elseif !empty($MYVIMRC)
      set nocompatible
      execute "source ".fnameescape($MYVIMRC)
    elseif !empty($EXINIT)
      execute $EXINIT
    elseif filereadable($XDG_CONFIG_HOME."/vim/exrc")
      execute "source ".fnameescape($XDG_CONFIG_HOME."/vim/exrc")
    elseif filereadable($VIMRUNTIME."/defaults.vim")
      set nocompatible
      execute "source ".fnameescape($VIMRUNTIME."/defaults.vim")
    endif
  '');

  checkMigrate = ''
    : ''${XDG_CONFIG_HOME:=$HOME/.config} \
      ''${XDG_CACHE_HOME:=$HOME/.cache} \
      ''${XDG_DATA_HOME:=$HOME/.local/share}
    ${migrate} ''${migrate_gui:-} \
      ~/.vimrc      "$XDG_CONFIG_HOME/vim/vimrc" \
      ~/_vimrc      "$XDG_CONFIG_HOME/vim/vimrc" \
      ~/.vim/.vimrc "$XDG_CONFIG_HOME/vim/vimrc" \
      ~/.exrc       "$XDG_CONFIG_HOME/vim/exrc" \
      ~/_exrc       "$XDG_CONFIG_HOME/vim/exrc" \
      ~/.viminfo    "$XDG_CACHE_HOME/vim/viminfo" \
      ~/.vim        "$XDG_DATA_HOME/vim"
    mkdir -p "$XDG_CACHE_HOME"/vim/{swap,backup,undo} 2>/dev/null || true
    [[ -f ~/.viminfo.tmp ]] && rm -f ~/.viminfo.tmp
  '';

in
{
  vim = makeTransWrapper prev.vim [ "out" ] (pkg: {
    inherit checkMigrate;
    command = ''
      shopt -s extglob
      mkdir -p $out/bin
      ln -st $out ${pkg}/share
      ln -st $out/bin ${pkg}/bin/{xxd,vimtutor}
      for name in ex rview rvim vi view vimdiff; do
        ln -s vim "$out/bin/$name"
      done
      makeWrapper ${pkg}/bin/vim $out/bin/vim \
        --run "$checkMigrate" \
        --argv0 '$0' \
        --add-flags '-u ${initFile} -U ${initFile}'
    '';
  });

  vim_configurable = let
    wrapCommand = pkg: overrideInit: ''
      mkdir -p $out/bin
      ln -st $out ${pkg}/share
      for f in ${pkg}/bin/*; do
        name="$(basename "$f")"
        if [[ "$name" = g* ]]; then
          migrate=$'migrate_gui=--gui\n'"$checkMigrate"
        else
          migrate="$checkMigrate"
        fi
        makeWrapper "$f" "$out/bin/$name" \
          --run "$migrate" \
          ${final.lib.optionalString overrideInit "--add-flags '-u ${initFile} -U ${initFile}'"}
      done
    '';

    wrapConfigurable = pkg: makeTransWrapper pkg [ "out" ] (pkg: {
      inherit checkMigrate;
      command = wrapCommand pkg true;
      passthru = {
        override = arg: wrapConfigurable (pkg.override arg);
        overrideAttrs = arg: wrapConfigurable (pkg.overrideAttrs arg);
        customize = arg: let
          arg' = arg // {
            vimrcConfig = (arg.vimrcConfig or {}) // {
              beforePlugins =
                # Default value.
                final.lib.optionalString (!(arg ? vimrcConfig.beforePlugins)) ''
                  " configuration generated by NIX
                  set nocompatible
                '' +
                initStr +
                (arg.vimrcConfig.beforePlugins or "");
            };
          };
        in wrapCustomized (pkg.customize arg');
      };
    });

    wrapCustomized = pkg: makeTransWrapper pkg [ "out" ] (pkg: {
      inherit checkMigrate;
      command = wrapCommand pkg false;
    });

  in
    wrapConfigurable prev.vim_configurable;

  # It is forwarded to `vim` but we don't touch it. Keep the original one to reduce rebuilds.
  # Note that it use `vim` from final pkgs, so we cannot simply use `prev.xxd`.
  # From: pkgs/top-level/unixtools.nix
  xxd = let
    # All unix tools have the same version. Choose random one to avoid self-reference.
    version = (builtins.parseDrvName prev.unixtools.arp.name).version;

    singleBinary = with final; with lib; cmd: providers: let
        provider = providers.${stdenv.hostPlatform.parsed.kernel.name} or providers.linux;
        bin = "${getBin provider}/bin/${cmd}";
        manpage = "${getOutput "man" provider}/share/man/man1/${cmd}.1.gz";
      in runCommand "${cmd}-${version}" {
        meta = {
          priority = 10;
          platforms = lib.platforms.${stdenv.hostPlatform.parsed.kernel.name} or lib.platforms.all;
        };
        passthru = { inherit provider; };
        preferLocalBuild = true;
      } ''
        if ! [ -x ${bin} ]; then
          echo Cannot find command ${cmd}
          exit 1
        fi

        mkdir -p $out/bin
        ln -s ${bin} $out/bin/${cmd}

        if [ -f ${manpage} ]; then
          mkdir -p $out/share/man/man1
          ln -s ${manpage} $out/share/man/man1/${cmd}.1.gz
        fi
      '';
  in
    singleBinary "xxd" {
      linux = prev.vim;
      darwin = prev.vim;
    };
}
