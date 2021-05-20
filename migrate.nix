final: prev:
let
  enable = final.xdgify-overlay.enable-migrate;
  flavor = final.xdgify-overlay.migrate-gui-flavor;

  script = final.writeShellScript "xdgify-migrate" ''
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

in rec {
  migrate = if enable then "${script}" else ":";
  migrate-gui = "${migrate} --gui";
}
