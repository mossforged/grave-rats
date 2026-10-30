import * as THREE from 'three';
import { GLTFLoader } from './vendor/jsm/loaders/GLTFLoader.js';
import { EffectComposer } from './vendor/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from './vendor/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from './vendor/jsm/postprocessing/UnrealBloomPass.js';
import { GTAOPass } from './vendor/jsm/postprocessing/GTAOPass.js';
import { OutputPass } from './vendor/jsm/postprocessing/OutputPass.js';
import { RoomEnvironment } from './vendor/jsm/environments/RoomEnvironment.js';
import { library, pbr, bindMaterials, setAnisotropy } from './src/materials.js';
import { loadCharacters, Character } from './src/characters.js';

// ============================================================================================
// Dead Circuit — First Contact (visual pass 05: authored asset pipeline)
// Gameplay rules (grid, collision, sight, AI, weapons, roll, cover, pickups, extraction) are
// unchanged from pass 04 unless noted "pass 05". Visuals come from Blender-built glTF assets:
//   assets/operator.glb, robot.glb  (assets-src/build_characters.py)
//   assets/kit.glb                  (assets-src/build_kit.py)
//   assets/tex/*                    (assets-src/textures.py)
// ============================================================================================
const $ = id => document.getElementById(id);
const params = new URLSearchParams(location.search);
const QUALITY = params.get('q') === 'low' ? 'low' : 'high';
const scene = new THREE.Scene(); scene.background = new THREE.Color('#04070a'); scene.fog = new THREE.FogExp2('#04070a', .004);
let renderer;
try { renderer = new THREE.WebGLRenderer({ antialias: QUALITY === 'low', powerPreference: 'high-performance' }); }
catch (e) { $('error').classList.remove('hidden'); $('error').textContent = 'This prototype needs WebGL. Please open it in a desktop browser with hardware acceleration enabled.'; throw e; }
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5)); renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
renderer.info.autoReset = false;
$('viewport').appendChild(renderer.domElement);
setAnisotropy(Math.min(8, renderer.capabilities.getMaxAnisotropy()));

const camera = new THREE.OrthographicCamera(-25, 25, 17, -17, .1, 180);
const CAM_OFFSET = new THREE.Vector3(12, 40, 29);
// pass 05: interiors are lit by practicals; sky/sun only lift the blacks and give contact shadows.
const hemi = new THREE.HemisphereLight(0x8aa4b4, 0x0b0f12, .55); scene.add(hemi);
const sun = new THREE.DirectionalLight(0xc4d6e2, .75); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -24, right: 24, top: 24, bottom: -24, near: 1, far: 120 }); sun.shadow.bias = -.0004; sun.shadow.normalBias = .03;
scene.add(sun, sun.target);
const ambient = new THREE.AmbientLight(0x31424e, .18); scene.add(ambient);
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), .04).texture; scene.environmentIntensity = .32;

let rngState = 1049; function rand() { rngState = (Math.imul(1664525, rngState) + 1013904223) | 0; return (rngState >>> 0) / 4294967296; } const ri = (a, b) => Math.floor(a + rand() * (b - a));
const TH = .40, T = 2.2, NX = 43, NZ = 36, grid = Array.from({ length: NZ }, () => Array(NX).fill(0));
const rooms = [{ name: 'BOARDING AIRLOCK', x: 2, z: 24, w: 8, h: 7, color: '#79999b' }, { name: 'CREW QUARTERS', x: 2, z: 14, w: 10, h: 8, color: '#6d8187' }, { name: 'MEDBAY', x: 2, z: 3, w: 11, h: 9, color: '#829d9e' }, { name: 'CARGO HOLD', x: 20, z: 3, w: 13, h: 10, color: '#8b8c7c' }, { name: 'ENGINEERING', x: 20, z: 19, w: 13, h: 11, color: '#6f8e92' }, { name: 'MAINTENANCE', x: 36, z: 5, w: 4, h: 25, color: '#7b8381' }];
function carve(x, z, w, h) { for (let j = z; j < z + h; j++)for (let i = x; i < x + w; i++)grid[j][i] = 1; } rooms.forEach(r => carve(r.x, r.z, r.w, r.h)); [[14, 3, 4, 30], [9, 25, 7, 3], [11, 8, 10, 3], [17, 8, 5, 3], [7, 14, 32, 3], [27, 11, 3, 5], [23, 16, 3, 5], [32, 24, 6, 3], [15, 30, 24, 3], [25, 28, 3, 4], [37, 28, 2, 4], [32, 7, 6, 3]].forEach(r => carve(...r));
const walkCells = []; for (let z = 0; z < NZ; z++)for (let x = 0; x < NX; x++)if (grid[z][x]) walkCells.push({ x, z, seen: false, visible: false });
const cellAt = new Map(walkCells.map(c => [c.x + ',' + c.z, c]));
const roomAt = (x, z) => rooms.find(r => x >= r.x && x < r.x + r.w && z >= r.z && z < r.z + r.h);
const world = new THREE.Group(); scene.add(world); const solids = [], decor = [], doors = [], pickups = [], enemies = [], traces = [], particles = []; const temp = new THREE.Object3D(), color = new THREE.Color();

// ---------------------------------------------------------------- assets
$('startBtn').disabled = true; const startLabel = $('startBtn').innerHTML; $('startBtn').textContent = 'LOADING SHIP ASSETS…';
try { await Promise.race([document.fonts.load('800 118px "Barlow Condensed"'), new Promise(r => setTimeout(r, 1500))]); } catch { }
const [kitGltf] = await Promise.all([new GLTFLoader().loadAsync('assets/kit.glb'), loadCharacters('assets/')]);
const KIT = {}; for (const o of kitGltf.scene.children) { bindMaterials(o); o.updateMatrixWorld(true); KIT[o.name] = o; }
const L = library();
function kitParts(name) { const out = [], root = KIT[name]; if (!root) throw new Error('missing kit piece ' + name); root.traverse(m => { if (m.isMesh) out.push({ geometry: m.geometry, material: m.material, matrix: m.matrixWorld.clone() }); }); return out; }
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(), _p = new THREE.Vector3(), _up = new THREE.Vector3(0, 1, 0);
function placeMatrix(x, z, rotY = 0, sx = 1, sy = 1, sz = 1, y = 0) { return new THREE.Matrix4().compose(_p.set(x, y, z), _q.setFromAxisAngle(_up, rotY), _s.set(sx, sy, sz)); }
/** One InstancedMesh per kit sub-mesh; returns meshes so callers can tint instances. */
function instanced(name, mats, shadow = true) {
  if (!mats.length) return [];
  return kitParts(name).map(p => {
    const im = new THREE.InstancedMesh(p.geometry, p.material, mats.length);
    mats.forEach((m, i) => im.setMatrixAt(i, _m.multiplyMatrices(m, p.matrix)));
    im.castShadow = shadow && !p.material.emissive?.getHex?.() ; im.receiveShadow = true; im.name = name; world.add(im); return im;
  });
}
const propQueue = new Map();
function prop(name, x, z, rotY = 0, sx = 1, sy = 1, sz = 1) { if (!propQueue.has(name)) propQueue.set(name, []); propQueue.get(name).push(placeMatrix(x, z, rotY, sx, sy, sz)); }
function kitClone(name) { const g = KIT[name].clone(true); g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); return g; }

// Legacy procedural pieces (engineering, maintenance) now share the authored PBR library.
function mat(c, metal = .4, rough = .7, extra = {}) { return new THREE.MeshStandardMaterial({ color: c, metalness: metal, roughness: rough, ...extra }); }
const steel = L.paint_robot, dark = L.dark_metal, edge = pbr('dark_metal', { color: 0xa9b4b8, name: 'edge' }), black = L.rubber, orange = L.paint_orange, ivory = L.paint_white, rubber = L.rubber, cyanGlow = L.light_cyan, amberGlow = L.light_amber, redGlow = L.light_red;
const boxGeo = new THREE.BoxGeometry(1, 1, 1), cylGeo = new THREE.CylinderGeometry(1, 1, 1, 16), sphereGeo = new THREE.SphereGeometry(1, 12, 8);
function box(parent, x, y, z, w, h, d, m, shadow = true) { const o = new THREE.Mesh(boxGeo, m); o.position.set(x, y, z); o.scale.set(w, h, d); if (shadow) { o.castShadow = true; o.receiveShadow = true; } parent.add(o); return o; }
function cyl(parent, x, y, z, r, h, m, axis = 'y') { const o = new THREE.Mesh(cylGeo, m); o.position.set(x, y, z); o.scale.set(r, h, r); if (axis === 'z') o.rotation.x = Math.PI / 2; if (axis === 'x') o.rotation.z = Math.PI / 2; o.castShadow = true; o.receiveShadow = true; parent.add(o); return o; }
function sphere(parent, x, y, z, r, m) { const o = new THREE.Mesh(sphereGeo, m); o.position.set(x, y, z); o.scale.setScalar(r); o.castShadow = true; parent.add(o); return o; }

