#!/usr/bin/env python3
"""Writes the placeholder sound set to assets/game/audio/, synthesised here. Re-runnable: each sound is
seeded from its own name, so the same script gives the same files. No downloads.

    python3 tools/audio/gen_placeholder_audio.py [--only name,name]
    godot --headless --path . --import

Every file is ph_<cue>.wav (ph = placeholder), mono, 16-bit, peaking at PEAK_DB. Loudness in the game is
data/audio.json's business. To replace one with real audio, drop the new file in and point the cue's
"file" at it; a .ogg works too.
"""
import argparse
import pathlib
import wave
import zlib

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "game" / "audio"
SR = 44100
SR_AMB = 22050
PEAK_DB = -3.0


class Synth:
    """One sound's generators, with its own random numbers."""

    def __init__(self, name, sr=SR):
        self.sr = sr
        self.rng = np.random.default_rng(zlib.crc32(name.encode()))

    def t(self, s):
        return np.arange(int(s * self.sr)) / self.sr

    def noise(self, s):
        return self.rng.uniform(-1.0, 1.0, int(s * self.sr))

    def tone(self, s, hz, shape="sine"):
        """`hz` is a number or an array of the sound's length, for sweeps."""
        n = int(s * self.sr)
        f = np.full(n, float(hz)) if np.isscalar(hz) else np.asarray(hz)[:n]
        ph = np.cumsum(2.0 * np.pi * f / self.sr)
        if shape == "saw":
            return 2.0 * ((ph / (2.0 * np.pi)) % 1.0) - 1.0
        if shape == "square":
            return np.sign(np.sin(ph))
        return np.sin(ph)

    def lowpass(self, x, hz):
        a = 1.0 - np.exp(-2.0 * np.pi * hz / self.sr)
        y = np.empty_like(x)
        v = 0.0
        for i, s in enumerate(x):
            v += a * (s - v)
            y[i] = v
        return y

    def highpass(self, x, hz):
        return x - self.lowpass(x, hz)

    def band(self, x, lo, hi):
        return self.highpass(self.lowpass(x, hi), lo)

    def fall(self, s, per_s):
        return np.exp(-per_s * self.t(s))

    def attack(self, s, attack_s, per_s):
        t = self.t(s)
        return np.minimum(t / max(attack_s, 1e-5), 1.0) * np.exp(-per_s * np.maximum(t - attack_s, 0.0))

    def thump(self, s, hi_hz, lo_hz, per_s, sweep_per_s=30.0):
        t = self.t(s)
        return self.tone(s, lo_hz + (hi_hz - lo_hz) * np.exp(-sweep_per_s * t)) * self.fall(s, per_s)

    def clank(self, s, freqs, per_s, jitter=0.0):
        """Struck metal: unrelated partials, the higher ones dying first."""
        out = np.zeros(int(s * self.sr))
        for i, hz in enumerate(freqs):
            f = hz * (1.0 + self.rng.uniform(-jitter, jitter))
            out += self.tone(s, f) * self.fall(s, per_s * (1.0 + i * 0.5)) / (1.0 + i * 0.4)
        return out

    def burst(self, s, lo, hi, per_s):
        return self.band(self.noise(s), lo, hi) * self.fall(s, per_s)

    def place(self, length_s, *parts):
        """Mixes (at_s, sound) pairs into one array."""
        out = np.zeros(int(length_s * self.sr))
        for at, x in parts:
            i = int(at * self.sr)
            n = min(len(x), len(out) - i)
            if n > 0:
                out[i:i + n] += x[:n]
        return out

    def seamless(self, x, fade_s):
        """A loop with no click: the end fades into the start. Comes back fade_s shorter."""
        n = int(fade_s * self.sr)
        ramp = np.linspace(0.0, 1.0, n)
        head = x[:n] * ramp + x[-n:] * (1.0 - ramp)
        return np.concatenate([head, x[n:-n]])


def fade_out(x, sr, s=0.004):
    n = min(int(s * sr), len(x))
    x = x.copy()
    x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


# --- player ---

def step_deck(y):
    return y.thump(0.16, 170, 80, 34) + 0.35 * y.burst(0.16, 300, 2600, 60) + 0.22 * y.clank(0.16, [640, 1130], 42, 0.03)


