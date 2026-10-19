# SPEC: the meetup evening stream

The contract every repository in this workspace builds against. Change it here
first, then in the code.

## Goal

Paste a Meetup event link, get a full evening on screen, startable from
awscommunity.at: a pre-show loop while doors are open, then welcome, the sponsor
handover, each speaker's handover, the break with a countdown and what is next,
the closing with a feedback ask, and the last networking with how long people
can stay. It follows the clock on its own; the host can step forward or back.

First event: AWS Meetup Vienna #53, hosted by RBI, 20 October 2026,
<https://www.meetup.com/amazon-web-services-aws-vienna/events/316893745/>.

## Repositories

| Folder | What | Depends on |
|---|---|---|
| `meetup-sync/` | Node + TypeScript CLI: Meetup URL (or a saved HTML file) to `event.json`. Reads the page's JSON-LD `Event` (name, startDate, endDate, location, organizer) and the description markdown in `__NEXT_DATA__` (agenda lines, talks, speakers, sponsors, notices). Test fixture: `tests/fixtures/aws-meetup-vienna-53.html` (the real page, saved 16 Oct 2026) | nothing |
| `meetup-stream-templates/` | Remotion compositions for every scene (`src/`), Studio, stills; and `web-player/`, the Vite app that runs the evening by the clock with `@remotion/player`, built to a static folder that works from any path | the `event.json` contract only |
| `meetup-event-vienna/` | One folder per meetup: `events/<id>/source.json` (the Meetup link plus optional overrides), the generated `event.json`, and assets (speaker photos, sponsor logo). `make sync EVENT=<id>` runs meetup-sync | meetup-sync |
| `meetup-deck/` | Python + `python-pptx`: the group's own slide deck (`.pptx` export of the Google Slides deck, never committed) filled in for one meetup: number, Meetup header image (`image`), sponsor, and the agenda, talk, break and closing stills as slides. `make deck EVENT=<id>` in `meetup-event-vienna` | `event.json`, the stills |
| website (`aws-community-austria-website/`, its own repository, cloned here) | A page per meetup, `/organizers/`, and `/present/` serving the built player and the event JSON | the player build, `meetup.json` |

Each folder is its own git repository (`git init` done, nothing committed, no
remote). Nothing is pushed anywhere.

## event.json (version 1)

```ts
type EventFile = {
  version: 1;
  id: string;                       // "2026-10-20-aws-meetup-vienna-53": date + slug of the title
  source: { meetupUrl: string; fetchedAt: string };   // ISO
  title: string;                    // "AWS Meetup Vienna #53 - hosted by RBI"
  tagline?: string;                 // first paragraph of the description, emoji stripped
  image?: string;                   // the featured event photo (header image), full size
  group: { id: string; name: string; url: string };   // id "aws-ug-vienna"
  timezone: "Europe/Vienna";
  doorsOpen: string;                // ISO with offset, JSON-LD startDate
  end: string;                      // ISO with offset, JSON-LD endDate: "how long we can stay"
  venue: { name: string; address: string };            // name from the "Location" block when present
  sponsors: { name: string; short?: string; logo?: string; url?: string }[];
  segments: Segment[];              // in time order, contiguous where the agenda is
  links: { meetup: string; feedback: string; codeOfConduct?: string; nextEvents?: string };
  notices: string[];                // e.g. the photo and video notice, verbatim, emoji stripped
  upcoming?: Upcoming[];            // coming community days, from meetup-event-vienna/upcoming.json
  community?: Community;            // the group for the intro screens, from meetup-event-vienna/community.json
};

type Community = {                // shared by every meetup of the group
  name: string;
  team: { name: string; role?: string; photo?: string; email?: string }[];  // who we are
  groups: { name: string; logo?: string; url?: string }[];          // what we do
  badges: { name: string; image: string; title: string; text?: string }[];  // introducing our members
  codeOfConduct?: { title: string; subtitle?: string; lines: string[]; url?: string };
  photos: string[];                                                 // community/<file>: past meetups
  links: { website?: string; meetup?: string; linkedin?: string };
};
// Shared folders, served at the player's root next to events/: people/, logos/,
// badges/, community/ (all in meetup-event-vienna).

type Upcoming = {
  name: string;                     // "AWS Community Day Adria"
  date: string;                     // "2026-10-22", first day, local
  endDate?: string;                 // last day of a multi-day event
  location: string;                 // "Ljubljana, Slovenia"
  url: string;
  speakers?: Speaker[];             // community members speaking there
  screenshot?: string;              // its website, community/<file> (16:9): shown with the link and a QR code
};

type Segment = {
  id: string;                       // "doors", "welcome", "sponsor", "talk-1", "break-1", "talk-2", "closing"
  kind: "networking" | "welcome" | "sponsor" | "talk" | "break" | "closing";
  start: string;                    // ISO with offset
  end: string;                      // ISO; "Open End" means the event's `end`
  title: string;                    // agenda label, quotes and markdown removed
  talk?: { title: string; abstract?: string; speakers: Speaker[] };
  sponsor?: { name: string; short?: string; logo?: string };
};

type Speaker = {
  name: string; role?: string; company?: string; photo?: string;
  bio?: string;                              // plain text: Sessionize, then people/<name>.json, then source.json
  links?: { title: string; url: string }[];  // e.g. { title: "LinkedIn", url }: the speaker's link in the description
};
// photo: a full https URL, events/<id>/assets/<file> (one meetup), or people/<file>
// (meetup-event-vienna/people/, shared by every meetup: organizers, recurring speakers).
// Players serve people/ at their root, next to events/.
```

