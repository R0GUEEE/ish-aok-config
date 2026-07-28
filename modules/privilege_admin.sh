#!/bin/sh
sudoers_validate(){ have visudo && run_capture 'Validate sudoers' run_root visudo -cf /etc/sudoers || ui_msg sudoers 'visudo is not installed.'; }
sudoers_dropin(){
    u=$(ui_input sudoers 'Username:' "$CURRENT_USER") || return
    mode=$(ui_menu sudoers 'Privilege policy' all 'Passwordless all commands' commands 'Passwordless selected commands' password 'Require password for all commands') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $mode in
        all) rule="$u ALL=(ALL:ALL) NOPASSWD: ALL";;
        commands) cmds=$(ui_input sudoers 'Absolute commands, comma-separated:' '/usr/bin/apt-get, /usr/bin/systemctl') || return; rule="$u ALL=(ALL:ALL) NOPASSWD: $cmds";;
        password) rule="$u ALL=(ALL:ALL) ALL";;
    esac
    f="/etc/sudoers.d/90-ish-aok-$u"; write_file "$f" 440 "$rule"
    have visudo && run_root visudo -cf "$f" || true
}
sudo_defaults_wizard(){
    opts=$(ui_checklist sudoers 'Select managed Defaults.' envreset 'Reset environment' on mailbad 'Mail on bad password' off securepath 'Set secure_path' on ttytickets 'Separate credentials per terminal' on pwfeedback 'Show feedback while typing password' off timeout '15-minute credential timeout' on logio 'Log sudo input/output' off) || return
    body=''; echo "$opts" | grep -qx envreset && body="$body\nDefaults env_reset"; echo "$opts" | grep -qx mailbad && body="$body\nDefaults mail_badpass"; echo "$opts" | grep -qx securepath && body="$body\nDefaults secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\""; echo "$opts" | grep -qx ttytickets && body="$body\nDefaults tty_tickets"; echo "$opts" | grep -qx pwfeedback && body="$body\nDefaults pwfeedback"; echo "$opts" | grep -qx timeout && body="$body\nDefaults timestamp_timeout=15"; echo "$opts" | grep -qx logio && body="$body\nDefaults log_input,log_output\nDefaults iolog_dir=/var/log/sudo-io"
    write_file /etc/sudoers.d/00-ish-aok-defaults 440 "${body#\\n}"; have visudo && run_root visudo -cf /etc/sudoers.d/00-ish-aok-defaults || true
}
doas_wizard(){ u=$(ui_input doas 'Username:' "$CURRENT_USER") || return; persist=$(ui_yesno doas 'Cache authentication briefly?'; echo $?); rule="permit"; [ "$persist" -eq 0 ] && rule="$rule persist"; ui_yesno doas 'Allow without a password?' && rule="$rule nopass"; rule="$rule $u as root"; write_file /etc/doas.conf 600 "$rule"; }
admin_group_add(){ u=$(ui_input Admin 'Username:' "$CURRENT_USER") || return; if getent group sudo >/dev/null 2>&1; then run_root usermod -aG sudo "$u"; elif getent group wheel >/dev/null 2>&1; then run_root usermod -aG wheel "$u"; else run_root groupadd sudo; run_root usermod -aG sudo "$u"; fi; }
privilege_admin_menu(){ while :; do c=$(ui_menu 'Privilege administration' 'Manage sudo, doas, groups, and validation.' install 'Install sudo or doas' nopass 'Create passwordless sudo policy' defaults 'Configure sudo Defaults' edit 'Edit sudoers with visudo' validate 'Validate all sudoers files' doas 'Generate doas.conf rule' group 'Add user to admin group' list 'List effective sudo configuration' remove 'Remove managed privilege policies') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in install) p=$(ui_menu Install 'Choose tool' sudo sudo doas doas) || continue; run_capture Install pkg_install "$p";; nopass) sudoers_dropin;; defaults) sudo_defaults_wizard;; edit) have visudo && run_root visudo || edit_file /etc/sudoers;; validate) sudoers_validate;; doas) doas_wizard;; group) admin_group_add;; list) ui_text sudoers "$(run_root sudo -l -U "$CURRENT_USER" 2>&1; find /etc/sudoers.d -maxdepth 1 -type f -print -exec sed -n '1,80p' {} \; 2>/dev/null)";; remove) for f in /etc/sudoers.d/90-ish-aok-* /etc/sudoers.d/00-ish-aok-defaults; do [ -e "$f" ] && run_root rm -i "$f"; done;; esac; done; }