// ---------------------------------------------------------------- deck: floor modules
// pass 05: real plate modules (bevelled seams, authored normal/ORM) with grate runs in corridors.
const floorMats = { floor_tile: [], floor_grate_tile: [] };
walkCells.forEach(a => {
  const inRoom = !!roomAt(a.x, a.z);
  const grate = !inRoom && ((a.x === 15 && a.z % 4 === 1) || (a.z === 9 && a.x > 12 && a.x < 20 && a.x % 3 === 0) || (a.z === 15 && a.x % 5 === 0));
  a.fv = grate ? 'floor_grate_tile' : 'floor_tile';
  const rot = grate ? (a.z === 9 || a.z === 15 ? 0 : Math.PI / 2) : (ri(0, 4) * Math.PI / 2);
  a.fi = floorMats[a.fv].length; floorMats[a.fv].push(placeMatrix(a.x * T, a.z * T, rot));
});
const floorMeshes = { floor_tile: instanced('floor_tile', floorMats.floor_tile, false), floor_grate_tile: instanced('floor_grate_tile', floorMats.floor_grate_tile, false) };
for (const ms of Object.values(floorMeshes)) for (const im of ms) { for (let i = 0; i < im.count; i++) im.setColorAt(i, color.set(1, 1, 1)); }
const floors = { setColorAt(i, c) { const a = walkCells[i]; for (const im of floorMeshes[a.fv]) im.setColorAt(a.fi, c); }, get instanceColor() { return { set needsUpdate(v) { for (const ms of Object.values(floorMeshes)) for (const im of ms) im.instanceColor.needsUpdate = v; } }; } };

// ---------------------------------------------------------------- bulkheads
// pass 05: walls facing the camera are full height; walls between the camera and a room are
// cut away low (thick dark section on top), as in the concept's dollhouse view.
const wallCells = [];
for (const a of walkCells) for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (!grid[a.z + dz]?.[a.x + dx]) wallCells.push({ x: a.x + dx * .5, z: a.z + dz * .5, dx, dz, cx: a.x, cz: a.z });
const hash = (x, z) => { let h = Math.imul(Math.round(x * 2) + 101, 73856093) ^ Math.imul(Math.round(z * 2) + 7, 19349663); return (h >>> 0) % 97; };
const wallMats = {}, postInfo = new Map();
for (const a of wallCells) {
  const low = a.dz === 1 || a.dx === 1, room = roomAt(a.cx, a.cz), h = hash(a.x, a.z);
  let v = 'wall_low';
  if (!low) {
    if (room?.name === 'MEDBAY') v = h % 3 === 0 ? 'wall_med_light' : 'wall_med';
    else if (!room) v = h % 3 === 0 ? 'wall_tall_light' : h % 3 === 1 ? 'wall_tall_pipes' : h % 11 === 2 ? 'wall_tall_vent' : 'wall_tall';
    else v = h % 3 === 0 ? 'wall_tall_light' : h % 7 === 1 ? 'wall_tall_screen' : h % 5 === 2 ? 'wall_tall_vent' : h % 4 === 3 ? 'wall_tall_pipes' : 'wall_tall';
  }
  a.low = low; a.pv = v; (wallMats[v] ||= []); a.pi = wallMats[v].length;
  wallMats[v].push(placeMatrix(a.x * T, a.z * T, Math.atan2(-a.dx, -a.dz)));
  for (const s of [-.5, .5]) {
    const ex = a.x + Math.abs(a.dz) * s, ez = a.z + Math.abs(a.dx) * s, key = ex + ',' + ez;
    const p = postInfo.get(key) || { x: ex, z: ez, tall: true }; p.tall = p.tall && !low; postInfo.set(key, p);
  }
}
// signature medbay sign wall (north wall, centre bay)
for (const a of wallCells) if (a.cx === 7 && a.cz === 3 && a.dz === -1) { wallMats[a.pv][a.pi] = null; a.pv = 'wall_med_sign'; (wallMats.wall_med_sign ||= []); a.pi = wallMats.wall_med_sign.length; wallMats.wall_med_sign.push(placeMatrix(a.x * T, a.z * T, 0)); }
const wallMeshes = {};
for (const [v, list] of Object.entries(wallMats)) {
  const idx = []; const compact = list.filter((m, i) => { if (m) idx.push(i); return !!m; });
  const remap = new Map(idx.map((old, i) => [old, i]));
  for (const a of wallCells) if (a.pv === v) a.pi = remap.get(a.pi);
  wallMeshes[v] = instanced(v, compact);
  for (const im of wallMeshes[v]) for (let i = 0; i < im.count; i++) im.setColorAt(i, color.set(1, 1, 1));
}
const walls = { setColorAt(i, c) { const a = wallCells[i]; for (const im of wallMeshes[a.pv]) im.setColorAt(a.pi, c); }, get instanceColor() { return { set needsUpdate(v) { for (const ms of Object.values(wallMeshes)) for (const im of ms) im.instanceColor.needsUpdate = v; } }; } };
const posts = { post_tall: [], post_low: [] };
for (const p of postInfo.values()) posts[p.tall ? 'post_tall' : 'post_low'].push(placeMatrix(p.x * T, p.z * T));
instanced('post_tall', posts.post_tall); instanced('post_low', posts.post_low);
// Structural backing: walls read ~1 m thick from above (dark cut section), voids stay open and dark.
{
  const backs = [];
  for (const a of wallCells) {
    const h = a.low ? .84 : 2.66, depth = .62, off = TH / 2 + depth / 2;
    backs.push(placeMatrix((a.x + a.dx * 0) * T + a.dx * off, (a.z) * T + a.dz * off, 0, a.dx ? depth : T + .02, h, a.dz ? depth : T + .02, h / 2));
  }
  const side = L.dark_metal, top = L.hull_top;
  const im = new THREE.InstancedMesh(boxGeo, [side, side, top, side, side, side], backs.length);
  backs.forEach((m, i) => im.setMatrixAt(i, m)); im.receiveShadow = true; im.castShadow = true; world.add(im);
  const voidMat = new THREE.MeshStandardMaterial({ color: 0x050708, roughness: .95, metalness: .2, name: 'void' });
  const voidPlane = new THREE.Mesh(new THREE.PlaneGeometry(NX * T + 20, NZ * T + 20), voidMat); voidPlane.rotation.x = -Math.PI / 2; voidPlane.position.set((NX - 1) * T / 2, -.05, (NZ - 1) * T / 2); voidPlane.receiveShadow = true; world.add(voidPlane);
}
// Thin ship underbody and a dusted starfield beyond the cutaway.
const starPos = []; for (let i = 0; i < 800; i++)starPos.push(rand() * 320 - 100, -3 - rand() * 8, rand() * 260 - 90); const starsG = new THREE.BufferGeometry(); starsG.setAttribute('position', new THREE.Float32BufferAttribute(starPos, 3)); scene.add(new THREE.Points(starsG, new THREE.PointsMaterial({ size: .065, color: 0x8facbc, transparent: true, opacity: .65 })));

// ---------------------------------------------------------------- stencils
function stencilTexture(text, c, alpha, font = '800 118px "Barlow Condensed", Arial') {
  const cv = document.createElement('canvas'); cv.width = 1024; cv.height = 256; const g = cv.getContext('2d');
  g.fillStyle = c; g.globalAlpha = alpha; g.font = font; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(text, 512, 132);
  g.globalCompositeOperation = 'destination-out'; for (let i = 0; i < 420; i++) { g.globalAlpha = rand() * .8; g.fillRect(rand() * 1024, rand() * 256, rand() * 14, rand() * 3); }
  const tx = new THREE.CanvasTexture(cv); tx.colorSpace = THREE.SRGBColorSpace; return tx;
}
function decal(text, x, z, w = 8, h = 2, c = '#b9c8c3', rotation = 0, alpha = .42) { const plane = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshStandardMaterial({ map: stencilTexture(text, c, alpha), transparent: true, depthWrite: false, roughness: .9, polygonOffset: true, polygonOffsetFactor: -2 })); plane.rotation.x = -Math.PI / 2; plane.rotation.z = rotation; plane.position.set(x, .012, z); plane.receiveShadow = true; world.add(plane); return plane; }
function wallSign(text, x, z, w = 4.4, c = '#c9d2cf') { const p = new THREE.Mesh(new THREE.PlaneGeometry(w, w / 4), new THREE.MeshStandardMaterial({ map: stencilTexture(text, c, .7), transparent: true, depthWrite: false, roughness: .8, polygonOffset: true, polygonOffsetFactor: -2 })); p.position.set(x, 2.0, z); world.add(p); return p; }
rooms.forEach(r => { if (r.name !== 'MEDBAY' && r.name !== 'CARGO HOLD') decal(r.name, r.x * T + r.w * T * .46, (r.z + 1.3) * T, Math.min(r.w * T * .65, 12), 1.3); });
wallSign('MEDBAY', 4.5 * T, 2.5 * T + .22); wallSign('CARGO  ›››', 25.5 * T, 2.5 * T + .22, 5.2, '#d0a85c'); wallSign('ENGINEERING', 27 * T, 18.5 * T + .22, 5.2);
decal('01', 15.6 * T, 11.6 * T, 3.6, 2.4, '#c4cbc4', 0, .5); decal('04', 15.5 * T, 22 * T, 3.8, 2.5, '#b5bbb4'); decal('KEEP CLEAR', 5.7 * T, 28.9 * T, 9, 1.2, '#c9a15a'); decal('›››', 15.5 * T, 12.9 * T, 2.2, 1.2, '#c6a266');
decal('+', 5 * T, 9.6 * T, 2.5, 2.5, '#a75a48', 0, .55);
function addSolid(x, z, w, d) { solids.push({ x, z, w, d }); }
function smearTexture(col, seed) { const cv = document.createElement('canvas'); cv.width = 512; cv.height = 256; const g = cv.getContext('2d'); let x = 30, y = 128; g.fillStyle = col; for (let i = 0; i < 170; i++) { x += 2.6 + rand() * .8; y += (rand() - .5) * 6; g.globalAlpha = .04 + rand() * .12; g.beginPath(); g.ellipse(x, y, 6 + rand() * 18, 4 + rand() * 10, rand() * 3, 0, 7); g.fill(); if (rand() < .08) { g.globalAlpha = .5; g.beginPath(); g.arc(x + (rand() - .5) * 60, y + (rand() - .5) * 60, 1 + rand() * 4, 0, 7); g.fill(); } } const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace; return t; }
function smear(x, z, w, rot, col = '#3a0805') { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, w / 2), new THREE.MeshStandardMaterial({ map: smearTexture(col), transparent: true, depthWrite: false, roughness: .35, metalness: 0, polygonOffset: true, polygonOffsetFactor: -3 })); m.rotation.set(-Math.PI / 2, 0, rot); m.position.set(x, .014, z); world.add(m); }
smear(7.6 * T, 8.6 * T, 5.5, -.5); smear(10.6 * T, 9.3 * T, 4, .1); smear(4.2 * T, 8.0 * T, 2.6, 2.2); smear(15.2 * T, 9.4 * T, 4.5, .05, '#1c0604');
for (const [x, z, w, r] of [[16.2, 7.2, 3, .4], [14.6, 11.2, 2.5, 2], [24.5, 9.5, 4, 1.1], [28.5, 11, 3.5, .2], [21.8, 7.5, 3, 2.6]]) smear(x * T, z * T, w, r, '#0b0c0b');

