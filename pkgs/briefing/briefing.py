"""Generate a periodic briefing (daily, later weekly, ...) for Home Assistant.

Pipeline:  collectors -> prompt -> Ollama -> JSON file read by an HA sensor.

Every source is a collector: a function (cfg, opts, now) -> list[Section].
Collectors never raise; a failing source becomes a section saying so, so one
broken source (mail server down, vault not synced) doesn't kill the briefing.
Adding a source (e.g. Slack) means writing one collector, registering it in
COLLECTORS and enabling it for a kind in the Nix config.

Facts that must be exact (the agenda) are rendered by this script, not by the
model; the model writes the narrative overview on top.

Usage: briefing --config config.json [--dry-run] KIND|commute
Secrets come from $CREDENTIALS_DIRECTORY (systemd LoadCredential=).
"""

import argparse
import datetime as dt
import email
import email.policy
import html
import imaplib
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Section:
    title: str
    body: str
    # rendered verbatim below the model's text
    verbatim: bool = False
    # only shown to the model, e.g. raw journal text
    private: bool = False
    errors: list = field(default_factory=list)


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def secret(name):
    creds = os.environ.get("CREDENTIALS_DIRECTORY")
    if not creds:
        raise RuntimeError(f"no $CREDENTIALS_DIRECTORY, can't read secret {name}")
    return (Path(creds) / name).read_text().strip()


def http_json(url, *, data=None, headers=None, timeout=30):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers or {})
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def midnight(day):
    return dt.datetime.combine(day, dt.time(), tzinfo=dt.datetime.now().astimezone().tzinfo)


def truncate(text, limit):
    return text if len(text) <= limit else text[:limit] + " [...]"


def ha_get(cfg, path):
    headers = {"Authorization": f"Bearer {secret('ha_token')}"}
    return http_json(f"{cfg['home_assistant']['url']}{path}", headers=headers)


def fetch_events(cfg, opts, start, end):
    """Events from HA calendars between start and end, sorted.

    opts.include: calendar names to read (default: all)
    opts.ignore:  regexes for routine events (standups, ...) to leave out
    All-day events start and end at midnight, end inclusive.
    """
    include = set(opts.get("include", []))
    ignore = [re.compile(p, re.I) for p in opts.get("ignore", [])]
    query = urllib.parse.urlencode({"start": start.isoformat(), "end": end.isoformat()})
    events = []
    for cal in ha_get(cfg, "/api/calendars"):
        if include and cal["name"] not in include:
            continue
        for ev in ha_get(cfg, f"/api/calendars/{cal['entity_id']}?{query}"):
            if any(p.search(ev.get("summary", "")) for p in ignore):
                continue
            s, e = ev["start"], ev["end"]
            if "dateTime" in s:
                es = dt.datetime.fromisoformat(s["dateTime"]).astimezone()
                ee = dt.datetime.fromisoformat(e["dateTime"]).astimezone()
            else:
                # end date is exclusive
                es = midnight(dt.date.fromisoformat(s["date"]))
                ee = midnight(dt.date.fromisoformat(e["date"]) - dt.timedelta(days=1))
            events.append({
                "start": es, "end": ee, "allday": "date" in s,
                "summary": ev.get("summary") or "(no title)",
                "location": ev.get("location") or "",
                "description": ev.get("description") or "",
                "calendar": cal["name"],
            })
    return sorted(events, key=lambda e: (e["start"], not e["allday"]))


# --- collectors ------------------------------------------------------------