def step_grate(y):
    s = 0.24
    a = y.clank(s, [820, 1370, 2210, 3120], 26, 0.04)
    return 0.55 * y.thump(s, 150, 90, 38) + 0.5 * a + 0.3 * y.place(s, (0.035, y.clank(0.2, [1020, 1880], 40, 0.04)))


def step_wet(y):
    s = 0.26
    t = y.t(s)
    slap = y.burst(s, 500, 4500, 22)
    plip = y.tone(s, 480 + 900 * t / s) * y.attack(s, 0.03, 30)
    return 0.45 * y.thump(s, 120, 70, 36) + 0.5 * slap + 0.3 * y.place(s, (0.05, plip))


def crouch_rustle(y):
    s = 0.34
    env = y.attack(s, 0.05, 11) * (0.7 + 0.3 * np.sin(2.0 * np.pi * 21.0 * y.t(s)))
    return y.band(y.noise(s), 900, 5200) * env + 0.25 * y.thump(s, 110, 70, 30)


def suit_breath(y):
    """One breath, in and out through a rebreather: a little plastic, a little valve."""
    length = 3.6
    t = y.t(length)
    air = y.noise(length)
    inhale = np.clip(np.sin(np.pi * np.clip(t / 1.35, 0.0, 1.0)), 0.0, 1.0) ** 1.6
    exhale = np.clip(np.sin(np.pi * np.clip((t - 1.55) / 1.7, 0.0, 1.0)), 0.0, 1.0) ** 1.8
    x = y.band(air, 1400, 5200) * inhale + 0.8 * y.band(air, 420, 1900) * exhale
    valve = y.clank(0.07, [2300, 3100], 90)
    return x + y.place(length, (1.38, 0.12 * valve), (3.28, 0.08 * valve))


def pickup_small(y):
    return y.clank(0.16, [1700, 2600, 3900], 40, 0.02) + 0.5 * y.burst(0.16, 1500, 6000, 55)


def pickup_medium(y):
    s = 0.36
    return 0.8 * y.thump(s, 170, 90, 16) + 0.45 * y.clank(s, [410, 760, 1240], 18, 0.03) + 0.25 * y.band(y.noise(s), 700, 3000) * y.attack(s, 0.06, 12)


def pickup_heavy(y):
    s = 0.62
    strain = y.tone(s, 62 + 22 * y.t(s) / s, "saw")
    return 0.65 * y.lowpass(strain, 400) * y.attack(s, 0.1, 5) + 0.7 * y.clank(s, [190, 320, 545], 9, 0.02) + 0.5 * y.place(s, (0.3, y.thump(0.3, 120, 60, 18)))


def drop_small(y):
    s = 0.22
    return y.clank(s, [2100, 3300], 28, 0.03) + 0.7 * y.place(s, (0.07, y.clank(0.14, [2500, 3600], 45, 0.03)))


def drop_medium(y):
    s = 0.42
    return y.thump(s, 210, 70, 15) + 0.4 * y.clank(s, [340, 690, 1090], 17, 0.03) + 0.3 * y.burst(s, 300, 3000, 28)


def drop_heavy(y):
    """A loud thud: the stalkers hear this one too, and so should you."""
    s = 1.0
    boom = y.thump(s, 150, 42, 6.5, 20)
    ring = y.clank(s, [118, 233, 371, 612], 6, 0.02)
    return boom + 0.45 * ring + 0.55 * y.burst(s, 150, 2600, 22) + 0.3 * y.place(s, (0.16, y.thump(0.5, 110, 50, 14)))


# --- weapons ---

def _rifle_body(y, punch_hz, crack_per_s, mid_per_s):
    """The punch of the shot and nothing else: the action and the room are their own layers."""
    s = 0.34
    crack = y.band(y.noise(s), 900, 11000) * y.fall(s, crack_per_s)
    body = y.thump(s, punch_hz, 64, 24, 55)
    mid = y.band(y.noise(s), 180, 1400) * y.fall(s, mid_per_s)
    return 1.15 * crack + 1.2 * body + 0.8 * mid


def rifle_body_1(y):
    return _rifle_body(y, 260, 75, 30)


def rifle_body_2(y):
    return _rifle_body(y, 240, 85, 34)


def rifle_body_3(y):
    return _rifle_body(y, 285, 68, 28)


def rifle_body_4(y):
    return _rifle_body(y, 225, 80, 36)


def rifle_body_5(y):
    return _rifle_body(y, 270, 92, 26)


