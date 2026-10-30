// Material library: binds the authored texture sets (dist/assets/tex) to named PBR materials.
// Blender exports carry only material NAMES; every asset resolves them here, so one texture
// set is loaded once and shared by characters, kit pieces and props.
import * as THREE from 'three';

const loader = new THREE.TextureLoader();
const cache = new Map();
export let maxAnisotropy = 8;
let TEX_BASE = 'assets/tex/';
export function setTextureBase(b) { TEX_BASE = b; }
export function setAnisotropy(n) { maxAnisotropy = n; }

function tex(path, srgb) {
  const key = path + srgb;
  if (cache.has(key)) return cache.get(key);
  const t = loader.load(path);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = maxAnisotropy;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  cache.set(key, t);
  return t;
}

/** Standard PBR material from a texture set name: albedo (sRGB) + tangent normal + ORM (AO/rough/metal). */
export function pbr(set, opts = {}) {
  const base = TEX_BASE + set;
  const orm = tex(`${base}_orm.jpg`, false);
  const m = new THREE.MeshStandardMaterial({
    map: tex(`${base}_albedo.jpg`, true),
    normalMap: tex(`${base}_normal.jpg`, false),
    normalScale: new THREE.Vector2(opts.normal ?? 1, opts.normal ?? 1),
    aoMap: orm, aoMapIntensity: opts.ao ?? 1,
    roughnessMap: orm, roughness: opts.roughness ?? 1,
    metalnessMap: orm, metalness: opts.metalness ?? 1,
    color: opts.color ?? 0xffffff,
    envMapIntensity: opts.env ?? 1,
  });
  m.name = opts.name || set;
  return m;
}

export function glow(color, intensity = 3, name) {
  const m = new THREE.MeshStandardMaterial({ color: 0x050505, emissive: color, emissiveIntensity: intensity, roughness: .4, metalness: 0 });
  m.name = name || 'glow';
  return m;
}

let lib;
/** Shared named materials. Names match Blender material slots. */
export function library() {
  if (lib) return lib;
  lib = {
    suit_fabric: pbr('suit_fabric'),
    paint_orange: pbr('paint_orange'),
    paint_white: pbr('paint_white'),
    paint_yellow: pbr('paint_yellow'),
    paint_hazard: pbr('paint_hazard'),
    paint_robot: pbr('paint_robot'),
    rubber: pbr('rubber'),
    dark_metal: pbr('dark_metal'),
    floor_plate: pbr('floor_plate'),
    floor_grate: pbr('floor_grate'),
    wall_panel: pbr('wall_panel'),
    wall_med: pbr('wall_med'),
    hull_top: pbr('hull_top'),
    medical_fabric: pbr('medical_fabric'),
    visor: new THREE.MeshPhysicalMaterial({ color: 0x081014, roughness: .12, metalness: .1, clearcoat: .6, clearcoatRoughness: .12, envMapIntensity: .9, name: 'visor' }),
    glass: new THREE.MeshPhysicalMaterial({ color: 0x0d1b20, roughness: .1, metalness: 0, transparent: true, opacity: .55, envMapIntensity: 1.6, name: 'glass' }),
    light_cyan: glow(0x5fe3ff, 7, 'light_cyan'),
    light_amber: glow(0xff8a2a, 7, 'light_amber'),
    light_red: glow(0xff2a16, 8, 'light_red'),
    light_white: glow(0xdff3ff, 6.5, 'light_white'),
    screen_cyan: glow(0x2bc4d6, 1.6, 'screen_cyan'),
  };
  return lib;
}

/** Replace glTF placeholder materials by name (strips Blender ".001" suffixes). */
export function bindMaterials(root, overrides = {}) {
  const L = library();
  root.traverse(o => {
    if (!o.isMesh) return;
    const swap = m => {
      const key = (m.name || '').replace(/\.\d+$/, '');
      return overrides[key] || L[key] || m;
    };
    o.material = Array.isArray(o.material) ? o.material.map(swap) : swap(o.material);
  });
}
