#!/usr/bin/env bash
##
# creates and verifies every flag listed in files-needed.yml.
#
# must run as root. intended to run once at image build time (see Dockerfile),
# but is safe to re-run on an existing system.
#
#   setup-flags.sh           create all flags, then verify them
#   setup-flags.sh verify    verify only
#
# Env:
#   CIC_USER   member account the home-directory flags belong to (default: cic-guest)

set -euo pipefail

CIC_USER="${CIC_USER:-cic-guest}"
CIC_HOME="/home/${CIC_USER}"
ANSWERS="/root/cic-answers.txt"   # contains the randomized bonus answer

FLAG_WELCOME='CIC{h311o_sh311}'
FLAG_HIDDEN='CIC{d0t_f1l3s}'
FLAG_MAZE='CIC{t4b_c0mpl3t3}'
FLAG_TAIL='CIC{t41l_3nd}'
FLAG_NEEDLE='CIC{n33dl3_f0und}'
FLAG_LOST='CIC{f1nd_1t}'
FLAG_LOCKED='CIC{chm0d_r34d}'
FLAG_EXEC='CIC{x_b1t_s3t}'
FLAG_PS='CIC{ps_4ux}'

P_WELCOME="${CIC_HOME}/welcome/flag.txt"
P_HIDDEN="${CIC_HOME}/.secret_flag"
P_MAZE="/opt/cic/maze/2/0/0/7/flag.txt"   # easter egg: 2007 is the year RWU Cybersecurity program was founded
P_TAIL="/var/log/cic/server.log"
P_NEEDLE="/opt/cic/haystack.txt"
P_LOST="/usr/share/misc/lost_flag.txt"
P_LOCKED="${CIC_HOME}/locked.txt"
P_EXEC="${CIC_HOME}/run_me.sh"
P_WORDS="/opt/cic/words.txt"
P_SERVICE="/etc/systemd/system/bonus-flag.service"
P_BEACON="/usr/local/bin/cic-beacon"

TAIL_LINES=5000     # total lines in server.log, the flag is on the last line
NEEDLE_LINES=10000  # total lines in haystack.txt. the flag replaces a random line in the file

log() { printf '[setup] %s\n' "$*"; }

# write_file PATH OWNER MODE  (content on stdin)
write_file() {
    local path=$1 owner=$2 mode=$3
    install -d -m 755 "$(dirname "$path")"
    rm -f "$path"
    cat > "$path"
    chown "$owner:$owner" "$path"
    chmod "$mode" "$path"
}

create_user() {
    if ! id "$CIC_USER" &>/dev/null; then
        useradd --create-home --shell /bin/bash "$CIC_USER"
    fi
    chmod 750 "$CIC_HOME"
}

create_navigation() {
    install -d -o "$CIC_USER" -g "$CIC_USER" -m 755 "${CIC_HOME}/welcome"
    echo "$FLAG_WELCOME" | write_file "$P_WELCOME" "$CIC_USER" 644
    echo "$FLAG_HIDDEN"  | write_file "$P_HIDDEN"  "$CIC_USER" 644
    echo "$FLAG_MAZE"    | write_file "$P_MAZE"    root 644
}

create_reading() {
    # 2.1: fake server log, flag on the very last line
    {
        awk -v n=$((TAIL_LINES - 1)) -v seed="$RANDOM" 'BEGIN {
            srand(seed)
            split("INFO INFO INFO WARN DEBUG", lvl, " ")
            split("GET POST PUT DELETE", verb, " ")
            split("/ /login /api/status /api/users /static/app.js /health", path, " ")
            for (i = 1; i <= n; i++) {
                printf "2026-09-28T%02d:%02d:%02d [%s] %s %s %d %dms\n",
                    int(i / 3600) % 24, int(i / 60) % 60, i % 60,
                    lvl[int(rand() * 5) + 1], verb[int(rand() * 4) + 1],
                    path[int(rand() * 6) + 1], (rand() < 0.9 ? 200 : 404), int(rand() * 900) + 5
            }
        }'
        echo "2026-09-28T23:59:59 [INFO] shutdown complete: $FLAG_TAIL"
    } | write_file "$P_TAIL" root 644

    # 2.2: haystack, flag on a random line
    awk -v n="$NEEDLE_LINES" -v flag="$FLAG_NEEDLE" -v seed="$RANDOM" 'BEGIN {
        srand(seed)
        pos = int(rand() * n) + 1
        for (i = 1; i <= n; i++) {
            if (i == pos) { print flag; continue }
            s = ""
            for (j = 0; j < 32; j++) s = s substr("0123456789abcdef", int(rand() * 16) + 1, 1)
            print "hay-" s
        }
    }' | write_file "$P_NEEDLE" root 644

    # 2.3: lost file
    echo "$FLAG_LOST" | write_file "$P_LOST" root 644
}

