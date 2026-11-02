/* cicrwu.org/calendar — renders cic.ics with ical.js (vendor/ical.min.js). */

(function () {
  "use strict";

  var FEED = "cic.ics";
  var TZ = "America/New_York";
  var UPCOMING = 8;           // events shown in the "Upcoming" list
  var LOOKAHEAD = 180;        // days searched for upcoming events
  var MAX_STEPS = 2000;       // safety cap per recurring event

  var grid = document.getElementById("cal-grid");
  var list = document.getElementById("cal-list");
  var title = document.getElementById("cal-title");
  if (!grid || !list || !window.ICAL) return;

  /* ---- dates: everything is bucketed by its calendar day in TZ ---- */

  var dayKeyFmt = new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" });
  var timeFmt = new Intl.DateTimeFormat("en-US", { timeZone: TZ, hour: "numeric", minute: "2-digit" });
  var monthFmt = new Intl.DateTimeFormat("en-US", { timeZone: "UTC", month: "long", year: "numeric" });
  var longDayFmt = new Intl.DateTimeFormat("en-US", { timeZone: "UTC", weekday: "short", month: "short", day: "numeric" });

  function pad(n) { return (n < 10 ? "0" : "") + n; }
  function key(y, m, d) { return y + "-" + pad(m) + "-" + pad(d); }   // m is 1-based
  function keyOf(date) { return dayKeyFmt.format(date); }
  // a UTC-midnight Date for a day key, used only for calendar arithmetic and labels
  function utcDay(k) { var p = k.split("-"); return new Date(Date.UTC(+p[0], p[1] - 1, +p[2])); }
  function addDays(k, n) { var d = utcDay(k); d.setUTCDate(d.getUTCDate() + n); return key(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate()); }

  /* ---- parse the feed ---- */

  var events = [];  // ICAL.Event masters, with RECURRENCE-ID overrides related to them

  function load(text) {
    var cal = new ICAL.Component(ICAL.parse(text));
    cal.getAllSubcomponents("vtimezone").forEach(function (vtz) {
      ICAL.TimezoneService.register(vtz);
    });

    var byUid = {}, overrides = [];
    cal.getAllSubcomponents("vevent").forEach(function (ve) {
      var ev = new ICAL.Event(ve);
      if (ev.isRecurrenceException()) overrides.push(ev);
      else byUid[ev.uid] = ev;
    });
    overrides.forEach(function (ex) {
      if (byUid[ex.uid]) byUid[ex.uid].relateException(ex);
    });
    events = Object.keys(byUid).map(function (uid) { return byUid[uid]; });
  }

  // the instant a floating date starts in TZ (falls back to UTC if the feed has no VTIMEZONE)
  function midnight(date) {
    var zone = ICAL.TimezoneService.get(TZ);
    if (!zone) return utcDay(key(date.year, date.month, date.day));
    return ICAL.Time.fromData({ year: date.year, month: date.month, day: date.day, isDate: false }, zone).toJSDate();
  }

  // a plain occurrence object; all-day events keep their floating date
  function occurrence(item, start, end) {
    var o = { summary: item.summary || "(untitled)", location: item.location || "", description: item.description || "", allDay: start.isDate };
    if (o.allDay) {
      o.day = key(start.year, start.month, start.day);
      o.start = midnight(start);
      o.end = end ? midnight(end) : midnight(start.clone().adjust(1, 0, 0, 0));
    } else {
      o.start = start.toJSDate();
      o.end = end ? end.toJSDate() : o.start;
      o.day = keyOf(o.start);
    }
    return o;
  }

  // every occurrence that overlaps [from, to), sorted by start
  function expand(from, to) {
    var out = [];
    events.forEach(function (ev) {
      if (!ev.isRecurring()) {
        var o = occurrence(ev, ev.startDate, ev.endDate);
        if (o.start < to && o.end > from) out.push(o);
        return;
      }
      var it = ev.iterator(), next, steps = 0;
      while ((next = it.next()) && steps++ < MAX_STEPS) {
        var d = ev.getOccurrenceDetails(next);
        var occ = occurrence(d.item, d.startDate, d.endDate);
        if (occ.start >= to) break;
        if (occ.end > from) out.push(occ);
      }
    });
    return out.sort(function (a, b) { return a.start - b.start || b.allDay - a.allDay; });
  }

  /* ---- rendering helpers (all text goes through textContent) ---- */

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function timeLabel(o) {
    if (o.allDay) return "All day";
    var s = timeFmt.format(o.start);
    return o.end > o.start ? s + " – " + timeFmt.format(o.end) : s;
  }

  function setTitle(text) {
    title.textContent = text;
    title.setAttribute("aria-label", text);   // main.js's decrypt effect reads this
  }

  /* ---- month grid ---- */

  var todayKey = keyOf(new Date());
  var view = { y: +todayKey.slice(0, 4), m: +todayKey.slice(5, 7) };   // m is 1-based
  var DOW = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  function renderMonth() {
    var first = key(view.y, view.m, 1);
    var gridStart = addDays(first, -utcDay(first).getUTCDay());
    var gridEnd = addDays(gridStart, 42);
    setTitle(monthFmt.format(utcDay(first)));

    // pad the range a day each side so TZ offsets never drop an edge event
    var buckets = {};
    expand(utcDay(addDays(gridStart, -1)), utcDay(addDays(gridEnd, 1))).forEach(function (o) {
      (buckets[o.day] = buckets[o.day] || []).push(o);
    });

    var table = el("table", "cal-table");
    var head = table.createTHead().insertRow();
    DOW.forEach(function (d) {
      var th = el("th", null, d);
      th.scope = "col";
      head.appendChild(th);
    });

    var body = table.createTBody(), row;
    for (var i = 0, k = gridStart; i < 42; i++, k = addDays(k, 1)) {
      if (i % 7 === 0) row = body.insertRow();
      var cell = row.insertCell();
      var day = utcDay(k);
      if (day.getUTCMonth() + 1 !== view.m) cell.className = "out";
      if (k === todayKey) { cell.className += " today"; cell.setAttribute("aria-current", "date"); }
      cell.appendChild(el("span", "cal-date", String(day.getUTCDate())));
      (buckets[k] || []).forEach(function (o) {
        var chip = el("span", "cal-ev");
        chip.appendChild(el("b", null, o.allDay ? "" : timeFmt.format(o.start)));
        chip.appendChild(document.createTextNode(o.summary));
        chip.title = timeLabel(o) + " · " + o.summary + (o.location ? " · " + o.location : "");
        cell.appendChild(chip);
      });
    }

    grid.textContent = "";
    grid.appendChild(table);
  }

  document.querySelectorAll(".cal-ctrl [data-step]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var step = +btn.dataset.step;
      if (step === 0) {
        view.y = +todayKey.slice(0, 4);
        view.m = +todayKey.slice(5, 7);
      } else {
        view.m += step;
        if (view.m < 1) { view.m = 12; view.y--; }
        if (view.m > 12) { view.m = 1; view.y++; }
      }
      renderMonth();
    });
  });

  /* ---- upcoming list ---- */

  function renderUpcoming() {
    var now = new Date();
    var soon = expand(now, new Date(now.getTime() + LOOKAHEAD * 864e5)).slice(0, UPCOMING);

    list.textContent = "";
    if (!soon.length) {
      list.appendChild(el("li", "todo", "Nothing scheduled yet. Check back soon."));
      return;
    }
    soon.forEach(function (o) {
      var li = el("li");
      var when = el("time", "cal-when");
      when.dateTime = o.allDay ? o.day : o.start.toISOString();
      when.appendChild(el("strong", null, longDayFmt.format(utcDay(o.day))));
      when.appendChild(el("span", null, timeLabel(o)));
      li.appendChild(when);

      var what = el("div", "cal-what");
      what.appendChild(el("strong", null, o.summary));
      if (o.location) what.appendChild(el("span", "cal-loc", o.location));
      if (o.description) what.appendChild(el("p", null, o.description));
      li.appendChild(what);
      list.appendChild(li);
    });
  }

  /* ---- go ---- */

  function fail(err) {
    if (window.console) console.error("calendar:", err);
    var msg = el("p", "cal-error");
    msg.appendChild(document.createTextNode("Couldn't load the calendar. You can still "));
    var a = el("a", null, "download cic.ics");
    a.href = FEED;
    msg.appendChild(a);
    msg.appendChild(document.createTextNode("."));
    grid.textContent = "";
    grid.appendChild(msg);
    list.textContent = "";
  }

  fetch(FEED, { cache: "no-cache" })
    .then(function (res) {
      if (!res.ok) throw new Error(res.status + " " + res.statusText);
      return res.text();
    })
    .then(function (text) {
      load(text);
      renderMonth();
      renderUpcoming();
    })
    .catch(fail);
})();
