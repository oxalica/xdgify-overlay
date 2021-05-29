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
    while [[ $# -ne 0 ]]; do
      if [[ "$1" != /* || "$2" != /* ]]; then
        echo "xdgifiy-overlay: Paths must be absolute: $1 -> $2" >&2
        exit 1
      fi
      if [[ -e "$1" ]]; then
        srcs+=("$1")
        dests+=("$2")
        msg+=$'\n  '"$1 -> $2"
      fi
      shift 2
    done

    # If no original paths found, we are okay.
    [[ "''${#srcs[@]}" = 0 ]] && exit 0

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
      src="''${srcs[i]}"
      dest="''${dests[i]}"
      if [[ -L "$src" ]]; then
        dialog_error "Source path is a symbolic link: $src"$'\n'"Please migrate manually."
      fi
      if [[ -e "$dest" ]]; then
        dialog_error "Target path already exists: $dest"$'\n'"Please migrate manually."
      fi
      if ! ( mkdir -p "$(dirname "$dest")" && mv -T "$src" "$dest" ); then
        dialog_error "Move failed: $src -> $dest"$'\n'"Please migrate manually."
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

    name = "${parsed.name}-xdgify${lib.optionalString (parsed.version != "") "-${parsed.version}"}";

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
      }
      # Forward unchanged outputs (like libraries) to the original derivation.
      // lib.genAttrs (lib.subtractLists overrideOuts pkg.outputs) (out: pkg.${out})
      # Forward common attributes here to avoid fetching `src` when building wrapper.
      // lib.optionalAttrs (pkg ? pname) { inherit (pkg) pname; }
      // lib.optionalAttrs (pkg ? version) { inherit (pkg) version; }
      // lib.optionalAttrs (pkg ? src) { inherit (pkg) src; }
      // lib.optionalAttrs (pkg ? meta) { inherit (pkg) meta; }
      // (opts.passthru or {});
    }
    // removeAttrs opts [ "nativeBuildInputs" "command" "passthru" ];

    wrapped = final.runCommandLocal name opts' command;

  in
    # Currently we always overrides the default output.
    assert lib.elem (lib.head pkg.outputs) overrideOuts;
    wrapped;

in rec {
  migrate = if enable then "${migrate-script}" else ":";
  inherit makeTransWrapper;
  preload_redirect = "${final.callPackage ./preload_redirect {}}/lib/libpreload_redirect.so";
}
