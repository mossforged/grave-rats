# A013 — Company graphics for five rooms

Status: prepared for John's explicit copy-and-look approval gate. No approval is claimed and no game import is authorized by this handoff. Work stops here for human review, as required by `docs/tasks/A013-room-graphics-five-rooms.md`: **“Autonomy: human-gated (John approves the copy and look).”**

## Deliverables

Sources: `assets/source/A013-room-graphics/`. Every image has its exact built-in image_gen prompt beside it. Six selected atlases contain 37 separate graphics. All atlases are opaque 1536 × 1024 PNGs on plain pale-gray backgrounds with gutters for cutting out; these are source sheets, not individual alpha decals or PBR maps.

Review: `docs/screens/A013/sheet.png` (3200 × 3500, six labelled native-size atlases) and `docs/screens/A013/readability.png` (1800 × 3000, reduced and foreshortened crop comparisons). Assembly instructions, a reproducible Pillow assembly script and crop coordinates are beside the review images. Pillow was used only for review-sheet composition; generated source art is unmodified.

## Image inventory

- **A013-01 — Engineering:** containment-event board at 00; lockout/tagout notice; radiation badge poster; reactor-cage and power-cell hazard plates; ENGINEERING / DECK 03 room plate. Faded teal/ivory and worn safety yellow/red.
- **A013-02 — Bio lab:** numbered specimen labels 01–03, labels 02 and 03 redacted; containment notice; expired ethics-board certificate; fume-hood warning; BIO LAB / DECK 03 plate.
- **A013-03 — Bridge:** printed commendation plaque for cost control; captain's-chair privilege poster; BRIDGE / DECK 01 plate; section A/01 and B/02 plates; abstract nav-table graphic with five waypoint dots and an amber dashed route.
- **A013-04 — Crew quarters:** child's crayon drawing; flat WORLD'S OKAYEST DAD mug decal; M. VALE / BUNK 08 tag; bunk-rental notice; quiet-hours sign; CREW QUARTERS / DECK 02 plate. The drawing and name connect the crew to the birthday banner without adding a horror gag.
- **A013-05 — Mess:** priced dispenser menu including both hot and cold water; nutrition-paste poster; shared-fridge note; HAPPY BIRTHDAY, MARA banner; MESS / DECK 02 plate.
- **A013-06 — Remnant overlays, superseded first pass:** all required copy is correct, but the tool invented a triangular emblem and distressed the labels too much. Retained for provenance, excluded from the main review sheet; use revision b for review.
- **A013-06b — Remnant overlays, selected revision:** ASSESSED stamp; LOW/MEDIUM/HIGH priority labels with one/two/three filled bars; biological-material exclusion tape; reactor-core and captain's-chair inventory tags. Revised using A010-02 as the reference for the established circular cargo emblem and fresh label finish.

## Copy transcript

Line breaks in the artwork may differ from these reading-order transcripts. Words hidden by intentional redaction bars are not missing or garbled copy.

### A013-01

```text
DAYS SINCE LAST
CONTAINMENT EVENT
00
VESPER REACH FREIGHT

LOCKOUT / TAGOUT
ISOLATE BEFORE SERVICE
ONE LOCK PER WORKER

RADIATION BADGE
MUST BE WORN
(BADGES SOLD SEPARATELY)

REACTOR CAGE
AUTHORISED ACCESS ONLY

POWER CELLS
STORED ENERGY

ENGINEERING
DECK 03
```

### A013-02

```text
SPECIMEN 01
STATUS: RETAINED

SPECIMEN 02
[redaction bar]

SPECIMEN 03
TRANSFER ON HOLD
[redaction bar]

BIOHAZARD
KEEP CONTAINMENT SEALED
REPORT ALL SEAL FAILURES

ETHICS BOARD APPROVAL
VESPER REACH FREIGHT
VALID UNTIL 14.06.2189
EXPIRED

FUME HOOD
KEEP SASH BELOW LINE
EXTRACTION MUST BE ACTIVE

BIO LAB
DECK 03
```

### A013-03

```text
CAPTAIN'S COMMENDATION
FOR EXCEPTIONAL COST CONTROL
VESPER REACH FREIGHT

THE CAPTAIN'S CHAIR
IS A PRIVILEGE,
NOT A RIGHT

BRIDGE
DECK 01

SECTION A
01

SECTION B
02

NAVIGATION
N / E / S / W
```

The compass letters are intentional additional directional labels. Nav routes are decorative, not established gameplay or world geography.

### A013-04

```text
COME HOME SOON

WORLD'S OKAYEST DAD

M. VALE
BUNK 08

BUNK RENTAL
DEDUCTED FROM WAGES
VESPER REACH FREIGHT

QUIET HOURS
ARE BILLABLE

CREW QUARTERS
DECK 02
```