def collect_calendar(cfg, opts, now):
    """Events from HA calendars, one verbatim section per day."""
    days = [now.date() + dt.timedelta(days=i) for i in range(opts.get("days", 2))]
    events = fetch_events(cfg, opts, midnight(days[0]), midnight(days[-1] + dt.timedelta(days=1)))
    several = len({e["calendar"] for e in events}) > 1

    sections = []
    for i, day in enumerate(days):
        label = {0: "Today", 1: "Tomorrow"}.get(i, day.strftime("%A"))
        lines = []
        for ev in events:
            es, ee = ev["start"], ev["end"]
            if not es.date() <= day <= ee.date():
                continue
            if ev["allday"]:
                when = "all day"
            elif es.date() == ee.date():
                when = f"{es:%H:%M}–{ee:%H:%M}"
            else:
                when = f"from {es:%a %H:%M}"
            line = f"- **{when}** {ev['summary']}"
            if ev["location"]:
                line += f" · {ev['location']}"
            if several:
                line += f" _({ev['calendar']})_"
            lines.append(line)
        body = "\n".join(lines) or "_Nothing scheduled._"
        sections.append(Section(f"{label}, {day:%a %d %b}", body, verbatim=True))
    return sections


def _clean_note(text):
    """Drop Obsidian noise that only costs tokens: frontmatter, queries,
    comments, embeds."""
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    text = re.sub(r"```(dataview|dataviewjs|tasks|query)\n.*?```", "", text, flags=re.S)
    text = re.sub(r"%%.*?%%|<!--.*?-->", "", text, flags=re.S)
    text = re.sub(r"!\[\[[^\]]*\]\]", "", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def _heading_section(text, heading):
    """The body under a markdown heading, up to the next heading of the same
    or a higher level. None if the heading isn't there."""
    m = re.search(rf"^(#+)\s*{re.escape(heading)}\s*$", text, re.M)
    if not m:
        return None
    rest = text[m.end():]
    end = re.search(rf"^#{{1,{len(m.group(1))}}}\s", rest, re.M)
    return rest[:end.start() if end else None].strip()


def _ago(back):
    return {0: "today", 1: "yesterday"}.get(back, f"{back} days ago")


def collect_journal(cfg, opts, now):
    """The most recent daily journal entries plus the outlook part of the
    latest weekly reflection.

    Entries are often written late in the evening or the next day, so at
    briefing time yesterday's may be missing: take the newest `entries` that
    exist within `lookback_days` rather than fixed dates.

    """
    vault = Path(cfg["vault"])
    daily = opts.get("daily_path", "Journal/{d:%Y}/{d:%Y-%m}/{d:%Y-%m-%d} Daily Journal.md")
    weekly = opts.get("weekly_path", "Journal/{d:%Y}/{d:%Y-%m}/{d:%Y-%m-%d} Weekly Reflections.md")
    limit = opts.get("max_chars", 4000)
    sections = []

    heading = opts.get("weekly_heading")
    if heading:
        for back in range(0, opts.get("weekly_lookback_days", 7) + 1):
            day = now.date() - dt.timedelta(days=back)
            path = vault / weekly.format(d=day)
            if path.exists():
                part = _heading_section(_clean_note(path.read_text(errors="replace")), heading)
                if part:
                    sections.append(Section(f"{heading} (my weekly reflection, {_ago(back)})",
                                            truncate(part, limit), private=True))
                else:
                    log(f"journal: no '{heading}' section in {path.name}")
                break

    found = []
    for back in range(0, opts.get("lookback_days", 4) + 1):
        if len(found) == opts.get("entries", 2):
            break
        day = now.date() - dt.timedelta(days=back)
        path = vault / daily.format(d=day)
        if path.exists():
            text = _clean_note(path.read_text(errors="replace"))
            if text:
                # small models read "today" in a note as the briefing's today
                # unless told which day the entry is about
                found.append(f"### Entry for {_ago(back)}, {day:%A %d %b}\n{truncate(text, limit)}")
    body = "\n\n".join(reversed(found)) or "No recent journal entries."
    sections.append(Section("My journal, most recent last", body, private=True))
    return sections


# automated mail gets a subject line, mail from people the full text
BULK_SENDER = re.compile(r"no-?reply|do-?not-?reply|notification|newsletter|mailer-daemon", re.I)
QUOTE_START = re.compile(
    r"^(On .{5,200} wrote:|Am .{5,200} schrieb .{1,100}:|-+ ?Original Message ?-+|"
    r"-+ ?Ursprüngliche Nachricht ?-+|From: .+|Von: .+)$", re.M)


UNSUBSCRIBE = re.compile(r"unsubscribe|abmelden|abbestellen|désinscri", re.I)


def _is_bulk(msg, text):
    if msg["List-Unsubscribe"] or msg["List-Id"]:
        return True
    if (msg["Precedence"] or "").lower() in ("bulk", "list", "junk"):
        return True
    if (msg["Auto-Submitted"] or "no").lower() != "no":
        return True
    if BULK_SENDER.search(msg["From"] or ""):
        return True
    # marketing that skips the list headers still has an unsubscribe link
    return bool(UNSUBSCRIBE.search(text))


def _mail_text(msg):
    part = msg.get_body(preferencelist=("plain", "html"))
    if part is None:
        return ""
    try:
        text = part.get_content()
    except (LookupError, ValueError):
        return ""
    if part.get_content_type() == "text/html":
        text = re.sub(r"(?is)<(script|style).*?</\1>", " ", text)
        text = re.sub(r"(?i)<br\s*/?>|</p>|</div>", "\n", text)
        text = html.unescape(re.sub(r"<[^>]+>", " ", text))
    # only the new part of a reply, not the quoted thread below it
    m = QUOTE_START.search(text)
    if m:
        text = text[:m.start()]
    lines = [" ".join(line.split()) for line in text.splitlines() if not line.lstrip().startswith(">")]
    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()


def collect_mail(cfg, opts, now):
    """Recent inbox mail. Mail from people with its text, automated mail
    (newsletters, notifications, shops) as one line each."""
    m = cfg["imap"]
    since = now - dt.timedelta(hours=opts.get("hours", 24))
    personal, bulk = [], []
    with imaplib.IMAP4_SSL(m["host"], m.get("port", 993), timeout=30) as conn:
        conn.login(m["user"], secret("imap_password"))
        conn.select(opts.get("mailbox", "INBOX"), readonly=True)
        _, data = conn.search(None, "SINCE", since.strftime("%d-%b-%Y"))
        ids = data[0].split()[-opts.get("limit", 40):]
        for num in reversed(ids):
            # BODY.PEEK so nothing gets marked as read
            _, resp = conn.fetch(num, "(FLAGS INTERNALDATE BODY.PEEK[])")
            meta, raw = resp[0]
            received = imaplib.Internaldate2tuple(meta)
            if received and dt.datetime(*received[:6]).astimezone() < since:
                continue
            msg = email.message_from_bytes(raw, policy=email.policy.default)
            unread = "" if b"\\Seen" in meta else "[unread] "
            head = f"{unread}From: {msg['from']} | Subject: {msg['subject']}"
            text = _mail_text(msg)
            if _is_bulk(msg, text):
                bulk.append(f"- {head}")
            else:
                personal.append(f"#### {head}\n{truncate(text, opts.get('body_chars', 1500))}")
    return [
        Section("Mail from people", "\n\n".join(personal) or "None.", private=True),
        Section("Automated mail (newsletters, shops, notifications)", "\n".join(bulk) or "None.", private=True),
    ]


COLLECTORS = {
    "calendar": collect_calendar,
    "journal": collect_journal,
    "mail": collect_mail,
}


def collect(cfg, kind, now):
    sections = []
    for name, opts in kind["sources"].items():
        try:
            sections += COLLECTORS[name](cfg, opts, now)
        except Exception as e:  # one broken source must not kill the briefing
            log(f"source {name} failed: {e!r}")
            sections.append(Section(name.capitalize(), f"(unavailable: {e})", errors=[str(e)]))
    return sections


# --- model -----------------------------------------------------------------

def build_prompt(kind, sections, now):
    ctx = "\n\n".join(f"## {s.title}\n{s.body}" for s in sections)
    return (
        f"Current time: {now:%A, %d %B %Y, %H:%M}.\n\n"
        f"{kind['prompt']}\n\n"
        f"Source material:\n\n{ctx}"
    )


def generate(cfg, kind, prompt):
    o = cfg["ollama"]
    est_tokens = len(prompt) // 3
    log(f"prompt ~{est_tokens} tokens")
    if est_tokens > o["num_ctx"] - 2000:
        log(f"warning: prompt is ~{est_tokens} tokens, num_ctx {o['num_ctx']}; "
            "ollama will cut it off, lower the source limits or raise num_ctx")
    resp = http_json(
        f"{o['url']}/api/chat",
        data={
            "model": o["model"],
            "messages": [
                {"role": "system", "content": cfg["system_prompt"]},
                {"role": "user", "content": prompt},
            ],
            "stream": False,
            # thinking took qwen3.5:9b ~7 min instead of ~45 s without a
            # better briefing
            "think": o.get("think", False),
            # keep these in line with Home Assistant's ollama integration,
            # otherwise ollama reloads the model whenever the two alternate
            "keep_alive": o["keep_alive"],
            "options": {"num_ctx": o["num_ctx"], "temperature": 0.3},
        },
        timeout=600,
    )
    return resp["message"]["content"].strip()


# --- commute ---------------------------------------------------------------
#
# No model involved: for the next appointments that have a place, when to
# leave from each HA zone (Buchs, Suhr, ...) to arrive on time by public
# transport, so the evening before you know when to set the alarm.

TRANSPORT_API = "https://transport.opendata.ch/v1/connections"
ONLINE = re.compile(r"teams|zoom|webex|meet\.google|google meet|https?://|\bonline\b", re.I)
# "Schaffhauserstrasse 6, 8006 Zürich", "Bahnhofstr. 12a 5000 Aarau", or with
# the postcode on the next line as in a signature
SWISS_ADDRESS = re.compile(
    r"([A-ZÄÖÜ][\w.\-]*(?: [\w.\-]+){0,3} \d+[a-z]?),?\s+(\d{4}) +([A-ZÄÖÜ][\w\-]*(?: [A-ZÄÖÜ][\w\-]*)?)")
VEHICLE = {"T": "Tram", "B": "Bus", "BUS": "Bus"}


def event_place(ev):
    """Where an event physically is: its location, or else an address in the
    description. None for online meetings and events without a place."""
    loc = ev["location"].strip()
    if loc and not ONLINE.search(loc):
        return loc
    m = SWISS_ADDRESS.search(ev["description"])
    return f"{m[1]}, {m[2]} {m[3]}" if m else None


def origins(cfg, opts, states):
    """Starting points: every HA zone, plus where the person is right now if
    that's outside all zones. Returns [(label, "lat,lon", is_current)]."""
    zones = [s for s in states
             if s["entity_id"].startswith("zone.") and not s["attributes"].get("passive")]
    if opts.get("zones"):
        zones = [z for z in zones if z["attributes"]["friendly_name"] in opts["zones"]]
    pid = opts.get("person")
    persons = [s for s in states
               if (s["entity_id"] == pid if pid else s["entity_id"].startswith("person."))]
    person = persons[0] if len(persons) == 1 else None
    where = person["state"] if person else None

    result = []
    for z in zones:
        a = z["attributes"]
        # a person in zone.home has state "home", in other zones the zone's name
        current = where == ("home" if z["entity_id"] == "zone.home" else a["friendly_name"])
        result.append((a["friendly_name"], f"{a['latitude']:.5f},{a['longitude']:.5f}", current))
    if person and not any(c for *_, c in result) and "latitude" in person["attributes"]:
        a = person["attributes"]
        result.append(("Current location", f"{a['latitude']:.3f},{a['longitude']:.3f}", True))
    return result


def _parse_time(value):
    return dt.datetime.fromisoformat(value).astimezone() if value else None


def find_connection(origin, place, arrive_by):
    """The latest connection that still arrives by arrive_by, summarised."""
    query = urllib.parse.urlencode({
        "from": origin, "to": place, "isArrivalTime": 1, "limit": 4,
        "date": f"{arrive_by:%Y-%m-%d}", "time": f"{arrive_by:%H:%M}",
    })
    data = http_json(f"{TRANSPORT_API}?{query}")
    conns = data["connections"]
    if not conns:
        # usually the place couldn't be resolved: show what the API made of it
        names = [(data.get(k) or {}).get("name") for k in ("from", "to")]
        log(f"commute: no connections {origin!r} -> {place!r}, resolved as {names}")
        return None
    on_time = [c for c in conns if _parse_time(c["to"]["arrival"]) <= arrive_by]
    if on_time:
        c = max(on_time, key=lambda c: (c["from"]["departure"], -_parse_time(c["to"]["arrival"]).timestamp()))
    else:
        c = min(conns, key=lambda c: c["to"]["arrival"])
    legs, platform = [], None
    for sec in c["sections"]:
        j = sec.get("journey")
        if not j:
            continue
        cat = VEHICLE.get(j["category"], j["category"])
        legs.append(f"{cat} {j['number']}" if cat in ("Tram", "Bus") else f"{cat}{j['number']}")
        if platform is None:
            platform = sec["departure"].get("platform")
    return {
        "leave": c["from"]["departure"],
        "arrive": c["to"]["arrival"],
        "delay": c["from"].get("delay"),
        "on_time": bool(on_time),
        "legs": legs,
        "platform": platform,
    }


def commute(cfg, now):
    opts = cfg["commute"]
    cache_path = Path(cfg["state_dir"]) / "commute-cache.json"
    try:
        cache = json.loads(cache_path.read_text())
    except (OSError, ValueError):
        cache = {}
    new_cache, errors = {}, []

    events = fetch_events(cfg, opts, now, now + dt.timedelta(hours=opts.get("horizon_hours", 36)))
    upcoming = [(ev, place) for ev in events
                if not ev["allday"] and ev["start"] > now and (place := event_place(ev))]
    upcoming = upcoming[:opts.get("max_appointments", 3)]
    starts = origins(cfg, opts, ha_get(cfg, "/api/states")) if upcoming else []

    appointments = []
    for ev, place in upcoming:
        arrive_by = ev["start"] - dt.timedelta(minutes=opts.get("arrive_early", 10))
        soon = ev["start"] - now < dt.timedelta(hours=3)
        rows = []
        for label, coords, current in starts:
            if label == "Current location" and ev["start"].date() != now.date():
                continue
            key = f"{coords}|{place}|{arrive_by.isoformat()}"
            hit = cache.get(key)
            age = now - dt.datetime.fromisoformat(hit["fetched"]) if hit else None
            # close to departure delays matter, the day before hourly is
            # plenty; "nothing found" is retried every run
            if hit and hit["conn"] and age < dt.timedelta(minutes=9 if soon else 60):
                conn, entry = hit["conn"], hit
            else:
                try:
                    conn = find_connection(coords, place, arrive_by)
                    entry = {"fetched": now.isoformat(), "conn": conn}
                except Exception as e:
                    log(f"commute: {label} -> {place} failed: {e!r}")
                    errors.append(f"{label} -> {place}: {e}")
                    # keep showing the last result, retry next run
                    conn = hit["conn"] if hit and hit["conn"] else {"error": str(e)}
                    entry = hit
            if entry:
                new_cache[key] = entry
            rows.append({"origin": label, "current": current, **(conn or {})})
        appointments.append({
            "summary": ev["summary"], "start": ev["start"].isoformat(),
            "place": place, "calendar": ev["calendar"], "rows": rows,
        })

    cache_path.write_text(json.dumps(new_cache))
    return appointments, errors


def _hm(value):
    return f"{_parse_time(value):%H:%M}" if value else "–"


def render_commute(appointments, now):
    if not appointments:
        return None, "_No appointments with a place in the next days._"
    blocks = []
    for ap in appointments:
        start = dt.datetime.fromisoformat(ap["start"])
        day = {0: "Today", 1: "Tomorrow"}.get((start.date() - now.date()).days, f"{start:%a %d %b}")
        lines = [f"**{day} {start:%H:%M} · {ap['summary']}**  ", ap["place"], "",
                 "| From | Leave | Arrive | Via |", "|:--|:--|:--|:--|"]
        for r in ap["rows"]:
            if r.get("error"):
                lines.append(f"| {r['origin']} | – | – | lookup failed, retrying |")
                continue
            if not r.get("leave"):
                lines.append(f"| {r['origin']} | – | – | no connection found |")
                continue
            origin = f"📍 **{r['origin']}**" if r["current"] else r["origin"]
            leave = _hm(r["leave"]) + (f" +{r['delay']}'" if r.get("delay") else "")
            leave = f"**{leave}**" if r["current"] else leave
            arrive = _hm(r["arrive"]) + ("" if r["on_time"] else " ⚠️ late")
            via = " → ".join(r["legs"]) or "walk"
            if r.get("platform"):
                via += f" (pl. {r['platform']})"
            lines.append(f"| {origin} | {leave} | {arrive} | {via} |")
        blocks.append("\n".join(lines))

    # the sensor's state: when to leave for the next appointment, from where
    # you are now (or else the first zone that has a connection)
    rows = [r for r in appointments[0]["rows"] if r.get("leave")]
    best = next((r for r in rows if r["current"]), rows[0] if rows else None)
    state = _parse_time(best["leave"]).isoformat() if best else None
    return state, "\n\n".join(blocks)


# --- main ------------------------------------------------------------------

def write_result(cfg, name, result):
    out = Path(cfg["state_dir"])
    tmp = out / f".{name}.json.tmp"
    tmp.write_text(json.dumps(result))
    tmp.replace(out / f"{name}.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--dry-run", action="store_true",
                    help="print the prompt and the result, don't write anything")
    ap.add_argument("kind", help="a briefing kind from the config, or 'commute'")
    args = ap.parse_args()

    cfg = json.loads(Path(args.config).read_text())
    now = dt.datetime.now().astimezone()

    if args.kind == "commute":
        appointments, errors = commute(cfg, now)
        state, text = render_commute(appointments, now)
        if args.dry_run:
            print(text)
            return
        write_result(cfg, "commute", {"state": state, "text": text, "errors": errors,
                                      "appointments": appointments})
        log(f"wrote commute ({len(appointments)} appointments, {len(errors)} errors)")
        return

    kind = cfg["kinds"][args.kind]
    sections = collect(cfg, kind, now)
    prompt = build_prompt(kind, sections, now)
    if args.dry_run:
        print(prompt, "\n\n========\n")

    summary = generate(cfg, kind, prompt)
    verbatim = "\n\n".join(f"### {s.title}\n{s.body}" for s in sections if s.verbatim)
    text = f"{summary}\n\n{verbatim}".strip()
    errors = [e for s in sections for e in s.errors]

    if args.dry_run:
        print(text)
        return

    archive = Path(cfg["state_dir"]) / args.kind
    archive.mkdir(parents=True, exist_ok=True)
    (archive / f"{now:%Y-%m-%d}.md").write_text(text + "\n")
    generated = now.isoformat(timespec="seconds")
    write_result(cfg, args.kind, {"state": generated, "generated": generated,
                                  "text": text, "errors": errors})
    log(f"wrote {args.kind} briefing ({len(text)} chars, {len(errors)} source errors)")


if __name__ == "__main__":
    main()