def rifle_mech(y):
    """The action: bolt back and home, close to the gun."""
    s = 0.09
    return y.place(s, (0.0, y.clank(0.05, [1900, 3100, 4700], 90, 0.02)), (0.04, 0.8 * y.clank(0.05, [1400, 2500, 3900], 100, 0.02)))


def rifle_mech_bright(y):
    """The last five rounds: the same action, thinner and higher, as the magazine spring runs out."""
    s = 0.09
    return y.place(s, (0.0, y.clank(0.05, [3300, 5200, 7400], 95, 0.02)), (0.035, 0.7 * y.clank(0.05, [2800, 4400, 6600], 110, 0.02)))


def rifle_thump(y):
    """Felt more than heard: only your own gun has this."""
    s = 0.16
    return y.thump(s, 90, 42, 24, 40)


def _tail(y, s, lo, hi, attack_s, per_s, slaps):
    wash = y.band(y.noise(s), lo, hi) * y.attack(s, attack_s, per_s)
    hits = [(at, g * y.burst(0.12, lo, hi, 40)) for at, g in slaps]
    return wash + y.place(s, *hits)


def tail_slap(y):
    """A corridor: a short hard slap off the walls."""
    return _tail(y, 0.35, 300, 3200, 0.008, 16, [(0.03, 0.9), (0.075, 0.5)])


def tail_room(y):
    """A medbay: a medium room with soft walls."""
    return _tail(y, 0.7, 200, 2400, 0.02, 8, [(0.05, 0.4), (0.12, 0.25)])


def tail_hold(y):
    """A cargo hold: long and boomy."""
    return _tail(y, 1.5, 70, 1100, 0.05, 3.2, [(0.09, 0.3), (0.21, 0.2)]) + 0.5 * y.thump(1.5, 80, 50, 4, 8)


def rifle_dry(y):
    """A hard click."""
    s = 0.12
    return y.clank(s, [2400, 3700, 5200], 80, 0.02) + 0.4 * y.burst(s, 2000, 9000, 110)


def rifle_dry_tail(y):
    """The nothing after the click: a breath of room, with no shot in it."""
    s = 0.22
    return 0.5 * y.band(y.noise(s), 400, 2200) * y.attack(s, 0.01, 22)


def rifle_mag_out(y):
    s = 0.34
    slide = y.band(y.noise(s), 1200, 6000) * y.attack(s, 0.04, 16)
    return y.clank(s, [980, 1650, 2750], 45, 0.02) + 0.45 * slide + 0.3 * y.place(s, (0.2, y.clank(0.14, [1400, 2300], 50, 0.02)))


def rifle_mag_in(y):
    s = 0.24
    return 0.6 * y.place(s, (0.0, y.burst(0.08, 1000, 5000, 60))) + y.place(s, (0.05, y.clank(0.19, [720, 1480, 2900], 36, 0.02) + 0.6 * y.thump(0.19, 180, 100, 40)))


def rifle_charge(y):
    s = 0.36
    back = y.clank(0.16, [1260, 2240, 3480], 50, 0.02) + 0.4 * y.burst(0.16, 1800, 7000, 50)
    home = y.clank(0.2, [860, 1720, 2960], 34, 0.02) + 0.6 * y.thump(0.2, 200, 110, 34)
    return y.place(s, (0.0, 0.8 * back), (0.15, home))


def _tink(y, freqs, per_s):
    s = 0.14
    return y.clank(s, freqs, per_s, 0.04)


def tink_deck_1(y):
    return _tink(y, [4300, 6200, 8100], 34)


def tink_deck_2(y):
    return _tink(y, [4700, 6600, 8900], 38)


def tink_deck_3(y):
    return _tink(y, [3900, 5800, 7600], 30)


def tink_grate_1(y):
    """Rattly: the casing chatters on the bars."""
    s = 0.2
    t = lambda: _tink(y, [2900, 4400], 60)
    return y.place(s, (0.0, t()), (0.04, 0.6 * t()), (0.08, 0.4 * t()))


def tink_grate_2(y):
    s = 0.2
    t = lambda: _tink(y, [3300, 4900], 60)
    return y.place(s, (0.0, t()), (0.03, 0.7 * t()), (0.1, 0.3 * t()))


def tink_wet_1(y):
    s = 0.12
    return 0.7 * _tink(y, [2300, 3100], 70)[:int(s * y.sr)] + 0.4 * y.burst(s, 600, 2800, 45)


