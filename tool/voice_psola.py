"""TD-PSOLA sederhana: ubah kontur nada vokal "Maa" tanpa mengubah durasi.

Pakai: python -I psola.py in.wav out.wav
Kontur target: nada sumber awal dipertahankan sampai 40% durasi, lalu naik
linear ke +RISE semitone di akhir.
"""
import math
import struct
import sys
import wave

RISE_ST = 1.7
HOLD = 0.40


def read(path):
    w = wave.open(path)
    sr, n = w.getframerate(), w.getnframes()
    x = list(struct.unpack('<%dh' % n, w.readframes(n)))
    return sr, [v / 32768 for v in x]


def write(path, sr, y):
    peak = max(1e-9, max(abs(v) for v in y))
    g = min(1.0, 0.95 / peak)
    w = wave.open(path, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(struct.pack('<%dh' % len(y), *[int(max(-1, min(1, v * g)) * 32767) for v in y]))
    w.close()


def f0_at(x, sr, center, lo=180, hi=380):
    win = int(sr * 0.03)
    a = max(0, center - win // 2)
    seg = x[a:a + win]
    if len(seg) < win:
        return None
    best, lag = -1, None
    for L in range(int(sr / hi), int(sr / lo)):
        c = sum(seg[j] * seg[j + L] for j in range(0, len(seg) - L, 2))
        if c > best:
            best, lag = c, L
    return sr / lag if lag else None


def main(src, dst):
    sr, x = read(src)
    n = len(x)
    # Nada sumber per 10 ms (diisi ke depan bila gagal).
    step = int(sr * 0.01)
    f0s, last = [], 276.0
    for c in range(0, n, step):
        f = f0_at(x, sr, c) or last
        f0s.append(f)
        last = f

    def f_src(i):
        return f0s[min(len(f0s) - 1, i // step)]

    # Penanda periode di sumber: puncak lokal tiap periode.
    marks = []
    i = int(sr * 0.005)
    while i < n - 1:
        p = int(sr / f_src(i))
        a, b = max(0, i - p // 4), min(n, i + p // 4)
        j = max(range(a, b), key=lambda k: x[k])
        marks.append(j)
        i = j + p
    base = f0s[2] if len(f0s) > 2 else 276.0

    def f_target(t):
        u = t / n
        if u < HOLD:
            return base
        k = (u - HOLD) / (1 - HOLD)
        k = k * k * (3 - 2 * k)  # smoothstep: naik halus
        return base * 2 ** (RISE_ST * k / 12)

    y = [0.0] * (n + 2000)
    t = marks[0]
    while t < n:
        # Penanda sumber terdekat dengan waktu keluaran (durasi tetap).
        m = min(marks, key=lambda q: abs(q - t))
        p = int(sr / f_src(m))
        for k in range(-p, p):
            s = m + k
            if 0 <= s < n:
                hw = 0.5 * (1 + math.cos(math.pi * k / p))
                y[t + k] += x[s] * hw
        t += int(sr / f_target(t))
    write(dst, sr, y[:n])


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
