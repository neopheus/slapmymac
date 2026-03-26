#!/usr/bin/env python3
"""Generate sound effects for SlapMyMac sound packs using synthesis."""

import wave, struct, math, random, os, subprocess, sys

SR = 44100
SOUNDS_DIR = os.path.join(os.path.dirname(__file__), "..", "Sources", "SlapMyMac", "Resources", "Sounds")

random.seed(42)  # Reproducible

# ── Primitives ──────────────────────────────────────────────

def to_wav(samples, path):
    with wave.open(path, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b''.join(
            struct.pack('<h', int(max(-32767, min(32767, s * 32767))))
            for s in samples
        ))

def to_mp3(wav_path, mp3_path):
    subprocess.run(
        ['ffmpeg', '-y', '-i', wav_path, '-codec:a', 'libmp3lame', '-b:a', '192k', '-ar', '44100', mp3_path],
        capture_output=True
    )
    os.remove(wav_path)

def save(folder, index, samples, name=""):
    d = os.path.join(SOUNDS_DIR, folder)
    os.makedirs(d, exist_ok=True)
    # Normalize to 0.9 peak
    peak = max((abs(s) for s in samples), default=1.0)
    if peak > 0:
        samples = [s * 0.9 / peak for s in samples]
    wav = os.path.join(d, f"{index:02d}.wav")
    mp3 = os.path.join(d, f"{index:02d}.mp3")
    to_wav(samples, wav)
    to_mp3(wav, mp3)
    tag = f" ({name})" if name else ""
    print(f"  ✓ {folder}/{index:02d}.mp3{tag}")

def n_samples(dur):
    return int(SR * dur)

# ── DSP building blocks ────────────────────────────────────

def silence(dur):
    return [0.0] * n_samples(dur)

def noise(dur):
    return [random.uniform(-1, 1) for _ in range(n_samples(dur))]

def sine(freq, dur, phase=0.0):
    return [math.sin(2 * math.pi * freq * t / SR + phase) for t in range(n_samples(dur))]

def square(freq, dur):
    return [1.0 if math.sin(2 * math.pi * freq * t / SR) > 0 else -1.0 for t in range(n_samples(dur))]

def saw(freq, dur):
    return [2.0 * ((freq * t / SR) % 1.0) - 1.0 for t in range(n_samples(dur))]

def sweep(f0, f1, dur):
    n = n_samples(dur)
    out, phase = [], 0.0
    for t in range(n):
        freq = f0 + (f1 - f0) * t / n
        phase += 2 * math.pi * freq / SR
        out.append(math.sin(phase))
    return out

def fm_synth(carrier, mod_freq, mod_depth, dur):
    return [math.sin(2*math.pi*carrier*t/SR + mod_depth*math.sin(2*math.pi*mod_freq*t/SR))
            for t in range(n_samples(dur))]

def env_ad(samples, attack=0.003, decay=None):
    """Attack-decay envelope."""
    if decay is None:
        decay = len(samples) / SR - attack
    n = len(samples)
    a_n = min(int(SR * attack), n)
    d_n = min(int(SR * decay), n - a_n)
    out = list(samples)
    for i in range(a_n):
        out[i] *= i / max(1, a_n)
    for i in range(d_n):
        idx = a_n + i
        if idx < n:
            out[idx] *= 1.0 - i / max(1, d_n)
    for i in range(a_n + d_n, n):
        out[i] = 0.0
    return out

def env_exp(samples, attack=0.002, decay_rate=5.0):
    """Exponential decay envelope."""
    n = len(samples)
    a_n = int(SR * attack)
    out = list(samples)
    for i in range(min(a_n, n)):
        out[i] *= i / max(1, a_n)
    for i in range(a_n, n):
        out[i] *= math.exp(-decay_rate * (i - a_n) / SR)
    return out

def highpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / SR
    a = rc / (rc + dt)
    out = [samples[0]]
    for i in range(1, len(samples)):
        out.append(a * (out[-1] + samples[i] - samples[i-1]))
    return out

def lowpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / SR
    a = dt / (rc + dt)
    out = [samples[0]]
    for i in range(1, len(samples)):
        out.append(out[-1] + a * (samples[i] - out[-1]))
    return out

