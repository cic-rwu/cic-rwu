#!/usr/bin/env bash
##[bin/cical.sh]
# list, add, skip, remove, merge, and check events in the club calendar (www/calendar/cic.ics)
#
#   cical.sh list [events]
#   cical.sh add event TITLE START [END] [DESCRIPTION] [at LOCATION] [uid UID]
#   cical.sh add repeating event daily|weekly|biweekly|monthly TITLE START [END] [DESCRIPTION]
#            [until DATE] [at LOCATION] [uid UID]
#   cical.sh skip event UID START
#   cical.sh remove event UID
#   cical.sh merge event UID
#   cical.sh check
#
# dates and times:
#   START   'YYYY-MM-DD HH:MM' for a timed event, or YYYY-MM-DD for an all-day event
#           'YYYY-MM-DD HH:MM-HH:MM' gives the start and end time together
#   END     HH:MM (same day), 'YYYY-MM-DD HH:MM', or YYYY-MM-DD (all-day, inclusive)
#           defaults to one hour after START, or the same day for all-day events
#   UNTIL   YYYY-MM-DD, the last day a repeating event can occur (inclusive);
#           without it, a repeating event goes on forever
#   times are 24-hour HH:MM (18:30 is 6:30 PM), in Eastern (America/New_York) local time
#   monthly repeats on START's day of the month; skip takes the START of one occurrence
#   'at', 'until', and 'uid' clauses may go anywhere after the event type
#
# merging:
#   when a one-time event overlaps an existing event (or one occurrence of a repeating
#   one), add asks before writing: merge into it, add separately, or cancel. merging
#   appends the new title ("Weekly Meeting — Guest Speaker") and description, and fills
#   in a missing or TBD location; for a repeating event only that occurrence changes.
#   'merge event UID' does the same for an event that is already in the calendar,
#   then removes it. the answer is read from stdin, so 'echo m | cical.sh …' works in scripts
#
# examples:
#   cical.sh add event 'CTF night' '2026-11-20 18:30-21:00' 'Bring a laptop' at 'Room 101'
#   cical.sh add event 'Finals break' 2026-12-14 2026-12-18
#   cical.sh add repeating event weekly 'Weekly meeting' '2027-01-27 18:00' until 2027-05-05
#   cical.sh skip event weekly-meeting-20270127@cicrwu.org '2027-03-17 18:00'
#
# set CIC_ICS to work on a different file
##
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ICS=${CIC_ICS:-"$SCRIPT_DIR/../www/calendar/cic.ics"}
TZID="America/New_York"
DOMAIN="cicrwu.org"

die(){ printf 'cical.sh: %s\n' "$*" >&2; exit 1; }

usage(){
  sed -n '3,/^##$/{/^##$/d; s/^# \{0,1\}//p;}' "${BASH_SOURCE[0]}"
  exit "${1:-0}"
}

# cic.ics is CRLF; work on LF internally and convert back on write
read-ics(){ tr -d '\r' < "$ICS"; }

write-ics(){
  local tmp
  tmp=$(mktemp "$ICS.XXXXXX")
  sed 's/$/\r/' > "$tmp"
  chmod --reference="$ICS" "$tmp"
  mv "$tmp" "$ICS"
}

# 'YYYY-MM-DD' -> YYYYMMDD, 'YYYY-MM-DD HH:MM' (24-hour) -> YYYYMMDDTHHMM00
ical-time(){
  [[ "$1" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})(\ ([0-9]{2}):([0-9]{2}))?$ ]] \
    || die "bad date '$1' (want YYYY-MM-DD or 'YYYY-MM-DD HH:MM', 24-hour)"
  TZ=UTC date -d "$1" >/dev/null 2>&1 || die "no such date '$1'"
  local d="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
  if [[ -n "${BASH_REMATCH[4]}" ]]; then
    printf '%sT%s%s00' "$d" "${BASH_REMATCH[5]}" "${BASH_REMATCH[6]}"
  else
    printf '%s' "$d"
  fi
}

