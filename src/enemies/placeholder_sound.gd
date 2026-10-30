extends RefCounted
## Placeholder bangs and spits: decaying noise over a low tone, made once from
## data/enemies.json "sound". Real sound is a later packet.


static func make(spec: Dictionary, mix_rate: int) -> AudioStreamWAV:
	var n := int(float(spec.length_s) * mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	var low := float(spec.low_share)
	for i in n:
		var t := float(i) / mix_rate
		var v := lerpf(rng.randf_range(-1.0, 1.0), sin(TAU * float(spec.low_hz) * t), low)
		v *= exp(-float(spec.decay_per_s) * t)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = mix_rate
	w.data = bytes
	return w
