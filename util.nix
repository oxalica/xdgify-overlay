final: prev:
let
  inherit (final) lib;

  enable = final.xdgify-overlay.enable-migrate;
  flavor = final.xdgify-overlay.migrate-gui-flavor;

  migrate-script = final.writeShellScript "xdgify-migrate" ''
    set -e

    gui=
    if [[ "$1" == "--gui" ]]; then
      [[ -n "$DISPLAY" ]] && gui=1
      shift
    fi

    srcs=()
    dests=()
    msg=
    src_found=
    while [[ $# -ne 0 ]]; do
      srcs+="$1"
      dests+="$2"
      msg+=$'\n'"$1 -> $2"
      [[ -e "$1" ]] && src_found=1
      shift 2
    done

    # If no original paths found, we are okay.
    [[ -z "$src_found" ]] && exit 0

    # Otherwise we should prompt to migrate.

    dialog_confirm_migrate() {
      local msg inp
      msg="xdgify-overlay: $1"
      if [[ -n "$gui" ]]; then
        ${
          if flavor == "kdialog" then ''${final.kdialog}/bin/kdialog --yesno "$msg"; return''
          else if flavor == "none" then ""
          else throw "Unknow migrate-gui-flavor: ${flavor}"
        }
      fi
      echo "$msg" >&2
      if [[ ! -t 0 || ! -t 2 ]]; then
        echo "xdgify-overlay: stdin or stderr is not tty, exit" >&2
        exit 1
      fi

      while echo -n "xdgify-overlay: Confirm migrate? [y/N] " >&2 && read -r inp; do
        case "$inp" in
          y|Y)
            return;;
          n|N|"")
            exit 1;;
          *)
            ;;
        esac
      done
    }

    dialog_error() {
      local msg="xdgify-overlay: $1"
      if [[ -n "$gui" ]]; then
        ${
          if flavor == "kdialog" then ''${final.kdialog}/bin/kdialog --error "$msg"; exit 1''
          else if flavor == "none" then ""
          else throw "Unknow migrate-gui-flavor: ${flavor}"
        }
      fi
      echo "$msg" >&2
      exit 1
    }

    dialog_confirm_migrate "Migration required:$msg"

    for (( i = 0; i < "''${#srcs[@]}"; ++i )); do
      if [[ -e "''${dests[i]}" ]]; then
        dialog_error "Target path already exists: ''${dests[i]}"$'\n'"Please migrate manually."
      fi
      if ! ( mkdir -p "$(dirname "''${dests[i]}")" && mv -T "''${srcs[i]}" "''${dests[i]}" ); then
        dialog_error "Move failed: ''${srcs[i]} -> ''${dests[i]}"$'\n'"Please migrate manually."
      fi
    done
  '';

  # Make a (nearly) transparent wrapper over a package.
  #
  # It overrides some outputs `overrideOuts` of the original package, keep some meta attributes,
  # make `override{,Attrs}` applied to the original package (and wrap it after).
  makeTransWrapper = pkg: overrideOuts: wrapper: let
    opts = wrapper pkg;
    parsed = builtins.parseDrvName pkg.name;

    # Workaround. Since outputs must contains "out".
    noOut = !lib.elem "out" overrideOuts;

    command = opts.command + lib.optionalString noOut ''
      touch "$out"
    '';

    opts' = {
      outputs = overrideOuts ++ lib.optional noOut "out";
      nativeBuildInputs = [ final.makeWrapper ] ++ (opts.nativeBuildInputs or []);

      passthru = {
        inherit (pkg) outputs;
        override = arg: makeTransWrapper (pkg.override arg) overrideOuts wrapper;
        overrideAttrs = arg: makeTransWrapper (pkg.overrideAttrs arg) overrideOuts wrapper;
        __before_xdgify = pkg;

      # Forward unchanged outputs (like libraries) to the original derivation.
      } // lib.genAttrs (lib.subtractLists overrideOuts pkg.outputs) (out: pkg.${out});
    }
    // lib.optionalAttrs (pkg ? pname) { inherit (pkg) pname; }
    // lib.optionalAttrs (pkg ? version) { inherit (pkg) version; }
    // lib.optionalAttrs (pkg ? src) { inherit (pkg) src; }
    // lib.optionalAttrs (pkg ? meta) { inherit (pkg) meta; }
    // removeAttrs opts [ "nativeBuildInputs" "command" ];

    wrapped = final.runCommandLocal "${parsed.name}-xdgify-${parsed.version}" opts' command;

  in
    # Currently we always overrides the default output.
    assert lib.elem (lib.head pkg.outputs) overrideOuts;
    wrapped;

in rec {
  migrate = if enable then "${migrate-script}" else ":";
  migrate-gui = "${migrate} --gui";
  inherit makeTransWrapper;
}