# ical-time -> seconds, treating the wall-clock time as UTC (so DST never shifts it)
ical-epoch(){
  local t=$1
  if [[ "$t" == *T* ]]; then
    TZ=UTC date -d "${t:0:4}-${t:4:2}-${t:6:2} ${t:9:2}:${t:11:2}:${t:13:2}" +%s
  else
    TZ=UTC date -d "${t:0:4}-${t:4:2}-${t:6:2}" +%s
  fi
}

# add N seconds to an ical-time
ical-add(){
  local t=$1 secs=$2 epoch
  epoch=$(ical-epoch "$t")
  if [[ "$t" == *T* ]]; then
    TZ=UTC date -d "@$((epoch + secs))" +%Y%m%dT%H%M%S
  else
    TZ=UTC date -d "@$((epoch + secs))" +%Y%m%d
  fi
}

# a UTC value (…Z) -> Eastern wall-clock ical-time; anything else passes through
ical-local(){
  local t=$1
  if [[ "$t" == *Z ]]; then
    TZ=$TZID date -d "${t:0:4}-${t:4:2}-${t:6:2}T${t:9:2}:${t:11:2}:${t:13:2}Z" +%Y%m%dT%H%M%S
  else
    printf '%s' "$t"
  fi
}

# 'YYYYMMDDTHHMMSS' -> 'YYYY-MM-DD HH:MM' for messages
ical-show(){
  local t=$1
  if [[ "$t" == *T* ]]; then printf '%s-%s-%s %s:%s' "${t:0:4}" "${t:4:2}" "${t:6:2}" "${t:9:2}" "${t:11:2}"
  else printf '%s-%s-%s' "${t:0:4}" "${t:4:2}" "${t:6:2}"; fi
}

# DTSTART/DTEND/EXDATE property for an ical-time
ical-prop(){
  if [[ "$2" == *T* ]]; then
    printf '%s;TZID=%s:%s' "$1" "$TZID" "$2"
  else
    printf '%s;VALUE=DATE:%s' "$1" "$2"
  fi
}