def bandpass(samples, low, high):
    return highpass(lowpass(samples, high), low)

def mix(*tracks):
    max_len = max(len(t) for t in tracks)
    out = [0.0] * max_len
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max((abs(s) for s in out), default=1.0)
    if peak > 1.0:
        out = [s / peak for s in out]
    return out

def scale(samples, vol):
    return [s * vol for s in samples]

def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out

def reverb_simple(samples, delay=0.05, feedback=0.3, n_taps=4):
    """Simple multi-tap delay for reverb-like effect."""
    out = list(samples)
    for tap in range(1, n_taps + 1):
        d = int(SR * delay * tap)
        gain = feedback ** tap
        for i in range(d, len(out)):
            out[i] += samples[i - d] * gain if i - d < len(samples) else 0
    peak = max((abs(s) for s in out), default=1.0)
    if peak > 1.0:
        out = [s / peak for s in out]
    return out

def distort(samples, amount=2.0):
    """Soft clipping distortion."""
    return [math.tanh(s * amount) for s in samples]

def ring_mod(samples, freq):
    return [s * math.sin(2*math.pi*freq*t/SR) for t, s in enumerate(samples)]

# ── Sound generators per pack ──────────────────────────────

def gen_whip():
    print("🔊 Whip")
    variants = [
        (2000, 0.15, 8.0),
        (2500, 0.20, 6.0),
        (3000, 0.12, 10.0),
        (1800, 0.25, 5.0),
        (3500, 0.10, 12.0),
        (2200, 0.18, 7.0),
        (4000, 0.08, 15.0),
        (1500, 0.30, 4.0),
    ]
    for i, (hp_freq, dur, decay) in enumerate(variants):
        n = noise(dur)
        s = highpass(n, hp_freq)
        s = env_exp(s, attack=0.001, decay_rate=decay)
        # Add a subtle low "thwack"
        thwack = env_exp(sine(120, dur), attack=0.001, decay_rate=20.0)
        s = mix(scale(s, 0.8), scale(thwack, 0.3))
        save("Whip", i, s, f"crack {i+1}")

def gen_cartoon():
    print("🔊 Cartoon")
    # 00: Bonk (low thump)
    s = env_exp(sine(100, 0.3), decay_rate=8.0)
    s = mix(s, scale(env_exp(noise(0.3), decay_rate=15.0), 0.3))
    save("Cartoon", 0, s, "bonk")

    # 01: Boing (spring)
    s = env_exp(sweep(200, 1200, 0.5), attack=0.001, decay_rate=3.0)
    save("Cartoon", 1, s, "boing")

    # 02: Splat
    s = env_exp(lowpass(noise(0.4), 800), decay_rate=4.0)
    s = mix(s, scale(env_exp(sine(80, 0.2), decay_rate=10.0), 0.5))
    save("Cartoon", 2, s, "splat")

    # 03: Ding
    s = env_exp(sine(1200, 1.0), decay_rate=2.0)
    s = mix(s, scale(env_exp(sine(2400, 1.0), decay_rate=3.0), 0.4))
    s = mix(s, scale(env_exp(sine(3600, 1.0), decay_rate=4.0), 0.2))
    save("Cartoon", 3, s, "ding")

    # 04: Pop
    s = env_exp(sine(600, 0.1), attack=0.0005, decay_rate=30.0)
    save("Cartoon", 4, s, "pop")

    # 05: Slide whistle up
    s = env_ad(sweep(300, 3000, 0.4), attack=0.01, decay=0.39)
    save("Cartoon", 5, s, "whistle up")

    # 06: Slide whistle down
    s = env_ad(sweep(3000, 300, 0.5), attack=0.01, decay=0.49)
    save("Cartoon", 6, s, "whistle down")

    # 07: Wobble
    s = [math.sin(2*math.pi*400*t/SR + 4*math.sin(2*math.pi*8*t/SR)) for t in range(n_samples(0.6))]
    s = env_exp(s, decay_rate=2.5)
    save("Cartoon", 7, s, "wobble")

    # 08: Honk
    s = env_exp(distort(sine(120, 0.4), 3.0), decay_rate=4.0)
    save("Cartoon", 8, s, "honk")

    # 09: Boing 2 (deeper spring)
    s = env_exp(sweep(80, 600, 0.6), decay_rate=2.5)
    save("Cartoon", 9, s, "boing deep")