def tink_wet_2(y):
    s = 0.12
    return 0.7 * _tink(y, [2600, 3500], 70)[:int(s * y.sr)] + 0.4 * y.burst(s, 500, 2400, 45)


def mag_clatter_deck(y):
    s = 0.42
    hit = lambda g: g * (y.clank(0.2, [820, 1560, 2700], 30, 0.03) + 0.5 * y.thump(0.2, 200, 110, 30))
    return y.place(s, (0.0, hit(1.0)), (0.13, hit(0.55)), (0.22, hit(0.3)))


def mag_clatter_grate(y):
    s = 0.5
    hit = lambda g: g * (y.clank(0.16, [1100, 2100, 3300], 40, 0.03) + 0.3 * y.burst(0.16, 1500, 6000, 40))
    return y.place(s, (0.0, hit(1.0)), (0.07, hit(0.7)), (0.14, hit(0.5)), (0.24, hit(0.3)), (0.31, hit(0.2)))


def mag_clatter_wet(y):
    s = 0.36
    return y.clank(s, [640, 1200], 26, 0.03) + 0.6 * y.burst(s, 500, 2600, 18)


# --- impacts ---

def _ping(y, freqs, per_s):
    s = 0.22
    return y.clank(s, freqs, per_s, 0.03) + 0.5 * y.burst(s, 1800, 9000, 70)


def impact_metal_1(y):
    return _ping(y, [1800, 3100, 5200], 32)


def impact_metal_2(y):
    return _ping(y, [1300, 2500, 4100], 42)


def impact_metal_3(y):
    """More thunk than ping."""
    s = 0.22
    return 0.8 * y.clank(s, [620, 1180, 2100], 44, 0.03) + 0.7 * y.thump(s, 240, 110, 36) + 0.4 * y.burst(s, 1200, 6000, 80)


def _whine(y, hi, lo):
    s = 0.55
    f = lo + (hi - lo) * np.exp(-5.0 * y.t(s))
    return y.tone(s, f) * y.attack(s, 0.006, 7) + 0.25 * y.burst(s, 2000, 9000, 30)


def ricochet_1(y):
    return _whine(y, 5200, 1800)


def ricochet_2(y):
    return _whine(y, 3900, 1300)


def _crack(y, lo, hi, per_s, snap_hz):
    s = 0.16
    return y.burst(s, lo, hi, per_s) + 0.6 * y.clank(s, [snap_hz, snap_hz * 1.7], 90, 0.04)


def impact_panel_1(y):
    return _crack(y, 700, 6000, 60, 1600)


def impact_panel_2(y):
    return _crack(y, 900, 7000, 70, 2100)


def impact_panel_3(y):
    return _crack(y, 500, 5000, 50, 1300)


def impact_glass_1(y):
    return _crack(y, 2500, 11000, 80, 4600)


def impact_glass_2(y):
    return _crack(y, 3000, 12000, 95, 5600)


def _wet(y, lo, hi):
    s = 0.2
    return y.burst(s, lo, hi, 26) + 0.8 * y.thump(s, 170, 80, 30)


def impact_wet_1(y):
    return _wet(y, 300, 2600)


def impact_wet_2(y):
    return _wet(y, 240, 2100)


def impact_flesh_1(y):
    s = 0.16
    return 0.7 * y.burst(s, 200, 1600, 40) + y.thump(s, 150, 70, 38)


def impact_flesh_2(y):
    s = 0.16
    return 0.7 * y.burst(s, 160, 1300, 44) + y.thump(s, 130, 62, 40)


def grunt_1(y):
    """A man who's been shot, on the placeholder budget: a buzzed vowel falling away."""
    s = 0.26
    f = 150 - 40 * y.t(s) / s
    return y.band(y.tone(s, f, "saw"), 200, 1500) * y.attack(s, 0.015, 9)


def grunt_2(y):
    s = 0.22
    f = 175 - 55 * y.t(s) / s
    return y.band(y.tone(s, f, "saw"), 240, 1700) * y.attack(s, 0.012, 11)


def impact_chew(y):
    """Cover coming apart: heavier, under the surface's own hit."""
    s = 0.24
    return y.thump(s, 190, 80, 24) + 0.9 * y.burst(s, 300, 3400, 28)


# --- environment effects ---

