# John's list (kept by the lead; updated 2026-11-01)

Shortest first. Gut reactions are enough; the lead turns them into tuning.

## Play tomorrow night (one session covers most of it)
**First: restart the Mac.** On Oct 31 Godot hung at launch in macOS's audio service (not the game; a clean copy of main hung too). A restart should clear it. If it still hangs, add `--audio-driver Dummy` to the launch command (no sound, but it plays).

Pull and run (paste in Terminal). If it stops during the import step, just paste it again: the import sometimes crashes on the first try and passes on the second.
`cd ~/Projects/grave-rats-playtesting && git pull && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import && /Applications/Godot.app/Contents/MacOS/Godot --path .`
- [ ] **One full shift:** grab the black box, push past the 60% and 30% oxygen tiers (CUSTODIAN wakes), and try to extract.
- [ ] **Anti-aliasing:** F1 → Display. Flip the four modes while turning; pick by eye (it saves).
- [ ] **Sound:** headphones on. Is the alarm too loud, are the room hums too quiet, is the breathing right, and is it OK that you can hear stalkers through walls? (Tune it in F1 → Audio buses.)
- [ ] **Gun:** dump a whole magazine in a dark room, reload, look at the casings. Does it feel heavy and real? Do you hear the magazine running out before the click?
- [ ] **Movement:** do the new Mixamo animations make the hauler move like a soldier? Watch strafing, crouch-walking, heavy carry (may look like a shuffle) and picking things up.
- [ ] **Solo feel:** do aim, fire and E feel exactly as before? (They now go through the co-op command layer.)
- [ ] **Corridors:** too dark to see the new detail? Door jamb tops too heavy? Does the torn panel read?
- [ ] **The overturned bed:** can you see it in its dark corner now that it has a hazard stripe?
- [ ] **The second ship (the survey vessel, merged):** add `--ship survey` to the launch command, or pick it in F1 → Shift. Does it feel different, and is the black-box run tense? Known: only 10 salvage spots (can't meet the quota without the black box), and the patrol drone flies through shut doors.
- [ ] **Effects gallery:** F1 → Effects, if you're curious.

## Balance questions the play will answer
- [ ] Greedy bots die in every shift on the current ship with CUSTODIAN awake (a bot bug had hidden how far they really get). Is the black-box route too lethal? (First lever: move the cargo cutter.)
- [ ] Survey vessel: more salvage spots, or its own lower quota?
- [ ] Are fees too small next to a good shift? Does dying cost less on the quota than leaving empty-handed? (It shouldn't.)
- [ ] Do stalkers reach you too fast (about 2 s) at the higher tiers?

## Picks and approvals (no game needed)
- [ ] **Threats:** pick from the A015 bestiary (top five in gold: Loader, Suit Hitch, Pool Bell, Prior Claim Surveyor, Seam Spiders).
- [ ] **Weapons:** judge the Blender models (`docs/screens/props/weapons_sheet.jpg`) and the two paint-overs (A017: plasma cutter, decoy beacon); say which to wire in first, and whether to try Meshy retexturing for the rest (10 credits each).
- [ ] **Paperwork copy:** approve the new lines in `docs/handoffs/auto-T014.md` and `auto-T015.md` (end-of-shift forms, CUSTODIAN announcements).
- [ ] **Meshy:** set a standing credit budget (for example "up to 150 credits a week on agreed models, report each"), or keep OK-ing each batch. Say what to make next.
- [ ] **Stalker legs:** OK a code task giving the new Meshy stalker procedural legs?
- [ ] **Skill card:** save the meshy-3d-models update card in the chat (the lead will add one more fix: Meshy's API rig uses its own bone names).

## When you have ten minutes
- [ ] **Real sounds:** download the packs in `docs/handoffs/sound-shortlist.md` into one folder (say where), and the lead sorts them into the game.