The sleeping pictogram also contains three decorative Z marks.

### A013-05

```text
CREW MENU
NUTRITION PASTE  4.20 CR
PROTEIN PORTION  6.80 CR
HOT WATER  1.10 CR
COLD WATER  0.90 CR
PAYMENT BEFORE DISPENSING

NUTRITION PASTE:
NOW WITH 12%
MORE FLAVOUR

SHARED FRIDGE
PLEASE LABEL YOUR FOOD.
UNLABELLED ITEMS ARE NOT
A CREW BENEFIT.

HAPPY BIRTHDAY, MARA

MESS
DECK 02
```

### A013-06 / A013-06b

```text
ASSESSED

REMNANT ASSET RECOVERY
SALVAGE PRIORITY: LOW

REMNANT ASSET RECOVERY
SALVAGE PRIORITY: MEDIUM

REMNANT ASSET RECOVERY
SALVAGE PRIORITY: HIGH

BIOLOGICAL MATERIAL
NOT COVERED BY CONTRACT

REMNANT ASSET RECOVERY
REACTOR CORE
INVENTORY RAR-013-01
DECK 03

REMNANT ASSET RECOVERY
CAPTAIN'S CHAIR
INVENTORY RAR-013-02
DECK 01
```

## Readability and use

The separate readability sheet uses actual atlas crops at 256 px wide, then 50% vertical compression for a wall viewed at roughly 60° pitch, or 87% for the horizontal navigation table. This is an approximate graphic stress test, not a Godot capture; game distance, ambient light, wall orientation, texture filtering and occlusion remain for the code lane to verify.

- **Engineering:** room plate, 00 counter, reactor/power-cell names and warning symbols are strong at decal size. The radiation headline reads when the poster is given a generous wall footprint; the badges-sold-separately line needs a close view. Lockout instructions are detail text.
- **Bio lab:** large specimen numbers, BIOHAZARD headline and EXPIRED stamp are the distance cues. Fume-hood header and room plate are strong; seal instructions, retained/transfer status and certificate date are close-view details.
- **Bridge:** BRIDGE, section numerals and large chair silhouette read first. Full privilege copy needs a large poster and favorable wall orientation. Nav-table waypoint dots, route shape and amber dashed line survive reduction; the fine orbital arcs are decorative. Commendation citation and company footer are close-view copy.
- **Crew quarters:** QUIET HOURS / ARE BILLABLE and BUNK RENTAL are the clearest poster copy. DAD and the figures in the child's drawing carry at distance; the full mug slogan, M. VALE and COME HOME SOON require more screen space. The two-line CREW QUARTERS plate needs a larger footprint than BRIDGE or MESS.
- **Mess:** MESS, 12%, main poster headline and birthday lettering are clear at useful decal sizes. Menu prices and fridge-note body must be read close; do not depend on them as gameplay instructions.
- **Remnant:** ASSESSED, filled priority-bar count and large asset names carry first. Priority words need enough width; company subtitle, inventory IDs and deck fields are close-view detail. The exclusion tape's long sentence needs a long physical strip or close inspection.

Room plates and big posters are the primary camera-readable layer. Small print is environmental storytelling for inspection. No gameplay information should depend on tiny legal copy.

## Review notes and approval gate

- No image was refused. No misspelled or garbled copy was found in the six initial sheets or the selected A013-06b revision. Intentional redactions and fading are described above. All seven source PNGs decoded at 1536 × 1024, each has a nonempty prompt, and both assembled review images were visually checked for labels, clipping and overlap. `manifest.json` records the selected IDs, generation paths and revision references.
- The generated owner graphics add a small winged engineering ornament and an ethics-certificate seal; neither is the primary A010 navigation-star/cargo-lane logo. Treat these as proposed department ornaments, not replacement company branding, subject to this same copy/look gate.
- Deck assignments, specimen numbers, certificate date, menu prices, M. Vale/Mara and inventory IDs are proposed dressing copy, not changes to game data or established layout. The certificate is explicitly stamped EXPIRED, so its date does not establish the current game year.
- No real brands, celebrities, other games' characters or ships are used. Owner graphics retain A010's Vesper Reach Freight name and faded teal/ivory hierarchy; Remnant uses fresh high-contrast recovery graphics over that older institutional layer.
- Read AGENTS.md, STATUS.md, game brief, style and asset contracts, tone bible, A010 packet/handoff, and A013 packet; visually inspected A010's review sheet and both requested prop sheets.
- No git commands were run. No game imports, code, scenes, data, tests, tools, legacy source assets or existing art were modified.

**Pending decision:** John approves or requests revisions to the copy and look before the A014/code lane uses these decals. This packet is complete as a review submission and stops at that human gate.
