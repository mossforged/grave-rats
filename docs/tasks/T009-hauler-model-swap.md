# T009 - John's hauler replaces the grey operator (code)

**Modules:** `src/player/` (model, animation), `src/pirates/` (their body). **Read:** `CLAUDE.md`, the `src/player/` and `src/pirates/` contracts, `docs/handoffs/meshy-shortlist.md`, `docs/screens/A005/sheet.png`. **Needs:** T008 merged.
**Autonomy:** human-gated (John: *"Does the hauler look and move right from the game camera?"*).

John made the player model in Meshy, rigged and animated: `assets/source/meshy/hauler-rigged.glb`.
- **Mesh:** one mesh, 30.7k triangles, 2K PBR textures (base colour, normal, metal/roughness), double-sided material.
- **Size:** 1.70 m tall in the file.
- **Skeleton:** 66 joints with **Mixamo bone names** (`mixamorig:Hips` …), in an A-pose bind.
- **19 clips:** `Running`, `Walking`, `Walk_Backward`, `Idle_Turn_Left` and `_Right`, `Lean_Forward_Sprint`, `Rifle_Aim_Turn_Right`, `Rifle_Turn_Left`, `Rifle_Charge`, `Walk_Forward_While_Shooting`, `Walk_Turn_Left` and `_Right`, `Roll_Dodge` (plus `_1`, `_2`, `_3`), `Run_to_Walk_Transition`, `Standard_Forward_Charge_inplace`, `Dead`, and an unnamed 2.97 s clip (probably a duplicate of `Dead`).

## Do
1. **Import** a copy into `assets/game/hauler/` (never edit `assets/source/`). Scale it to the legacy operator's height in data (1.8 m before the character scale), with feet on the floor.
2. **Map the clips to the operator's animation states** in data (`data/player.json` or a new `data/hauler_anim.json`), choosing the best fit for each:
   - idle;
   - walk (forward, back, strafe left and right);
   - run and sprint;
   - turn in place;
   - crouch idle and crouch walk;
   - aim;
   - fire (recoil);
   - reload;
   - roll;
   - hit or stagger;
   - death.
   **Strip horizontal root motion from the hips** so the code keeps moving the body. Keep the existing torso-lead / aim layering: the upper body aims while the legs walk.
3. **Missing clips** (no idle holding a rifle, no strafe, crouch, reload or hit in this file):
   - retarget the legacy clips onto the Mixamo skeleton where you can (Godot's humanoid `SkeletonProfile` / `BoneMap`);
   - otherwise use the closest Meshy clip;
   - otherwise keep the pose.
   - List each state and its source (Meshy clip, retargeted legacy clip, or stand-in) in the handoff, so John knows what to fetch next.
   - Leave the clip list open to new files: `assets/source/meshy/hauler-<clip>.glb`, or Mixamo `.fbx` clips "without skin".
4. **The rifle:** attach the legacy rifle to `mixamorig:RightHand`, with an offset in data; the left hand roughly on the foregrip (IK is optional). The muzzle and flashlight follow the rifle as now.
5. **Pirates:** they use the hauler too, recoloured from data (the orange plates become navy, the fabric off-white), with a shader or material tint, not new textures. They must still read apart from you at the game camera.
6. **Keep the legacy operator selectable** by a data switch, for comparison.

## Acceptance
- **Headless:**
  - all old tests pass;
  - the hauler's height matches the data;
  - each animation state resolves to a clip or a declared stand-in;
  - no horizontal root motion;
  - the rifle stays attached to the hand bone through walk, roll and death;
  - the pirates get the recolour.
- **Bot check:** foot slide in walk and run (`tools/t003_footslide.gd` or its successor) against the legacy numbers.
- **Windowed** (`docs/screens/T009/`):
  - the hauler at the default camera: idle, walk, run, crouch, aiming, rolling, dead;
  - beside a pirate;
  - the legacy operator in the same frame for comparison;
  - a close-up with the camera moved in;
  - frame time in `pirate_deck`.
- **Human (John):** does the hauler look and move right from the game camera?

Out of scope: new animations (list what's missing), the stalker model, the props.
