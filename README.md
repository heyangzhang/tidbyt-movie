# Coming Soon for Tidbyt

A [Pixlet](https://github.com/tidbyt/pixlet) app that shows the most-anticipated upcoming theatrical releases on a stock Tidbyt.

**How it picks films:** it takes the top 5 by TMDB popularity among films with a US theatrical or limited release between 6 days ago and 6 weeks from now. It uses the US theatrical date, not festival premieres or earlier international dates.

**What it shows:** it cycles through the films in release order, about 3 seconds each. Each card has the poster, the title, the release date, and `OUT NOW`, `Tomorrow`, or `in N days`.

GitHub Actions renders the app and pushes it to the Tidbyt every day at about 6 am Eastern (`.github/workflows/movies.yml`). It goes into the device's rotation as the slot `movies`.

## Secrets (Settings → Secrets and variables → Actions)

- `TIDBYT_DEVICE_ID`, `TIDBYT_API_TOKEN`: from the Tidbyt app (device settings → General → Get API Key)
- `TMDB_API_KEY`: your TMDB v3 API key, from themoviedb.org → Settings → API

## Local use

```bash
pixlet serve movies.star       # enter the TMDB key in the config panel
./push.sh movies.star movies api_key="$TMDB_API_KEY"
```

To remove the app from the rotation:

```bash
pixlet delete --api-token "$TIDBYT_API_TOKEN" "$TIDBYT_DEVICE_ID" movies
```

Data comes from TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB.