// ---------------------------------------------------------------- props (collision footprints unchanged from pass 04)
function crate(x, z, w = 1.7, d = 1.6, h = 1.1, col = steel) {
  const piece = col === orange ? 'crate_yellow' : col === ivory ? 'crate_small' : h > 1.45 ? 'crate_tall' : 'crate_large';
  const base = { crate_yellow: [1.5, 1.0, 1.2], crate_small: [.9, .7, .8], crate_tall: [1.5, 1.7, 1.5], crate_large: [1.9, 1.25, 1.7] }[piece];
  prop(piece, x, z, 0, w / base[0], h / base[1], d / base[2]); addSolid(x, z, w + .12, d + .12);
}
function bed(x, z) { prop('med_bed', x, z, 0, 1.15, 1, 1.12); addSolid(x, z, 1.7, 2.7); }
function consoleUnit(x, z, rot = 0) { prop('med_console', x, z, rot, 1.05, 1, 1.1); addSolid(x, z, 1.8, 1); }
// Medbay: treatment beds, surgical consoles, supply cabinets, IV stands.
for (const x of [4, 7.5, 11]) { bed(x * T, 6.5 * T); prop('iv_stand', x * T + .72, 6.5 * T - 1.05); }
for (const x of [4, 8, 11]) consoleUnit(x * T, 3.25 * T); crate(3 * T, 10 * T, 1.4, 1.4, 1.5, ivory);
// pass 05 additions hug the walls and carry their own solids (no route changes).
prop('med_cabinet', 1.5 * T + .52, 5.2 * T, Math.PI / 2); addSolid(1.5 * T + .52, 5.2 * T, .62, 1.66);
prop('med_cabinet', 12.5 * T - .52, 4.6 * T, -Math.PI / 2); addSolid(12.5 * T - .52, 4.6 * T, .62, 1.66);
prop('stool', 8.6 * T, 8.4 * T); prop('stool', 5.3 * T, 4.4 * T);
prop('med_cabinet', 1.5 * T + .52, 8.4 * T, Math.PI / 2); addSolid(1.5 * T + .52, 8.4 * T, .62, 1.66);
prop('med_bed', 6.6 * T, 11.5 * T - .9, Math.PI / 2, 1.1, 1, 1.1); addSolid(6.6 * T, 11.5 * T - .9, 2.6, 1.5);
prop('canister', 2.5 * T - .3, 2.5 * T + .62); addSolid(2.5 * T - .3, 2.5 * T + .62, .72, .72);
prop('canister', 12.5 * T - .6, 2.5 * T + .62, 2); addSolid(12.5 * T - .6, 2.5 * T + .62, .72, .72);
prop('iv_stand', 6.6 * T + 1.4, 11.5 * T - 1.8, .5);
prop('cable_run', 9.6 * T, 9.8 * T, .3); prop('cable_run', 3.4 * T, 7.2 * T, 1.7);
// Crew quarters with bunks and a central service table.
for (const x of [3, 6]) { bed(x * T, 17 * T); box(world, x * T, 1.55, 17 * T, 1.2, .16, 2.6, dark); } crate(10 * T, 19 * T, 2, 1.6, 1.2); box(world, 6 * T, .55, 20 * T, 3.2, 1.1, 1.1, steel); addSolid(6 * T, 20 * T, 3.2, 1.1);
// Cargo stacks leave a deliberate route between cover islands.
[[22, 5, 2.4, 2.4, 1.4], [24, 5, 1.8, 2.4, 1.8], [29, 6, 3, 2.4, 1.5], [30, 10, 2, 2.4, 1.1], [23, 10, 1.8, 1.8, 1.6], [26, 8, 2, 2, 1.3]].forEach(([x, z, w, d, h], i) => crate(x * T, z * T, w, d, h, i % 3 === 0 ? orange : steel));
prop('shelf', 27.6 * T, 2.5 * T + .62); addSolid(27.6 * T, 2.5 * T + .62, 2.2, .8);
prop('shelf', 31.4 * T, 2.5 * T + .62); addSolid(31.4 * T, 2.5 * T + .62, 2.2, .8);
prop('canister', 32.5 * T - .5, 8.5 * T); addSolid(32.5 * T - .5, 8.5 * T, .72, .72);
prop('crate_small', 20 * T - .1, 7.7 * T, .2); addSolid(20 * T - .1, 7.7 * T, 1, .9);
prop('crate_tall', 32.5 * T - .9, 4.4 * T, .05); addSolid(32.5 * T - .9, 4.4 * T, 1.6, 1.6);
prop('crate_yellow', 20 * T + .1, 4.2 * T, Math.PI / 2); addSolid(20 * T + .1, 4.2 * T, 1.3, 1.6);
prop('crate_small', 20 * T, 5.5 * T, -.15); addSolid(20 * T, 5.5 * T, 1.0, 1.0);
prop('canister', 24.3 * T, 2.5 * T + .6); addSolid(24.3 * T, 2.5 * T + .6, .72, .72);
prop('cable_run', 26.5 * T, 11.7 * T, 0); prop('floor_hatch', 27 * T, 9.6 * T);
// Transit corridor at the junction: pressure canisters, cable runs, service hatches.
prop('canister', 13.5 * T + .55, 5.6 * T); addSolid(13.5 * T + .55, 5.6 * T, .72, .72);
prop('canister', 13.5 * T + .55, 6.1 * T, 1); addSolid(13.5 * T + .55, 6.1 * T, .72, .72);
prop('floor_hatch', 16 * T, 9 * T); prop('floor_hatch', 15.5 * T, 18 * T, Math.PI / 2);
prop('cable_run', 14.6 * T, 4.4 * T, Math.PI / 2); prop('cable_run', 19.5 * T, 10.4 * T, 0);
// Engineering: a glowing industrial reactor, pumps, ribs, pipe runs.
const reactor = new THREE.Group(); reactor.position.set(28 * T, 0, 24 * T); cyl(reactor, 0, .3, 0, 2.1, .6, dark); cyl(reactor, 0, .7, 0, 1.8, .22, edge); cyl(reactor, 0, 1.15, 0, 1.35, .8, steel); cyl(reactor, 0, 1.6, 0, 1.2, .18, cyanGlow); cyl(reactor, 0, 1.8, 0, .7, .3, dark); for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; box(reactor, Math.cos(a) * 1.5, 1.1, Math.sin(a) * 1.5, .22, 1.2, .22, edge); } world.add(reactor); addSolid(28 * T, 24 * T, 4.3, 4.3);
for (const x of [21, 22.5]) { cyl(world, x * T, .7, 27.7 * T, .6, 1.4, steel); cyl(world, x * T, 1.4, 27.7 * T, .62, .1, edge); addSolid(x * T, 27.7 * T, 1.2, 1.2); } consoleUnit(29 * T, 20 * T); consoleUnit(22 * T, 20 * T); crate(31 * T, 28 * T, 2, 2, 1.5);
for (let x = 21; x < 32; x++) { cyl(world, x * T, .32, 29.2 * T, .13, T, orange, 'x'); cyl(world, x * T, .32, 28.9 * T, .09, T, edge, 'x'); } for (let z = 7; z < 28; z += 3) { box(world, 39.3 * T, .7, z * T, .7, 1.3, 1.6, dark); box(world, 39.3 * T, 1.38, z * T, .5, .08, 1.3, edge); }
consoleUnit(3 * T, 25 * T, Math.PI / 2); crate(9 * T, 29 * T, 1.5, 1.5, 1.2, orange);
// Boarding lockers, cargo pallets, and ventilation assemblies.
for (const z of [25, 27, 29]) { const x = 2.35 * T; box(world, x, .72, z * T, .65, 1.4, 1.35, steel); box(world, x + .34, .75, z * T, .04, 1.1, 1.1, dark); box(world, x + .39, .95, z * T + .3, .06, .25, .08, edge); box(world, x + .4, 1.25, z * T, .06, .06, .4, amberGlow, false); addSolid(x, z * T, .8, 1.4); }
for (const [x, z] of [[8.7, 24.4], [32.2, 4.5], [20.5, 12.3], [31.5, 19.5]]) { const g = new THREE.Group(); g.position.set(x * T, 0, z * T); box(g, 0, .75, 0, 1.6, 1.5, .8, dark); for (let i = 0; i < 7; i++)box(g, 0, .2 + i * .17, -.45, 1.35, .055, .07, edge, false); box(g, 0, 1.55, 0, 1.65, .1, .85, steel); world.add(g); addSolid(x * T, z * T, 1.7, 1); }
for (const [x, z] of [[21.4, 6.2], [29.7, 4.5], [30.5, 11.5]]) { prop('pallet', x * T, z * T, 0, 1.5, 1, 1.43); crate(x * T, z * T, 2.8, 2.4, 1.2, steel); }
// Scuffed traffic lanes and oil stains break up the modular floor grid.
const stainCanvas = document.createElement('canvas'); stainCanvas.width = stainCanvas.height = 128; const stainG = stainCanvas.getContext('2d'); const gradient = stainG.createRadialGradient(64, 64, 4, 64, 64, 62); gradient.addColorStop(0, 'rgba(0,4,6,.5)'); gradient.addColorStop(.55, 'rgba(0,6,9,.22)'); gradient.addColorStop(1, 'rgba(0,0,0,0)'); stainG.fillStyle = gradient; stainG.fillRect(0, 0, 128, 128); const stainTx = new THREE.CanvasTexture(stainCanvas); const stainMat = new THREE.MeshBasicMaterial({ map: stainTx, transparent: true, depthWrite: false });
for (let i = 0; i < 38; i++) { const p = walkCells[ri(0, walkCells.length)], o = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), stainMat); o.rotation.x = -Math.PI / 2; o.rotation.z = rand() * 6.28; o.position.set(p.x * T, .006, p.z * T); o.scale.set(1 + rand() * 4, 1 + rand() * 2, 1); world.add(o); }
for (let z = 5; z < 32; z++) { if (z % 3 === 0) continue; box(world, 14.62 * T, .004, z * T, .07, .012, 1.25, L.paint_yellow, false); box(world, 16.38 * T, .004, z * T, .07, .012, 1.25, L.paint_yellow, false); }
for (const [x, z] of [[3, 23.7], [21, 18.7], [20, 2.7], [35.7, 10]]) { box(world, x * T, .004, z * T, 1.8, .012, .4, L.paint_hazard, false); }
for (let i = 0; i < 70; i++) { const p = walkCells[ri(0, walkCells.length)]; if (rand() > .3) { const o = box(world, p.x * T + (rand() - .5) * 1.5, .02, p.z * T + (rand() - .5) * 1.5, .08 + rand() * .22, .03, .06 + rand() * .16, rand() > .7 ? ivory : dark, false); o.rotation.y = rand() * 6.28; } }

