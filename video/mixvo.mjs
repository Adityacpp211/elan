// Assembles the narration clips (from voiceover.ps1) into one WAV that lines
// up with dist/Elan-Film.mp4 when both start at 0:00.
//   node mixvo.mjs <clips dir> [out.wav]
import fs from 'node:fs';
import path from 'node:path';

const dir = process.argv[2] || path.join(import.meta.dirname, '.work', 'vo');
const outFile = process.argv[3] || path.join(import.meta.dirname, '..', 'dist', 'Elan-Film-Voiceover.wav');
const SR = 48000, LENGTH = 123.55;   // the MP4's duration in seconds

// The film starts slightly into the MP4 (the recorder's lead-in), measured from
// two scene cuts: film 7.0 s → MP4 7.78 s, film 95.3 s → MP4 96.15 s.
const toMp4 = t => t + 0.78 + (0.85 - 0.78) * (t - 7.0) / (95.3 - 7.0);

function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, fmt, data;
  while (p < b.length) {
    const id = b.toString('ascii', p, p + 4), size = b.readUInt32LE(p + 4);
    if (id === 'fmt ') fmt = { ch: b.readUInt16LE(p + 10), sr: b.readUInt32LE(p + 12), bits: b.readUInt16LE(p + 22) };
    if (id === 'data') data = b.subarray(p + 8, p + 8 + size);
    p += 8 + size + (size & 1);
  }
  if (fmt.sr !== SR || fmt.bits !== 16 || fmt.ch !== 1) throw new Error(`${file}: expected 48 kHz 16-bit mono`);
  const s = new Float32Array(data.length / 2);
  for (let i = 0; i < s.length; i++) s[i] = data.readInt16LE(i * 2) / 32768;
  return s;
}

const clips = JSON.parse(fs.readFileSync(path.join(dir, 'clips.json'), 'utf8').replace(/^﻿/, ''));
const mix = new Float32Array(Math.ceil(LENGTH * SR));
let prevEnd = 0;
for (const c of clips) {
  const s = readWav(path.join(dir, path.basename(c.file)));
  // trim the synthesiser's leading/trailing silence
  let a = 0, z = s.length - 1;
  while (a < z && Math.abs(s[a]) < 0.003) a++;
  while (z > a && Math.abs(s[z]) < 0.003) z--;
  const clip = s.subarray(Math.max(0, a - 480), Math.min(s.length, z + 2400));
  // never overlap the previous line: keep at least 0.2 s between lines
  let start = toMp4(c.t);
  if (start < prevEnd + 0.2) { console.log(`line at ${c.t}s nudged +${(prevEnd + 0.2 - start).toFixed(2)}s`); start = prevEnd + 0.2; }
  const off = Math.round(start * SR), fade = 480;
  for (let i = 0; i < clip.length && off + i < mix.length; i++) {
    const g = Math.min(1, i / fade, (clip.length - i) / fade);
    mix[off + i] += clip[i] * g;
  }
  prevEnd = start + clip.length / SR;
}

// gentle high-pass (removes rumble), then normalise to -1 dBFS
let y = 0, xPrev = 0; const k = Math.exp(-2 * Math.PI * 80 / SR);
for (let i = 0; i < mix.length; i++) { const x = mix[i]; y = k * (y + x - xPrev); xPrev = x; mix[i] = y; }
let peak = 0; for (const v of mix) peak = Math.max(peak, Math.abs(v));
const gain = 0.89 / peak;

// write 48 kHz 16-bit stereo WAV
const n = mix.length, buf = Buffer.alloc(44 + n * 4);
buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 4, 4); buf.write('WAVE', 8);
buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34);
buf.write('data', 36); buf.writeUInt32LE(n * 4, 40);
for (let i = 0; i < n; i++) {
  const v = Math.max(-1, Math.min(1, mix[i] * gain)) * 32767 | 0;
  buf.writeInt16LE(v, 44 + i * 4); buf.writeInt16LE(v, 46 + i * 4);
}
fs.writeFileSync(outFile, buf);
console.log(`wrote ${outFile} · ${clips.length} lines · ${LENGTH}s · ${(buf.length / 1e6).toFixed(1)} MB`);
