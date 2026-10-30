// Skinned characters + layered animation controller.
// Clips are authored in Blender (assets-src/build_characters.py) on one shared skeleton:
//   L_*  lower body (pelvis + legs)   — directional locomotion blend, crouch
//   U_*  upper body (spine, arms, weapon) — aim, low-ready, reload
//   F_*  full body overrides — roll, death
// Procedural layers (recoil, flinch) are added on top after the mixer each frame.
import * as THREE from 'three';
import { GLTFLoader } from './../vendor/jsm/loaders/GLTFLoader.js';
import * as SkeletonUtils from './../vendor/jsm/utils/SkeletonUtils.js';
import { bindMaterials, library, glow } from './materials.js';

const LOWER = new Set(['root', 'pelvis', 'thigh_L', 'thigh_R', 'shin_L', 'shin_R', 'foot_L', 'foot_R']);
const RUN_SPEED = 4.8;
const LOCO = ['L_Idle', 'L_Run_F', 'L_Run_B', 'L_Strafe_L', 'L_Strafe_R', 'L_Crouch_Idle', 'L_Crouch_Walk', 'L_Walk_F'];
const UPPER = ['U_Aim', 'U_LowReady', 'U_Reload'];
const FULL = ['F_Roll', 'F_Death'];

let assets;
export async function loadCharacters(base = 'assets/') {
  const loader = new GLTFLoader();
  const [op, robot] = await Promise.all([loader.loadAsync(base + 'operator.glb'), loader.loadAsync(base + 'robot.glb')]);
  const clips = {};
  for (const c of op.animations) {
    const filter = c.name.startsWith('L_') ? t => LOWER.has(t.name.split('.')[0])
      : c.name.startsWith('U_') ? t => !LOWER.has(t.name.split('.')[0]) : () => true;
    clips[c.name] = new THREE.AnimationClip(c.name, c.duration, c.tracks.filter(filter));
  }
  assets = { op: op.scene, robot: robot.scene, clips };
  return assets;
}

const damp = (a, b, k, dt) => THREE.MathUtils.damp(a, b, k, dt);

