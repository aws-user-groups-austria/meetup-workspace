# meetup-workspace

The meetup evening of the AWS User Groups in Austria, from just the Meetup
event link: the room screen that runs the evening on its own (pre-show,
welcome, the host's slot, each speaker's handover, break, closing), the
group's slide deck filled in, and a page per meetup on
[awscommunity.at](https://awscommunity.at) with a live header. The contract
every repository builds against is [`SPEC.md`](SPEC.md).

This repository is the workspace: the Makefile that runs everything, the
spec, and this guide. The parts are repositories of their own in
[aws-user-groups-austria](https://github.com/aws-user-groups-austria); `make clone` puts them in this folder.

| Repository | What |
|---|---|
| [`meetup-sync`](https://github.com/aws-user-groups-austria/meetup-sync) | Command line: a Meetup page (link or saved HTML) to `event.json`, with Sessionize, photos and logos |
| [`meetup-event-vienna`](https://github.com/aws-user-groups-austria/meetup-event-vienna) | One folder per meetup: `source.json` (link and overrides), the generated `event.json` and `meetup.json`; shared photos, logos, badges |
| [`meetup-stream-templates`](https://github.com/aws-user-groups-austria/meetup-stream-templates) | The Remotion scenes, Studio, stills, and `web-player/`: the room screen and the meetup pages' live header |
| [`meetup-deck`](https://github.com/aws-user-groups-austria/meetup-deck) | Python: the group's slide deck (.pptx and PDF) filled in for one meetup |
| [`aws-community-austria-website`](https://github.com/aws-user-groups-austria/aws-community-austria-website) | [awscommunity.at](https://awscommunity.at): a page per meetup, `/present/`, `/organizers/`, the prep guide |
| `out/` | Screenshots of the last end-to-end check (generated, not in git) |

## Get it

```sh
git clone https://github.com/aws-user-groups-austria/meetup-workspace.git
cd meetup-workspace
make clone      # the five repositories above, into this folder
make install
```

The group's deck template (Google Slides, downloaded as .pptx) holds the
organizers' contacts and is never committed: save it as
`meetup-event-vienna/deck/aws-ug-vienna-austria.pptx` before `make deck`.

## Automatic updates, every Monday and Friday

| When (UTC) | Where | What |
|---|---|---|
| 05:30 | `meetup-event-vienna`, "Update meetups" | `make update`: the past meetups from the archive page, each coming meetup synced, a folder for a meetup announced since. Committed when something changed (a run that only fetched again leaves nothing to commit) |
| 06:30 | the website, "Update meetup pages" | The room screen built from `meetup-stream-templates`, then `npm run present:sync` and a build: the meetup pages, `/present/` and the live headers. Committed and deployed when something changed |
| daily 06:00 | the website, "Fetch Meetup Events" | The next and last meetup of each group, for the start page and the group pages |

Both scheduled jobs can be started by hand from the repository's Actions tab ("Run workflow").

Not automatic: the slide decks. The deck template holds the organizers'
contacts and stays out of git, and the PDF comes from PowerPoint, so before a
meetup an organizer runs `make deck EVENT=<id>` and then publishes the decks
with `npm run present:sync` in the website. The scheduled job leaves the
published decks as they are.

## Try it yourself

Everything runs from this folder with `make`; `make` alone lists the
targets. Needs Node 24, npm and `uv`.

Once, install everything:

```sh
make install
```

Start the evening: this syncs the event from Meetup and Sessionize, builds
the player, copies it into the website, and runs both. It prints the
rehearsal links; Ctrl-C stops both:

```sh
make start
```

| Open | What you see |
|---|---|
| `http://127.0.0.1:4100/?event=2026-10-20-aws-meetup-vienna-53&at=17:55` | The pre-show, 5 minutes before the talks, with the countdown |
| the same with `&speed=10` | The whole evening, ten times faster |
| `&at=18:09:50` | The handover to the first speakers |
| `&at=18:52` | The break, counting down to 19:20, with who is next |
| `&at=19:59:50` | The closing: thank you, feedback QR code, networking until 22:00 |
| `http://localhost:5173/` | The website: "Present" at the bottom of a meetup page (or `/organizers/`) opens `/present/` |

`make links` prints the full list again. In the player: `→` `Space` `PgDn`
next, `←` `PgUp` back, `A` back to the clock, `+` `-` move the rest of the
evening a minute, `F` fullscreen, `B` black, `?` help.

The slide deck in our design, as `.pptx` and as the PDF to present from (needs
the group's deck saved as `meetup-event-vienna/deck/aws-ug-vienna-austria.pptx`,
see below; PowerPoint exports the PDF):

```sh
make deck
```

Both land in `meetup-event-vienna/events/<id>/deck/` (`<id>.pptx`, `<id>.pdf`).
Open the PDF:

```sh
make open-deck
```

Every test suite and the audits:

```sh
make check
```

```sh
make audit
```

If a port is still taken from an earlier run:

```sh
make stop
```

## Where the content comes from

| Source | What it gives | Where it is set |
|---|---|---|
| The Meetup page | Title, date, venue, the agenda with times, talks, speakers and roles, sponsor, notices, header image | `meetupUrl` in `events/<id>/source.json` |
| Sessionize | Speaker photos for the stream screens, and abstracts or speakers the page left out | `sessionize` in `source.json`: the API endpoint id |
| Canva | The speaker cards and header the team designs for the announcement, used as the deck's talk slides | PNGs in `events/<id>/canva/` |
| `overrides` in `source.json` | Anything else or anything to correct: a feedback form, a logo, a photo | `source.json` |

Later sources fill gaps or win over earlier ones: Meetup, then Sessionize
(gaps only), then the overrides.

**Sessionize.** The endpoint for 20 October is `3epsgjj2`. Either format
works: the embed (HTML) it has now, or JSON. JSON is better, because it also
carries the abstracts. In Sessionize, API / Embed, that endpoint: Format
JSON, Includes sessions Accepted, Save. Accepted rather than All, because the
endpoint is public and All publishes every submission, including the ones
not accepted. A talk only gets photos when it is on Sessionize with the same
title; `make sync` warns about each talk it cannot find.

**Canva.** Export the event's pages from the Canva design as PNG
(1920 x 1080) into `meetup-event-vienna/events/<id>/canva/`: `header.png`
for the header slide, and one per talk named after its segment id,
`talk-1.png`, `talk-2.png`. `make deck` uses them in place of the stream's
stills. They show speaker photos, so they are gitignored. For 20 October they
are pages 1, 3 and 4 of "Copy of AWS UG Vienna 2025".

## Adding what is missing, by hand

Anything Meetup and Sessionize do not have goes into `overrides` in
`meetup-event-vienna/events/<id>/source.json`, and wins over both. Talks are
addressed by their segment id (`talk-1`, `talk-2`, as in `event.json`),
speakers by name. Images go into `events/<id>/assets/`. Then `make sync`
(or `make start`). The 20 October event does this for the speaker photos
and the RBI logo, cut from the Canva announcement:

```json
"overrides": {
  "sponsors": [
    { "name": "Raiffeisen Bank International AG", "logo": "events/2026-10-20-aws-meetup-vienna-53/assets/rbi.png" }
  ],
  "segments": [
    { "id": "talk-1", "talk": { "speakers": [
      { "name": "Roman Jokel", "photo": "events/2026-10-20-aws-meetup-vienna-53/assets/roman-jokel.png" }
    ] } }
  ]
}
```

The same way, by hand: a talk's `abstract`, a speaker's `role` or
`company`, a speaker the page does not name (a new name is added to the
talk), `links.feedback` for a feedback form, `venue.name`. A whole talk that
is not on the Meetup page at all is better added to the Meetup description
(the agenda is read from there); an override segment with a new id is
added too, but must fit the agenda's time order. `make sync` reports any
key it does not know, so a typo does not go unnoticed.

## From a Meetup link to the live site

1. Create the event folder from the link. This fetches the Meetup page once,
   works out the id (date plus title slug), writes `source.json` and runs the
   sync. In `meetup-event-vienna`:

   ```sh
   make new URL="https://www.meetup.com/amazon-web-services-aws-vienna/events/316893745/"
   ```

2. Add what the page does not have, in `events/<id>/source.json` under
   `overrides`: a feedback form, a next-events link, speaker photos and the
   sponsor logo (files in `events/<id>/assets/`, only with the owner's
   consent). Then sync again, in `meetup-event-vienna`:

   ```sh
   make sync EVENT=2026-10-20-aws-meetup-vienna-53
   ```

3. Look at the evening as stills, in `meetup-stream-templates`. They land in
   `out/stills/`; `Agenda.png` is the still for the slide deck:

   ```sh
   make stills EVENT=2026-10-20-aws-meetup-vienna-53
   ```

4. Rehearse it in the player, in `meetup-stream-templates`. Copy the event
   in, start the dev server, and open
   `http://127.0.0.1:4100/?event=2026-10-20-aws-meetup-vienna-53&at=17:55&speed=10`:

   ```sh
   make player-event EVENT=2026-10-20-aws-meetup-vienna-53
   ```

   ```sh
   make player
   ```

5. The slide deck, in `meetup-event-vienna`. Save the group's deck from
   Google Slides as `deck/aws-ug-vienna-austria.pptx` first (it stays out of
   git); this writes `events/<id>/deck/<id>.pptx` with the number, the Meetup
   header image, the sponsor, the agenda and the evening's slides:

   ```sh
   make deck EVENT=2026-10-20-aws-meetup-vienna-53
   ```

6. Build the player, in `meetup-stream-templates`:

   ```sh
   make player-build
   ```

7. Publish it on the website, in `aws-community-austria-website`. This copies
   the player build, every `event.json`, their `assets/` and an
   `events/index.json` (Meetup link to id) into `public/present/`:

   ```sh
   npm run present:sync
   ```

   ```sh
   npm run build
   ```

   Commit `public/present/` and push; GitHub Pages serves it at `/present/`. Every
   event card whose Meetup link is in `events/index.json`, including the cards
   fetched into `public/data/meetups.json`, has a page at `/meetups/<id>/` with a quiet "Present" link for
   organizers at the bottom, linking to `/present/?event=<id>`.

8. On the evening, open that link on the room laptop and press `F`. The
   player follows the clock; `→` and `←` (or a clicker) step, `A` goes back to
   the clock, `+` and `-` move the rest of the evening a minute when it runs
   late, `?` shows the help. See `meetup-stream-templates/web-player/README.md`.

## Checks

Each folder's README has its own tests and audit. The full set, in each
folder:

```sh
npm test
```

```sh
npm audit
```

In `meetup-stream-templates`, typecheck, tests and player build together,
then the headless Chrome run of the built player at simulated times:

```sh
make check
```

```sh
make player-check
```

In `meetup-deck`, the Python tests:

```sh
uv run pytest
```
