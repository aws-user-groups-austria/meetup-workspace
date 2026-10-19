# The whole meetup evening from this folder. Every target runs the real
# command in the right sub-folder; README.md says what each one shows.
#
#   make                 this list
#   make clone           the repositories (meetup-sync, meetup-event-vienna, meetup-stream-templates, meetup-deck, the website) into this folder
#   make install         install everything: meetup-sync, the scenes, the web player, meetup-deck, the website
#   make fonts FONTS=... Amazon Ember from the official Amazon Typefaces set (folder or zip), for renders and the player
#   make fonts-system FONTS=...  the same, and installed on this Mac (PowerPoint, browsers, the website)
#   make start           sync the event, build the player, and run the player (4100) and the website (5173) together
#   make stop            stop the player and the website dev servers
#   make links           the rehearsal links for EVENT (pre-show, handovers, break, closing)
#   make player          only the rehearsal player on http://127.0.0.1:4100
#   make website         only the website with /present/ on http://localhost:5173
#   make sync            fetch the Meetup page (and Sessionize) into event.json
#   make sync-offline    the same from the saved page, no network
#   make new URL="..."   a new meetup from its Meetup link
#   make archive         every past meetup from Meetup, for the website's meetup pages (and present mode where the agenda parses)
#   make stills          one PNG per scene into meetup-stream-templates/out/stills
#   make studio          Remotion Studio, to look at and change the scenes
#   make deck            the group's slide deck filled in for EVENT (needs meetup-event-vienna/deck/aws-ug-vienna-austria.pptx)
#   make open-deck       open the folder with the filled-in deck
#   make review          one page with the real stills, deck and website screenshots for EVENT; opens it
#   make check           every test suite and typecheck
#   make audit           npm audit and pip-audit everywhere
#
# EVENT defaults to the next meetup; pass EVENT=<id> for another one.

EVENT   ?= 2026-10-20-aws-meetup-vienna-53
WEBSITE ?= aws-community-austria-website

SYNC      = meetup-sync
EVENTS    = meetup-event-vienna
TEMPLATES = meetup-stream-templates
PLAYER    = $(TEMPLATES)/web-player
DECK      = meetup-deck

PLAYER_PORT  = 4100
WEBSITE_PORT = 5173
PLAYER_URL   = http://127.0.0.1:$(PLAYER_PORT)/?event=$(EVENT)

.PHONY: help install start stop links player website serve-player serve-website \
        sync sync-offline new archive stills studio deck open-deck check audit check-website prepare review fonts fonts-system

help:
	@sed -n 's/^#   //p' Makefile

# The parts, each its own repository in https://github.com/aws-user-groups-austria: cloned next to this Makefile (existing folders are left alone).
REPOS = meetup-sync meetup-event-vienna meetup-stream-templates meetup-deck aws-community-austria-website
clone:
	@for r in $(REPOS); do \
	  if [ -d "$$r/.git" ]; then echo "$$r: already here"; else git clone https://github.com/aws-user-groups-austria/$$r.git "$$r"; fi; \
	done

install:
	npm --prefix $(SYNC) ci
	npm --prefix $(TEMPLATES) ci
	npm --prefix $(PLAYER) ci
	cd $(DECK) && uv sync
	@$(MAKE) --no-print-directory check-website
	npm --prefix $(WEBSITE) ci

fonts:
	@test -n "$(FONTS)" || { echo 'usage: make fonts FONTS="<Amazon_Typefaces_Complete_Font_Set folder or zip>"' >&2; exit 2; }
	$(TEMPLATES)/scripts/install-fonts.sh "$(FONTS)"

fonts-system:
	@test -n "$(FONTS)" || { echo 'usage: make fonts-system FONTS="<Amazon_Typefaces_Complete_Font_Set folder or zip>"' >&2; exit 2; }
	$(TEMPLATES)/scripts/install-fonts.sh "$(FONTS)" --system

check-website:
	@test -f "$(WEBSITE)/package.json" || { echo "No website at $(WEBSITE): clone aws-community-austria-website into this folder, or pass WEBSITE=<path>" >&2; exit 2; }

sync:
	$(MAKE) -C $(EVENTS) sync EVENT=$(EVENT)

sync-offline:
	$(MAKE) -C $(EVENTS) sync-offline EVENT=$(EVENT)

archive:
	$(MAKE) -C $(EVENTS) archive

new:
	@test -n "$(URL)" || { echo 'usage: make new URL="<meetup event link>"' >&2; exit 2; }
	$(MAKE) -C $(EVENTS) new URL="$(URL)"

stills:
	$(MAKE) -C $(TEMPLATES) stills EVENT=$(EVENT)

studio:
	$(MAKE) -C $(TEMPLATES) studio

