// Builds the download page into the directory given as the first argument (default ../../_site):
// site/ at the root, the README gif, and the cat scene from web/ under cat/ as the live demo.
// Only index.html and the scripts it loads are copied from web/: the demo never opens the
// settings or 今日小结 windows.
// Usage: node tools/site/build.js [out]
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const web = path.join(root, 'web');
const out = path.resolve(process.argv[2] || path.join(root, '_site'));

fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(path.join(root, 'site'), out, { recursive: true });
fs.copyFileSync(path.join(root, 'assets/keycat.gif'), path.join(out, 'keycat.gif'));

const html = fs.readFileSync(path.join(web, 'index.html'), 'utf8');
const scripts = [...html.matchAll(/<script src="([^"]+)"><\/script>/g)].map(m => m[1]);
const cat = path.join(out, 'cat');
fs.mkdirSync(cat);
for (const name of ['index.html', 'THREE_LICENSE', ...scripts]) fs.copyFileSync(path.join(web, name), path.join(cat, name));

console.log(`cat/: index.html, ${scripts.join(', ')}`);
