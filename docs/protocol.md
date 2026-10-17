# The hall link, version 1

How Nunki and OpenPairings talk. The same protocol serves Polis (the print
station); only the product id in the paths and the commands differ. The
server side is `plugins/openpairings_nunki`; the device side is
`lib/nunki/join.ex` and `lib/nunki/link.ex`.

Hall devices always dial out. Nothing in the hall's network has to be
opened, forwarded or known in advance.

## Joining: one link, one step

In OpenPairings, a tournament's *Hall announcer* page, "Add an announcer"
makes a join code: random, at least ten characters, valid fifteen minutes,
good once, bound to that tournament. It is shown as a link and a QR code:

    https://<host>/p/nunki/join/<code>

The operator pastes it into the control page and presses Join. Nunki POSTs
to exactly that address:

    POST <link>
    content-type: application/json

    {"v": 1, "device": "<device id>", "name": "<device name>", "software": "nunki 0.1.0"}

| Answer | Meaning |
|---|---|
| `200 {"key", "socket", "server", "tournament": {"id", "name"}}` | joined. `key` is the device's secret for this tournament (32 random bytes or more, base64url); it goes into `state.json` and is never shown. `socket` is the absolute path of the link. `server` is a name to show. |
| `404`, `410` | the code is unknown, used or expired |
| `409` | the server does not speak this `v` |
| anything else | not an OpenPairings server |

The link's path must end in `/p/<id>/join/<code>`; anything before `/p/` is
kept, so OpenPairings behind a sub-path works. The last `/p/` counts. A link
whose `<id>` is not `nunki` (a print station's) is refused before anything
is sent, so its code is not spent on the wrong device.

The socket address is built from the join link: the same host and port,
`ws` for `http`, `wss` for `https`, and the `socket` path.

## The link: one WebSocket per joined tournament

JSON text frames, each an object with a `type`.

The device connects, sends `hello` first and waits for `welcome`. It pings
every 25 seconds (a tunnel or a proxy must not decide the line is idle) and
takes a line that has said nothing for 75 seconds for dead. A lost line is
tried again after 1 second, doubling to 30; after a refusal, 60 seconds.

### Device to server

| type | fields | when |
|---|---|---|
| `hello` | `v`, `device`, `key`, `name`, `software` | first, always. The key travels here and nowhere else - not in the address, not in a log |
| `status` | `voice` (the voice that would speak the tournament's language, a label, or `null`), `speaking` (boolean) | after `welcome`, and whenever either changes |
| `leave` | | the tournament was removed on the device |

### Server to device

| type | fields | what Nunki does |
|---|---|---|
| `welcome` | `v`, `server`, `tournament: {id, name}` | the line is up; the name is updated if it changed |
| `refused` | `reason`: `version`, `key`, `revoked` | `revoked`: forgets the tournament. The others: says so on the control page and tries again in a minute |
| `round` | `round`: the payload below | keeps it as the latest round; reads it aloud when its number has not been read before and "Read the pairings when they are published" is on. A changed payload of a round already read is not read again by itself |
| `leave` | | removed in OpenPairings while connected: forgets the tournament |
| `countdown` | `round`, `seconds_left` (integer), `id` | starts a countdown to that round, on the device's own monotonic clock. The same `id` again (after a reconnect) only moves the end; nothing already said is said again |
| `countdown_cancel` | `id` | cancels that countdown, and only that one |
| `read` | `round` | reads that round's pairings now (the latest held; another round is not known to the device) |
| `stop` | | stops speaking now and forgets the queue |

The server sends `round` after `welcome` (the latest published round, if
there is one) and whenever its `rev` changes or a newer round is published.
A round taken back is never sent.

### Why seconds, not a time

`countdown` says how many seconds are left, never at what o'clock the round
starts. The device adds them to its own monotonic clock. Nobody's wall
clock is involved, so nobody's wall clock can be wrong - and a hall PC's
wall clock is wrong surprisingly often.

## The round payload

```json
{"tournament": {"id": 12, "name": "Open Brugge", "city": "Brugge", "dates": "2026-10-18 - 2026-10-20"},
 "round": 3, "rounds": 7, "published_at": "2026-10-18T13:02:00Z",
 "locale": "nl", "rating_label": "Elo", "team": false,
 "boards": [{"board": "1",
             "white": {"name": "Last, First", "spoken": "First Last", "title": "GM",
                       "rating": 2830, "federation": "NOR", "club": "", "number": 1, "score": "2"},
             "black": {"...": "..."},
             "bye": null}],
 "rev": "<hex sha256 of the payload without rev>"}
```

- `board` is a string: team tournaments may say `"2.3"`.
- `black` is `null` for a bye, and `bye` says which.
- `spoken` is what Nunki says; without it, Nunki turns `name` round itself.
- `locale` is the OpenPairings account's language, `"nl"` or `"en"`. Nunki
  announces in it unless the control page says otherwise.

## What the server must not expect

- A device to be connected. Announcing is the device's business; the
  server only says what happened. A device that was off when a round was
  published hears it on `welcome` - and reads it, since it was never read.
- A device to answer a command. There is no reply frame; `status` says
  what the device is doing, when it changes.
