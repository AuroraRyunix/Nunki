# The launcher's Details panel

What the Windows launcher's *Details* window and `./nunki.sh details` show,
and the one endpoint that answers them. Alnasl, Arkab and OpenPairings have
the same endpoint with their own numbers.

## Who may ask

`GET /_launcher/stats`, answered only when all three hold, and a 404 like
any missing page otherwise - with no hint which failed:

1. the peer is this machine, read from the socket, never from a header.
   The pages may be open to the hall's network (`NUNKI_LISTEN=lan`); this is
   not;
2. the header `x-launcher-token` carries this start's secret;
3. no proxy header is on the request (`x-forwarded-for`, `forwarded`,
   `x-real-ip`, `cf-connecting-ip`, `x-forwarded-host`).

The secret: the Windows launcher makes one per start and hands it over in
`NUNKI_LAUNCHER_TOKEN`. Without a launcher (`nunki.sh`, the systemd service,
a Mac), Nunki makes its own and writes it to `<data>/run/launcher.token` -
the secret on the first line, the port on the second - readable by the
owner only, and deletes it on a clean stop. `config :nunki,
launcher_details: false` (the tests) makes none, and the answer is always
404.

## What comes back

`?lang=nl` puts `summary` in Dutch; anything else is English. Nothing in it
runs a program or asks the voice for its list: it is what Nunki already
holds, cheap enough to ask every two seconds.

```json
{"app": "nunki", "version": "0.1.0", "uptime_s": 3600, "started_at": "...",
 "system": {"os": "windows", "os_version": "10.0.26100", "arch": "...", "cores": 8,
            "otp": "27", "elixir": "1.18.4", "load_average": null},
 "beam": {"memory_bytes": {"total": 0, "processes": 0, "ets": 0, "binary": 0, "code": 0},
          "processes": 400, "schedulers": 8, "run_queue": 0, "cpu_percent": 0.4},
 "state": {"path": "C:\\Users\\...\\NunkiData\\state.json", "size_bytes": 1200},
 "log": {"source": "file", "path": "..."},
 "nunki": {"live_views": 2, "tournaments": 1, "links_up": 1,
           "voice": "en: Microsoft Zira (en-US); nl: Microsoft Frank (nl-NL)",
           "speaking": false},
 "summary": [{"label": "Version", "value": "Nunki 0.1.0"}, "..."]}
```

| Field | What |
|---|---|
| `state` | `state.json`, where it is and how big. There is no database |
| `log` | `file` (the launcher's log), `journald` (the systemd unit) or `stdout` |
| `nunki.tournaments` | joined tournaments |
| `nunki.links_up` | of those, the lines that are up |
| `nunki.voice` | the voice each language would be spoken with, as last looked up |
| `nunki.speaking` | whether a line is being said right now |

Nothing in the answer is a secret: not this start's, not a tournament's
key. A test checks both.
