// Renders film.html to an MP4 using only the Edge already installed.
//   node record.mjs preview 1.5,9,20     -> preview JPEGs for chosen times
//   node record.mjs frames               -> every frame as a JPEG (30 fps)
//   node record.mjs encode               -> frames + synthesised audio -> MP4
// Work files go to $WORK (default: ./.work). Output: ../dist/Elan-Film.mp4
import { launch } from './cdp.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const work = process.env.WORK || path.join(here, '.work');
const frames = path.join(work, 'frames');
const [mode = 'frames', arg] = process.argv.slice(2);
fs.mkdirSync(frames, { recursive: true });
const udd = path.join(work, 'edge-profile');

const b = await launch({ userDataDir: udd });
try {
  if (mode === 'encode') {
    const meta = JSON.parse(fs.readFileSync(path.join(work, 'film.json'), 'utf8'));
    await b.send('Page.navigate', { url: pathToFileURL(path.join(here, 'encoder.html')).href });
    await b.sleep(1500);
    const dir = pathToFileURL(frames).href;
    console.log(`encoding ${meta.frameCount} frames (${meta.duration.toFixed(1)} s) in real time…`);
    const res = await b.evaluate(`run(${JSON.stringify(dir)}, ${meta.frameCount}, ${JSON.stringify(meta.events)}, ${meta.duration})`);
    console.log('recorded', res);
    const size = 4 * 1024 * 1024, parts = [];
    for (let i = 0; i * size < res.size; i++) parts.push(Buffer.from(await b.evaluate(`readChunk(${i}, ${size})`), 'base64'));
    const out = path.join(here, '..', 'dist', 'Elan-Film.mp4');
    fs.writeFileSync(out, Buffer.concat(parts));
    console.log('wrote', out, (fs.statSync(out).size / 1e6).toFixed(1), 'MB');
  } else {
    await b.send('Page.navigate', { url: pathToFileURL(path.join(here, 'film.html')).href });
    await b.sleep(800);
    await b.evaluate('FILM_READY');
    const duration = await b.evaluate('FILM.DURATION');
    const fps = 30;
    // A headless screenshot can occasionally stall; give each one 15 s, then retry.
    const timeout = (p, ms) => Promise.race([p, new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), ms))]);
    const shot = async (t, file, quality = 90) => {
      for (let attempt = 1; ; attempt++) {
        try {
          await timeout(b.evaluate(`FILM.render(${t})`), 15000);
          const r = await timeout(b.send('Page.captureScreenshot', { format: 'jpeg', quality }), 15000);
          fs.writeFileSync(file, Buffer.from(r.result.data, 'base64'));
          return;
        } catch (e) {
          if (attempt >= 3) throw e;
          console.log(`retrying t=${t} (${e.message})`);
        }
      }
    };
    if (mode === 'preview') {
      for (const t of arg.split(',').map(Number)) await shot(t, path.join(work, `preview_${t}.jpg`), 80);
      console.log('previews in', work);
    } else {
      const frameCount = Math.ceil(duration * fps);
      const started = Date.now();
      for (let i = 0; i < frameCount; i++) {
        // Resumable: frames already on disk are kept (the last one is redone in case it was cut off).
        const file = path.join(frames, `f_${String(i).padStart(5, '0')}.jpg`);
        if (fs.existsSync(file) && fs.existsSync(path.join(frames, `f_${String(i + 1).padStart(5, '0')}.jpg`))) continue;
        await shot(i / fps, path.join(frames, `f_${String(i).padStart(5, '0')}.jpg`));
        if (i % 300 === 0) console.log(`frame ${i}/${frameCount} · ${((Date.now() - started) / 1000).toFixed(0)} s`);
      }
      const events = await b.evaluate('FILM.audioEvents()');
      fs.writeFileSync(path.join(work, 'film.json'), JSON.stringify({ duration, frameCount, fps, events }));
      console.log(`captured ${frameCount} frames in ${((Date.now() - started) / 1000).toFixed(0)} s`);
    }
  }
} finally {
  b.close();
}