// ---------------------------------------------------------------- bulkhead doors
// pass 05: frames fill the whole 3-tile opening and their jambs are solid, so a closed door now
// actually seals the corridor (pass 04 left ~1.1 m walkable gaps beside each leaf).
function makeDoor(x, z, axis, name) {
  const g = new THREE.Group(); g.position.set(x * T, 0, z * T); if (axis === 'x') g.rotation.y = Math.PI / 2;
  const width = 4.35, jamb = (3 * T - width) / 2;
  const frame = kitClone('door_frame'); frame.scale.set(1, 1, 1); g.add(frame);
  // kit frame jambs are .5 wide; widen them to fill the remaining opening
  frame.traverse(o => { if (o.isMesh) o.updateMatrix(); });
  for (const s of [-1, 1]) { box(g, s * (width / 2 + jamb / 2 + .25), 1.3, 0, jamb - .5 > 0 ? jamb - .5 : .01, 2.6, .66, dark); }
  const leaf = new THREE.Group(); g.add(leaf);
  const a = kitClone('door_leaf'); a.position.x = -width / 2 - .02; leaf.add(a);
  const b = kitClone('door_leaf'); b.position.x = width / 2 + .02; b.scale.x = -1; leaf.add(b);
  world.add(g);
  const door = { x: x * T, z: z * T, w: axis === 'x' ? .45 : width, d: axis === 'x' ? width : .45, g, leaf, open: false, slide: 0, name }; doors.push(door);
  for (const s of [-1, 1]) { const off = s * (width / 2 + jamb / 2); addSolid(x * T + (axis === 'x' ? 0 : off), z * T + (axis === 'x' ? off : 0), axis === 'x' ? .7 : jamb, axis === 'x' ? jamb : .7); }
  return door;
}
makeDoor(12.4, 9, 'x', 'MEDBAY BULKHEAD'); makeDoor(24, 18, 'z', 'ENGINEERING BULKHEAD'); makeDoor(18.5, 9, 'x', 'CARGO BULKHEAD');
for (const [name, list] of propQueue) instanced(name, list);

// ---------------------------------------------------------------- lighting (pass 05)
const practicals = [];
// Practicals hang high (4.6 m, above the cutaway): at 2.35 m they sat a hand's width above helmets and blew them out.
function light(x, z, c, p = 30, dist = 11, y = 4.6) { const k = (y * y) / (2.35 * 2.35); const l = new THREE.PointLight(c, p * k, dist + 3, 2); l.position.set(x * T, y, z * T); scene.add(l); practicals.push(l); return l; }
// junction: clinical cool medbay, cool corridor, sodium-amber cargo
light(4.5, 6.2, 0xd2ecff, 46, 12); light(9.8, 6.2, 0xd2ecff, 46, 12); light(7, 3.6, 0xff3b2a, 10, 6, 2.1); light(7, 10, 0x9fd8ff, 28, 9);
light(15.5, 5.5, 0xc4e6ff, 40, 11); light(15.5, 12.5, 0xc4e6ff, 40, 11); light(13.6, 9, 0xff9a3c, 16, 6, 2.4); light(18.6, 9, 0xff9a3c, 16, 6, 2.4);
light(23.5, 6, 0xff9440, 75, 13); light(29.5, 8.5, 0xff8a30, 75, 13); light(31.5, 3.6, 0xff6a1a, 22, 7); light(25, 11.5, 0xffb060, 30, 9);
light(28, 24, 0x49d5db, 40, 12); light(7, 26, 0xff9947, 30, 11); light(6, 18, 0x9ec4d8, 14, 10); light(38, 16, 0xff5a3a, 12, 10);
const flashlight = new THREE.SpotLight(0xe2f2f6, 80, 24, .5, .55, 1.4); flashlight.position.set(0, 1.2, 0); flashlight.target.position.set(0, 0, 0);
flashlight.castShadow = true; flashlight.shadow.mapSize.set(1024, 1024); flashlight.shadow.bias = -.0006; flashlight.shadow.normalBias = .02; flashlight.shadow.camera.near = .3; scene.add(flashlight, flashlight.target);
const flash = new THREE.PointLight(0xffb156, 0, 8, 1.4); scene.add(flash);
const beamGeometry = new THREE.BufferGeometry(); const beamVertices = new Float32Array(72 * 9); beamGeometry.setAttribute('position', new THREE.BufferAttribute(beamVertices, 3)); const beam = new THREE.Mesh(beamGeometry, new THREE.MeshBasicMaterial({ color: 0xb6d4cf, transparent: true, opacity: .05, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending })); beam.frustumCulled = false; scene.add(beam);
function updateBeam() { beam.visible = started && player.light; if (!beam.visible) return; let index = 0; const points = []; for (let i = 0; i <= 72; i++) { const a = player.angle - .48 + i / 72 * .96, dx = Math.sin(a), dz = -Math.cos(a); let d = 0; for (d = 1; d < 21; d += .4)if (blocked(player.x + dx * d, player.z + dz * d, .01)) break; points.push([player.x + dx * d, .07, player.z + dz * d]); } for (let i = 0; i < 72; i++) { beamVertices.set([player.x, .07, player.z, ...points[i], ...points[i + 1]], index); index += 9; } beamGeometry.attributes.position.needsUpdate = true; }
const extraction = new THREE.Group(); extraction.position.set(5.5 * T, .035, 27.5 * T); const ring = new THREE.Mesh(new THREE.RingGeometry(1.5, 1.58, 48), new THREE.MeshBasicMaterial({ color: 0x82c9bb, transparent: true, opacity: .65, side: THREE.DoubleSide })); ring.rotation.x = -Math.PI / 2; extraction.add(ring); world.add(extraction); decal('AIRLOCK', 5.5 * T, 28.7 * T, 5, 1, '#95c9bd');
// Dust motes drifting through light (visible in the flashlight cone as in the concept).
const dustCount = 900, dustPos = new Float32Array(dustCount * 3); for (let i = 0; i < dustCount; i++) { dustPos[i * 3] = rand() * 30 - 15; dustPos[i * 3 + 1] = .2 + rand() * 2.2; dustPos[i * 3 + 2] = rand() * 30 - 15; }
const dustGeo = new THREE.BufferGeometry(); dustGeo.setAttribute('position', new THREE.BufferAttribute(dustPos, 3));
const dust = new THREE.Points(dustGeo, new THREE.PointsMaterial({ color: 0xcfe0e6, size: .035, transparent: true, opacity: .45, depthWrite: false, blending: THREE.AdditiveBlending })); dust.frustumCulled = false; scene.add(dust);