Rules for meetup-sync:

- Agenda lines look like `* **18:10 - 18:50:** **"Title"**` or `20:00 - Open End: Networking`
  (hyphen or en dash). Times are local `Europe/Vienna` on the event's date.
- Kind by label: "Entry"/"Networking" before the first talk = `networking`; "Welcome" +
  community = `welcome`; label mentioning a sponsor or "sponsor" = `sponsor`; a quoted
  title = `talk`; "break" = `break`; the last item with "Open End" or after the last talk =
  `closing`.
- Talk details: a quoted title in the description followed by `Speakers:` or `Speaker:`
  lines. Both forms appear and must parse: `Roman Jokel, Cloud Architect (Raiffeisen Bank International)`
  and `Darko Mesaroš Principal Technologist@AWS` and `Mladen Trampic, Senior Technical Account Manager@AWS`.
  Then `About the talk:` up to the next talk or `***`.
- Sponsors: the `Sponsors:` block, and any "thank you to X for supporting" line.
- `links.feedback` defaults to the Meetup event URL (Meetup asks attendees to rate
  events); an override can set a form.
- Sessionize (`"sessionize": "<endpoint id>"` in `source.json`) fills gaps only, after the
  page: speaker photos, missing roles, bios, abstracts, speakers of a talk listed without any.
- A speaker's link in the description (`[Roman Jokel](https://www.linkedin.com/in/...)`) becomes
  `links: [{ title: "LinkedIn", url }]` ("Website" for other hosts).
- `people/<name>.json` (`{ "bio": "...", "links": [...] }`, same name as the photo) fills a
  speaker's missing bio and links, for people who are not on Sessionize.
- `source.json` overrides are deep-merged last (speaker photos, sponsor logo, feedback
  link, venue name). Never invent facts: a field the page does not have stays absent.
- No network in tests: everything is tested against the saved HTML.

A hand-written example for building scenes before meetup-sync exists:
`meetup-stream-templates/examples/event.sample.json`. meetup-sync's real output must
validate against the same zod schema (`event.schema.ts`, owned by
meetup-stream-templates, copied into meetup-sync; keep them identical).

## meetup.json (version 1): every meetup, past and coming