create_permissions() {
    # 3.1: owned by the member, but no permissions at all
    echo "$FLAG_LOCKED" | write_file "$P_LOCKED" "$CIC_USER" 000

    # 3.2: not executable. asks for the 3.1 flag before printing its own.
    # only hashes/encoded values are stored so `cat run_me.sh` doesn't give it away.
    local want_hash flag_b64
    want_hash=$(printf '%s' "$FLAG_LOCKED" | sha256sum | cut -d' ' -f1)
    flag_b64=$(printf '%s' "$FLAG_EXEC" | base64)
    write_file "$P_EXEC" "$CIC_USER" 644 <<EOF
#!/bin/bash
# You made it executable! Now prove you got into locked.txt.
read -rp "Enter the flag from locked.txt: " answer
if [[ "\$(printf '%s' "\$answer" | sha256sum | cut -d' ' -f1)" == "$want_hash" ]]; then
    printf '%s\n' "\$(echo '$flag_b64' | base64 -d)"
else
    echo "That's not it. Check ~/locked.txt again." >&2
    exit 1
fi
EOF
}

create_bonus() {
    # b.1: random number of lines containing "tux". No filler word contains "tux".
    local count
    install -d -m 755 "$(dirname "$P_WORDS")"
    count=$(awk -v n=400 -v out="$P_WORDS" -v seed="$RANDOM" 'BEGIN {
        srand(seed)
        split("penguin kernel shell bash grep pipe root daemon cron socket inode ext4 " \
              "process thread signal mount chmod chown sudo apt vim nano emacs", w, " ")
        want = int(rand() * 61) + 20            # 20..80 tux lines
        for (i = 1; i <= n; i++) tuxline[i] = 0
        placed = 0
        while (placed < want) { k = int(rand() * n) + 1; if (!tuxline[k]) { tuxline[k] = 1; placed++ } }
        for (i = 1; i <= n; i++) {
            line = ""
            words = int(rand() * 6) + 3
            at = tuxline[i] ? int(rand() * words) + 1 : 0
            for (j = 1; j <= words; j++) line = line (j > 1 ? " " : "") (j == at ? "tux" : w[int(rand() * 23) + 1])
            print line > out
        }
        print want
    }')
    chown root:root "$P_WORDS"
    chmod 644 "$P_WORDS"
    printf 'words.txt tux count: %s\nb.1 flag: CIC{%s}\n' "$count" "$count" > "$ANSWERS"
    chmod 600 "$ANSWERS"
    log "b.1 answer is CIC{${count}} (saved to ${ANSWERS})"

    # b.2: a long-running process whose command line carries the flag.
    # The container has no systemd, so the entrypoint starts ExecStart directly.
    write_file "$P_BEACON" root 755 <<'EOF'
#!/bin/bash
# cic-beacon: harmless idle process for the "Something's Running" challenge
exec sleep infinity
EOF
    write_file "$P_SERVICE" root 644 <<EOF
[Unit]
Description=CIC bonus flag beacon

[Service]
User=nobody
ExecStart=${P_BEACON} --token ${FLAG_PS}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

create_all() {
    [[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
    log "creating flags for user ${CIC_USER}"
    create_user
    create_navigation
    create_reading
    create_permissions
    create_bonus
}

## verify

FAILS=0
pass() { printf '  PASS  %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILS=$((FAILS + 1)); }
check() { local desc=$1; shift; if "$@" &>/dev/null; then pass "$desc"; else fail "$desc"; fi; }

as_user() { runuser -u "$CIC_USER" -- "$@"; }
has_flag() { grep -qF -- "$2" "$1"; }
mode_is() { (( 8#$(stat -c %a "$1") == 8#$2 )); }
owner_is() { [[ "$(stat -c %U "$1")" == "$2" ]]; }
last_line_is() { [[ "$(tail -n 1 "$1")" == *"$2" ]]; }
line_count_is() { [[ "$(wc -l < "$1")" -eq "$2" ]]; }
flag_count_is() { [[ "$(grep -c 'CIC{' "$1")" -eq "$2" ]]; }
tux_count_matches() { [[ "CIC{$(grep -c tux "$P_WORDS")}" == "$(sed -n 's/^b.1 flag: //p' "$ANSWERS")" ]]; }
run_me_accepts() { [[ "$(as_user bash "$P_EXEC" <<< "$FLAG_LOCKED" 2>/dev/null)" == "$FLAG_EXEC" ]]; }
run_me_rejects() { ! as_user bash "$P_EXEC" <<< "CIC{wrong}" 2>/dev/null | grep -qF "$FLAG_EXEC"; }
run_me_hides_flag() { ! grep -qF -e "$FLAG_EXEC" -e "$FLAG_LOCKED" "$P_EXEC"; }

verify_all() {
    log "verifying flags"

    echo "1.1 welcome"
    check "$P_WELCOME has flag"            has_flag "$P_WELCOME" "$FLAG_WELCOME"
    check "readable by $CIC_USER"          as_user test -r "$P_WELCOME"

    echo "1.2 hidden file"
    check "$P_HIDDEN has flag"             has_flag "$P_HIDDEN" "$FLAG_HIDDEN"
    check "readable by $CIC_USER"          as_user test -r "$P_HIDDEN"

    echo "1.3 maze"
    check "$P_MAZE has flag"               has_flag "$P_MAZE" "$FLAG_MAZE"
    check "readable by $CIC_USER"          as_user test -r "$P_MAZE"

    echo "2.1 tail"
    check "$P_TAIL is $TAIL_LINES lines"   line_count_is "$P_TAIL" "$TAIL_LINES"
    check "flag on last line"              last_line_is "$P_TAIL" "$FLAG_TAIL"
    check "exactly one flag"               flag_count_is "$P_TAIL" 1
    check "readable by $CIC_USER"          as_user test -r "$P_TAIL"

    echo "2.2 haystack"
    check "$P_NEEDLE is $NEEDLE_LINES lines" line_count_is "$P_NEEDLE" "$NEEDLE_LINES"
    check "has flag"                       has_flag "$P_NEEDLE" "$FLAG_NEEDLE"
    check "exactly one flag"               flag_count_is "$P_NEEDLE" 1
    check "readable by $CIC_USER"          as_user test -r "$P_NEEDLE"

    echo "2.3 lost file"
    check "$P_LOST has flag"               has_flag "$P_LOST" "$FLAG_LOST"
    check "readable by $CIC_USER"          as_user test -r "$P_LOST"

    echo "3.1 locked"
    check "$P_LOCKED has flag"             has_flag "$P_LOCKED" "$FLAG_LOCKED"
    check "owned by $CIC_USER"             owner_is "$P_LOCKED" "$CIC_USER"
    check "mode 000"                       mode_is "$P_LOCKED" 000
    check "NOT readable by $CIC_USER"      bash -c "! runuser -u '$CIC_USER' -- test -r '$P_LOCKED'"

    echo "3.2 run_me"
    check "owned by $CIC_USER"             owner_is "$P_EXEC" "$CIC_USER"
    check "mode 644 (no execute bit)"      mode_is "$P_EXEC" 644
    check "prints flag for 3.1 flag"       run_me_accepts
    check "rejects wrong input"            run_me_rejects
    check "flags not in plaintext"         run_me_hides_flag

    echo "b.1 words"
    check "$P_WORDS exists"                test -s "$P_WORDS"
    check "tux count matches answer"       tux_count_matches
    check "readable by $CIC_USER"          as_user test -r "$P_WORDS"

    echo "b.2 service"
    check "$P_SERVICE has flag in ExecStart" grep -q "^ExecStart=.*${FLAG_PS}" "$P_SERVICE"
    check "$P_BEACON is executable"        test -x "$P_BEACON"

    echo "answers"
    check "$ANSWERS is root-only"          mode_is "$ANSWERS" 600
    check "NOT readable by $CIC_USER"      bash -c "! runuser -u '$CIC_USER' -- test -r '$ANSWERS'"

    if (( FAILS > 0 )); then
        log "${FAILS} check(s) failed"
        return 1
    fi
    log "all checks passed"
}

case "${1:-all}" in
    all)    create_all; verify_all ;;
    verify) verify_all ;;
    *)      echo "usage: $0 [all|verify]" >&2; exit 2 ;;
esac