# The filled-in deck in our design, and always the PDF to present from (PowerPoint
# exports it; without PowerPoint there is only the .pptx).
deck:
	$(MAKE) -C $(EVENTS) deck EVENT=$(EVENT)
	@$(MAKE) --no-print-directory -C $(EVENTS) deck-pdf EVENT=$(EVENT) || echo "no PDF: PowerPoint could not export it; the .pptx is there" >&2
	@echo "deck: $(EVENTS)/events/$(EVENT)/deck/$(EVENT).pptx and .pdf (make open-deck opens the PDF)"

review:
	$(MAKE) -C $(EVENTS) deck-pdf EVENT=$(EVENT) || echo "no deck PDF (needs the deck and PowerPoint): the page shows the rest" >&2
	$(MAKE) -C $(EVENTS) review EVENT=$(EVENT)

open-deck:
	@pdf="$(EVENTS)/events/$(EVENT)/deck/$(EVENT).pdf"; \
	if [ -f "$$pdf" ]; then open "$$pdf"; else echo "no PDF yet: make deck EVENT=$(EVENT)" >&2; open "$(EVENTS)/events/$(EVENT)/deck"; fi

# The event into the player and the website. Sync first when there is network,
# else keep the event.json there is.
prepare: check-website
	@$(MAKE) --no-print-directory sync || { echo "sync failed (no network?): using the existing event.json" >&2; }
	$(MAKE) -C $(TEMPLATES) player-event EVENT=$(EVENT)
	$(MAKE) -C $(TEMPLATES) player-build
	npm --prefix $(WEBSITE) run present:sync

start: prepare
	@$(MAKE) --no-print-directory links
	@echo ""
	@echo "Website:  http://localhost:$(WEBSITE_PORT)/  then a meetup page: Present at the bottom, or /organizers/"
	@echo "Ctrl-C stops both."
	@echo ""
	@$(MAKE) --no-print-directory -j2 serve-player serve-website

player:
	$(MAKE) -C $(TEMPLATES) player-event EVENT=$(EVENT)
	@$(MAKE) --no-print-directory links
	@$(MAKE) --no-print-directory serve-player

website: check-website
	$(MAKE) -C $(TEMPLATES) player-build
	npm --prefix $(WEBSITE) run present:sync
	@echo "Website: http://localhost:$(WEBSITE_PORT)/  then a meetup page: Present at the bottom, or /organizers/"
	@$(MAKE) --no-print-directory serve-website

serve-player:
	@lsof -nP -iTCP:$(PLAYER_PORT) -sTCP:LISTEN >/dev/null 2>&1 && { echo "port $(PLAYER_PORT) is in use: make stop first" >&2; exit 1; } || true
	cd $(PLAYER) && npm run dev

serve-website:
	@lsof -nP -iTCP:$(WEBSITE_PORT) -sTCP:LISTEN >/dev/null 2>&1 && { echo "port $(WEBSITE_PORT) is in use: make stop first" >&2; exit 1; } || true
	npm --prefix $(WEBSITE) run dev -- --port $(WEBSITE_PORT) --strictPort

stop:
	@for port in $(PLAYER_PORT) $(WEBSITE_PORT); do \
	  pids=$$(lsof -tnP -iTCP:$$port -sTCP:LISTEN 2>/dev/null); \
	  if [ -n "$$pids" ]; then kill $$pids && echo "stopped port $$port"; else echo "port $$port: nothing running"; fi; \
	done

links:
	@echo "Rehearse $(EVENT) (open one, then press ? for help):"
	@echo "  pre-show, 5 min before the talks  $(PLAYER_URL)&at=17:55"
	@echo "  the whole evening, 10x fast       $(PLAYER_URL)&at=17:55&speed=10"
	@echo "  welcome and sponsor               $(PLAYER_URL)&at=18:00"
	@echo "  handover to the first speakers    $(PLAYER_URL)&at=18:09:50"
	@echo "  break with the countdown          $(PLAYER_URL)&at=18:52"
	@echo "  handover to the second speaker    $(PLAYER_URL)&at=19:19:50"
	@echo "  closing, feedback, networking     $(PLAYER_URL)&at=19:59:50"
	@echo "  after the end                     $(PLAYER_URL)&at=22:05"
	@echo "  the real clock (on the evening)   $(PLAYER_URL)"

check:
	cd $(SYNC) && npm test
	$(MAKE) -C $(TEMPLATES) typecheck test
	cd $(DECK) && uv run pytest -q

audit:
	cd $(SYNC) && npm audit
	$(MAKE) -C $(TEMPLATES) audit
	cd $(DECK) && uv export -q --format requirements-txt --no-hashes --no-emit-project -o .audit-requirements.txt && uvx -q pip-audit -r .audit-requirements.txt --disable-pip --no-deps; status=$$?; rm -f .audit-requirements.txt; exit $$status