The record behind the website's page for each meetup (`/meetups/<id>/`),
written next to `event.json` in `meetup-event-vienna/events/<id>/` by
`make archive` (every past meetup on the group's Meetup page) and by
`make sync`. Unlike `event.json` it needs no parsable agenda, so old
meetups get a page too; `stream` says whether there is an `event.json` to
present.

```ts
type MeetupFile = {
  version: 1;
  id: string;                       // as event.json: "2026-09-28-aws-meetup-vienna-52"
  title: string;                    // "AWS Meetup Vienna #52 - hosted by Enspired"
  number?: number;                  // 52, from "#52" in the title
  meetupUrl: string;
  start: string;                    // ISO with offset
  end?: string;
  group: { id: string; name: string; url: string };
  venue?: { name: string; address?: string };
  hosts: { name: string }[];        // from "hosted by X" in the title, else the sponsors block
  image?: string;                   // the Meetup header image, full size
  summary: string;                  // first paragraph of the description, plain text, for meta description
  description: string;              // the whole description, markdown as on Meetup, emoji stripped
  talks: { title: string; speakers: { name: string; role?: string; company?: string }[] }[];
  stream: boolean;                  // events/<id>/event.json exists and is valid: present mode works
  media?: {                         // from source.json "media", for later
    photos?: { src: string; alt?: string }[];
    slides?: { title: string; url: string; speaker?: string }[];
    recordings?: { title: string; url: string }[];
  };
};
```

Host logos are not in this file: the website maps host names to its own
logo files, so one logo per company lives in one place.

## Scenes (compositions)

1920x1080, 30 fps. Every composition is a pure function of frame and props. The
live clock reaches them only through a React context provided by the web
player (`LiveClock`: `nowMs`, `running`), the pattern from
`../aws-community-gameday-europe-all/automating-the-chaos-talk/remotion/src/presenting/context.ts`.
Without it (Studio, renders) a scene shows a static, sensible value.

| Composition | Shown during | Content |
|---|---|---|
| `PreShow` | `networking` before the first talk | Loops: event title and venue, "Talks start at 18:00" with a live countdown, the agenda, thanks to the sponsor, the photo and video notice, Code of Conduct line, Meetup QR |
| `Welcome` | `welcome` | "Welcome to the AWS User Group Vienna, Meetup #53" beside the photo collage of past meetups, then tonight's agenda (the one agenda design) with the current item highlighted |
| `SponsorHandover` | `sponsor` | "Thank you, Raiffeisen Bank International", "over to RBI", sponsor logo or name |
| `SpeakerHandover` | first 90 s of each `talk` | "Next up", the talk title, each speaker's name, role, company, photo or initials |
| `NowSpeaking` | rest of each `talk` | Hold: "Now speaking", the talk title and its speakers with large photos, as on the SpeakerHandover; what comes after is in the bottom bar |
| `Break` | `break` | "Break" with a live countdown to the next segment, what is next (title and speakers), drinks and networking line |
| `Closing` | `closing` | Thank you to speakers and sponsor, "Please leave feedback" with a QR to `links.feedback`, "Networking until 22:00" (from `end`), next events link |
| `AfterEnd` | after `end` | "Thank you for coming", see you next time |
| `Agenda` | a still for slides | The whole agenda, for dropping into the Google Slides deck |

Design: the awscommunity.at tokens in
`~/code/aws-community-austria-website/src/styles/theme.css` (bg `#161E2D`, surface
`#1E2538`, surface-2 `#2F2B52`, accent `#A66FF0`, text `#FFFFFF`, secondary `#D8D8D8`,
muted `#9CA3AF`, font Inter). Logos and organizer photos from that repo's
`public/assets/` (copy what is used into `meetup-stream-templates/public/`, record
the source in a README). No emoji anywhere on screen. QR codes generated locally
(e.g. the `qrcode` package), never by a web service.

## Theme: one design for everything

Every screen of the stream, the web player's own controls and the deck's new
slides use these values and nothing else. Sizes are pixels on the 1920x1080
frame; the deck (10 x 5.625 in, 720 pt wide) uses the same scale in points
(1 px = 0.375 pt), so a title on the room screen and a title on a slide match.

| Token | Value |
|---|---|
| Font | **Amazon Ember** (Regular 400, Medium 500, Bold 700, Heavy 800), fallback Inter, then system sans-serif |
| Display (one per screen: Welcome, Break, Thank you, the countdown) | 136 px / 51 pt, Heavy 800 |
| Title | 96 px / 36 pt, Bold 700 |
| Heading | 68 px / 25.5 pt, Bold 700 |
| Lead | 56 px / 21 pt, Regular 400 |
| Body | 42 px / 15.75 pt, Regular 400 |
| Small | 34 px / 12.75 pt, Medium 500 |
| Label (overlines, chapter names; upper case, tracking 0.12 em) | 28 px / 10.5 pt, Bold 700. Nothing on screen is smaller |
| Colours | background #161E2D, surface #1E2538, surface 2 #2F2B52, accent #A66FF0 (the deck's own slides keep their master's #9E5EFB), text #FFFFFF, secondary #D8D8D8, muted #9CA3AF |
| Grid | side margins 112 px, top band 72 to 192 px (logos), bottom bar 96 px high from y 984, gutter 48 px, spacing in steps of 8 px |
| Photos (round, 6 px accent ring) | XL 360 px (one speaker), L 280 px (two), M 200 px (three or more, upcoming, the closing), team 160 px (the 3 x 2 cards on "Who we are"), S 96 px (lists) |
| Logos | user group top left and AWS Community Austria top right, both 88 px high; host logo 48 px high in the bottom bar, 160 px high on the sponsor screen |
| Layout | two-column screens 96 px between the columns (`SPLIT_GAP`); the photo collage 800 px wide (`COLLAGE_W`); "Who we are" the head in a 400 px column beside a 3 x 2 grid (`TEAM`); the agenda's time column 3.2 em, rows padded 8 px (`AGENDA`) |
| Countdowns | one format everywhere (screens, the countdown top right, the player's own lines): H:MM:SS from an hour ("1:00:00"), MM:SS below ("05:00"); only days ahead of the evening "2 days 5 h" |

Composition rules: every screen opens with the same head (an accent
eyebrow, the title, an optional Lead subtitle) and has one focal point,
either centred (sponsor, pre-show title, community day, What we do, the
members) or two columns with one strong visual on the right (the collage,
the team grid, the speakers' photos, a QR). One agenda design (time
column, title, the speakers of a talk in Small under it, talks bold, the
current item on an accent band) on the Agenda still, the pre-show and the
Welcome. Nothing smaller than Label except the bar and the countdown
chrome, and nothing closer than 64 px to the bottom bar. The deck's purple
triangle is no longer used on the screens.

**The bottom bar** is the GameDay talk deck's phase bar
(`automating-the-chaos-talk/remotion/src/components/SlideFrame.tsx`, `PhaseBar`;
`assets/css/deck.css`, `.phasebar`), adapted: 96 px high, a dark translucent
band with a 1 px top rule, no pills, no boxes, no gradient block. Left (about
300 px): a small upper-case "Now" label in the accent colour and the current
part's short name. Middle: the track, one equal-width segment per part of the
evening (Doors, Welcome, Sponsor, Talk 1, Break, Talk 2, Networking), a 4 px
rail with the accent gradient filling up to the current time, a tick between
segments, the part names above the rail (upper case, tracked; done in the
accent colour, the current one white, the rest muted), and a small round
marker (the user group logo) at the exact position. Right (about 240 px):
"hosted by" small and muted with the host logo 28 px high. Its type sits
below the screen minimum on purpose, as in the GameDay deck: labels 16 px,
the current name 26 px. Every segment is clickable in the player and jumps
to the start of that part.

Amazon Ember is free to use but its files are never committed or published:
`make fonts` copies them from the official Amazon Typefaces set into
gitignored folders for renders and the local player; pages served from the
website ask for the installed font (`local("Amazon Ember")`) and fall back
to Inter, so the room laptop needs Amazon Ember installed.

## The web player (run of show)

- Loads `event.json` from `?event=<url or id>` (an id resolves to `./events/<id>.json`).
- Auto mode: the current segment is the one containing "now" (the browser clock);
  before `doorsOpen` it shows `PreShow` with "Doors open at 17:00"; after `end`, `AfterEnd`.
  Inside a `talk`, `SpeakerHandover` for the first 90 s, then `NowSpeaking`.
- Keys: `→` `PgDn` `Space` next scene, `←` `PgUp` previous, `A` back to the clock,
  `F` fullscreen, `B` black, `?` help (shows mode, simulated time, current and next
  segment). Click also advances. Clickers send PgDn/PgUp.
- Rehearsal: `?at=18:49` starts the clock at that local time on the event date and runs
  on; `?speed=10` runs it faster. Shown in the help overlay, never on screen otherwise.
- Built with Vite `base: "./"` so it works under `/present/` on GitHub Pages; no server needed.
- Pure logic (`runOfShow.ts`: segment and scene for a given time and manual offset) is
  unit-tested at every agenda boundary of the real event.

## Website integration

There is no live stream: the player is the room screen, shown from the
organizer's laptop. The website gives it a home without advertising it.

- Every meetup has a page, `/meetups/<id>/`, built from its `meetup.json` and,
  when it exists, its `event.json` (agenda, talks, speakers with photos, host).
  Anyone can read it; it carries a non-interactive preview of the room screen
  and, at the very bottom, a quiet "For organizers" line with the Present link.
- `/organizers/` lists every meetup with its Present and rehearsal links and a
  short how-to. It is linked only from the footer and kept out of search.
- `/present/?event=<id>` is the player. The start page and the group pages do
  not link to it.
- `public/present/` holds the built player, every `events/<id>.json` with its
  `assets/`, and `people/`, copied by `npm run present:sync` from this
  workspace (path configurable), committed so GitHub Pages serves it.
  `npm run build` must pass.

## Stack and rules

- Node 24, npm. React 18.3.1, Remotion **exactly 4.0.530** for every `remotion` and
  `@remotion/*` package (4.0.531 and later bundle react-dom 19 into
  `@remotion/transitions` and break React 18 builds), Vite 6.4.x, TypeScript 5.9,
  zod 3.25, vitest 5. Patch and minor updates within these are fine; no majors.
- `npm audit` must report 0 vulnerabilities in every package; if one cannot be fixed
  within range, say so.
- Every folder has a README saying what is in it and how to run it. Commands in
  READMEs are one per code block, no inline comments (zsh does not treat a pasted
  `#` as a comment).
- No personal data beyond what the public Meetup page and the website already
  publish. No account ids, tokens or local paths in committed files.
- Verify before saying it works: tests, typecheck, builds, rendered stills, and a
  headless browser run at simulated times.
