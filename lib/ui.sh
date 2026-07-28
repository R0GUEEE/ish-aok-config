#!/bin/sh
select_ui(){ if have dialog; then UI=dialog; elif have whiptail; then UI=whiptail; else UI=text; fi; }
ui_msg(){ title=$1; text=$2; case $UI in dialog) dialog --clear --backtitle "$BACKTITLE" --title "$title" --msgbox "$text" 22 78;; whiptail) whiptail --title "$title" --msgbox "$text" 22 78;; *) printf '\n== %s ==\n%s\n' "$title" "$text" >&2; printf 'Press Enter...' >&2; IFS= read -r _x || true;; esac; }
ui_text(){ title=$1; text=$2; case $UI in dialog) printf '%s\n' "$text" >"$TMP_DIR/text"; dialog --clear --backtitle "$BACKTITLE" --title "$title" --textbox "$TMP_DIR/text" 24 90;; whiptail) ui_msg "$title" "$text";; *) ui_msg "$title" "$text";; esac; }
ui_yesno(){ title=$1; text=$2; case $UI in dialog) dialog --clear --backtitle "$BACKTITLE" --title "$title" --yesno "$text" 18 76;; whiptail) whiptail --title "$title" --yesno "$text" 18 76;; *) printf '%s [y/N]: ' "$text" >&2; IFS= read -r a || return 1; case $a in y|Y|yes|YES) return 0;; *) return 1;; esac;; esac; }
ui_input(){ title=$1; text=$2; init=${3:-}; case $UI in dialog) dialog --stdout --clear --backtitle "$BACKTITLE" --title "$title" --inputbox "$text" 12 76 "$init";; whiptail) whiptail --title "$title" --inputbox "$text" 12 76 "$init" 3>&1 1>&2 2>&3;; *) printf '%s [%s]: ' "$text" "$init" >&2; IFS= read -r a || return 1; printf '%s' "${a:-$init}";; esac; }

UI_MENU_BACK_RC=${UI_MENU_BACK_RC:-90}
ui_menu_is_back(){ case ${1:-} in back|return|previous|__back__|@return) return 0;; *) return 1;; esac; }

# Store menu rows in a temporary file and retrieve by line number. This avoids
# eval, stale variables from earlier menus, and interpretation of arbitrary tags.
ui_menu(){
  title=$1; text=$2; shift 2
  selected=
  case $UI in
    dialog)
      selected=$(dialog --stdout --clear --cancel-label Back --backtitle "$BACKTITLE" --title "$title" --menu "$text" 24 92 16 "$@")
      _ui_rc=$?
      [ "$_ui_rc" -eq 0 ] || return "$UI_MENU_BACK_RC"
      ;;
    whiptail)
      selected=$(whiptail --title "$title" --cancel-button Back --menu "$text" 24 92 16 "$@" 3>&1 1>&2 2>&3)
      _ui_rc=$?
      [ "$_ui_rc" -eq 0 ] || return "$UI_MENU_BACK_RC"
      selected=$(printf '%s' "$selected" | tr -d '"')
      ;;
    *)
      _ui_file="$TMP_DIR/menu.$$"
      : >"$_ui_file" || return 1
      i=1
      while [ "$#" -ge 2 ]; do
        printf '%s\t%s\n' "$1" "$2" >>"$_ui_file"
        i=$((i+1)); shift 2
      done
      printf '\n== %s ==\n%s\n' "$title" "$text" >&2
      # Reprint after header for compatibility with previous visual ordering.
      i=1
      while IFS="$(printf '\t')" read -r _tag _label; do
        printf '%2s) %-18s %s\n' "$i" "$_tag" "$_label" >&2
        i=$((i+1))
      done <"$_ui_file"
      printf 'Selection (blank=Back): ' >&2
      IFS= read -r n || { rm -f "$_ui_file"; return "$UI_MENU_BACK_RC"; }
      [ -n "$n" ] || { rm -f "$_ui_file"; return "$UI_MENU_BACK_RC"; }
      case $n in *[!0-9]*|0) rm -f "$_ui_file"; return "$UI_MENU_BACK_RC";; esac
      selected=$(sed -n "${n}s/$(printf '\t').*//p" "$_ui_file")
      rm -f "$_ui_file"
      [ -n "$selected" ] || return "$UI_MENU_BACK_RC"
      ;;
  esac
  ui_menu_is_back "$selected" && return "$UI_MENU_BACK_RC"
  printf '%s' "$selected"
}