def env_buzz(y):
    """A shorted panel: mains buzz that loops."""
    s = 1.2
    x = y.tone(s, 120, "saw") * 0.5 + y.tone(s, 240, "square") * 0.14 + 0.2 * y.band(y.noise(s), 1800, 7000)
    return y.band(x, 90, 4500)


def env_crackle(y):
    s = 0.3
    hits = [(y.rng.uniform(0.0, 0.2), y.rng.uniform(0.3, 1.0) * y.burst(0.08, 2000, 11000, 90)) for _ in range(7)]
    return y.place(s, *hits)


def env_hiss(y):
    """Steam from a broken pipe: loops; the jet's pulse is the game's."""
    s = 2.0 + 0.15
    return y.seamless(y.band(y.noise(s), 1800, 11000), 0.15)


def env_fire(y):
    s = 3.0 + 0.2
    roar = y.band(y.noise(s), 60, 520)
    pops = [(y.rng.uniform(0.0, s - 0.1), y.rng.uniform(0.2, 0.9) * y.burst(0.06, 1200, 7000, 90)) for _ in range(26)]
    return y.seamless(0.6 * roar + y.place(s, *pops), 0.2)


def env_sizzle(y):
    s = 2.5 + 0.2
    fizz = y.band(y.noise(s), 2600, 9000) * (0.6 + 0.4 * np.sin(2.0 * np.pi * 3.0 * y.t(s)))
    pops = [(y.rng.uniform(0.0, s - 0.1), y.rng.uniform(0.3, 1.0) * y.burst(0.05, 500, 2400, 80)) for _ in range(12)]
    return y.seamless(0.5 * fizz + y.place(s, *pops), 0.2)


def explosion_near(y):
    s = 1.8
    boom = y.thump(s, 150, 34, 3.4, 16)
    crack = y.band(y.noise(s), 400, 9000) * y.fall(s, 12)
    rumble = y.band(y.noise(s), 40, 400) * y.attack(s, 0.02, 3)
    return 1.3 * boom + 0.9 * crack + 0.9 * rumble


def explosion_far(y):
    s = 1.8
    boom = y.thump(s, 90, 30, 3.0, 12)
    rumble = y.band(y.noise(s), 30, 260) * y.attack(s, 0.06, 2.4)
    return boom + rumble


# --- stalker ---

def stalker_click(y):
    s = 0.2
    one = lambda: y.band(y.noise(0.03), 1800, 8000) * y.fall(0.03, 170)
    return y.place(s, (0.0, one()), (0.06, 0.8 * one()), (0.11, one()))


def stalker_chirp(y):
    s = 0.3
    t = y.t(s)
    f = 1500 + 1100 * np.sin(2.0 * np.pi * 7.0 * t) + 900 * t / s
    return y.tone(s, f, "saw") * y.attack(s, 0.02, 12) * (0.6 + 0.4 * np.sign(np.sin(2.0 * np.pi * 42.0 * t)))


def stalker_spit_windup(y):
    """As long as the wind-up in data/enemies.json: rising to the moment it throws."""
    s = 0.42
    t = y.t(s)
    swell = np.minimum(t / s, 1.0) ** 1.5
    hiss = y.highpass(y.noise(s), 2800)
    gargle = y.tone(s, 150 + 240 * t / s, "saw") * (0.5 + 0.5 * np.sin(2.0 * np.pi * 31.0 * t))
    return (hiss + 0.28 * y.lowpass(gargle, 1500)) * swell * np.minimum((s - t) / 0.012, 1.0)


def stalker_spit(y):
    s = 0.26
    return y.burst(s, 500, 5000, 20) + 0.8 * y.thump(s, 420, 120, 24, 45)


def stalker_lunge(y):
    s = 0.6
    t = y.t(s)
    f = 700 + 2500 * np.minimum(t / 0.2, 1.0) - 900 * np.maximum(t - 0.2, 0.0)
    scream = y.tone(s, f, "saw") + 0.7 * y.tone(s, f * 1.46, "saw")
    rough = 0.6 + 0.4 * np.sin(2.0 * np.pi * 63.0 * t)
    return (y.band(scream, 500, 6000) + 0.4 * y.highpass(y.noise(s), 2000)) * y.attack(s, 0.025, 4.5) * rough


def stalker_hit(y):
    s = 0.24
    wet = y.burst(s, 300, 3800, 20)
    yelp = y.tone(s, 1500 - 2400 * y.t(s), "saw") * y.attack(s, 0.01, 18)
    return 0.8 * wet + 0.35 * y.band(yelp, 400, 5000) + 0.5 * y.thump(s, 200, 90, 30)


