# Nunki on macOS

Every push to `main` builds **`Nunki.app`** for Apple Silicon, and a
release attaches it, exactly as Alnasl and Arkab do (their `docs/macos.md`
has the long story of the runtime built on the runner and why). Nobody on
the project has a Mac: the list at the end is what a person with one still
has to confirm.

| | |
|---|---|
| Apple Silicon only (M1 and later) | `nunki-macos-aarch64.zip`, built on `macos-15` |
| Runtime | Erlang/OTP compiled on the runner by `rel/macos/build_otp.sh`, with OpenSSL linked into `crypto` statically |
| Native code | none of Nunki's own: no database, no serial library. The only NIFs are the runtime's |
| Voice | `say`, which every Mac has |
| Signed | ad-hoc only, until there is an Apple Developer account (`docs/releasing.md`) |

## What the app is

`Nunki.app/Contents/MacOS/Nunki` is `rel/macos/Launcher.swift`: a Dock
icon and a small window, "Nunki is running at http://localhost:4062", with
*Open in browser* and *Stop Nunki*. It runs `Resources/launcher.sh`, which
starts the release in `Resources/app/`. Quitting stops the server and asks
first: while Nunki is stopped nothing is announced.

The data is in `~/Library/Application Support/NunkiData`, outside the app,
and stays when the app is binned.

## Voices

`say -v '?'` lists the voices Nunki can choose from. English is there.
Dutch voices are a download: System Settings, Accessibility, Spoken
Content, System voice, Manage voices - Xander, Claire, Ellen (Flemish) and
others. Afterwards press "Look for voices again" on the control page.
Without one, `say` reads Dutch with an English voice, which is a sound
worth hearing once.

## Unsigned, for now

The first open asks: macOS says it cannot check the app for malicious
software. Open System Settings, Privacy & Security, and press "Open Anyway"
beside Nunki. Once per download.

## Testing a build on a real Mac

1. Download `nunki-macos-aarch64.zip` from the release, unzip, move
   `Nunki.app` to Applications, open it ("Open Anyway" as above).
2. The window says it is running; the browser opens on the control page.
3. "Test voice", English: heard. Download a Dutch voice, "Look for voices
   again", choose it, "Test voice", Dutch: heard, in Dutch.
4. Join a tournament from an OpenPairings link; publish a round there; it
   is read aloud.
5. Start a 1-minute countdown on the control page: "one minute", then
   "starts now". Open `/hall`: the minutes run down in big digits.
6. Stop during a long reading: quiet at once; `ps ax | grep say` shows
   nothing left.
7. *Stop Nunki* asks, then stops; no `beam` is left. The data folder is
   still there.
