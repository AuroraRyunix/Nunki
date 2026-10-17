# Changelog

What changed in Nunki, for the people who run it in a hall. The newest is
at the top.

## [Unreleased]

### Added

- Nunki exists. It reads the pairings aloud the moment OpenPairings
  publishes them, white first, byes last, and counts down to the round:
  ten minutes, five, one, and "starts now". Only the moments still ahead,
  so a countdown started at five minutes does not open with "ten".
- English and Dutch, following the tournament unless the control page says
  otherwise. Dutch says "je", because nobody in a playing hall has ever
  been addressed as "u" by a loudspeaker and liked it.
- The machine's own voice, not the browser's: PowerShell on Windows, `say`
  on a Mac, espeak-ng on Linux. It speaks with every page closed and never
  waits for somebody to click first.
- A control page: join a tournament with one pasted link, see whether each
  line is up and why not, Read now, Stop, a countdown of your own, the
  voice per language and a button to hear it before the players do.
- A hall screen for a projector: the minutes in very large digits, then
  "Round 3 has started"; the latest pairings otherwise; the line being said
  at the bottom. One button for full screen.
- A round that is corrected after it was read is not read again by itself.
  Reading the same pairings twice is how a hall learns to stop listening.
- Installers and updates as in the other hall programs. An update refuses
  while a countdown runs or Nunki is speaking, unless somebody says yes
  twice; a countdown that stops a minute before zero is a round that
  starts in silence.