def stalker_death(y):
    s = 1.0
    t = y.t(s)
    f = 1600 * np.exp(-2.6 * t) + 90
    wail = y.tone(s, f, "saw") * (0.6 + 0.4 * np.sin(2.0 * np.pi * (46.0 - 20.0 * t) * t))
    fall = y.place(s, (0.68, y.thump(0.3, 150, 70, 22) + 0.5 * y.burst(0.3, 300, 2600, 24)))
    return y.band(wail, 200, 5000) * y.attack(s, 0.015, 3.6) + 0.8 * fall


def stalker_scuttle(y):
    """In the walls: claws on duct metal, boxed in and hollow."""
    s = 1.3
    parts = []
    at = 0.0
    while at < s - 0.1:
        parts.append((at, y.clank(0.06, [1500, 2600, 3500], 90, 0.15) * y.rng.uniform(0.35, 1.0)))
        at += y.rng.uniform(0.035, 0.11)
    x = y.place(s, *parts)
    swell = np.sin(np.pi * y.t(s) / s) ** 0.6
    return y.band(x, 500, 3400) * swell + 0.14 * y.band(y.noise(s), 180, 620) * swell


def stalker_bash(y):
    s = 0.7
    return y.thump(s, 150, 48, 9, 25) + 0.75 * y.clank(s, [162, 287, 513, 846], 9, 0.03) + 0.4 * y.burst(s, 200, 3000, 24)


def bulkhead_burst(y):
    s = 1.3
    return y.thump(s, 170, 38, 4.5, 16) + 0.8 * y.clank(s, [140, 262, 437, 790], 6, 0.03) + 0.9 * y.burst(s, 120, 5000, 8) \
        + 0.3 * y.place(s, (0.45, y.clank(0.4, [1200, 1900], 20, 0.05)), (0.7, y.clank(0.4, [1500, 2300], 24, 0.05)))


# --- CUSTODIAN ---

def cutter_warm(y):
    """A steady hum that loops. The rise is the cutter's: the game lifts its pitch with the ring."""
    s = 1.0 + 0.1
    base = 220.0
    x = y.tone(s, base, "saw") + 0.6 * y.tone(s, base * 2.0) + 0.3 * y.tone(s, base * 3.01)
    wob = 0.85 + 0.15 * np.sin(2.0 * np.pi * 10.0 * y.t(s))
    return y.seamless(y.lowpass(x, 2400) * wob, 0.1)


def cutter_burn(y):
    s = 0.5
    t = y.t(s)
    tear = y.tone(s, 118 + 25 * np.sin(2.0 * np.pi * 61.0 * t), "saw")
    hiss = y.highpass(y.noise(s), 1800)
    env = np.minimum(t / 0.006, 1.0) * np.minimum((s - t) / 0.13, 1.0)
    return (y.lowpass(tear, 3200) + 0.5 * hiss + 0.5 * y.tone(s, 59)) * env


def drone_chirp(y):
    """Two blips. The game lifts the pitch for each bar it fills."""
    s = 0.22
    blip = lambda hz: y.tone(0.08, hz) * y.attack(0.08, 0.004, 24) + 0.3 * y.tone(0.08, hz * 2.0, "square") * y.fall(0.08, 50)
    return y.place(s, (0.0, blip(1020)), (0.11, blip(1360)))


def custodian_chime(y):
    """A calm two-note company chime: the airport, not the alarm."""
    s = 1.05
    note = lambda hz, l: (y.tone(l, hz) + 0.3 * y.tone(l, hz * 2.0) + 0.12 * y.tone(l, hz * 3.0)) * y.attack(l, 0.012, 4.2)
    return y.place(s, (0.0, note(784.0, 0.9)), (0.2, 0.9 * note(1046.5, 0.85)))


# --- ship ---

def amb_medbay(y):
    """Clean and high: mains hum, a fridge's whine, faint ventilation."""
    s = 12.5
    t = y.t(s)
    drift = 0.88 + 0.12 * np.sin(2.0 * np.pi * t / 5.0)
    x = 0.5 * y.tone(s, 120.0) + 0.5 * y.tone(s, 240.0) + 0.32 * y.tone(s, 960.0) * drift + 0.2 * y.tone(s, 1442.0) * (1.0 - 0.4 * np.sin(2.0 * np.pi * t / 2.5))
    return y.seamless(x + 0.42 * y.band(y.noise(s), 1200, 5000), 0.5)