def gen_kungfu():
    print("🔊 Kung Fu")
    # 00: Punch
    s = mix(
        env_exp(sweep(200, 60, 0.15), decay_rate=12.0),
        scale(env_exp(bandpass(noise(0.15), 200, 2000), decay_rate=10.0), 0.5)
    )
    save("KungFu", 0, s, "punch")

    # 01: Hard punch
    s = mix(
        env_exp(sweep(250, 40, 0.2), decay_rate=8.0),
        scale(env_exp(bandpass(noise(0.2), 100, 3000), decay_rate=8.0), 0.6)
    )
    save("KungFu", 1, s, "hard punch")

    # 02: Kick
    s = mix(
        env_exp(sweep(150, 30, 0.25), decay_rate=6.0),
        scale(env_exp(lowpass(noise(0.25), 500), decay_rate=8.0), 0.4)
    )
    save("KungFu", 2, s, "kick")

    # 03: Chop
    s = mix(
        env_exp(sweep(800, 200, 0.08), attack=0.001, decay_rate=20.0),
        scale(env_exp(highpass(noise(0.1), 1000), decay_rate=15.0), 0.7)
    )
    save("KungFu", 3, s, "chop")

    # 04: Block / parry
    s = env_exp(bandpass(noise(0.12), 500, 4000), attack=0.001, decay_rate=12.0)
    s = mix(s, scale(env_exp(sine(300, 0.12), decay_rate=15.0), 0.4))
    save("KungFu", 4, s, "block")

    # 05: Slap
    s = mix(
        env_exp(highpass(noise(0.1), 1500), decay_rate=18.0),
        scale(env_exp(sine(180, 0.1), decay_rate=15.0), 0.3)
    )
    save("KungFu", 5, s, "slap")

    # 06: Body blow
    s = mix(
        env_exp(sweep(120, 35, 0.3), decay_rate=5.0),
        scale(env_exp(lowpass(noise(0.3), 400), decay_rate=6.0), 0.5)
    )
    s = reverb_simple(s, delay=0.03, feedback=0.2)
    save("KungFu", 6, s, "body blow")

    # 07: Flying kick (sweep + impact)
    whoosh = env_ad(highpass(noise(0.3), 800), attack=0.2, decay=0.1)
    impact = env_exp(sweep(200, 50, 0.15), decay_rate=10.0)
    s = concat(whoosh, impact)
    save("KungFu", 7, s, "flying kick")

def gen_drum():
    print("🔊 Drum")
    # 00: Kick
    s = mix(
        env_exp(sweep(180, 40, 0.3), decay_rate=6.0),
        scale(env_exp(lowpass(noise(0.1), 300), decay_rate=20.0), 0.3)
    )
    save("Drum", 0, s, "kick")

    # 01: Snare
    s = mix(
        env_exp(sine(200, 0.2), decay_rate=10.0),
        scale(env_exp(highpass(noise(0.2), 1000), decay_rate=8.0), 0.8)
    )
    save("Drum", 1, s, "snare")

    # 02: Hi-hat closed
    s = env_exp(highpass(noise(0.06), 5000), attack=0.0005, decay_rate=30.0)
    save("Drum", 2, s, "hi-hat closed")

    # 03: Hi-hat open
    s = env_exp(highpass(noise(0.3), 4000), attack=0.001, decay_rate=5.0)
    save("Drum", 3, s, "hi-hat open")

    # 04: Crash
    s = env_exp(highpass(noise(1.5), 2000), attack=0.002, decay_rate=1.5)
    s = mix(s, scale(env_exp(sine(300, 1.5), decay_rate=3.0), 0.2))
    save("Drum", 4, s, "crash")

    # 05: Tom high
    s = env_exp(sweep(300, 150, 0.3), decay_rate=5.0)
    s = mix(s, scale(env_exp(lowpass(noise(0.1), 800), decay_rate=15.0), 0.2))
    save("Drum", 5, s, "tom high")

    # 06: Tom mid
    s = env_exp(sweep(200, 100, 0.35), decay_rate=4.5)
    s = mix(s, scale(env_exp(lowpass(noise(0.1), 600), decay_rate=15.0), 0.2))
    save("Drum", 6, s, "tom mid")

    # 07: Tom low
    s = env_exp(sweep(140, 60, 0.4), decay_rate=4.0)
    s = mix(s, scale(env_exp(lowpass(noise(0.1), 400), decay_rate=15.0), 0.2))
    save("Drum", 7, s, "tom low")

    # 08: Rimshot
    click = env_exp(bandpass(noise(0.02), 2000, 8000), decay_rate=50.0)
    tone = env_exp(sine(800, 0.15), decay_rate=12.0)
    s = mix(scale(click, 0.8), scale(tone, 0.5))
    save("Drum", 8, s, "rimshot")

    # 09: Clap
    layers = []
    for j in range(4):
        offset = [0.0] * int(SR * 0.008 * j)
        layer = offset + env_exp(bandpass(noise(0.08), 1000, 5000), decay_rate=15.0)
        layers.append(layer)
    s = mix(*layers)
    save("Drum", 9, s, "clap")

