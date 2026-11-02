# `www/calendar`

Public club calendar, served at [cicrwu.org/calendar/](https://cicrwu.org/calendar/).

- `index.html` renders the calendar (`../js/calendar.js`).
- `cic.ics` is the **only** source of events. Members can subscribe to it directly:
  `webcal://cicrwu.org/calendar/cic.ics`

Changes go through a pull request like any other site change.

## Using `bin/cical.sh`

`bin/cical.sh` makes the common edits for you. It handles UIDs, `DTSTAMP`, escaping, line folding and CRLF line endings, and checks the file after every change. Times are **24-hour** `HH:MM` in Eastern time, so `18:30` is 6:30 PM. A repeating event without `until YYYY-MM-DD` repeats forever.

```bash
bin/cical.sh list events
bin/cical.sh add event 'CTF night' '2026-11-20 18:30-21:00' 'Bring a laptop' at 'Room 101'
bin/cical.sh add event 'Finals break' 2026-12-14 2026-12-18          # all-day, end inclusive
bin/cical.sh add repeating event weekly 'Weekly meeting' '2027-01-27 18:00' until 2027-05-05
bin/cical.sh add repeating event biweekly 'Hands-on demo' '2027-02-03 19:00-20:00' until 2027-05-05
bin/cical.sh skip event weekly-meeting-20270127@cicrwu.org '2027-03-17 18:00'
bin/cical.sh remove event ctf-night-20261120@cicrwu.org
bin/cical.sh check                                                    # structure, UIDs, line length, CRLF
```

When a new one-time event overlaps an existing one (including one week of a repeating event), `add` asks whether to **merge** it in, add it separately, or cancel. Merging appends the title (`Weekly Meeting — Guest Speaker: Tony Faria`) and description, and fills in a missing or `TBD` location. For a repeating event, only that one occurrence changes. `merge event UID` does the same for an event that is already in the file:

```bash
bin/cical.sh merge event guest-speaker-tony-faria-20261102@cicrwu.org
```

`bin/cical.sh help` shows the full syntax. The sections below cover editing the file by hand.

## Adding an event

Paste a `VEVENT` block before `END:VCALENDAR` in `cic.ics`:

```
BEGIN:VEVENT
UID:<short-slug>-<yyyymmdd>@cicrwu.org
DTSTAMP:<yyyymmdd>T000000Z
DTSTART;TZID=America/New_York:<yyyymmdd>T<hhmmss>
DTEND;TZID=America/New_York:<yyyymmdd>T<hhmmss>
SUMMARY:<title>
LOCATION:<room>
DESCRIPTION:<one line>
END:VEVENT
```

- `UID` must be unique and **never change** once published; subscribed calendars use it to update the event instead of duplicating it.
- Bump `DTSTAMP` (UTC) whenever you edit an existing event.
- Always use `TZID=America/New_York` for timed events so daylight saving is handled correctly.
- All-day events use dates only, with `DTEND` the day *after*:
  `DTSTART;VALUE=DATE:20261205` / `DTEND;VALUE=DATE:20261206`
- Commas and semicolons in text must be escaped: `\,` `\;`. Lines longer than 75 characters may be folded by starting the next line with a single space.

## Recurring events

- Repeat with `RRULE`, e.g. weekly until the end of the semester:
  `RRULE:FREQ=WEEKLY;UNTIL=20261210T045959Z`.
  - Use `INTERVAL=2` for every other week.
- Skip one occurrence with `EXDATE`. Its date and time must match the occurrence's `DTSTART` exactly:
  `EXDATE;TZID=America/New_York:20261125T180000`
- To change a single occurrence, add another `VEVENT` with the **same** `UID` plus a `RECURRENCE-ID` holding the original start time, and give it the new details.

## Checking your edit

```bash
python3 -m http.server -d www
# open http://localhost:8000/calendar/
```

The page shows an error banner if the file fails to parse.