# escape TEXT values per RFC 5545
ical-text(){
  local s=$1
  s=${s//\\/\\\\}; s=${s//;/\\;}; s=${s//,/\\,}; s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

# fold lines longer than 75 characters
ical-fold(){
  awk '{ while (length($0) > 75) { print substr($0, 1, 75); $0 = " " substr($0, 76) } print }'
}

now-stamp(){ date -u +%Y%m%dT%H%M%SZ; }

# true if a non-override VEVENT with this UID exists
has-uid(){
  read-ics | awk -v uid="$1" '
    /^BEGIN:VEVENT$/ { inev = 1; u = ""; rid = 0; next }
    inev && /^UID:/ { u = substr($0, 5) }
    inev && /^RECURRENCE-ID/ { rid = 1 }
    /^END:VEVENT$/ { if (u == uid && !rid) found = 1; inev = 0 }
    END { exit !found }'
}

#=======================

cmd-list(){
  # unfold, then one tab-separated row per VEVENT: start, freq, interval, until, override, summary, uid
  read-ics | awk '
    /^[ \t]/ { line = line substr($0, 2); next }
    { if (NR > 1) print line; line = $0 }
    END { print line }' \
  | awk '
    /^BEGIN:VEVENT$/ { inev = 1; s = u = d = f = n = un = ""; x = 0; next }
    !inev { next }
    /^SUMMARY/   { s = substr($0, index($0, ":") + 1) }
    /^UID/       { u = substr($0, index($0, ":") + 1) }
    /^DTSTART/   { d = substr($0, index($0, ":") + 1) }
    /^RECURRENCE-ID/ { x = 1 }
    /^RRULE:/ {
      k = split(substr($0, 7), parts, ";")
      for (i = 1; i <= k; i++) {
        split(parts[i], kv, "=")
        if (kv[1] == "FREQ") f = tolower(kv[2])
        if (kv[1] == "INTERVAL") n = kv[2]
        if (kv[1] == "UNTIL") un = kv[2]
      }
    }
    /^END:VEVENT$/ {
      inev = 0
      gsub(/\\,/, ",", s); gsub(/\\;/, ";", s); gsub(/\\\\/, "\\", s)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", d, (f == "" ? "-" : f), (n == "" ? "-" : n), (un == "" ? "-" : un), x, s, u
    }' \
  | sort \
  | while IFS=$'\t' read -r d freq interval until override summary uid; do
      local when repeats=""
      if [[ ${#d} -gt 8 ]]; then when="${d:0:4}-${d:4:2}-${d:6:2} ${d:9:2}:${d:11:2}"
      else when="${d:0:4}-${d:4:2}-${d:6:2}      "; fi
      if [[ "$freq" != "-" ]]; then
        [[ "$freq" == weekly && "$interval" == 2 ]] && freq=biweekly
        [[ "$interval" != "-" && "$interval" != 1 && "$freq" != biweekly ]] && freq="every $interval x $freq"
        if [[ "$until" == "-" ]]; then
          repeats="$freq, forever"
        elif [[ "$until" == *Z ]]; then
          # UTC -> the Eastern date it falls on
          repeats="$freq until $(TZ=$TZID date -d "${until:0:4}-${until:4:2}-${until:6:2}T${until:9:2}:${until:11:2}:${until:13:2}Z" +%F)"
        else
          repeats="$freq until ${until:0:4}-${until:4:2}-${until:6:2}"
        fi
      elif [[ "$override" == 1 ]]; then
        repeats="(one changed occurrence)"
      fi
      (( ${#summary} <= 32 )) || summary="${summary:0:31}…"
      printf '%s  %-32s  %-28s  %s\n' "$when" "$summary" "$repeats" "$uid"
    done
}

# one tab-separated row per VEVENT, with raw (still escaped) values and "-" for empty:
#   n uid recurrence-id dtstart dtend rrule exdates summary location description
event-rows(){
  read-ics | awk '
    /^[ \t]/ { line = line substr($0, 2); next }
    { if (NR > 1) print line; line = $0 }
    END { print line }' \
  | awk '
    function val(l) { return substr(l, index(l, ":") + 1) }
    function f(v) { return v == "" ? "-" : v }
    /^BEGIN:VEVENT$/ { inev = 1; n++; u = rid = ds = de = rr = ex = s = l = d = ""; next }
    !inev { next }
    /^UID:/               { u = val($0) }
    /^RECURRENCE-ID[;:]/  { rid = val($0) }
    /^DTSTART[;:]/        { ds = val($0) }
    /^DTEND[;:]/          { de = val($0) }
    /^RRULE:/             { rr = val($0) }
    /^EXDATE[;:]/         { ex = ex (ex == "" ? "" : ",") val($0) }
    /^SUMMARY[;:]/        { s = val($0) }
    /^LOCATION[;:]/       { l = val($0) }
    /^DESCRIPTION[;:]/    { d = val($0) }
    /^END:VEVENT$/ {
      inev = 0
      printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", n, f(u), f(rid), f(ds), f(de), f(rr), f(ex), f(s), f(l), f(d)
    }'
}

# does RRULE (starting at DTSTART) produce an occurrence on DAY (YYYYMMDD)?
# handles FREQ=DAILY/WEEKLY/MONTHLY with INTERVAL, UNTIL and COUNT; anything else returns 2
rule-hits(){
  local rrule=$1 dtstart=$2 day=$3
  local freq="" interval=1 until="" count="" part
  local -a parts
  IFS=';' read -ra parts <<< "$rrule"
  for part in "${parts[@]}"; do
    case $part in
      FREQ=*) freq=${part#FREQ=} ;;
      INTERVAL=*) interval=${part#INTERVAL=} ;;
      UNTIL=*) until=${part#UNTIL=} ;;
      COUNT=*) count=${part#COUNT=} ;;
      *) return 2 ;;
    esac
  done

  local first=${dtstart:0:8}
  [[ ! "$day" < "$first" ]] || return 1
  local index
  case $freq in
    DAILY|WEEKLY)
      local step=$interval days
      [[ "$freq" == WEEKLY ]] && step=$((interval * 7))
      days=$(( ($(ical-epoch "$day") - $(ical-epoch "$first")) / 86400 ))
      (( days % step == 0 )) || return 1
      index=$((days / step)) ;;
    MONTHLY)
      [[ "${day:6:2}" == "${first:6:2}" ]] || return 1
      local months=$(( (10#${day:0:4} * 12 + 10#${day:4:2}) - (10#${first:0:4} * 12 + 10#${first:4:2}) ))
      (( months % interval == 0 )) || return 1
      index=$((months / interval)) ;;
    *) return 2 ;;
  esac

  [[ -z "$count" ]] || (( index < count )) || return 1
  if [[ -n "$until" ]]; then
    local last
    last=$(ical-local "$until")
    if [[ "$dtstart" == *T* && "$last" == *T* ]]; then
      [[ ! "$day${dtstart:8}" > "$last" ]] || return 1
    else
      [[ ! "$day" > "${last:0:8}" ]] || return 1
    fi
  fi
  return 0
}

# true if [s1, e1) and [s2, e2) overlap; ical-times compare as strings
overlaps(){ [[ "$1" < "$4" && ( "$3" < "$2" || "$1" == "$3" ) ]]; }

# fills OVERLAPS with "kind<TAB>row-number<TAB>start<TAB>end<TAB>uid<TAB>summary" for every
# event or occurrence overlapping [start, end) (kind is "event" or "occurrence")
find-overlaps(){
  local new_start=$1 new_end=$2 skip_uid=${3:-}
  local n uid rid ds de rr ex summary location desc
  local -A replaced=()
  local -a rows=()
  OVERLAPS=()
  mapfile -t rows < <(event-rows)

  # occurrences already replaced by a RECURRENCE-ID override are checked as that override
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r n uid rid _ <<< "$row"
    [[ "$rid" == "-" ]] || replaced["$uid|$(ical-local "$rid")"]=1
  done

  for row in "${rows[@]}"; do
    IFS=$'\t' read -r n uid rid ds de rr ex summary location desc <<< "$row"
    [[ "$uid" != "$skip_uid" ]] || continue
    ds=$(ical-local "$ds")
    [[ "${ds//[0-9]/}" == "${new_start//[0-9]/}" ]] || continue   # timed vs all-day never overlap
    local dur=0
    if [[ "$de" != "-" ]]; then
      dur=$(( $(ical-epoch "$(ical-local "$de")") - $(ical-epoch "$ds") ))
    elif [[ "$ds" != *T* ]]; then
      dur=86400
    fi

    if [[ "$rr" == "-" || "$rid" != "-" ]]; then
      local e
      e=$(ical-add "$ds" "$dur")
      overlaps "$ds" "$e" "$new_start" "$new_end" && OVERLAPS+=("event"$'\t'"$n"$'\t'"$ds"$'\t'"$e"$'\t'"$uid"$'\t'"$summary")
      continue
    fi

    local occ="${new_start:0:8}${ds:8}" status=0
    rule-hits "$rr" "$ds" "${new_start:0:8}" || status=$?
    if (( status == 2 )); then
      printf "cical.sh: note: can't check overlaps with '%s' (RRULE:%s)\n" "$uid" "$rr" >&2
      continue
    fi
    (( status == 0 )) || continue
    [[ ",$ex," != *",$occ,"* && -z "${replaced["$uid|$occ"]:-}" ]] || continue
    local occ_end
    occ_end=$(ical-add "$occ" "$dur")
    overlaps "$occ" "$occ_end" "$new_start" "$new_end" \
      && OVERLAPS+=("occurrence"$'\t'"$n"$'\t'"$occ"$'\t'"$occ_end"$'\t'"$uid"$'\t'"$summary")
  done
  return 0
}

# merged (escaped) SUMMARY, LOCATION and DESCRIPTION values; "-" means empty
merge-summary(){
  if [[ "$1" == "-" ]]; then ical-text "$2"; else printf '%s — %s' "$1" "$(ical-text "$2")"; fi
}
merge-location(){
  local old=$1 new=$2
  if [[ -z "$new" ]]; then [[ "$old" == "-" ]] || printf '%s' "$old"
  elif [[ "$old" == "-" || "$old" == "TBD" ]]; then ical-text "$new"
  elif [[ "$old" == "$(ical-text "$new")" ]]; then printf '%s' "$old"
  else printf '%s / %s' "$old" "$(ical-text "$new")"; fi
}
merge-description(){
  local old=$1 new=$2
  if [[ -z "$new" ]]; then [[ "$old" == "-" ]] || printf '%s' "$old"
  elif [[ "$old" == "-" ]]; then ical-text "$new"
  else printf '%s\\n\\n%s' "$old" "$(ical-text "$new")"; fi
}

# SUMMARY/LOCATION/DESCRIPTION/DTSTAMP lines for a merged event, folded
merged-props(){
  local summary=$1 location=$2 desc=$3
  {
    echo "DTSTAMP:$(now-stamp)"
    echo "SUMMARY:$summary"
    [[ -z "$location" ]] || echo "LOCATION:$location"
    [[ -z "$desc" ]] || echo "DESCRIPTION:$desc"
  } | ical-fold
}

# if the new event overlaps existing ones, ask whether to merge; sets MERGED=1 if it did
MERGED=0
offer-merge(){
  local start=$1 end=$2 summary=$3 location=$4 desc=$5 skip_uid=${6:-}
  find-overlaps "$start" "$end" "$skip_uid"
  (( ${#OVERLAPS[@]} )) || return 0

  local i kind n s e uid old
  printf "'%s' (%s) overlaps:\n" "$summary" "$(ical-show "$start")" >&2
  for i in "${!OVERLAPS[@]}"; do
    IFS=$'\t' read -r kind n s e uid old <<< "${OVERLAPS[i]}"
    printf '  %d) %s  %s%s\n' "$((i + 1))" "$(ical-show "$s")" "$old" \
      "$([[ "$kind" == occurrence ]] && printf ' (one occurrence of a repeating event)')" >&2
  done

  local answer choice
  if (( ${#OVERLAPS[@]} == 1 )); then
    printf '[m]erge into it, [a]dd as a separate event, or [c]ancel? ' >&2
  else
    printf 'merge into [1-%d], [a]dd as a separate event, or [c]ancel? ' "${#OVERLAPS[@]}" >&2
  fi
  read -r answer || answer=c
  case $answer in
    m|M) (( ${#OVERLAPS[@]} == 1 )) || die "pick which event to merge into (1-${#OVERLAPS[@]})"; choice=0 ;;
    a|A) return 0 ;;
    [0-9]*) (( answer >= 1 && answer <= ${#OVERLAPS[@]} )) || die "no option $answer"; choice=$((answer - 1)) ;;
    *) die "cancelled" ;;
  esac

  IFS=$'\t' read -r kind n s e uid old <<< "${OVERLAPS[choice]}"
  local row _uid _rid _ds _de _rr _ex osum oloc odesc
  row=$(event-rows | awk -F'\t' -v n="$n" '$1 == n')
  IFS=$'\t' read -r _ _uid _rid _ds _de _rr _ex osum oloc odesc <<< "$row"
  local props
  props=$(merged-props "$(merge-summary "$osum" "$summary")" \
                       "$(merge-location "$oloc" "$location")" \
                       "$(merge-description "$odesc" "$desc")")

  if [[ "$kind" == event ]]; then
    # rewrite the event's text properties in place (dropping their folded continuations)
    read-ics | PROPS="$props" awk -v n="$n" '
      /^BEGIN:VEVENT$/ { ev++ }
      ev == n && inev && /^[ \t]/ { if (skip) next }
      ev == n && /^BEGIN:VEVENT$/ { inev = 1 }
      inev && /^(DTSTAMP|SUMMARY|LOCATION|DESCRIPTION)[;:]/ { skip = 1; next }
      inev && !/^[ \t]/ { skip = 0 }
      inev && /^END:VEVENT$/ { print ENVIRON["PROPS"]; inev = 0 }
      { print }' | write-ics
    printf 'merged into %s\n' "$uid"
  else
    # override just this occurrence; it keeps the series UID
    local override
    override=$(
      echo "BEGIN:VEVENT"
      echo "UID:$uid"
      ical-prop RECURRENCE-ID "$s"; echo
      ical-prop DTSTART "$s"; echo
      ical-prop DTEND "$e"; echo
      echo "$props"
      echo "END:VEVENT"
    )
    read-ics | EV="$override" awk '/^END:VCALENDAR$/ { print ENVIRON["EV"] } { print }' | write-ics
    printf 'merged into %s on %s\n' "$uid" "$(ical-show "$s")"
  fi
  MERGED=1
}

# looks like an END argument: HH:MM, YYYY-MM-DD, or 'YYYY-MM-DD HH:MM'
is-when(){ [[ "$1" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})?\ ?([0-9]{2}:[0-9]{2})?$ && -n "$1" ]]; }

cmd-add(){
  local add_usage="usage: cical.sh add [repeating] event [daily|weekly|biweekly|monthly] TITLE START [END] [DESCRIPTION] ..."
  local repeat="" summary start end="" location="" desc="" until="" uid="" rrule=""

  if [[ "${1:-}" == "repeating" ]]; then
    shift
    [[ "${1:-}" == "event" ]] || die "$add_usage"
    case ${2:-} in
      daily|weekly|biweekly|monthly) repeat=$2 ;;
      *) die "repeating events need daily, weekly, biweekly, or monthly (got '${2:-}')" ;;
    esac
    shift 2
  else
    [[ "${1:-}" == "event" ]] || die "$add_usage"
    shift
  fi
  # pull out keyword clauses wherever they are; what's left is positional
  local -a pos=()
  while (( $# )); do
    case $1 in
      at|until|uid)
        (( $# >= 2 )) || die "'$1' needs a value"
        case $1 in
          at) location=$2 ;;
          until) until=$2 ;;
          uid) uid=$2 ;;
        esac
        shift 2 ;;
      *) pos+=("$1"); shift ;;
    esac
  done
  (( ${#pos[@]} >= 2 )) || die "$add_usage"
  summary=${pos[0]} start=${pos[1]}
  is-when "$summary" && die "TITLE '$summary' looks like a date; TITLE goes before START"

  # 'YYYY-MM-DD HH:MM-HH:MM' carries its own end time
  if [[ "$start" =~ ^(.+\ [0-9]{2}:[0-9]{2})-([0-9]{2}:[0-9]{2})$ ]]; then
    start=${BASH_REMATCH[1]} end=${BASH_REMATCH[2]}
  fi

  # optional END, then optional DESCRIPTION
  local i=2
  if (( ${#pos[@]} > i )) && is-when "${pos[i]}"; then
    [[ -z "$end" ]] || die "END given twice ('$end' in START and '${pos[i]}')"
    end=${pos[i]}; i=$((i + 1))
  fi
  if (( ${#pos[@]} > i )); then desc=${pos[i]}; i=$((i + 1)); fi
  (( ${#pos[@]} == i )) || die "unexpected argument '${pos[i]}' (quote multi-word values)"
  [[ -z "$until" || -n "$repeat" ]] || die "'until' only applies to repeating events"

  local dtstart dtend
  dtstart=$(ical-time "$start")
  if [[ -z "$end" ]]; then
    # timed: one hour; all-day: DTEND is the next day (exclusive)
    if [[ "$dtstart" == *T* ]]; then dtend=$(ical-add "$dtstart" 3600); else dtend=$(ical-add "$dtstart" 86400); fi
  elif [[ "$end" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    [[ "$dtstart" == *T* ]] || die "an HH:MM end only works with a timed start"
    dtend=$(ical-time "${start:0:10} $end")
  else
    dtend=$(ical-time "$end")
    # an all-day end date is inclusive on the command line
    [[ "$dtend" == *T* ]] || dtend=$(ical-add "$dtend" 86400)
  fi
  [[ "${dtstart//[0-9]/}" == "${dtend//[0-9]/}" ]] || die "start and end must both be dates or both be date-times"
  [[ "$dtend" > "$dtstart" ]] || die "end must be after start"

  if [[ -z "$repeat" ]]; then
    offer-merge "$dtstart" "$dtend" "$summary" "$location" "$desc"
    (( MERGED == 0 )) || return 0
  fi

  if [[ -n "$repeat" ]]; then
    case $repeat in
      daily)    rrule="FREQ=DAILY" ;;
      weekly)   rrule="FREQ=WEEKLY" ;;
      biweekly) rrule="FREQ=WEEKLY;INTERVAL=2" ;;
      monthly)  rrule="FREQ=MONTHLY" ;;
    esac
    if [[ -n "$until" ]]; then
      local last
      last=$(ical-time "$until")
      [[ "$last" != *T* ]] || die "until takes a date (YYYY-MM-DD), not a time"
      [[ ! "$last" < "${dtstart:0:8}" ]] || die "until must not be before START"
      # timed events need UNTIL in UTC: the end of that day in Eastern time
      if [[ "$dtstart" == *T* ]]; then
        last=$(TZ=$TZID date -d "$until 23:59:59" +%s)
        last=$(date -u -d "@$last" +%Y%m%dT%H%M%SZ)
      fi
      rrule+=";UNTIL=$last"
    fi
  fi

  if [[ -z "$uid" ]]; then
    local slug
    slug=$(printf '%s' "$summary" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
    uid="${slug:-event}-${dtstart:0:8}@$DOMAIN"
  fi
  ! has-uid "$uid" || die "UID '$uid' already exists (pick another with: uid UID)"

  local event
  event=$(
    echo "BEGIN:VEVENT"
    echo "UID:$uid"
    echo "DTSTAMP:$(now-stamp)"
    ical-prop DTSTART "$dtstart"; echo
    ical-prop DTEND "$dtend"; echo
    [[ -n "$rrule" ]] && echo "RRULE:$rrule"
    echo "SUMMARY:$(ical-text "$summary")"
    [[ -n "$location" ]] && echo "LOCATION:$(ical-text "$location")"
    [[ -n "$desc" ]] && echo "DESCRIPTION:$(ical-text "$desc")"
    echo "END:VEVENT"
  )
  event=$(ical-fold <<< "$event")

  # via ENVIRON, since awk -v would eat the backslash escapes
  read-ics | EV="$event" awk '/^END:VCALENDAR$/ { print ENVIRON["EV"] } { print }' | write-ics
  printf 'added %s\n' "$uid"
  if [[ -n "$repeat" && -z "$until" ]]; then
    printf "cical.sh: note: '%s' repeats forever; use 'until YYYY-MM-DD' to end it\n" "$summary" >&2
  fi
}

cmd-skip(){
  [[ "${1:-}" == "event" && $# -eq 3 ]] || die "usage: cical.sh skip event UID 'YYYY-MM-DD[ HH:MM]'"
  shift
  local uid=$1 when exdate
  when=$(ical-time "${2%-[0-9][0-9]:[0-9][0-9]}")
  has-uid "$uid" || die "no event with UID '$uid'"
  exdate=$(ical-prop EXDATE "$when")

  # add EXDATE to the recurring (non-override) event and bump its DTSTAMP
  read-ics | awk -v uid="$uid" -v ex="$exdate" -v stamp="$(now-stamp)" '
    /^BEGIN:VEVENT$/ { inev = 1; n = 0; u = ""; rid = 0 }
    inev {
      buf[++n] = $0
      if ($0 ~ /^UID:/) u = substr($0, 5)
      if ($0 ~ /^RECURRENCE-ID/) rid = 1
      if ($0 == "END:VEVENT") {
        hit = (u == uid && !rid)
        for (i = 1; i <= n; i++) {
          if (hit && buf[i] == "END:VEVENT") print ex
          if (hit && buf[i] ~ /^DTSTAMP:/) print "DTSTAMP:" stamp
          else print buf[i]
        }
        inev = 0
      }
      next
    }
    { print }' | write-ics
  printf 'skipped %s on %s\n' "$uid" "$2"
}

cmd-remove(){
  [[ "${1:-}" == "event" && $# -eq 2 ]] || die "usage: cical.sh remove event UID"
  local uid=$2
  has-uid "$uid" || die "no event with UID '$uid'"

  # drops the event and any RECURRENCE-ID overrides sharing its UID
  read-ics | awk -v uid="$uid" '
    /^BEGIN:VEVENT$/ { inev = 1; n = 0; u = "" }
    inev {
      buf[++n] = $0
      if ($0 ~ /^UID:/) u = substr($0, 5)
      if ($0 == "END:VEVENT") {
        if (u != uid) for (i = 1; i <= n; i++) print buf[i]
        inev = 0
      }
      next
    }
    { print }' | write-ics
  printf 'removed %s\n' "$uid"
}

# undo ical-text escaping
ical-unescape(){
  local s=$1
  s=${s//\\n/$'\n'}; s=${s//\\,/,}; s=${s//\;/;}; s=${s//\\\\/\\}
  printf '%s' "$s"
}

cmd-merge(){
  [[ "${1:-}" == "event" && $# -eq 2 ]] || die "usage: cical.sh merge event UID"
  local uid=$2 row n rid ds de rr summary location desc
  row=$(event-rows | awk -F'\t' -v u="$uid" '$2 == u && $3 == "-"')
  [[ -n "$row" ]] || die "no event with UID '$uid'"
  IFS=$'\t' read -r n _ rid ds de rr _ summary location desc <<< "$row"
  [[ "$rr" == "-" ]] || die "'$uid' repeats; only one-time events can be merged into others"

  ds=$(ical-local "$ds")
  if [[ "$de" != "-" ]]; then de=$(ical-local "$de")
  elif [[ "$ds" == *T* ]]; then de=$(ical-add "$ds" 1)
  else de=$(ical-add "$ds" 86400); fi
  [[ "$summary" != "-" ]] || summary=""
  [[ "$location" != "-" ]] || location=""
  [[ "$desc" != "-" ]] || desc=""

  offer-merge "$ds" "$de" "$(ical-unescape "$summary")" "$(ical-unescape "$location")" "$(ical-unescape "$desc")" "$uid"
  if (( ${#OVERLAPS[@]} == 0 )); then die "nothing overlaps '$uid'"; fi
  if (( MERGED )); then
    cmd-remove event "$uid" >/dev/null
    printf 'removed %s\n' "$uid"
  else
    printf 'left %s as it is\n' "$uid"
  fi
}

cmd-check(){
  local problems
  problems=$(read-ics | awk '
    NR == 1 && $0 != "BEGIN:VCALENDAR" { print NR ": file must start with BEGIN:VCALENDAR" }
    length($0) > 75 { print NR ": line longer than 75 characters (fold it)" }
    /^BEGIN:/ { stack[++depth] = substr($0, 7) }
    /^END:/ {
      if (depth == 0 || stack[depth] != substr($0, 5)) print NR ": unexpected " $0
      else depth--
    }
    /^BEGIN:VEVENT$/ { ev = NR; uid = ""; st = dt = rid = 0 }
    ev && /^UID:/ { uid = substr($0, 5) }
    ev && /^DTSTAMP:/ { st = 1 }
    ev && /^DTSTART[;:]/ { dt = 1 }
    ev && /^RECURRENCE-ID[;:]/ { rid = 1 }
    /^END:VEVENT$/ {
      if (uid == "") print ev ": VEVENT has no UID"
      if (!st) print ev ": VEVENT has no DTSTAMP"
      if (!dt) print ev ": VEVENT has no DTSTART"
      if (uid != "" && !rid) { if (uid in seen) print ev ": duplicate UID " uid " (first at line " seen[uid] ")"; else seen[uid] = ev }
      ev = 0
    }
    END { if (depth) print "EOF: unclosed BEGIN:" stack[depth] }')
  if grep -qv $'\r$' "$ICS"; then
    problems+=$'\n'"file has lines without CRLF endings"
  fi
  problems=$(sed '/^$/d' <<< "$problems")
  if [[ -n "$problems" ]]; then
    printf '%s\n' "$problems" >&2
    die "$ICS has problems"
  fi
  printf 'ok: %s\n' "$ICS"
}

main(){
  [[ -f "$ICS" ]] || die "no calendar at $ICS (set CIC_ICS)"
  local cmd=${1:-}
  shift || true
  case $cmd in
    list)
      [[ $# -eq 0 || ( $# -eq 1 && "$1" == "events" ) ]] || die "usage: cical.sh list [events]"
      cmd-list ;;
    # not "cmd && check": set -e is ignored inside the left side of &&
    add|skip|remove|merge) "cmd-$cmd" "$@"; cmd-check >/dev/null ;;
    check)  cmd-check ;;
    -h|--help|help|"") usage ;;
    *) printf 'cical.sh: unknown command %s\n' "$cmd" >&2; usage 1 ;;
  esac
}; main "$@"
