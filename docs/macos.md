# Nunki on macOS

Every push to `main` builds **`Nunki.app`** for Apple Silicon, and a
release attaches it, together with a build for **Intel Macs** from macOS
10.13 (see [Intel Macs](#intel-macs)), exactly as Alnasl and Arkab do (their `docs/macos.md`
has the long story of the runtime built on the runner and why). Nobody on
the project has a Mac: the list at the end is what a person with one still
has to confirm.

| | |
|---|---|
| Apple Silicon (M1 and later) | `nunki-macos-aarch64.zip`, built on `macos-15`, macOS 11 and newer |
| Intel | `nunki-macos-x86_64.zip`, built on `macos-15-intel`, macOS 10.13 and newer, only for a release or a hand-started run |
| Runtime | Erlang/OTP compiled on the runner by `rel/macos/build_otp.sh`, with OpenSSL linked into `crypto` statically |
| Native code | none of Nunki's own: no database, no serial library. The only NIFs are the runtime's |
| Voice | `say`, which every Mac has |
| Signed | Developer ID, hardened runtime, notarised and stapled (`docs/releasing.md`) |

## Intel Macs

macOS 10 exists only on Intel Macs, so the Intel build is also the one that
reaches back. It is `nunki-macos-x86_64.zip`, compiled on GitHub's Intel
runner (`macos-15-intel`; a real Intel machine, nothing is cross-compiled)
with `MACOSX_DEPLOYMENT_TARGET=10.13`, which `build_otp.sh` and
`build_app.sh` read like the Apple Silicon build reads 11.0.

It is built **only when a release is published** (a version bump on `main`
with its changelog section) **or when the workflow is started by hand**
(*Actions > Build and release > Run workflow*), never on an ordinary push or
pull request: the Intel runner is slow, which is why Intel was dropped on
2026-10-14. The `plan` job in `release.yml` decides, from the release's own
two conditions, and adds the Intel target to the build matrix when it
should run. A release that cannot build for Intel is not published. A
hand-started run on a branch builds everything and publishes nothing: the
`release` job runs only on `main` or a tag.

Nunki's update notice picks the zip that matches the Mac it is on
(`Nunki.Updates.arch/0`): an Intel Mac gets `nunki-macos-x86_64.zip`, an
Apple Silicon Mac `nunki-macos-aarch64.zip`, and an Intel Nunki running
under Rosetta on an Apple Silicon Mac still counts as Apple Silicon
(`sysctl.proc_translated`). `Nunki.Updates.no_build?/1` is now false
everywhere.

### How far back

10.13 (High Sierra) is where the Intel build stops. The proof is in the
smoke test's log: it lists the `minos` of every Mach-O file in the bundle
(`vtool -show-build`) and `LSMinimumSystemVersion` in `Info.plist`, which the
test also compares with the target; `build_app.sh` fails the build, naming
the files, if any asks for more. The launcher is Swift, and macOS before
10.14.4 has no Swift runtime, so the libraries it uses are copied into
`Contents/Frameworks` by `swift-stdlib-tool` and found through an `@rpath`.
A few Foundation and AppKit calls it made are 10.14 or 10.15 and newer
(`scrollableTextView()`, `FileHandle.seekToEnd()` and relatives,
`monospacedSystemFont`); `Launcher.swift` asks `#available` and uses the
older call on 10.13, where it uses any.

**Not tested on a real Mac running 10.13.** The runner is macOS 15. What CI
proves is that nothing in the bundle asks for more than 10.13 and that the
app starts and answers on a current macOS. Whether 10.13 runs it, and
whether `say` speaks the voices Nunki asks for there, is for a person with
a Mac that old.

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

## Signing

Every Mach-O file in the app (the Erlang runtime, `beam.smp`, the NIF
libraries) is signed with the Developer ID Application certificate, the
hardened runtime and a timestamp, from the inside out, then the bundle. The
BEAM's JIT needs entitlements the hardened runtime otherwise forbids
(`rel/macos/entitlements.plist` says which). The bundle is then sent to
Apple's notary service and the ticket is stapled to it, so a Mac with no
network at the venue opens it without a question. The workflow asks
Gatekeeper itself (`spctl -a -vvv -t exec`) and fails unless the answer is
"Notarized Developer ID".

So the first start is a double-click. Only a build from a fork, which has no
signing secrets, is ad-hoc signed; macOS then refuses it once and *System
Settings > Privacy & Security > Open Anyway* is the way in.

To try the signing without a release: run the workflow by hand on any branch
with **mac_only** ticked. It builds, signs, notarises and checks the Mac
apps and publishes nothing.

## Testing a build on a real Mac

1. Download `nunki-macos-aarch64.zip` from the release, unzip, move
   `Nunki.app` to Applications, open it.
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
