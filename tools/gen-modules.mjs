import { readFileSync, writeFileSync } from 'node:fs';

const [src, out] = process.argv.slice(2);
const md = readFileSync(src, 'utf8');
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const inline = s => esc(s).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>').replace(/\*(.+?)\*/g, '<em>$1</em>');
const cells = line => line.trim().replace(/^\||\|$/g, '').split('|').map(c => c.trim());
const WHO = { '👤': ['cust', 'Customer'], '🛠': ['admin', 'Admin'], '⚙': ['sys', 'System'] };
const whoChips = s => s.split(/\s+/).filter(Boolean).map(t => WHO[t] ? `<span class="who ${WHO[t][0]}">${WHO[t][1]}</span>` : '').join('');
const phaseChip = p => p === '—' ? '' : `<span class="ph">${esc(p)}</span>`;

// ---- summary table
const sumStart = md.indexOf('| # | Module');
const sumRows = md.slice(sumStart).split('\n').slice(2).filter(l => l.startsWith('|') && /^\|\s*\d+\s*\|/.test(l)).map(cells);

// ---- modules
const modBlocks = md.split(/\n### Module /).slice(1).map(b => b.split('\n---')[0]);
let asked = 0, added = 0;
const modules = modBlocks.map(block => {
  const lines = block.split('\n');
  const m = lines[0].match(/^(\d+) · (.+?) — (.+?) · (\d+) days/);
  const [, num, name, phase, days] = m;
  const table = lines.filter(l => l.startsWith('|'));
  const prose = lines.slice(1).filter(l => l.trim() && !l.startsWith('|') && !l.startsWith('\\*'));
  const foot = lines.find(l => l.startsWith('\\*'));
  let body = '';
  if (prose.length) body += prose.map(p => `<p class="mod-note">${inline(p)}</p>`).join('');
  if (table.length) {
    const head = cells(table[0]);
    const rows = table.slice(2).map(cells);
    if (head[0] === 'Feature') {
      body += '<ul class="feats">' + rows.map(([f, who, scope]) => {
        const isAdded = scope.startsWith('Added');
        isAdded ? added++ : asked++;
        const extra = scope.match(/\((.+)\)/);
        return `<li data-scope="${isAdded ? 'added' : 'asked'}"><span class="f">${inline(f)}</span><span class="meta">${whoChips(who)}<span class="scope ${isAdded ? 'added' : 'asked'}">${isAdded ? 'Added' : 'Asked'}${extra ? ' ' + esc(extra[1]) : ''}</span></span></li>`;
      }).join('') + '</ul>';
    } else {
      body += `<div class="table-wrap"><table><thead><tr>${head.map(h => `<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>` +
        rows.map(r => `<tr>${r.map((c, i) => `<td${i === r.length - 1 ? ' class="num"' : ''}>${esc(c)}</td>`).join('')}</tr>`).join('') + '</tbody></table></div>';
    }
  }
  if (foot) body += `<p class="mod-foot">${inline(foot.replace(/^\\\*\s*/, '* '))}</p>`;
  return `<article class="mod" id="m${num}"><header><span class="mnum">${num.padStart(2, '0')}</span><h3>${esc(name)}</h3><span class="mmeta"><span class="ph">${esc(phase)}</span><span class="days">${days} days</span></span></header>${body}</article>`;
});

// ---- not included, phases, questions
const section = title => md.split(`## ${title}`)[1].split('\n---')[0];
const notIncl = section('3. What is NOT included (unless the client asks)').split('\n').filter(l => l.startsWith('- ')).map(l => `<li>${inline(l.slice(2))}</li>`).join('');
const phaseRows = section('4. Phases at a glance').split('\n').filter(l => /^\| \*\*P/.test(l)).map(cells);
const questions = section('5. Questions for the client').split('\n').filter(l => /^\d+\./.test(l)).map(l => `<li>${inline(l.replace(/^\d+\.\s*/, ''))}</li>`).join('');

const totalFeatures = sumRows.reduce((a, r) => a + Number(r[4]), 0);
const totalDays = sumRows.reduce((a, r) => a + Number(r[5]), 0);

const summary = sumRows.map(r => `<tr><td class="num">${r[0]}</td><td><a href="#m${r[0]}">${esc(r[1])}</a></td><td>${whoChips(r[2])}</td><td>${phaseChip(r[3])}</td><td class="num">${r[4]}</td><td class="num">${r[5]}</td></tr>`).join('');

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Courier Platform Modules and Features</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..100,500..800&family=IBM+Plex+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
/* Layout: same spec-sheet family as the other deliverables. Module cards in one column,
   each feature row tagged by who uses it and whether the client asked for it. */
:root {
  --bg: #f4f6f9; --surface: #ffffff; --ink: #152030; --muted: #5a6779; --line: #d9dfe8;
  --accent: #1c5bc4; --accent-soft: #e6eefb;
  --asked: #17703f; --asked-soft: #e2f4e9;
  --added: #9a5b00; --added-soft: #fbefd9;
  --cust: #1c5bc4; --admin: #5b3fb3; --sys: #57606c;
  --font-display: "Archivo", "Helvetica Neue", Arial, sans-serif;
  --font-body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, Consolas, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #0e131a; --surface: #151c26; --ink: #e4e9f1; --muted: #95a2b4; --line: #263243;
    --accent: #79a9ff; --accent-soft: #1a2a45; --asked: #5fd391; --asked-soft: #133022;
    --added: #f0a940; --added-soft: #33270f; --cust: #79a9ff; --admin: #b9a4ff; --sys: #a9b3c0;
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #0e131a; --surface: #151c26; --ink: #e4e9f1; --muted: #95a2b4; --line: #263243;
  --accent: #79a9ff; --accent-soft: #1a2a45; --asked: #5fd391; --asked-soft: #133022;
  --added: #f0a940; --added-soft: #33270f; --cust: #79a9ff; --admin: #b9a4ff; --sys: #a9b3c0;
  color-scheme: dark;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font-family: var(--font-body); font-size: 16px; line-height: 1.6; padding: 0 16px; }
main { max-width: 900px; margin: 0 auto; padding-block: 40px 80px; display: grid; gap: 56px; }
a { color: var(--accent); }

.waybill { background: var(--surface); border: 1.5px solid var(--ink); border-radius: 4px; }
.waybill-top { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 8px 24px; padding: 12px 20px; border-bottom: 1.5px solid var(--ink); font: 500 12px/1.4 var(--font-mono); letter-spacing: .04em; color: var(--muted); }
.waybill-body { padding: 24px 20px 20px; display: grid; gap: 12px; }
h1 { font: 800 clamp(30px, 5vw, 46px)/1.05 var(--font-display); font-stretch: 85%; margin: 0; text-wrap: balance; }
.lede { margin: 0; color: var(--muted); max-width: 64ch; }
.tally { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); border-top: 1.5px solid var(--ink); }
.tally div { padding: 14px 20px; border-right: 1px solid var(--line); display: grid; gap: 2px; }
.tally div:last-child { border-right: 0; }
.tally .n { font: 800 32px/1 var(--font-display); font-stretch: 85%; font-variant-numeric: tabular-nums; }
.tally .t { font-size: 13px; color: var(--muted); }
.tally .asked .n { color: var(--asked); } .tally .added .n { color: var(--added); }

section { display: grid; gap: 18px; scroll-margin-top: 24px; }
.eyebrow { font: 600 11px/1 var(--font-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--accent); }
h2 { font: 700 clamp(22px, 3vw, 28px)/1.15 var(--font-display); font-stretch: 90%; margin: 0; text-wrap: balance; }
p { margin: 0; max-width: 72ch; }
.muted { color: var(--muted); }
.note { border-left: 3px solid var(--added); background: var(--added-soft); padding: 12px 16px; border-radius: 0 8px 8px 0; font-size: 14.5px; }

.legend { display: flex; flex-wrap: wrap; gap: 10px 22px; font-size: 13.5px; color: var(--muted); align-items: center; }
.legend > span { display: inline-flex; gap: 6px; align-items: center; }
.who { font: 600 10.5px/1 var(--font-body); letter-spacing: .04em; padding: 4px 6px; border-radius: 4px; border: 1px solid; white-space: nowrap; }
.who.cust { color: var(--cust); border-color: var(--cust); }
.who.admin { color: var(--admin); border-color: var(--admin); }
.who.sys { color: var(--sys); border-color: var(--sys); border-style: dashed; }
.scope { font: 600 10.5px/1 var(--font-body); padding: 4px 7px; border-radius: 999px; white-space: nowrap; }
.scope.asked { color: var(--asked); background: var(--asked-soft); }
.scope.added { color: var(--added); background: var(--added-soft); }
.ph { font: 500 11.5px/1 var(--font-mono); padding: 4px 7px; border-radius: 4px; background: var(--accent-soft); color: var(--accent); white-space: nowrap; }

.table-wrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); }
table { width: 100%; border-collapse: collapse; font-size: 14.5px; }
th, td { text-align: left; vertical-align: middle; padding: 9px 12px; border-bottom: 1px solid var(--line); }
tbody tr:last-child td { border-bottom: 0; }
th { font: 600 11px/1.2 var(--font-body); letter-spacing: .08em; text-transform: uppercase; color: var(--muted); background: var(--bg); }
td.num { font-variant-numeric: tabular-nums; text-align: right; white-space: nowrap; font-family: var(--font-mono); font-size: 13px; }
td .who + .who { margin-left: 4px; }
tfoot td { font-weight: 700; background: var(--bg); border-top: 1.5px solid var(--ink); border-bottom: 0; }
.summary td:nth-child(2) a { color: var(--ink); text-decoration: none; font-weight: 600; }
.summary td:nth-child(2) a:hover { color: var(--accent); text-decoration: underline; }

.filters { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; position: sticky; top: env(safe-area-inset-top, 0px); z-index: 2; background: var(--bg); padding-block: 10px; border-bottom: 1px solid var(--line); }
.filters .lbl { font-size: 13px; color: var(--muted); margin-right: 4px; }
.filters button { font: 600 13px/1 var(--font-body); padding: 8px 12px; border-radius: 999px; border: 1.5px solid var(--line); background: var(--surface); color: var(--ink); cursor: pointer; }
.filters button[aria-pressed="true"] { border-color: var(--accent); background: var(--accent); color: var(--surface); }
.filters button:focus-visible { outline: 2px solid var(--ink); outline-offset: 2px; }
#filter-count { font-size: 13px; color: var(--muted); margin-left: auto; }

.mods { display: grid; gap: 16px; }
.mod { background: var(--surface); border: 1px solid var(--line); border-radius: 8px; overflow: hidden; scroll-margin-top: 70px; }
.mod header { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 14px; padding: 14px 18px; border-bottom: 1px solid var(--line); }
.mnum { font: 800 22px/1 var(--font-display); font-stretch: 85%; color: var(--line); font-variant-numeric: tabular-nums; }
.mod h3 { font: 700 19px/1.2 var(--font-display); font-stretch: 90%; margin: 0; flex: 1 1 auto; min-width: 0; }
.mmeta { display: inline-flex; gap: 8px; align-items: center; }
.days { font: 500 12.5px/1 var(--font-mono); color: var(--muted); white-space: nowrap; }
.feats { list-style: none; margin: 0; padding: 0; }
.feats li { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 6px 14px; padding: 9px 18px; border-bottom: 1px dashed var(--line); font-size: 14.5px; }
.feats li:last-child { border-bottom: 0; }
.feats .f { flex: 1 1 280px; min-width: 0; }
.feats .meta { display: inline-flex; gap: 5px; align-items: center; flex-wrap: wrap; }
.mod .table-wrap { border: 0; border-radius: 0; }
.mod-note { padding: 12px 18px 0; font-size: 14.5px; color: var(--muted); }
.mod-note:last-child { padding-bottom: 14px; }
.mod-foot { padding: 10px 18px 14px; font-size: 13px; color: var(--muted); border-top: 1px solid var(--line); }
body.f-asked .feats li[data-scope="added"], body.f-added .feats li[data-scope="asked"] { display: none; }
.mod.empty { display: none; }

ul.plain, ol.plain { margin: 0; padding-left: 22px; display: grid; gap: 8px; max-width: 72ch; }
footer { font-size: 13px; color: var(--muted); border-top: 1px solid var(--line); padding-top: 20px; }
</style>
</head>
<body>
<main>
  <header class="waybill">
    <div class="waybill-top"><span>DELIVERABLE 03 / MODULES AND FEATURES</span><span>MULTI-COURIER BOOKING &amp; TRACKING ERP</span></div>
    <div class="waybill-body">
      <h1>Courier Platform Modules and Features</h1>
      <p class="lede">Everything the platform will contain, module by module, so the client can confirm nothing is missing and nothing extra is assumed.</p>
    </div>
    <div class="tally">
      <div><span class="n">${sumRows.length}</span><span class="t">Modules</span></div>
      <div><span class="n">${totalFeatures}</span><span class="t">Features</span></div>
      <div class="asked"><span class="n">${asked}</span><span class="t">Asked by the client</span></div>
      <div class="added"><span class="n">${added}</span><span class="t">Added by us, optional</span></div>
      <div><span class="n">≈${totalDays}</span><span class="t">Developer build days</span></div>
    </div>
  </header>

  <section id="summary">
    <div class="eyebrow">Section 1</div>
    <h2>Summary</h2>
    <div class="legend">
      <span><span class="who cust">Customer</span><span class="who admin">Admin</span><span class="who sys">System</span> who uses it</span>
      <span><span class="ph">P0</span> build phase</span>
    </div>
    <div class="table-wrap">
      <table class="summary">
        <thead><tr><th style="text-align:right">#</th><th>Module</th><th>Who</th><th>Phase</th><th style="text-align:right">Features</th><th style="text-align:right">Days</th></tr></thead>
        <tbody>${summary}</tbody>
        <tfoot><tr><td></td><td>Total</td><td></td><td></td><td class="num">${totalFeatures}</td><td class="num">≈${totalDays}</td></tr></tfoot>
      </table>
    </div>
    <p class="note"><strong>About the days:</strong> these are build days for one developer, without testing, project management or buffer. The timeline (deliverable #6) adds those and splits the work across the team, so calendar time will be much shorter.</p>
  </section>

  <section id="modules">
    <div class="eyebrow">Section 2</div>
    <h2>Modules in detail</h2>
    <div class="legend">
      <span><span class="scope asked">Asked</span> in the client's requirement document</span>
      <span><span class="scope added">Added</span> our recommendation; the client can drop it</span>
    </div>
    <div class="filters" role="group" aria-label="Filter features">
      <span class="lbl">Show</span>
      <button type="button" data-f="all" aria-pressed="true">All features</button>
      <button type="button" data-f="asked" aria-pressed="false">Asked only</button>
      <button type="button" data-f="added" aria-pressed="false">Added only</button>
      <span id="filter-count" role="status"></span>
    </div>
    <div class="mods">${modules.join('\n')}</div>
  </section>

  <section id="excluded">
    <div class="eyebrow">Section 3</div>
    <h2>Not included unless the client asks</h2>
    <ul class="plain">${notIncl}</ul>
  </section>

  <section id="phases">
    <div class="eyebrow">Section 4</div>
    <h2>Phases at a glance</h2>
    <div class="table-wrap"><table><thead><tr><th>Phase</th><th>Delivers</th></tr></thead><tbody>
      ${phaseRows.map(r => `<tr><td style="white-space:nowrap">${inline(r[0])}</td><td>${inline(r[1])}</td></tr>`).join('')}
    </tbody></table></div>
  </section>

  <section id="questions">
    <div class="eyebrow">Section 5</div>
    <h2>Questions for the client</h2>
    <ol class="plain">${questions}</ol>
  </section>

  <footer>Companion to the System Architecture, Database Design and Courier Feasibility Report. Source: docs/MODULES_AND_FEATURES.md.</footer>
</main>
<script>
  const counts = { all: ${asked + added}, asked: ${asked}, added: ${added} };
  const status = document.getElementById('filter-count');
  function apply(f) {
    document.body.classList.remove('f-asked', 'f-added');
    if (f !== 'all') document.body.classList.add('f-' + f);
    document.querySelectorAll('.filters button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.f === f)));
    document.querySelectorAll('.mod').forEach(m => {
      const items = m.querySelectorAll('.feats li');
      if (!items.length) { m.classList.toggle('empty', f !== 'all'); return; }
      const visible = [...items].some(li => f === 'all' || li.dataset.scope === f);
      m.classList.toggle('empty', !visible);
    });
    status.textContent = counts[f] + ' features shown';
    try { localStorage.setItem('features-filter', f); } catch (e) {}
  }
  document.querySelectorAll('.filters button').forEach(b => b.addEventListener('click', () => apply(b.dataset.f)));
  let saved = 'all';
  try { saved = localStorage.getItem('features-filter') || 'all'; } catch (e) {}
  apply(counts[saved] !== undefined ? saved : 'all');
</script>
</body>
</html>
`;
writeFileSync(out, html);
console.log({ modules: modules.length, summaryRows: sumRows.length, asked, added, totalFeatures, totalDays });