# Plain checklist accepts comma/space-separated numbers. Empty input returns
# the items whose initial state is "on". Output is one tag per line.
ui_checklist(){
  title=$1; text=$2; shift 2
  case $UI in
    dialog)
      dialog --stdout --separate-output --clear --backtitle "$BACKTITLE" --title "$title" --checklist "$text" 24 92 16 "$@"
      ;;
    whiptail)
      _ui_out=$(whiptail --title "$title" --checklist "$text" 24 92 16 "$@" 3>&1 1>&2 2>&3)
      _ui_rc=$?
      [ "$_ui_rc" -eq 0 ] || return "$UI_MENU_BACK_RC"
      printf '%s\n' "$_ui_out" | tr -d '"' | tr ' ' '\n' | sed '/^$/d'
      ;;
    *)
      _ui_file="$TMP_DIR/checklist.$$"; : >"$_ui_file" || return 1
      i=1
      printf '\n== %s ==\n%s\n' "$title" "$text" >&2
      while [ "$#" -ge 3 ]; do
        printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$_ui_file"
        [ "$3" = on ] && mark=x || mark=' '
        printf '%2s) [%s] %-18s %s\n' "$i" "$mark" "$1" "$2" >&2
        i=$((i+1)); shift 3
      done
      printf 'Selections (numbers separated by spaces/commas; blank=defaults; 0=Back): ' >&2
      IFS= read -r answer || { rm -f "$_ui_file"; return "$UI_MENU_BACK_RC"; }
      [ "$answer" = 0 ] && { rm -f "$_ui_file"; return "$UI_MENU_BACK_RC"; }
      if [ -z "$answer" ]; then
        awk -F '\t' '$3=="on"{print $1}' "$_ui_file"
      else
        _ui_numbers="$TMP_DIR/checklist-numbers.$$"
        printf '%s\n' "$answer" | tr ',' ' ' | tr ' ' '\n' >"$_ui_numbers"
        while IFS= read -r n; do
          case $n in ''|*[!0-9]*) continue;; esac
          sed -n "${n}s/$(printf '\t').*//p" "$_ui_file"
        done <"$_ui_numbers"
        rm -f "$_ui_numbers"
      fi
      rm -f "$_ui_file"
      ;;
  esac
}

ui_radiolist(){
  title=$1; text=$2; shift 2
  case $UI in
    dialog)
      dialog --stdout --clear --backtitle "$BACKTITLE" --title "$title" --radiolist "$text" 24 92 16 "$@"
      ;;
    whiptail)
      _ui_out=$(whiptail --title "$title" --radiolist "$text" 24 92 16 "$@" 3>&1 1>&2 2>&3)
      _ui_rc=$?
      [ "$_ui_rc" -eq 0 ] || return "$UI_MENU_BACK_RC"
      printf '%s' "$_ui_out" | tr -d '"'
      ;;
    *)
      set -- "$@"
      _ui_file="$TMP_DIR/radiolist.$$"; : >"$_ui_file" || return 1
      while [ "$#" -ge 3 ]; do printf '%s\t%s\n' "$1" "$2" >>"$_ui_file"; shift 3; done
      set --
      while IFS="$(printf '\t')" read -r _tag _label; do set -- "$@" "$_tag" "$_label"; done <"$_ui_file"
      rm -f "$_ui_file"
      ui_menu "$title" "$text" "$@"
      ;;
  esac
}
ui_password(){ title=$1; text=$2; case $UI in dialog) dialog --stdout --clear --insecure --backtitle "$BACKTITLE" --title "$title" --passwordbox "$text" 12 76;; whiptail) whiptail --title "$title" --passwordbox "$text" 12 76 3>&1 1>&2 2>&3;; *) stty -echo 2>/dev/null || true; printf '%s: ' "$text" >&2; IFS= read -r a || { stty echo 2>/dev/null || true; return 1; }; stty echo 2>/dev/null || true; printf '\n' >&2; printf '%s' "$a";; esac; }
