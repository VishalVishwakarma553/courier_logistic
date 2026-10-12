// Converts a simple deliverable .md file into a standalone, theme-aware HTML page.
// Usage: node md2page.mjs <in.md> <out.html> "<Page title>" "<eyebrow>"
import MarkdownIt from 'markdown-it';
import { readFileSync, writeFileSync } from 'node:fs';

const [src, out, title, eyebrow] = process.argv.slice(2);
const md = new MarkdownIt({ html: false, linkify: true });
let text = readFileSync(src, 'utf8');
const h1 = text.match(/^# (.+)$/m)[1];
text = text.replace(/^# .+$/m, '');
// first paragraph after h1 = lede
const ledeMatch = text.match(/^\s*\n([^\n#|].+?)\n\n/s);
let lede = '';
if (ledeMatch) { lede = md.renderInline(ledeMatch[1].trim()); text = text.replace(ledeMatch[0], '\n'); }
let body = md.render(text)
  .replace(/<table>/g, '<div class="table-wrap"><table>')
  .replace(/<\/table>/g, '</table></div>')
  // mark totals rows (first cell empty or bold "Total")
  .replace(/<tr>\n<td>(<\/td>|<strong>Total)/g, m => m.replace('<tr>', '<tr class="total">'));
// split into sections at h2
const parts = body.split(/(?=<h2>)/);
body = parts.map((p, i) => (p.trim() ? `<section>${p}</section>` : '')).join('\n');

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..100,500..800&family=IBM+Plex+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
/* Layout: same family as the other deliverables. Header block, then plain sections and tables. */
:root {
  --bg: #f4f6f9; --surface: #ffffff; --ink: #152030; --muted: #5a6779; --line: #d9dfe8;
  --accent: #1c5bc4; --accent-soft: #e6eefb; --total: #17703f;
  --font-display: "Archivo", "Helvetica Neue", Arial, sans-serif;
  --font-body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, Consolas, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #0e131a; --surface: #151c26; --ink: #e4e9f1; --muted: #95a2b4; --line: #263243;
    --accent: #79a9ff; --accent-soft: #1a2a45; --total: #5fd391; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #0e131a; --surface: #151c26; --ink: #e4e9f1; --muted: #95a2b4; --line: #263243;
  --accent: #79a9ff; --accent-soft: #1a2a45; --total: #5fd391; color-scheme: dark;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font-family: var(--font-body); font-size: 16px; line-height: 1.6; padding: 0 16px; }
main { max-width: 900px; margin: 0 auto; padding-block: 40px 80px; display: grid; gap: 36px; }
.head { background: var(--surface); border: 1.5px solid var(--ink); border-radius: 4px; }
.head-top { padding: 12px 20px; border-bottom: 1.5px solid var(--ink); font: 500 12px/1.4 var(--font-mono); letter-spacing: .04em; color: var(--muted); }
.head-body { padding: 24px 20px; display: grid; gap: 8px; }
h1 { font: 800 clamp(28px, 5vw, 42px)/1.05 var(--font-display); font-stretch: 85%; margin: 0; text-wrap: balance; }
.lede { margin: 0; font-size: 17px; max-width: 70ch; }
.lede strong { color: var(--total); }
section { display: grid; gap: 14px; }
h2 { font: 700 22px/1.2 var(--font-display); font-stretch: 90%; margin: 0; }
p { margin: 0; max-width: 72ch; }
em { color: var(--muted); }
ol, ul { margin: 0; padding-left: 22px; display: grid; gap: 6px; max-width: 74ch; }
li::marker { color: var(--accent); font-weight: 600; }
.table-wrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); }
table { width: 100%; border-collapse: collapse; font-size: 15px; }
th, td { text-align: left; vertical-align: top; padding: 10px 14px; border-bottom: 1px solid var(--line); }
tbody tr:last-child td { border-bottom: 0; }
th { font: 600 11px/1.2 var(--font-body); letter-spacing: .08em; text-transform: uppercase; color: var(--muted); background: var(--bg); }
td { font-variant-numeric: tabular-nums; }
td:first-child { font-weight: 600; }
tr.total td { background: var(--accent-soft); font-weight: 700; }
tr.total td strong { color: var(--total); }
td:has(> strong:only-child) { white-space: nowrap; }
</style>
</head>
<body>
<main>
  <header class="head">
    <div class="head-top">${eyebrow}</div>
    <div class="head-body">
      <h1>${md.renderInline(h1)}</h1>
      ${lede ? `<p class="lede">${lede}</p>` : ''}
    </div>
  </header>
${body}
</main>
</body>
</html>
`;
writeFileSync(out, html);
console.log('wrote', out.split(/[\\/]/).pop(), 'sections:', parts.filter(p => p.trim()).length, 'tables:', (html.match(/<table>/g) || []).length);