// ---------------------------------------------------------------- characters (pass 05: skinned glTF)
function actor(isRobot = false) {
  const ch = new Character(isRobot ? 'robot' : 'operator'); const g = new THREE.Group(); g.add(ch.root); scene.add(g);
  return { g, rig: ch.root, char: ch, legs: [], arms: [], upper: ch.bones.spine2, gun: ch.muzzle };
}
const player = { ...actor(), x: 5.5 * T, z: 26 * T, angle: 0, hp: 100, meds: 1, weapon: 0, ammo: [30, 6], reserve: [120, 24], reload: 0, cooldown: 0, light: true, recorder: false, steps: 0, roll: 0, rollCooldown: 0, rollX: 0, rollZ: 0, crouch: false, recoil: 0, vx: 0, vz: 0 }; player.g.position.set(player.x, 0, player.z);
function addEnemy(x, z) { const a = { ...actor(true), x: x * T, z: z * T, hp: 65, angle: 0, alert: 0, cooldown: rand(), path: [], repath: 0, home: { x: x * T, z: z * T }, dead: false, px: x * T, pz: z * T }; a.g.position.set(a.x, 0, a.z); enemies.push(a); }
[[15.5, 17], [24, 7], [30, 9], [37, 15], [22, 23], [30, 26], [37, 28], [16, 30]].forEach(a => addEnemy(...a));
function pickup(type, x, z) { const g = new THREE.Group(); g.position.set(x * T, 0, z * T); g.add(kitClone(type === 'med' ? 'pickup_med' : type === 'recorder' ? 'pickup_recorder' : 'pickup_ammo')); g.rotation.y = rand() * .6 - .3; world.add(g); pickups.push({ type, x: x * T, z: z * T, g, taken: false }); }
[['ammo', 8, 26], ['med', 10, 10], ['ammo', 22, 11], ['ammo', 31, 21], ['med', 37, 19], ['recorder', 25, 23], ['ammo', 16, 28]].forEach(a => pickup(...a));
const glowCanvas = document.createElement('canvas'); glowCanvas.width = glowCanvas.height = 128; const glowCtx = glowCanvas.getContext('2d'); const glowGrad = glowCtx.createRadialGradient(64, 64, 0, 64, 64, 64); glowGrad.addColorStop(0, 'rgba(255,255,255,.8)'); glowGrad.addColorStop(.17, 'rgba(255,255,255,.3)'); glowGrad.addColorStop(1, 'rgba(255,255,255,0)'); glowCtx.fillStyle = glowGrad; glowCtx.fillRect(0, 0, 128, 128); const glowTexture = new THREE.CanvasTexture(glowCanvas);
// Equipment details: cylindrical pumps, hoses and valves fill the engineering perimeter.
for (const [x, z] of [[21, 25], [31.5, 22], [10.7, 15]]) { const g = new THREE.Group(); g.position.set(x * T, 0, z * T); cyl(g, 0, .65, 0, .32, 1.3, edge); cyl(g, 0, 1.3, 0, .38, .1, dark); cyl(g, 0, .15, 0, .38, .12, dark); cyl(g, .52, .4, 0, .08, .8, orange, 'x'); const valve = new THREE.Mesh(new THREE.TorusGeometry(.18, .035, 6, 14), orange); valve.position.set(.7, .72, 0); valve.rotation.y = Math.PI / 2; g.add(valve); world.add(g); }
// Batch repeated static legacy geometry so the detailed ship remains inexpensive to draw.
function batchStatic() { world.updateMatrixWorld(true); const skip = new Set([...doors.map(d => d.g), ...pickups.map(p => p.g), extraction]); const bins = new Map(); function visit(o) { if (skip.has(o)) return; if (o.isMesh && !o.isInstancedMesh && !Array.isArray(o.material) && o.geometry === boxGeo || o.isMesh && !o.isInstancedMesh && (o.geometry === cylGeo)) { const key = o.geometry.uuid + o.material.uuid; let b = bins.get(key); if (!b) bins.set(key, b = { geometry: o.geometry, material: o.material, objects: [] }); b.objects.push(o); } else for (const child of [...o.children]) visit(child); } for (const o of [...world.children]) visit(o); for (const b of bins.values()) { if (b.objects.length < 2) continue; const inst = new THREE.InstancedMesh(b.geometry, b.material, b.objects.length); inst.castShadow = b.objects.some(o => o.castShadow); inst.receiveShadow = true; b.objects.forEach((o, i) => { inst.setMatrixAt(i, o.matrixWorld); o.removeFromParent(); }); scene.add(inst); } } batchStatic();

// ---------------------------------------------------------------- post-processing (pass 05)
let composer = null, gtao = null, bloom = null;
function buildComposer() {
  const size = renderer.getDrawingBufferSize(new THREE.Vector2());
  const rt = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, samples: 4 });
  composer = new EffectComposer(renderer, rt);
  composer.addPass(new RenderPass(scene, camera));
  if (!params.has('nogtao')) { gtao = new GTAOPass(scene, camera, size.x, size.y); gtao.updateGtaoMaterial({ radius: .55, distanceExponent: 1.4, thickness: 1.2, scale: 1.1, samples: 12 }); gtao.blendIntensity = .85; composer.addPass(gtao); }
  if (!params.has('nobloom')) { bloom = new UnrealBloomPass(new THREE.Vector2(size.x / 2, size.y / 2), .75, .5, 2.8); composer.addPass(bloom); }
  composer.addPass(new OutputPass());
}
if (QUALITY === 'high') buildComposer();

// ---------------------------------------------------------------- simulation (unchanged rules)
const keys = new Set(), mouse = new THREE.Vector2(.35, .1), raycaster = new THREE.Raycaster(), ground = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0), aimPoint = new THREE.Vector3(); let firing = false, started = false, paused = false, mapOpen = false, ended = false, elapsed = 0, kills = 0, shots = 0, soundOn = true, audio, zoom = 17, noticeTimer = 0, time = 0, visTimer = 0, cameraKick = 0, hitFeedback = 0, camTarget = new THREE.Vector3(17 * T, 0, 15 * T), last = performance.now();
function notify(s) { $('notice').textContent = s; $('notice').style.opacity = 1; noticeTimer = 3; }
function tone(freq, dur = .08, vol = .08, type = 'sine') { if (!audio || !soundOn) return; const o = audio.createOscillator(), g = audio.createGain(); o.type = type; o.frequency.setValueAtTime(freq, audio.currentTime); o.frequency.exponentialRampToValueAtTime(Math.max(20, freq * .4), audio.currentTime + dur); g.gain.setValueAtTime(vol, audio.currentTime); g.gain.exponentialRampToValueAtTime(.001, audio.currentTime + dur); o.connect(g).connect(audio.destination); o.start(); o.stop(audio.currentTime + dur); }
function gunSound(heavy = false) { if (!audio || !soundOn) return; const count = Math.floor(audio.sampleRate * .11), buf = audio.createBuffer(1, count, audio.sampleRate), data = buf.getChannelData(0); for (let i = 0; i < count; i++)data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (count * .19)); const src = audio.createBufferSource(), filter = audio.createBiquadFilter(), gain = audio.createGain(); src.buffer = buf; filter.type = 'lowpass'; filter.frequency.value = heavy ? 1100 : 2400; gain.gain.value = heavy ? .35 : .17; src.connect(filter).connect(gain).connect(audio.destination); src.start(); tone(heavy ? 95 : 160, .08, .09, 'triangle'); }
function cellOpen(x, z) { return grid[Math.round(z / T)]?.[Math.round(x / T)] === 1; }
function blocked(x, z, r = .33, skipDoors = false) { for (const dx of [-r, r]) for (const dz of [-r, r]) if (!cellOpen(x + dx, z + dz)) return true; for (const s of solids) if (Math.abs(x - s.x) < s.w / 2 + r && Math.abs(z - s.z) < s.d / 2 + r) return true; if (!skipDoors) for (const d of doors) if (!d.open && Math.abs(x - d.x) < d.w / 2 + r && Math.abs(z - d.z) < d.d / 2 + r) return true; return false; }
function move(a, dx, dz) { if (!blocked(a.x + dx, a.z)) a.x += dx; if (!blocked(a.x, a.z + dz)) a.z += dz; }
function clearLine(x, z, xx, zz, props = true) { const d = Math.hypot(xx - x, zz - z), steps = Math.ceil(d / .35); for (let i = 1; i < steps; i++) { const px = x + (xx - x) * i / steps, pz = z + (zz - z) * i / steps; if (!cellOpen(px, pz)) return false; for (const a of doors) if (!a.open && Math.abs(px - a.x) < a.w / 2 + .05 && Math.abs(pz - a.z) < a.d / 2 + .05) return false; if (props) for (const a of solids) if (Math.abs(px - a.x) < a.w / 2 && Math.abs(pz - a.z) < a.d / 2) return false; } return true; }
function angleTo(x, z) { return Math.atan2(x, -z); } function angleDiff(a, b) { return Math.atan2(Math.sin(a - b), Math.cos(a - b)); }
function visible(x, z) { const dx = x - player.x, dz = z - player.z, d = Math.hypot(dx, dz); return d < (player.light ? 22 : 11) && (d < 3.4 || Math.abs(angleDiff(angleTo(dx, dz), player.angle)) < (player.light ? 1.05 : .85)) && clearLine(player.x, player.z, x, z); }
function pathTo(a, b) { const sx = Math.round(a.x / T), sz = Math.round(a.z / T), ex = Math.round(b.x / T), ez = Math.round(b.z / T), q = [[sx, sz]], prev = new Map([[`${sx},${sz}`, null]]); let dest = null; for (let k = 0; k < q.length && k < 1200; k++) { const [x, z] = q[k]; if (x === ex && z === ez) { dest = [x, z]; break; } for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, nz = z + dz, key = `${nx},${nz}`; if (grid[nz]?.[nx] && !prev.has(key) && !blocked(nx * T, nz * T, .32)) { prev.set(key, [x, z]); q.push([nx, nz]); } } } if (!dest) return []; const p = []; while (dest) { p.push({ x: dest[0] * T, z: dest[1] * T }); dest = prev.get(`${dest[0]},${dest[1]}`); } p.reverse(); return p.slice(1); }
const sparkGeo = new THREE.BoxGeometry(1, 1, 1);
function spark(x, z, c = 0xf6b35e, num = 7) { for (let i = 0; i < num; i++) { const o = new THREE.Mesh(sparkGeo, new THREE.MeshBasicMaterial({ color: new THREE.Color(c).multiplyScalar(3), transparent: true })); o.scale.set(.035, .035, .18); o.position.set(x, .8, z); const vx = (Math.random() - .5) * 5, vz = (Math.random() - .5) * 5; o.rotation.y = Math.atan2(vx, vz); scene.add(o); particles.push({ o, vx, vz, vy: 2 + Math.random() * 2, life: .3 + Math.random() * .3 }); } }
function trace(x, z, xx, zz, c = 0xffe1a6, y = 1) { const start = new THREE.Vector3(x, y, z), end = new THREE.Vector3(xx, .9, zz), delta = end.clone().sub(start), distance = delta.length(); if (distance < .05) return; const group = new THREE.Group(), geo = new THREE.CylinderGeometry(.014, .014, 1, 5); const core = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: new THREE.Color(c).multiplyScalar(3.5), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); const halo = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: .18, blending: THREE.AdditiveBlending, depthWrite: false })); group.add(core, halo); group.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), delta.clone().normalize()); group.position.copy(start); scene.add(group); traces.push({ o: group, core, halo, geo, start, delta, distance, age: 0, life: Math.max(.065, distance / 260 + .025) }); }
const casingMat = mat('#c6a157', .65, .35);
function muzzleBurst(position, heavy) { const size = heavy ? 1.05 : .65; const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTexture, color: new THREE.Color(0xffb45e).multiplyScalar(4), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); glow.position.copy(position); glow.scale.set(size, size, size); scene.add(glow); particles.push({ o: glow, vx: 0, vz: 0, vy: 0, gravity: 0, life: .055, total: .055 }); const core = sphere(scene, position.x, position.y, position.z, heavy ? .14 : .08, new THREE.MeshBasicMaterial({ color: new THREE.Color(0xfff4bd).multiplyScalar(6), transparent: true })); core.scale.z *= 2.7; core.rotation.y = -player.angle; particles.push({ o: core, vx: 0, vz: 0, vy: 0, gravity: 0, life: .04, total: .04 });
  const casing = new THREE.Mesh(sparkGeo, casingMat.clone()); casing.scale.set(.055, .055, heavy ? .18 : .12); casing.position.copy(position).add(new THREE.Vector3(-Math.sin(player.angle) * .6, 0, Math.cos(player.angle) * .6)); scene.add(casing); particles.push({ o: casing, vx: Math.cos(player.angle) * 2.8, vz: Math.sin(player.angle) * 2.8, vy: 2, life: 1.3, total: 1.3, spin: 12, bounce: true });
  const smoke = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTexture, color: 0x9ca6a3, transparent: true, opacity: .15, depthWrite: false })); smoke.position.copy(position); smoke.scale.setScalar(.35); scene.add(smoke); particles.push({ o: smoke, vx: Math.sin(player.angle) * .6, vz: -Math.cos(player.angle) * .6, vy: .7, gravity: 0, life: .38, total: .38, smoke: true }); }