def gen_cat():
    print("🔊 Cat (escalating)")
    # Escalation: quiet mew → loud angry meow
    configs = [
        # (carrier_start, carrier_end, mod_freq, mod_depth, duration, vol, name)
        (600, 500, 5, 2, 0.3, 0.4, "tiny mew"),
        (650, 550, 6, 2.5, 0.35, 0.5, "soft mew"),
        (700, 500, 5, 3, 0.5, 0.6, "mew"),
        (800, 500, 4, 3.5, 0.6, 0.65, "meow"),
        (900, 450, 4, 4, 0.7, 0.7, "meow!"),
        (1000, 400, 3, 5, 0.8, 0.8, "MEOW"),
        (1100, 350, 3, 6, 0.9, 0.85, "MEOW!"),
        (1200, 300, 2.5, 7, 1.2, 1.0, "MREOOOW!"),
    ]
    for i, (f0, f1, mf, md, dur, vol, name) in enumerate(configs):
        n = n_samples(dur)
        s = []
        for t in range(n):
            frac = t / n
            # Pitch contour: rise then fall
            freq = f0 + (f1 - f0) * (1 - math.sin(math.pi * frac))
            # FM synthesis for "vocal" quality
            mod = md * math.sin(2 * math.pi * mf * t / SR)
            # Add vibrato
            vibrato = 0.02 * freq * math.sin(2 * math.pi * 6 * t / SR)
            sample = math.sin(2 * math.pi * (freq + vibrato) * t / SR + mod)
            # Add harmonics for "nasal" quality
            sample += 0.4 * math.sin(2 * math.pi * (freq * 2 + vibrato) * t / SR + mod * 1.5)
            sample += 0.2 * math.sin(2 * math.pi * (freq * 3) * t / SR + mod * 0.5)
            s.append(sample)
        # Envelope: quick attack, sustain, decay
        s = env_ad(s, attack=0.02, decay=dur * 0.3)
        # Add breathiness
        breath = scale(bandpass(noise(dur), 800, 3000), 0.1 * vol)
        s = mix(scale(s, vol), breath)
        save("Cat", i, s, name)

