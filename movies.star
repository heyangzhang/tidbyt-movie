"""
Coming Soon — the next most-anticipated theatrical releases, for Tidbyt.

  ┌──────────────────────────────────┐
  │ Wicked: For Good          Fri    │  this week: weekday
  │ Zootopia 2              Nov 26   │  later: month + day
  │ Avengers: Doomsday      Dec 18   │  long titles scroll
  └──────────────────────────────────┘

Picks the top 3 by TMDB popularity among films with a US theatrical (or
limited) release from today through the next 6 weeks, then lists them in
release order. Films already in theaters are not shown.

Data: TMDB API. `api_key` accepts either the v3 API key or the
API Read Access Token.
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

API = "https://api.themoviedb.org/3"
TTL = 6 * 3600
TZ = "America/New_York"
MAX_FILMS = 3
LOOKAHEAD_DAYS = 42
MAX_CANDIDATES = 15  # most-popular films to check for a US theatrical date

TITLE = "#FFFFFF"
SOON = "#FFC94A"  # opening this week
LATER = "#9AA0A8"
RULE = "#1C2230"

def get_json(config, path, params):
    base = config.get("api_url") or API  # api_url: hidden override for local testing
    key = config.get("api_key").strip()

    # Accept either TMDB credential: the long "API Read Access Token" (a JWT,
    # sent as a Bearer header) or the short v3 "API Key" (a query parameter).
    if key.startswith("eyJ"):
        url = "%s%s?%s" % (base, path, params)
        resp = http.get(url, headers = {"Authorization": "Bearer " + key, "accept": "application/json"}, ttl_seconds = TTL)
    else:
        url = "%s%s?api_key=%s&%s" % (base, path, key, params)
        resp = http.get(url, ttl_seconds = TTL)
    if resp.status_code != 200:
        print("TMDB %s -> HTTP %d" % (path, resp.status_code))  # shows in the Actions log
        return None
    return resp.json()

def us_theatrical_date(config, movie_id, tz):
    """Earliest US limited (2) or theatrical (3) release date, or None."""
    data = get_json(config, "/movie/%d/release_dates" % movie_id, "")
    if data == None:
        return None
    best = None
    for country in data.get("results", []):
        if country.get("iso_3166_1") != "US":
            continue
        for rd in country.get("release_dates", []):
            if int(rd.get("type", 0)) not in (2, 3):
                continue
            t = time.parse_time(rd["release_date"][:10], format = "2006-01-02", location = tz)
            if best == None or t < best:
                best = t
    return best

def days_between(a, b):
    d = (b - a).hours / 24  # round to nearest day (DST can shift by an hour)
    return int(d + 0.5) if d >= 0 else -int(-d + 0.5)

def pick_films(config, today, tz):
    hi = (today + time.parse_duration("%dh" % (24 * LOOKAHEAD_DAYS))).format("2006-01-02")
    params = "region=US&with_release_type=2|3&release_date.gte=%s&release_date.lte=%s" % (today.format("2006-01-02"), hi)
    params += "&sort_by=popularity.desc&include_adult=false&language=en-US&page=1"
    data = get_json(config, "/discover/movie", params)
    if data == None:
        return None

    films = []
    for m in data.get("results", [])[:MAX_CANDIDATES]:
        date = us_theatrical_date(config, int(m["id"]), tz)
        if date == None:
            continue
        days = days_between(today, date)
        if days < 0 or days > LOOKAHEAD_DAYS:  # already out, or too far off
            continue
        films.append({"title": m["title"], "date": date, "days": days})
        if len(films) == MAX_FILMS:
            break

    return sorted(films, key = lambda f: f["days"])

def date_label(f):
    if f["days"] == 0:
        return ("Today", SOON)
    if f["days"] == 1:
        return ("Tmrw", SOON)
    if f["days"] < 7:
        return (f["date"].format("Mon"), SOON)
    return (f["date"].format("Jan 2"), LATER)

def row(f):
    label, color = date_label(f)
    date = render.Text(label, font = "tom-thumb", color = color)
    title_width = 62 - len(label) * 4 - 5
    return render.Box(
        width = 64,
        height = 10,
        child = render.Padding(
            pad = (1, 0, 1, 0),
            child = render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Marquee(
                        width = title_width,
                        child = render.Text(f["title"], font = "tom-thumb", color = TITLE),
                    ),
                    date,
                ],
            ),
        ),
    )

def message(text):
    return render.Root(child = render.Box(child = render.WrappedText(text, color = LATER, align = "center", width = 60)))

def main(config):
    if not config.get("api_key"):
        return message("Add a TMDB API key")

    today = time.parse_time(time.now().in_location(TZ).format("2006-01-02"), format = "2006-01-02", location = TZ)
    films = pick_films(config, today, TZ)
    if films == None:
        return message("Movies unavailable")
    if not films:
        return message("No big releases soon")
    for f in films:
        print("Showing: %s (%s, in %d days)" % (f["title"], f["date"].format("Jan 2"), f["days"]))

    rows = []
    for i, f in enumerate(films):
        if i > 0:
            rows.append(render.Box(width = 64, height = 1, color = RULE))
        rows.append(row(f))

    return render.Root(
        delay = 80,
        max_age = TTL,
        child = render.Box(child = render.Column(main_align = "center", expanded = True, children = rows)),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_key",
                name = "TMDB API key",
                desc = "Your TMDB v3 API key or API Read Access Token.",
                icon = "key",
            ),
        ],
    )
