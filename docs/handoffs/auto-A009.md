# A009 — Rival crew design and Meshy inputs

Art production complete; human look selection pending. Built-in `image_gen` was used for all character/identity renders. Pillow only composed the requested labelled review sheets and 1x/exact-4x samples. No git commands were run; no game files were changed or imported.

## Recommended pick and decision for John

Pick **Prior Claim / porcelain white and deep navy**, with the broad navy crown stripe and shoulder caps, white hard chest armour and narrow black visor. Use the A009-02 squad leader and `rival-apose-front.png` as the shape authority, corrected `rival-apose-back.png` for rear construction, and **A009-03b** for camera readability. This develops the invented Prior Claim name already visible in A001-13, replacing its warm metallic trim with navy so it stays separate from our orange hauler. The invented sponsor is **Lien Capital**.

John must pick/approve this rival look before making the rival in Meshy. This is the packet's human gate, not an approved final faction or an automatic model upload. Stop here pending that choice; no downstream import or modelling work performed.

## Deliverables — one line per image

| Image | Review |
| --- | --- |
| `assets/source/A009-rivals/A009-01.png` | 1536x1024 identity sheet: original bracket/chevron logo, Prior Claim wordmark, Lien Capital sponsor, white/navy/graphite/ice-blue palette and three legible deadpan taglines. |
| `assets/source/A009-rivals/A009-02.png` | 1536x1024 front lineup: leader, heavy, scout, tech; matching expensive armour, all empty-handed; height labels are design intentions, not dimensionally accurate rulers. |
| `assets/source/A009-rivals/A009-03.png` | 1840x960 initial camera comparison sheet, retained for revision history; 96 px leader proxy and exact 4x enlargement. Superseded by 03b. |
| `assets/source/A009-rivals/A009-03b.png` | 1840x960 preferred steeper overhead comparison: four rivals beside the orange hauler, 96 px leader proxy plus exact 4x; faction separation reads immediately through large crown/shoulder colour blocks. |
| `assets/source/meshy/input/rival-apose-front.png` | 1254x1254 leader authority; straight spread legs, open hands, arms out/down approximately 45 degrees, clear arm/hip and inter-leg gaps on light-grey studio background. |
| `assets/source/meshy/input/rival-apose-side.png` | 1254x1254 near-side leader; helmet points left, pack depth visible, separated feet and hands; deliberately short of true profile following A008 to retain gaps. |
| `assets/source/meshy/input/rival-apose-back.png` | 1254x1254 selected back revision (A009/rival-apose-backb): corrected rear knee flexion folds and separate seat panels; matching helmet stripe, shoulders, pack, open hands and spread stance. |
| `assets/source/meshy/input/rival-apose-34.png` | 1254x1254 front three-quarter leader; useful chest/shoulder/pack relationship and open limb gaps; more frontal than the side input. |
| `docs/screens/A009/sheet.png` | 2048x2480 labelled review sheet: identity, lineup, preferred camera panel pasted at native size, four Meshy previews. |
| `docs/screens/A009/A009-03-render.png` | 1774x887 initial generated camera row, retained as source; elevation was too shallow, prompting 03b. |
| `docs/screens/A009/A009-03b-render.png` | 1774x887 selected steeper generated row; full figures with crown and pack visibility; source for 03b review samples. |
| `docs/screens/A009/rival-apose-back-initial.png` | 1254x1254 rejected initial rear view, archived for traceability; mistakenly repeated front kneecap plates and a front-like pelvic cup. Do not use for reconstruction. |

Every image has a neighbouring `.prompt.md` with its exact generation prompt or deterministic composition recipe/reference to the generated source prompt. `docs/screens/A009/build_review.py` rebuilds the review images from the saved renders without repainting character content.

## Identity copy

- Your claim has been superseded.
- Liability belongs to the previous owner.
- Recovery is a shareholder right.

Palette: porcelain `#E8EDF0`, deep navy `#12243B`, graphite `#30383F`, ice blue `#81BCCD`. Ice blue is a small equipment accent; faction recognition relies on white/navy, not tiny decals. Clean manufactured hard armour and fitted compartments distinguish these rivals from patched fabric rentals. The heavy's width, scout's reduced bulk and tech's larger pack remain the role cues at small sizes; microtext does not survive gameplay reduction.

## View matching and limits

The four selected leader images match well in overall silhouette, palette, helmet/visor design, shoulder shells, chest plate and A-pose. They are generated views, not renders of one solved mesh: seams, buckles, thigh panels, decal scale and backpack fittings drift. The rear pack is the clearest construction reference; side/34 pack detail is less exact. Prefer the front for proportions, corrected back for rear anatomy, and use side/34 as supporting depth references. No actual Meshy reconstruction or rigging was performed, so reconstruction quality is unverified.

The side prompt requests approximately 60 degrees from front, but the rendered angle is visually closer to a shallow near-side view and overlaps the three-quarter's coverage; it is explicitly not a strict orthographic profile. This retains the A008 arm/leg clearance intent. Hand fingers remain grouped rather than widely splayed. Suit brand text is readable in the large views but should be treated as decal art rather than mesh detail.

A009-02 uses the same grey studio lineup format and intended metre scale as A005-04. Generated head positions do not exactly follow the height guides (especially scout/tech); final model height should be set numerically: leader 1.80 m, heavy 2.00 m, scout 1.65 m, tech 1.75 m. These are role design targets, not a proposed skeleton change.

The game-camera render is an illustrative high-angle concept, not a calibrated engine screenshot. It requests 65 degrees down in 03b; precise pitch cannot be measured from the generated picture. The 96 px leader is the established A005 review proxy, not a claim about the live game's pixel scale. One common resize retains relative sizes; 4x panels repeat exactly the same downsampled pixels with nearest-neighbour sampling.

## Refusals and verification

No image requests were refused. All new characters are empty-handed; no weapons were requested. No real brands, logos, celebrities, borrowed characters or ships were used.

Visually inspected identity, lineup, both camera renders, all four final leader views, initial rear error and assembled review sheet. Corrected the rear anatomy and rebuilt the contact sheet. PNG integrity, prompt coverage, output sizes and exact 4x sample equality were checked locally. Only new A009 art/review files and the four packet-requested rival Meshy input pairs were written. No source, scene, data, tests, tools or legacy assets were modified.