function killEnemy(e) { e.dead = true; kills++; e.char.playFull('F_Death'); e.char.eyeMaterial.emissiveIntensity = 0; tone(70, .16, .08, 'sawtooth'); }
function fire() { if (player.reload > 0 || player.cooldown > 0 || player.roll > 0 || player.crouch || ended) return; if (player.ammo[player.weapon] <= 0) { reload(); return; } player.ammo[player.weapon]--; shots++; const heavy = player.weapon === 1; player.cooldown = heavy ? .65 : .115; gunSound(heavy); const dx = Math.sin(player.angle), dz = -Math.cos(player.angle); flash.position.set(player.x + dx * 1.4, 1.3, player.z + dz * 1.4); flash.intensity = heavy ? 65 : 38; player.recoil = heavy ? 1.65 : 1; player.char.recoil = player.recoil; cameraKick = heavy ? .18 : .065; player.g.updateMatrixWorld(true); const muzzle = player.char.muzzle.getWorldPosition(new THREE.Vector3()); flash.position.copy(muzzle); muzzleBurst(muzzle, heavy); for (const e of enemies) if (!e.dead && Math.hypot(e.x - player.x, e.z - player.z) < 25) e.alert = 10;
  for (let k = 0; k < (heavy ? 7 : 1); k++) { const a = player.angle + (Math.random() - .5) * (heavy ? .22 : .025), vx = Math.sin(a), vz = -Math.cos(a); let tx = player.x, tz = player.z, hit = null; for (let d = 1; d < 32; d += .18) { tx = player.x + vx * d; tz = player.z + vz * d; if (blocked(tx, tz, .02)) break; hit = enemies.find(e => !e.dead && Math.hypot(e.x - tx, e.z - tz) < .55); if (hit) { hit.hp -= heavy ? 19 : 25; hit.alert = 14; hit.flinch = .2; hit.char.flinch = .2; hitFeedback = .13; tone(heavy ? 180 : 230, .035, .035, 'triangle'); spark(tx, tz, 0xffa559, heavy ? 9 : 7); if (hit.hp <= 0) killEnemy(hit); break; } } trace(muzzle.x, muzzle.z, tx, tz, heavy ? 0xffcf86 : 0xffedbb, muzzle.y); if (!hit) spark(tx, tz, 0xe6b47c, heavy ? 5 : 4); } updateHUD(); }
function beginRoll() { if (player.rollCooldown > 0 || player.roll > 0) return; let x = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0), z = (keys.has('KeyS') ? 1 : 0) - (keys.has('KeyW') ? 1 : 0); if (!x && !z) { player.rollX = Math.sin(player.angle); player.rollZ = -Math.cos(player.angle); } else { const n = Math.hypot(x, z); player.rollX = (x * .924 + z * .383) / n; player.rollZ = (-x * .383 + z * .924) / n; } player.roll = .62; player.rollCooldown = 1.7; player.reload = 0; player.char.stopReload(); player.char.playFull('F_Roll', .62); tone(120, .12, .05); }
function dodging() { return player.roll > .16 && player.roll < .52; }
function coverProtects(e) { if (!player.crouch) return false; const dist = Math.hypot(e.x - player.x, e.z - player.z); if (!dist) return false; for (let d = .3; d < Math.min(2.6, dist); d += .15) { const x = player.x + (e.x - player.x) * d / dist, z = player.z + (e.z - player.z) * d / dist; if (solids.some(a => Math.abs(x - a.x) < a.w / 2 + .16 && Math.abs(z - a.z) < a.d / 2 + .16)) return true; } return false; }
// pass 05: authored clips drive the body; the roll keeps its gameplay timing (.62 s, 7.8 m/s, dodge window)
// and the clip's own pelvis arc keeps the skinned silhouette above the deck (validated in Blender + tests).
function animateOperator(dt, moving) {
  player.rollCooldown = Math.max(0, player.rollCooldown - dt);
  const px = player.x, pz = player.z;
  if (player.roll > 0) {
    player.roll = Math.max(0, player.roll - dt); for (let i = 0; i < 5; i++)move(player, player.rollX * 7.8 * dt / 5, player.rollZ * 7.8 * dt / 5);
    player.g.position.set(player.x, 0, player.z); player.g.rotation.y = -angleTo(player.rollX, player.rollZ);
    if (player.roll === 0) player.char.endFull();
  }
  if (dt > 0) { player.vx = THREE.MathUtils.damp(player.vx, moving ? (player.x - px) / dt : 0, 18, dt); player.vz = THREE.MathUtils.damp(player.vz, moving ? (player.z - pz) / dt : 0, 18, dt); }
  if (player.reload <= 0 && player.char.reloading) player.char.stopReload();
  const facing = player.roll > 0 ? angleTo(player.rollX, player.rollZ) : player.angle;
  player.char.update(dt, { vx: player.roll > 0 ? 0 : player.vx, vz: player.roll > 0 ? 0 : player.vz, facing, crouch: player.crouch, low: false });
  const near = solids.some(a => Math.abs(player.x - a.x) < a.w / 2 + 1.1 && Math.abs(player.z - a.z) < a.d / 2 + 1.1); $('defenseStatus').textContent = player.roll > 0 ? 'EVADING' : player.crouch ? (near ? 'CROUCHED · COVER NEARBY' : 'CROUCHED') : player.rollCooldown > 0 ? 'ROLL RECHARGING' : 'SPACE · ROLL   /   HOLD C · COVER';
}
function reload() { if (player.reload || player.ammo[player.weapon] >= (player.weapon ? 6 : 30) || player.reserve[player.weapon] <= 0) return; player.reload = player.weapon ? 1.9 : 1.45; player.char.playReload(player.reload); tone(320, .06, .06, 'square'); updateHUD(); }
function interact() { const p = pickups.find(p => !p.taken && Math.hypot(p.x - player.x, p.z - player.z) < 2.5); if (p) { p.taken = true; p.g.visible = false; if (p.type === 'recorder') { player.recorder = true; notify('FLIGHT RECORDER SECURED · RETURN TO AIRLOCK'); tone(880, .3, .1); $('objectiveTitle').textContent = 'Return to the boarding airlock'; $('objectiveDesc').textContent = 'Recorder secured. Retrace your route or take the lower maintenance loop.'; $('objectiveStatus').textContent = 'EXTRACTION AVAILABLE · AIRLOCK'; } else if (p.type === 'ammo') { player.reserve[0] += 45; player.reserve[1] += 8; notify('AMMUNITION · +45 RIFLE / +8 SHOTGUN'); tone(550, .12, .08); } else { player.meds++; notify('MEDKIT RECOVERED · PRESS Q TO USE'); tone(660, .12, .08); } updateHUD(); return; }
  if (Math.hypot(player.x - extraction.position.x, player.z - extraction.position.z) < 3) { if (player.recorder) finish(true); else notify('RECOVER THE FLIGHT RECORDER BEFORE EXTRACTING'); return; }
  const d = doors.find(d => Math.hypot(player.x - d.x, player.z - d.z) < 4); if (d) { if (d.open && Math.abs(player.x - d.x) < d.w / 2 + .8 && Math.abs(player.z - d.z) < d.d / 2 + .8) { notify('MOVE CLEAR OF THE BULKHEAD'); return; } d.open = !d.open; tone(d.open ? 160 : 100, .3, .09, 'sawtooth'); } }
