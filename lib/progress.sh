#!/bin/sh
# Shared progress UI for long-running project operations.
PROGRESS_ENABLED=${ISH_AOK_PROGRESS:-yes}
PROGRESS_REFRESH=${ISH_AOK_PROGRESS_REFRESH:-1}

progress_last_line(){
    file=$1
    [ -s "$file" ] || { printf '%s' 'Starting operation…'; return; }
    tail -n 12 "$file" 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 1 | cut -c1-72
}

progress_text_spinner(){
    title=$1 pid=$2 logfile=$3
    spin='|/-\\'
    i=1
    while kill -0 "$pid" 2>/dev/null; do
        ch=$(printf '%s' "$spin" | cut -c "$i")
        line=$(progress_last_line "$logfile")
        printf '\r[%s] %s: %-72.72s' "$ch" "$title" "$line" >&2
        i=$((i + 1)); [ "$i" -le 4 ] || i=1
        sleep "$PROGRESS_REFRESH"
    done
    printf '\r[ ] %-78s\r' '' >&2
}

progress_dialog_gauge(){
    title=$1 pid=$2 logfile=$3
    (
        pct=3
        while kill -0 "$pid" 2>/dev/null; do
            line=$(progress_last_line "$logfile")
            printf 'XXX\n%s\n%s\nXXX\n' "$pct" "$line"
            pct=$((pct + 3)); [ "$pct" -lt 94 ] || pct=12
            sleep "$PROGRESS_REFRESH"
        done
        printf 'XXX\n100\nFinalizing…\nXXX\n'
    ) | dialog --clear --backtitle "$BACKTITLE" --title "$title" --gauge 'Starting…' 10 78 0
}

progress_whiptail_gauge(){
    title=$1 pid=$2 logfile=$3
    (
        pct=3
        while kill -0 "$pid" 2>/dev/null; do
            printf '%s\n' "$pct"
            pct=$((pct + 3)); [ "$pct" -lt 94 ] || pct=12
            sleep "$PROGRESS_REFRESH"
        done
        printf '100\n'
    ) | whiptail --title "$title" --gauge 'Operation in progress…' 8 76 0
}

# Run any command or shell function with captured output and a progress display.
progress_run(){
    title=$1; shift
    logfile=$TMP_DIR/progress.$$.log
    rcfile=$TMP_DIR/progress.$$.rc
    rm -f "$logfile" "$rcfile"
    verbose "$title: $(quote_cmd "$@")"
    log "PROGRESS START $title $(quote_cmd "$@")"
    if [ "$DRY_RUN" = yes ]; then
        printf 'Dry run: %s\n' "$(quote_cmd "$@")" >"$logfile"
        printf '0\n' >"$rcfile"
    else
        ( PROGRESS_CONTEXT=yes; export PROGRESS_CONTEXT; set +e; "$@" >"$logfile" 2>&1; cmd_rc=$?; printf '%s\n' "$cmd_rc" >"$rcfile"; exit 0 ) &
        task_pid=$!
        if [ "$PROGRESS_ENABLED" = yes ]; then
            case $UI in
                dialog) progress_dialog_gauge "$title" "$task_pid" "$logfile" ;;
                whiptail) progress_whiptail_gauge "$title" "$task_pid" "$logfile" ;;
                *) progress_text_spinner "$title" "$task_pid" "$logfile" ;;
            esac
        else
            wait "$task_pid"
        fi
        wait "$task_pid" 2>/dev/null || true
    fi
    rc=$(cat "$rcfile" 2>/dev/null || printf '1')
    cat "$logfile" >>"$LOG_FILE" 2>/dev/null || true
    log "PROGRESS EXIT $rc $title"
    PROGRESS_LAST_LOG=$logfile
    export PROGRESS_LAST_LOG
    return "$rc"
}

progress_summary(){
    title=$1 rc=$2 logfile=$3
    if [ "$rc" -eq 0 ]; then
        tailtext=$(tail -n 80 "$logfile" 2>/dev/null)
        [ -n "$tailtext" ] || tailtext='Operation completed successfully.'
        ui_text "$title — completed" "$tailtext"
    else
        tailtext=$(tail -n 160 "$logfile" 2>/dev/null)
        ui_text "$title — failed (exit $rc)" "$tailtext\n\nFull log: $LOG_FILE"
    fi
}

progress_steps_begin(){
    PROGRESS_STEPS_TITLE=$1
    PROGRESS_STEPS_TOTAL=$2
    PROGRESS_STEPS_CURRENT=0
    PROGRESS_STEPS_LOG=$TMP_DIR/steps.$$.log
    : >"$PROGRESS_STEPS_LOG"
}

progress_step(){
    label=$1; shift
    PROGRESS_STEPS_CURRENT=$((PROGRESS_STEPS_CURRENT + 1))
    title="$PROGRESS_STEPS_TITLE ($PROGRESS_STEPS_CURRENT/$PROGRESS_STEPS_TOTAL): $label"
    progress_run "$title" "$@"
    rc=$?
    cat "$PROGRESS_LAST_LOG" >>"$PROGRESS_STEPS_LOG" 2>/dev/null || true
    return "$rc"
}