export class Character {
  /** kind: 'operator' | 'robot' */
  constructor(kind) {
    const src = kind === 'robot' ? assets.robot : assets.op;
    this.kind = kind;
    this.root = SkeletonUtils.clone(src);
    const L = library();
    // Suit/robot status lights are small and close to camera: keep them below the bloom knee.
    const charGlow = { light_cyan: L.char_cyan ||= glow(0x5fe3ff, .9, 'char_cyan'), light_amber: L.char_amber ||= glow(0xff8a2a, .9, 'char_amber') };
    const own = kind === 'robot' ? { ...charGlow, light_red: glow(0xff2a16, 5, 'light_red') } : charGlow;
    this.eyeMaterial = own.light_red;
    bindMaterials(this.root, own);
    this.root.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; o.frustumCulled = false; } });
    this.bones = {};
    this.root.traverse(o => { if (o.isBone) this.bones[o.name] = o; });
    this.meshes = {};
    this.root.traverse(o => { if (o.isSkinnedMesh || o.isMesh) this.meshes[o.name] = o; });
    this.mixer = new THREE.AnimationMixer(this.root);
    this.actions = {};
    for (const n of [...LOCO, ...UPPER, ...FULL]) {
      const a = this.mixer.clipAction(assets.clips[n]);
      a.enabled = true; a.setEffectiveWeight(0); a.play();
      if (n.startsWith('F_') || n === 'U_Reload') { a.setLoop(THREE.LoopOnce); a.clampWhenFinished = true; a.paused = true; }
      this.actions[n] = a;
    }
    this.w = { move: 0, crouch: 0, F: 0, B: 0, L: 0, R: 0, low: 0, reload: 0, full: 0 };
    this.fullClip = null;
    this.muzzle = new THREE.Object3D();
    this.bones.weapon.add(this.muzzle);
    this.muzzle.position.set(0, .93, .005);
    this.setWeapon(0);
    this.recoil = 0; this.flinch = 0;
    this._q = new THREE.Quaternion(); this._e = new THREE.Euler();
  }

  setWeapon(i) {
    const rifle = this.root.getObjectByName('Rifle') || this.root.getObjectByName('RobotRifle');
    const shot = this.root.getObjectByName('Shotgun');
    if (rifle) rifle.visible = i === 0 || !shot;
    if (shot) shot.visible = i === 1;
    this.muzzle.position.y = i === 1 ? .86 : .93;
  }

  /** Start a one-shot full-body clip (roll/death). duration rescales the authored clip. */
  playFull(name, duration) {
    const a = this.actions[name];
    a.reset(); a.paused = false; a.play();
    if (duration) a.timeScale = a.getClip().duration / duration;
    this.fullClip = name;
    // The roll's first key is the standing stance, so it takes over instantly: cross-fading a
    // dipping clip over a standing pose is what pushes feet through the deck.
    if (name === 'F_Roll') this.w.full = 1;
  }
  endFull() { this.fullClip = null; }

  playReload(duration) {
    const a = this.actions.U_Reload;
    a.reset(); a.paused = false; a.play();
    a.timeScale = a.getClip().duration / duration;
    this.reloading = true;
  }
  stopReload() { this.reloading = false; }

  /**
   * state: { vx, vz (world m/s), facing (radians, game convention), crouch, alert, dead }
   */
  update(dt, s) {
    const fx = Math.sin(s.facing), fz = -Math.cos(s.facing);
    const speed = Math.hypot(s.vx, s.vz);
    const f = speed > .05 ? (s.vx * fx + s.vz * fz) / speed : 0;
    const r = speed > .05 ? (s.vx * -fz + s.vz * fx) / speed : 0;
    const W = this.w, k = 12;
    W.move = damp(W.move, speed > .3 ? 1 : 0, k, dt);
    W.crouch = damp(W.crouch, s.crouch ? 1 : 0, 10, dt);
    const dirs = { F: Math.max(f, 0) ** 2, B: Math.max(-f, 0) ** 2, L: Math.max(-r, 0) ** 2, R: Math.max(r, 0) ** 2 };
    const sum = dirs.F + dirs.B + dirs.L + dirs.R || 1;
    for (const d of 'FBLR') W[d] = damp(W[d], speed > .3 ? dirs[d] / sum : W[d], k, dt);
    const dn = W.F + W.B + W.L + W.R || 1;
    W.full = damp(W.full, this.fullClip ? 1 : 0, this.fullClip === 'F_Death' ? 8 : 26, dt);
    W.low = damp(W.low, s.low ? 1 : 0, 8, dt);
    W.reload = damp(W.reload, this.reloading ? 1 : 0, 14, dt);
    const keep = 1 - W.full;
    const A = this.actions, walk = this.kind === 'robot';
    const stand = (1 - W.crouch) * keep, crouch = W.crouch * keep;
    A.L_Idle.setEffectiveWeight(stand * (1 - W.move));
    if (walk) {
      A.L_Walk_F.setEffectiveWeight(stand * W.move);
      for (const n of ['L_Run_F', 'L_Run_B', 'L_Strafe_L', 'L_Strafe_R']) A[n].setEffectiveWeight(0);
      A.L_Walk_F.timeScale = Math.max(.6, speed / 2.2);
    } else {
      A.L_Walk_F.setEffectiveWeight(0);
      A.L_Run_F.setEffectiveWeight(stand * W.move * W.F / dn);
      A.L_Run_B.setEffectiveWeight(stand * W.move * W.B / dn);
      A.L_Strafe_L.setEffectiveWeight(stand * W.move * W.L / dn);
      A.L_Strafe_R.setEffectiveWeight(stand * W.move * W.R / dn);
      const ts = Math.max(.55, speed / RUN_SPEED);
      for (const n of ['L_Run_F', 'L_Run_B', 'L_Strafe_L', 'L_Strafe_R']) A[n].timeScale = ts;
    }
    A.L_Crouch_Idle.setEffectiveWeight(crouch * (1 - W.move));
    A.L_Crouch_Walk.setEffectiveWeight(crouch * W.move);
    A.L_Crouch_Walk.timeScale = Math.max(.6, speed / 2.2);
    const low = Math.max(W.low, W.crouch);
    A.U_Reload.setEffectiveWeight(keep * W.reload);
    A.U_Aim.setEffectiveWeight(keep * (1 - W.reload) * (1 - low));
    A.U_LowReady.setEffectiveWeight(keep * (1 - W.reload) * low);
    for (const n of FULL) A[n].setEffectiveWeight(this.fullClip === n || (n === 'F_Death' && s.dead) ? W.full : 0);
    this.mixer.update(dt);
    // procedural layers on top of the authored pose
    this.recoil *= Math.exp(-dt * 15);
    this.flinch = Math.max(0, this.flinch - dt);
    const sp = this.bones.spine2, wp = this.bones.weapon;
    if (this.recoil > .001 || this.flinch > 0) {
      this._e.set(-(this.recoil * .1 + this.flinch * .9), 0, this.recoil * .03);
      sp.quaternion.multiply(this._q.setFromEuler(this._e));
      wp.position.y -= this.recoil * .07;
      this._e.set(this.recoil * .22, 0, 0);
      wp.quaternion.multiply(this._q.setFromEuler(this._e));
    }
  }
}