def gen_glass():
    print("🔊 Glass (escalating)")
    # 00-01: Tiny tinkle
    for i in range(2):
        freqs = [2000 + i * 500, 3500 + i * 300, 5000]
        layers = [scale(env_exp(sine(f, 0.5), decay_rate=4.0 + i), 1.0 / len(freqs)) for f in freqs]
        s = mix(*layers)
        s = reverb_simple(s, delay=0.02, feedback=0.3)
        save("Glass", i, s, f"tinkle {i+1}")

    # 02-03: Small crack
    for i in range(2):
        crack = env_exp(highpass(noise(0.15), 3000), decay_rate=12.0 - i * 2)
        ring = env_exp(sine(1500 + i * 500, 0.4), decay_rate=5.0)
        s = mix(scale(crack, 0.7), scale(ring, 0.5))
        s = reverb_simple(s, delay=0.015, feedback=0.25)
        save("Glass", 2 + i, s, f"crack {i+1}")

    # 04-05: Medium break
    for i in range(2):
        impact = env_exp(noise(0.3 + i * 0.1), decay_rate=4.0 - i)
        impact = highpass(impact, 1500)
        ring_freqs = [1200, 2400, 3600, 4800]
        rings = [scale(env_exp(sine(f, 0.5), decay_rate=3.0), 0.15) for f in ring_freqs]
        s = mix(scale(impact, 0.6), *rings)
        s = reverb_simple(s, delay=0.025, feedback=0.3)
        save("Glass", 4 + i, s, f"break {i+1}")

    # 06-07: Full shatter
    for i in range(2):
        dur = 0.8 + i * 0.4
        # Initial impact
        impact = env_exp(noise(0.05), decay_rate=30.0)
        # Cascade of fragments
        fragments = []
        for j in range(8 + i * 4):
            delay_samples = [0.0] * int(SR * random.uniform(0.01, 0.15))
            frag_dur = random.uniform(0.1, 0.3)
            freq = random.uniform(2000, 6000)
            frag = delay_samples + env_exp(
                mix(
                    highpass(noise(frag_dur), 2000),
                    scale(sine(freq, frag_dur), 0.3)
                ),
                decay_rate=random.uniform(5.0, 15.0)
            )
            fragments.append(scale(frag, random.uniform(0.1, 0.4)))
        # Pad all to same length
        max_len = max(len(f) for f in fragments)
        max_len = max(max_len, len(impact))
        padded = []
        for f in [impact] + fragments:
            padded.append(f + [0.0] * (max_len - len(f)))
        s = mix(*padded)
        s = reverb_simple(s, delay=0.02, feedback=0.35)
        save("Glass", 6 + i, s, f"shatter {i+1}")

def gen_eightbit():
    print("🔊 8-Bit")
    # 00: Hit
    s = env_exp(square(220, 0.15), decay_rate=12.0)
    save("8Bit", 0, s, "hit")

    # 01: Jump
    s = sweep(150, 600, 0.12)
    s = [1.0 if x > 0 else -1.0 for x in s]  # Quantize to square
    s = env_ad(s, attack=0.001, decay=0.11)
    save("8Bit", 1, s, "jump")

    # 02: Coin
    s = env_exp(square(988, 0.08), decay_rate=15.0)
    s2 = [0.0] * int(SR * 0.08) + env_exp(square(1319, 0.15), decay_rate=8.0)
    s = s + [0.0] * (len(s2) - len(s)) if len(s) < len(s2) else s
    s2 = s2 + [0.0] * (len(s) - len(s2)) if len(s2) < len(s) else s2
    s = mix(s, s2)
    save("8Bit", 2, s, "coin")

    # 03: Explosion
    s = lowpass(noise(0.5), 600)
    s = env_exp(s, decay_rate=3.0)
    s = distort(s, 2.0)
    save("8Bit", 3, s, "explosion")

    # 04: Laser
    s = sweep(3000, 100, 0.2)
    s = [1.0 if x > 0 else -1.0 for x in s]
    s = env_ad(s, attack=0.001, decay=0.19)
    save("8Bit", 4, s, "laser")

    # 05: Power up
    notes = [262, 330, 392, 523]
    parts = []
    for note in notes:
        parts.extend(env_ad(square(note, 0.1), attack=0.002, decay=0.08))
    save("8Bit", 5, parts, "power up")

    # 06: Game over (descending)
    notes = [523, 392, 330, 262, 196]
    parts = []
    for note in notes:
        parts.extend(env_ad(square(note, 0.2), attack=0.002, decay=0.18))
    save("8Bit", 6, parts, "game over")

    # 07: Damage
    s = env_exp(square(110, 0.2), decay_rate=6.0)
    s = mix(s, scale(env_exp(lowpass(noise(0.2), 1000), decay_rate=8.0), 0.4))
    save("8Bit", 7, s, "damage")

    # 08: Blip
    s = env_exp(square(660, 0.05), decay_rate=40.0)
    save("8Bit", 8, s, "blip")

    # 09: Death
    n = n_samples(0.8)
    s = []
    for t in range(n):
        freq = 400 * math.exp(-3.0 * t / n)
        s.append(1.0 if math.sin(2*math.pi*freq*t/SR) > 0 else -1.0)
    s = env_ad(s, attack=0.001, decay=0.7)
    save("8Bit", 9, s, "death")