def amb_cargo(y):
    """Low machinery, turning over slowly, with something in it that knocks now and then."""
    s = 12.5
    t = y.t(s)
    turn = 0.72 + 0.28 * np.sin(2.0 * np.pi * t / 0.8)
    x = (y.tone(s, 41.0, "saw") + 0.7 * y.tone(s, 55.0, "saw")) * turn
    low = y.lowpass(x, 240)
    rumble = y.band(y.noise(s), 40, 300)
    knocks = [(at, 0.35 * y.clank(0.5, [150, 268, 410], 14, 0.05)) for at in (1.7, 5.3, 6.1, 9.4)]
    return y.seamless(low + 0.8 * rumble + 0.8 * y.place(s, *knocks), 0.5)


def amb_junction(y):
    """Moving air: a big duct with the fan a long way off."""
    s = 12.5
    t = y.t(s)
    gust = 0.76 + 0.24 * np.sin(2.0 * np.pi * t / 6.25 + 1.0) * np.sin(2.0 * np.pi * t / 2.5)
    air = y.band(y.noise(s), 220, 1700)
    return y.seamless(air * gust + 0.3 * y.lowpass(y.tone(s, 72.0, "saw"), 300), 0.5)


def door_open(y):
    s = 0.9
    t = y.t(s)
    servo = y.lowpass(y.tone(s, 150 + 90 * np.minimum(t / 0.55, 1.0), "saw"), 1500)
    env = np.minimum(t / 0.05, 1.0) * np.clip((0.7 - t) / 0.12, 0.0, 1.0)
    air = y.band(y.noise(s), 1500, 6000) * y.fall(s, 12)
    return servo * env * 0.7 + 0.5 * air + y.place(s, (0.0, 0.5 * y.clank(0.14, [720, 1320], 36, 0.02)), (0.62, 0.8 * y.thump(0.24, 180, 90, 24)))


def door_close(y):
    s = 0.95
    t = y.t(s)
    servo = y.lowpass(y.tone(s, 240 - 90 * np.minimum(t / 0.55, 1.0), "saw"), 1500)
    env = np.minimum(t / 0.05, 1.0) * np.clip((0.62 - t) / 0.08, 0.0, 1.0)
    shut = y.thump(0.32, 150, 56, 16, 25) + 0.5 * y.clank(0.32, [310, 620, 1040], 16, 0.02)
    return servo * env * 0.65 + y.place(s, (0.6, shut))


def door_locked(y):
    s = 0.5
    t = y.t(s)
    gate = np.minimum(t / 0.01, 1.0) * ((t % 0.25) < 0.17)
    return y.lowpass(y.tone(s, 118.0, "square"), 2200) * gate


def door_break(y):
    s = 1.4
    tear = y.place(s, (0.0, y.clank(0.6, [210, 370, 690, 1140], 7, 0.05)), (0.09, 0.8 * y.clank(0.6, [1540, 2300], 9, 0.05)))
    fall = y.place(s, (0.38, y.thump(0.9, 130, 40, 7, 18) + 0.6 * y.clank(0.9, [165, 303, 570], 9, 0.03)))
    return y.thump(s, 170, 44, 7, 25) + tear + y.burst(s, 180, 4000, 9) + fall


def lights_fail(y):
    s = 2.3
    t = y.t(s)
    clunk = y.thump(0.5, 130, 46, 12, 26) + 0.8 * y.clank(0.5, [240, 430, 700], 12, 0.03)
    stutter = (np.sin(2.0 * np.pi * 7.3 * t + 2.0 * np.sin(2.0 * np.pi * 2.1 * t)) > -0.2)
    buzz = y.band(y.tone(s, 120.0, "saw"), 200, 6000) * stutter * np.exp(-1.1 * t)
    # Down the line, one more breaker goes.
    return y.place(s, (0.0, clunk)) + 0.55 * buzz + 0.5 * y.place(s, (1.55, y.thump(0.4, 110, 50, 15)))


def alarm_siren(y):
    """Two sweeps, as long as it needs to loop."""
    s = 1.4
    t = y.t(s)
    phase = (t % 1.4) / 0.7
    sweep = np.where(phase < 1.0, phase, 2.0 - phase)
    f = 480.0 + 400.0 * sweep
    x = y.tone(s, f) + 0.5 * y.tone(s, f * 2.0, "saw") * 0.5 + 0.2 * y.tone(s, f * 1.5)
    return y.lowpass(x, 3800)


