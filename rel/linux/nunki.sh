#!/bin/sh
# Starts Nunki from this folder, in this terminal, without installing
# anything: to try it, or on a box you would rather not install a service on.
# install.sh, beside this file, is the other way.
#
# The data goes to ~/.nunki (or NUNKI_DATA), not into this folder: a new
# version unpacked beside the old one finds it.
set -e
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PORT=${PORT:-4062}
export PORT

# `./nunki.sh details [--once | --json]`: the numbers the Windows launcher's
# Details panel shows (version, uptime, CPU, memory, the tournaments, the
# links, the voice) and the last lines of the log, in this terminal. It asks
# the Nunki already running from this data folder, through a second,
# short-lived runtime (`eval` starts nothing of the server); see
# Nunki.LauncherDetails.CLI and docs/launcher-details.md.
if [ "${1:-}" = details ]; then
  shift
  exec "$here/bin/nunki" eval "Nunki.LauncherDetails.CLI.main()" "$@"
fi

echo "Starting Nunki on http://localhost:$PORT"
echo "Data: ${NUNKI_DATA:-$HOME/.nunki}"
echo "Press Ctrl-C to stop it. Nothing is announced while it is stopped."
echo
exec "$here/bin/nunki" start