function heal() { if (player.meds && player.hp < 100) { player.meds--; player.hp = Math.min(100, player.hp + 50); notify('SUIT PATCH APPLIED · +50 INTEGRITY'); tone(600, .2, .06); updateHUD(); } else notify(player.meds ? 'SUIT INTEGRITY FULL' : 'NO MEDKITS REMAINING'); }
function updateHUD() { $('healthText').textContent = Math.ceil(player.hp) + '%'; $('healthFill').style.width = player.hp + '%'; $('healthFill').style.background = player.hp < 30 ? '#d57654' : '#8bcacb'; $('medText').textContent = 'Q · MEDKIT × ' + player.meds; $('ammo').textContent = String(player.ammo[player.weapon]).padStart(2, '0'); $('reserve').textContent = player.reserve[player.weapon]; $('weaponName').textContent = player.weapon ? 'SG-8 / BREACH SHOTGUN' : 'AR-4 / SERVICE RIFLE'; $('reloadLabel').textContent = player.reload ? 'RELOADING' : player.weapon ? 'PUMP' : 'AUTO'; $('slot1').classList.toggle('selected', !player.weapon); $('slot2').classList.toggle('selected', !!player.weapon); }
function finish(win) { ended = true; firing = false; $('endOverlay').classList.remove('hidden'); $('endLabel').textContent = win ? 'CONTRACT 014 / COMPLETE' : 'OPERATOR SIGNAL LOST'; $('endTitle').innerHTML = win ? 'SIGNAL<br>RECOVERED.' : 'DEAD<br>IN THE WATER.'; $('endDesc').textContent = win ? "You made it back with the Kestrel’s flight recorder." : 'The Kestrel keeps another secret. Try a different approach, watch your ammunition, and use the alternate routes.'; $('endStats').innerHTML = `TIME ABOARD &nbsp; ${formatTime(elapsed)}<br>SECURITY UNITS NEUTRALIZED &nbsp; ${kills} / ${enemies.length}<br>SHOTS FIRED &nbsp; ${shots}`; $('crosshair').style.display = 'none'; document.body.style.cursor = 'default'; tone(win ? 880 : 90, .5, .1); }
function formatTime(s) { return String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(Math.floor(s % 60)).padStart(2, '0'); }
function start() { if (!started) { started = true; try { audio = new (window.AudioContext || window.webkitAudioContext)(); audio.resume(); } catch { } camTarget.set(player.x, 0, player.z); notify('BOARDING COMPLETE · FIND ENGINEERING · M TO VIEW DECK'); } paused = false; resize(); $('overlay').classList.add('hidden'); $('startBtn').textContent = 'RESUME BOARDING ↗'; $('crosshair').style.display = 'block'; document.body.style.cursor = 'none'; updateHUD(); updateVisibility(); }
function togglePause() { if (!started || ended) return; if (mapOpen) { toggleMap(); return; } paused = !paused; $('overlay').classList.toggle('hidden', !paused); $('startBtn').innerHTML = 'RESUME BOARDING <span>↗</span>'; $('crosshair').style.display = paused ? 'none' : 'block'; document.body.style.cursor = paused ? 'default' : 'none'; firing = false; }
function toggleMap() { if (!started || ended) return; mapOpen = !mapOpen; $('mapOverlay').classList.toggle('hidden', !mapOpen); document.body.style.cursor = mapOpen ? 'default' : 'none'; $('crosshair').style.display = mapOpen ? 'none' : 'block'; firing = false; drawMap($('bigmap'), true); }
$('startBtn').onclick = start; $('restartBtn').onclick = () => location.reload(); $('pauseBtn').onclick = togglePause; $('closeMap').onclick = toggleMap;
$('startBtn').disabled = false; $('startBtn').innerHTML = startLabel;
window.addEventListener('keydown', e => { if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(e.code)) e.preventDefault(); keys.add(e.code); if (e.repeat) return; if (e.code === 'Escape') { togglePause(); return; } if (e.code === 'KeyM') { toggleMap(); return; } if (!started || paused || mapOpen || ended) return; if (e.code === 'Space') beginRoll(); if (e.code === 'KeyR') reload(); if (e.code === 'KeyE') interact(); if (e.code === 'KeyQ') heal(); if (e.code === 'KeyF') { player.light = !player.light; notify(player.light ? 'FLASHLIGHT ON' : 'FLASHLIGHT OFF'); } if (e.code === 'Digit1' || e.code === 'Digit2') { player.weapon = e.code === 'Digit1' ? 0 : 1; player.reload = 0; player.char.stopReload(); player.char.setWeapon(player.weapon); tone(250, .06, .04); updateHUD(); } });
window.addEventListener('keyup', e => keys.delete(e.code)); window.addEventListener('blur', () => { keys.clear(); firing = false; if (started && !paused && !ended && !mapOpen) togglePause(); }); window.addEventListener('mousemove', e => { mouse.set(e.clientX / innerWidth * 2 - 1, 1 - e.clientY / innerHeight * 2); $('crosshair').style.left = e.clientX + 'px'; $('crosshair').style.top = e.clientY + 'px'; }); renderer.domElement.addEventListener('mousedown', e => { if (e.button === 0 && started && !paused && !mapOpen && !ended) firing = true; }); window.addEventListener('mouseup', () => firing = false); window.addEventListener('contextmenu', e => e.preventDefault()); window.addEventListener('wheel', e => { zoom = Math.max(12, Math.min(36, zoom + e.deltaY * .02)); resize(); }, { passive: true });
function resize() { const a = innerWidth / innerHeight; const size = started ? zoom : 26; camera.left = -size * a / 2; camera.right = size * a / 2; camera.top = size / 2; camera.bottom = -size / 2; camera.updateProjectionMatrix(); renderer.setSize(innerWidth, innerHeight); if (composer) { const s = renderer.getDrawingBufferSize(new THREE.Vector2()); composer.setSize(innerWidth, innerHeight); gtao?.setSize(s.x, s.y); } } window.addEventListener('resize', resize); resize();
function updateVisibility() { walkCells.forEach((a, i) => { const v = !started || visible(a.x * T, a.z * T); a.visible = v; if (v) a.seen = true; const shade = !started ? .9 : v ? 1 : a.seen ? .34 : .1; const room = roomAt(a.x, a.z); color.set(room?.color || '#8a9aa0').lerp(new THREE.Color(1, 1, 1), .72).multiplyScalar(shade); floors.setColorAt(i, color); }); floors.instanceColor.needsUpdate = true; wallCells.forEach((a, i) => { const d = Math.hypot(a.x * T - player.x, a.z * T - player.z); const seen = !started || cellAt.get(a.cx + ',' + a.cz)?.seen; const shade = !started ? 1 : seen ? (d < 20 ? 1 : .5) : .16; color.setScalar(shade); walls.setColorAt(i, color); }); walls.instanceColor.needsUpdate = true; for (const e of enemies) { if (!e.dead) e.g.visible = !started || visible(e.x, e.z); } for (const p of pickups) { if (!p.taken) p.g.visible = !started || visible(p.x, p.z); } drawMap($('minimap')); }
function drawMap(canvas, big = false) { const g = canvas.getContext('2d'), w = canvas.width, h = canvas.height, s = Math.min((w - 20) / NX, (h - 20) / NZ), ox = (w - NX * s) / 2, oz = (h - NZ * s) / 2; g.clearRect(0, 0, w, h); g.fillStyle = '#08141c'; g.fillRect(0, 0, w, h); for (const a of walkCells) { g.fillStyle = a.visible ? '#48747a' : a.seen ? '#2b454f' : '#172c36'; g.fillRect(ox + (a.x - .45) * s, oz + (a.z - .45) * s, s * .9, s * .9); } for (const d of doors) { g.fillStyle = d.open ? '#629b92' : '#b17c4d'; g.fillRect(ox + (d.x / T - .4) * s, oz + (d.z / T - .4) * s, s * .8, s * .8); } const px = ox + player.x / T * s, pz = oz + player.z / T * s; g.fillStyle = '#b0e7de'; g.beginPath(); g.arc(px, pz, big ? 5 : 2.8, 0, 7); g.fill(); g.strokeStyle = '#9bccc5'; g.lineWidth = big ? 2 : 1; g.beginPath(); g.moveTo(px, pz); g.lineTo(px + Math.sin(player.angle) * s * 2, pz - Math.cos(player.angle) * s * 2); g.stroke(); function dot(x, z, c, label) { const xx = ox + x * s, zz = oz + z * s; g.strokeStyle = c; g.lineWidth = big ? 2 : 1; g.beginPath(); g.arc(xx, zz, big ? 8 : 4, 0, 7); g.stroke(); if (big) { g.fillStyle = c; g.font = '11px Arial'; g.fillText(label, xx + 13, zz + 4); } } if (!player.recorder) dot(25, 23, '#e1a15c', 'FLIGHT RECORDER'); dot(5.5, 27.5, '#88bdb3', 'AIRLOCK'); if (big) { for (const r of rooms) { g.fillStyle = '#a8bbc0'; g.font = '10px Arial'; g.textAlign = 'center'; g.fillText(r.name, ox + (r.x + r.w / 2) * s, oz + (r.z + 1) * s); g.textAlign = 'left'; } } }
function update(dt) { time += dt; flash.intensity = Math.max(0, flash.intensity - dt * 150); player.recoil *= Math.exp(-dt * 15); cameraKick *= Math.exp(-dt * 21); hitFeedback = Math.max(0, hitFeedback - dt); $('crosshair').classList.toggle('hit', hitFeedback > 0); $('crosshair').style.width = (20 + player.recoil * 9) + 'px'; $('crosshair').style.height = (20 + player.recoil * 9) + 'px'; if (noticeTimer > 0) { noticeTimer -= dt; if (noticeTimer <= 0) $('notice').style.opacity = 0; }
  if (started && !paused && !mapOpen && !ended) { elapsed += dt; $('clock').textContent = formatTime(elapsed); raycaster.setFromCamera(mouse, camera); raycaster.ray.intersectPlane(ground, aimPoint); player.angle = angleTo(aimPoint.x - player.x, aimPoint.z - player.z); let dx = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0) - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0), dz = (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0) - (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0); const rawX = dx; dx = dx * .924 + dz * .383; dz = -rawX * .383 + dz * .924; player.crouch = keys.has('KeyC') && player.roll <= 0; const moving = dx || dz, speed = (player.crouch ? .45 : 1) * (keys.has('ShiftLeft') ? 7 : 4.8) * (player.weapon ? .9 : 1); if (player.roll <= 0 && moving) { const len = Math.hypot(dx, dz); move(player, dx / len * speed * dt, dz / len * speed * dt); player.steps += dt * speed; } player.g.position.set(player.x, 0, player.z); player.g.rotation.y = -player.angle; animateOperator(dt, !!moving || player.roll > 0);
    player.cooldown = Math.max(0, player.cooldown - dt); if (player.reload > 0) { player.reload -= dt; if (player.reload <= 0) { player.reload = 0; const w = player.weapon, n = Math.min((w ? 6 : 30) - player.ammo[w], player.reserve[w]); player.ammo[w] += n; player.reserve[w] -= n; tone(430, .08, .05); updateHUD(); } } if (firing) fire();
    for (const e of enemies) { if (e.dead) { e.char.update(dt, { vx: 0, vz: 0, facing: e.angle, dead: true }); continue; } e.cooldown = Math.max(0, e.cooldown - dt); const dist = Math.hypot(player.x - e.x, player.z - e.z), los = dist < 20 && clearLine(e.x, e.z, player.x, player.z); if (los && dist < 14) e.alert = 8; e.alert -= dt; e.px = e.x; e.pz = e.z; if (e.alert > 0) { e.angle = angleTo(player.x - e.x, player.z - e.z); if (dist > 8 || !los) { e.repath -= dt; if (e.repath <= 0) { e.path = pathTo(e, player); e.repath = .8 + rand() * .4; } let target = los ? player : e.path[0]; if (target) { const dd = Math.hypot(target.x - e.x, target.z - e.z); if (dd < .45) e.path.shift(); else move(e, (target.x - e.x) / dd * 2.2 * dt, (target.z - e.z) / dd * 2.2 * dt); } } if (los && dist < 18 && e.cooldown <= 0) { e.cooldown = 1.3 + rand() * .6; const hit = rand() < .6; const m = e.char.muzzle.getWorldPosition(new THREE.Vector3()); trace(m.x, m.z, player.x + (hit ? 0 : (rand() - .5) * 3), player.z + (hit ? 0 : (rand() - .5) * 3), 0xff7356, m.y); e.char.recoil = .8; tone(95, .08, .04, 'sawtooth'); if (hit && !dodging() && !coverProtects(e)) { player.hp = Math.max(0, player.hp - 9); $('damage').style.opacity = .65; spark(player.x, player.z, 0xff7755, 4); updateHUD(); if (player.hp <= 0) finish(false); } } } e.flinch = Math.max(0, (e.flinch || 0) - dt); e.g.position.set(e.x, 0, e.z); e.g.rotation.y = -e.angle; if (e.g.visible || dt === 0) e.char.update(dt, { vx: (e.x - e.px) / Math.max(dt, 1e-4), vz: (e.z - e.pz) / Math.max(dt, 1e-4), facing: e.angle, low: e.alert <= 0 }); }
    let prompt = ''; const p = pickups.find(p => !p.taken && Math.hypot(p.x - player.x, p.z - player.z) < 2.5); if (p) prompt = '[E] ' + (p.type === 'recorder' ? 'RECOVER FLIGHT RECORDER' : p.type === 'med' ? 'TAKE MEDKIT' : 'TAKE AMMUNITION'); else if (Math.hypot(player.x - extraction.position.x, player.z - extraction.position.z) < 3) prompt = player.recorder ? '[E] EXTRACT WITH RECORDER' : 'AIRLOCK · RECOVER RECORDER TO EXTRACT'; else { const d = doors.find(d => Math.hypot(d.x - player.x, d.z - player.z) < 4); if (d) prompt = '[E] ' + (d.open ? 'CLOSE ' : 'OPEN ') + d.name; } $('interaction').style.display = prompt ? 'block' : 'none'; $('interaction').textContent = prompt; const zone = rooms.find(r => player.x / T >= r.x - .5 && player.x / T < r.x + r.w - .5 && player.z / T >= r.z - .5 && player.z / T < r.z + r.h - .5); $('zoneName').textContent = zone?.name || 'TRANSIT CORRIDOR';
    visTimer -= dt; if (visTimer <= 0) { updateVisibility(); updateBeam(); visTimer = .09; }
  }
  for (const d of doors) { d.slide = THREE.MathUtils.damp(d.slide, d.open ? 1 : 0, 7, dt); d.leaf.position.y = -d.slide * 2.36; d.leaf.visible = d.slide < .995; }
  for (const pk of pickups) if (!pk.taken) pk.g.position.y = .02 + Math.sin(time * 2 + pk.x) * .015;
  for (let i = traces.length - 1; i >= 0; i--) { const p = traces[i]; p.age += dt; const head = Math.min(p.distance, p.age * 260), length = Math.min(head, 4.5), fraction = p.distance ? ((head - length * .5) / p.distance) : 0; p.o.position.copy(p.start).addScaledVector(p.delta, fraction); p.core.scale.set(1, length, 1); p.halo.scale.set(5, length, 5); p.core.material.opacity = Math.min(1, Math.max(0, (p.life - p.age) * 35)); p.halo.material.opacity = p.core.material.opacity * .16; if (p.age >= p.life) { scene.remove(p.o); p.geo.dispose(); p.core.material.dispose(); p.halo.material.dispose(); traces.splice(i, 1); } }
  for (let i = particles.length - 1; i >= 0; i--) { const p = particles[i]; p.life -= dt; p.vy -= dt * (p.gravity ?? 12); p.o.position.x += p.vx * dt; p.o.position.z += p.vz * dt; p.o.position.y += p.vy * dt; if (p.o.position.y < .045) { p.o.position.y = .045; p.vy = p.bounce ? Math.abs(p.vy) * .27 : 0; p.vx *= .65; p.vz *= .65; } if (p.spin) { p.o.rotation.x += dt * p.spin; p.o.rotation.z += dt * p.spin * .7; } if (p.smoke) p.o.scale.addScalar(dt * 1.4); p.o.material.opacity = p.smoke ? Math.max(0, p.life / p.total) * .15 : Math.min(1, Math.max(0, p.life / (p.total || .5))); if (p.life <= 0) { scene.remove(p.o); p.o.material.dispose(); particles.splice(i, 1); } }
  $('damage').style.opacity = Math.max(0, parseFloat($('damage').style.opacity || 0) - dt * 1.8); ring.material.opacity = .45 + Math.sin(time * 2) * .2;
  flashlight.intensity = player.light ? 80 : 0; flashlight.position.set(player.x + Math.sin(player.angle) * 1.08, 1.3, player.z - Math.cos(player.angle) * 1.08); flashlight.target.position.set(player.x + Math.sin(player.angle) * 13, 0, player.z - Math.cos(player.angle) * 13);
  dust.position.set(Math.round(camTarget.x / 30) * 30, 0, Math.round(camTarget.z / 30) * 30); dust.rotation.y = time * .01;
  if (!started) { camTarget.set(12.5 * T + Math.sin(time * .07) * 2, 0, 9.5 * T); player.g.visible = false; } else { player.g.visible = true; const desired = new THREE.Vector3(player.x + Math.sin(player.angle) * 1.7, 0, player.z - Math.cos(player.angle) * 1.7); camTarget.lerp(desired, 1 - Math.exp(-dt * 4)); } camera.position.copy(camTarget).add(CAM_OFFSET); camera.lookAt(camTarget); if (cameraKick > .001 && !matchMedia('(prefers-reduced-motion: reduce)').matches) { const kick = new THREE.Vector3(Math.sin(player.angle) * cameraKick, 0, -Math.cos(player.angle) * cameraKick); camera.position.add(kick); camera.lookAt(camTarget.clone().add(kick)); }
  // keep the sun's shadow frustum tight around the view for crisp contact shadows
  sun.position.set(camTarget.x - 14, 40, camTarget.z + 10); sun.target.position.copy(camTarget);
}
function render() { renderer.info.reset(); if (composer) composer.render(); else renderer.render(scene, camera); }
function frame(now) { requestAnimationFrame(frame); const dt = Math.min((now - last) / 1000, .1); last = now; update(dt); render(); } updateHUD(); updateVisibility(); requestAnimationFrame(frame);
// Read-only diagnostics for repeatable engine checks.
window.__deadCircuit = { getState: () => ({ started, paused, ended, quality: QUALITY, player: { x: player.x, z: player.z, hp: player.hp, ammo: [...player.ammo], recorder: player.recorder }, enemies: enemies.map(e => ({ x: e.x, z: e.z, hp: e.hp, dead: e.dead })), floorCells: walkCells.length, drawCalls: renderer.info.render.calls, triangles: renderer.info.render.triangles }), validate: () => ({ objectiveReachable: pathTo(player, { x: 25 * T, z: 23 * T }).length > 0, tiles: walkCells.length, doors: doors.length, spawnsClear: !blocked(player.x, player.z), enemySpawns: enemies.map(e => !blocked(e.x, e.z)) }) };
