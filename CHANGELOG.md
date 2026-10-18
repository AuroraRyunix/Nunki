# Changelog

What changed in Nunki, newest first. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and each entry is
tagged so that a version can be skimmed:

| tag | meaning |
|---|---|
| [Feature] | something new you can do |
| [Fix] | something that was broken |
| [Change] | existing behaviour works differently |
| [Removed] | something is gone |
| [Security] | a hole closed, or judged not to be one |
| [Verified] | checked against the real thing, no code change |

## [Unreleased]

- [Fix] **Stopping Nunki stops the voice too, whoever goes first.** Every program Nunki starts - `say`, `espeak-ng`, PowerShell, `kill` itself - now has a deadline, and is killed when whoever was waiting for it is gone. The voice reading a line aloud is killed even when the Speaker is not given the chance to say goodbye, and whatever is still talking when Nunki stops goes with it. Erlang closes the port and walks away; the program on the other end used to finish its sentence to an empty hall.
- [Fix] **No part of a stop waits forever.** Every supervisor has a deadline, open browser connections get three seconds instead of fifteen, and on the Mac the launcher's SIGKILL after twenty seconds now reaches the whole tree under the server - the BEAM and the programs it started - rather than the BEAM alone. The app's own last resort, ten seconds later, does the same instead of killing only the script and leaving the server to launchd.

- [Change] **The Hall announcer switch is in the Belgian pack** of OpenPairings' Features, not under "Optional tools for any federation", a heading whose main achievement was never being read.

## [0.1.0] - 2026-10-18

- [Feature] **Nunki exists.** It reads the pairings aloud the moment OpenPairings publishes them, white first, byes last, and counts down to the round: ten minutes, five, one, and "starts now". Only the moments still ahead, so a countdown started at five minutes does not open with "ten".
- [Feature] **English and Dutch**, following the tournament unless the control page says otherwise. Dutch says "je", because nobody in a playing hall has ever been addressed as "u" by a loudspeaker and liked it.
- [Feature] **The machine's own voice, not the browser's:** PowerShell on Windows, `say` on a Mac, espeak-ng on Linux. It speaks with every page closed and never waits for somebody to click first.
- [Feature] **A control page:** join a tournament with one pasted link, see whether each line is up and why not, Read now, Stop, a countdown of your own, the voice per language and a button to hear it before the players do.
- [Feature] **A hall screen for a projector:** the minutes in very large digits, then "Round 3 has started"; the latest pairings otherwise; the line being said at the bottom. One button for full screen.
- [Feature] **A round that is corrected after it was read is not read again by itself.** Reading the same pairings twice is how a hall learns to stop listening.
- [Feature] **Installers and updates as in the other hall programs:** a Windows installer that updates itself and a portable zip, Linux archives for PCs and the Raspberry Pi with a one-line installer and a systemd service, and an Apple Silicon Mac app. An update refuses while a countdown runs or Nunki is speaking, unless somebody says yes twice; a countdown that stops a minute before zero is a round that starts in silence. The news of a newer version is on the control page and the help, and never on the hall screen, which the players read and which is none of their business.
- [Feature] **"Start Nunki when Windows starts"**, on the control page of an installed Windows copy, off until somebody turns it on. Uninstalling takes the setting with it, so Windows is not left starting something that is gone.
