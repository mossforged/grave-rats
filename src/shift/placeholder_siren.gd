extends RefCounted
## A placeholder siren: a sine swept between two pitches, looped or not, until real sound.


static func make(spec: Dictionary, mix_rate: int, looped: bool) -> AudioStreamWAV:
	var n := int(float(spec.length_s) * mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / mix_rate
		var sweep := pingpong(t / float(spec.sweep_s), 1.0)
		phase += TAU * lerpf(float(spec.low_hz), float(spec.high_hz), sweep) / mix_rate
		bytes.encode_s16(i * 2, int(sin(phase) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = mix_rate
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w