def gen_thunder():
    print("🔊 Thunder")
    for i in range(6):
        dur = 1.5 + i * 0.3
        # Low rumble (brown noise)
        rumble = lowpass(noise(dur), 150 + i * 20)
        rumble = env_ad(rumble, attack=0.1 + i * 0.05, decay=dur * 0.6)

        # Crack at start (for later variants)
        if i >= 2:
            crack_dur = 0.05 + i * 0.01
            crack = env_exp(bandpass(noise(crack_dur), 500, 5000), decay_rate=20.0)
            crack = crack + [0.0] * (len(rumble) - len(crack))
            rumble = mix(scale(rumble, 0.6), scale(crack, 0.8))

        # Add some mid-frequency content
        mid = lowpass(highpass(noise(dur), 100), 800)
        mid = env_ad(mid, attack=0.05, decay=dur * 0.5)

        s = mix(scale(rumble, 0.7), scale(mid, 0.3))
        s = reverb_simple(s, delay=0.08, feedback=0.4, n_taps=6)
        save("Thunder", i, s, f"thunder {i+1}")

def gen_wwe():
    print("🔊 WWE")
    # Body impacts with "crowd" noise
    for i in range(8):
        # Impact
        impact_dur = 0.15 + i * 0.02
        impact = mix(
            env_exp(sweep(200 - i * 10, 40, impact_dur), decay_rate=8.0),
            scale(env_exp(bandpass(noise(impact_dur), 200, 2000), decay_rate=10.0), 0.5)
        )
        impact = reverb_simple(impact, delay=0.04, feedback=0.3)

        # "Crowd" (filtered noise swell)
        crowd_dur = 0.6 + i * 0.1
        crowd = bandpass(noise(crowd_dur), 300, 3000)
        # Swell up then down
        n = len(crowd)
        for t in range(n):
            frac = t / n
            # Bell curve envelope
            crowd[t] *= math.exp(-8 * (frac - 0.3) ** 2)
        crowd = scale(crowd, 0.25 + i * 0.03)

        # Pad impact to crowd length
        impact = impact + [0.0] * max(0, len(crowd) - len(impact))
        crowd = crowd + [0.0] * max(0, len(impact) - len(crowd))
        s = mix(scale(impact, 0.7), scale(crowd, 0.4))
        names = ["jab", "cross", "hook", "uppercut", "body slam", "suplex", "powerbomb", "finisher"]
        save("WWE", i, s, names[i])

def gen_metal():
    print("🔊 Metal")
    configs = [
        # (base_freq, n_harmonics, decay, detune, name)
        (80, 8, 2.0, 1.01, "gong"),
        (120, 6, 2.5, 1.015, "gong deep"),
        (200, 5, 3.0, 1.005, "bell"),
        (350, 4, 4.0, 1.02, "clang"),
        (500, 4, 5.0, 1.03, "clang high"),
        (150, 7, 1.5, 1.008, "anvil"),
        (90, 10, 1.8, 1.012, "sheet metal"),
        (250, 6, 3.5, 1.025, "pipe"),
    ]
    for i, (base, n_harm, decay, detune, name) in enumerate(configs):
        dur = 2.0 if decay < 3 else 1.5
        layers = []
        for h in range(1, n_harm + 1):
            freq = base * h * (detune ** (h - 1))
            harmonic = env_exp(sine(freq, dur), decay_rate=decay * h * 0.4)
            layers.append(scale(harmonic, 1.0 / (h * 0.7)))
        # Add attack transient
        transient = env_exp(highpass(noise(0.02), 2000), decay_rate=80.0)
        layers.append(scale(transient + [0.0] * (n_samples(dur) - n_samples(0.02)), 0.5))

        s = mix(*layers)
        s = reverb_simple(s, delay=0.03, feedback=0.35, n_taps=5)
        save("Metal", i, s, name)

# ── Main ────────────────────────────────────────────────────

if __name__ == "__main__":
    print(f"Generating sounds in: {SOUNDS_DIR}\n")
    gen_whip()
    gen_cartoon()
    gen_kungfu()
    gen_drum()
    gen_cat()
    gen_glass()
    gen_eightbit()
    gen_thunder()
    gen_wwe()
    gen_metal()
    print("\n✅ Done! All sound packs generated.")