def oxygen_warning(y):
    s = 0.72
    beep = lambda: (y.tone(0.2, 880.0) + 0.5 * y.tone(0.2, 1320.0)) * np.minimum(y.t(0.2) / 0.006, 1.0) * np.minimum((0.2 - y.t(0.2)) / 0.02, 1.0)
    return y.place(s, (0.0, beep()), (0.26, beep()), (0.52, beep()))


# --- UI ---

def stamp_accept(y):
    s = 0.34
    return y.thump(s, 240, 70, 24, 60) + 0.75 * y.burst(s, 500, 5500, 42) + 0.3 * y.clank(s, [340, 780], 30, 0.02)


def stamp_acknowledge(y):
    s = 0.44
    one = lambda: y.thump(0.24, 200, 80, 30, 60) + 0.7 * y.burst(0.24, 600, 5500, 52)
    return y.place(s, (0.0, 0.7 * one()), (0.15, one()))


def ledger_tick(y):
    s = 0.05
    return y.clank(s, [2900, 4400], 140, 0.02) + 0.5 * y.burst(s, 2000, 8000, 170)


SOUNDS = {
    "player": [step_deck, step_grate, step_wet, crouch_rustle, (suit_breath, SR_AMB), pickup_small, pickup_medium,
            pickup_heavy, drop_small, drop_medium, drop_heavy],
    "weapons": [rifle_body_1, rifle_body_2, rifle_body_3, rifle_body_4, rifle_body_5, rifle_mech, rifle_mech_bright, rifle_thump,
                tail_slap, tail_room, tail_hold, rifle_dry, rifle_dry_tail, rifle_mag_out, rifle_mag_in, rifle_charge,
                tink_deck_1, tink_deck_2, tink_deck_3, tink_grate_1, tink_grate_2, tink_wet_1, tink_wet_2,
                mag_clatter_deck, mag_clatter_grate, mag_clatter_wet],
    "impacts": [impact_metal_1, impact_metal_2, impact_metal_3, ricochet_1, ricochet_2, impact_panel_1, impact_panel_2, impact_panel_3,
                impact_glass_1, impact_glass_2, impact_wet_1, impact_wet_2, impact_flesh_1, impact_flesh_2, grunt_1, grunt_2, impact_chew],
    "effects": [env_buzz, env_crackle, env_hiss, env_fire, env_sizzle, explosion_near, explosion_far],
    "stalker": [stalker_click, stalker_chirp, stalker_spit_windup, stalker_spit, stalker_lunge, stalker_hit,
            stalker_death, stalker_scuttle, stalker_bash, bulkhead_burst],
    "custodian": [cutter_warm, cutter_burn, drone_chirp, custodian_chime],
    "ship": [(amb_medbay, SR_AMB), (amb_cargo, SR_AMB), (amb_junction, SR_AMB), door_open, door_close, door_locked,
            door_break, lights_fail, alarm_siren, oxygen_warning],
    "ui": [stamp_accept, stamp_acknowledge, ledger_tick],
}
LOOPS = {env_buzz, env_hiss, env_fire, env_sizzle, suit_breath, amb_medbay, amb_cargo, amb_junction, cutter_warm, alarm_siren}


def write_wav(path, x, sr):
    x = x - np.mean(x)
    x = x * (10.0 ** (PEAK_DB / 20.0)) / max(np.max(np.abs(x)), 1e-6)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--only", default="", help="comma-separated sound names")
    only = {n for n in ap.parse_args().only.split(",") if n}
    made = 0
    for group, entries in SOUNDS.items():
        (OUT / group).mkdir(parents=True, exist_ok=True)
        for entry in entries:
            fn, sr = entry if isinstance(entry, tuple) else (entry, SR)
            if only and fn.__name__ not in only:
                continue
            x = fn(Synth(fn.__name__, sr))
            if fn not in LOOPS:
                x = fade_out(x, sr)
            path = OUT / group / f"ph_{fn.__name__}.wav"
            write_wav(path, x, sr)
            made += 1
            print(f"{path.relative_to(ROOT)}  {len(x) / sr:5.2f} s")
    print(f"{made} placeholder sounds")


if __name__ == "__main__":
    main()
