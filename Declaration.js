// this Function and Global Variable Declaration for page 1
/* global apex */
window.SqlToolbar = (function () {
  "use strict";
  const $ = apex.jQuery;

  // ====== CONFIG (Static Files + CDN) ======
  const APP_JS_PDF_CANDIDATES = [
    '#APP_FILES#jspdf.min.js',
    '#APP_FILES#jspdf.js',
    '#APP_FILES#jspdf.umd.min.js'
  ];
  const APP_AUTOTABLE_CANDIDATES = [
    '#APP_FILES#jspdf.plugin.autotable.min.js',
    '#APP_FILES#jspdf.plugin.autotable.js'
  ];
  const CDN_JS_PDF_CANDIDATES = [
    'https://unpkg.com/jspdf@2.5.1/dist/jspdf.min.js',
    'https://unpkg.com/jspdf@2.5.1/dist/jspdf.umd.min.js'
  ];
  const CDN_AUTOTABLE_CANDIDATES = [
    'https://unpkg.com/jspdf-autotable@3.8.2/dist/jspdf.plugin.autotable.min.js'
  ];
  const FORCE_PRELOADED = false;

  // ====== Script loader ======
  function loadScriptOnce(url, timeoutMs = 12000){
    return new Promise((resolve, reject) => {
      if (!url) return reject(new Error('Empty URL'));
      if (document.querySelector(`script[src="${url}"]`)) return resolve();
      const s = document.createElement("script");
      s.src = url; s.async = true; s.crossOrigin = 'anonymous';
      const to = setTimeout(() => { s.remove(); reject(new Error("Timeout " + url)); }, timeoutMs);
      s.onload  = () => { clearTimeout(to); resolve(); };
      s.onerror = () => { clearTimeout(to); reject(new Error("Failed " + url)); };
      document.head.appendChild(s);
    });
  }
  function loadFirst(urls){
    let p = Promise.reject();
    urls.forEach(u => { p = p.catch(() => loadScriptOnce(u)); });
    return p;
  }

  function ensureJsPdf(){
    if (FORCE_PRELOADED) return Promise.resolve();
    if (window.jspdf?.jsPDF || window.jsPDF) {
      if (window.jspdf?.jsPDF?.API?.autoTable || window.autoTable || window.jspdfAutoTable) {
        return Promise.resolve();
      }
    }
    return loadFirst(APP_JS_PDF_CANDIDATES)
      .then(() => loadFirst(APP_AUTOTABLE_CANDIDATES))
      .then(tryApplyPlugin)
      .catch(() => {
        return loadFirst(CDN_JS_PDF_CANDIDATES)
          .then(() => loadFirst(CDN_AUTOTABLE_CANDIDATES))
          .then(tryApplyPlugin);
      });
  }

  function tryApplyPlugin(){
    const jsPDFCtor = (window.jspdf && window.jspdf.jsPDF) || window.jsPDF;
    const apiHas = !!(jsPDFCtor && jsPDFCtor.API && jsPDFCtor.API.autoTable);
    if (apiHas) return;
    const atGlobals = [
      window.jspdfAutoTable,
      window.jspdf_autotable,
      window['jspdf-autotable'],
      window.autoTable
    ].filter(Boolean);
    if (jsPDFCtor) {
      for (const g of atGlobals) {
        if (typeof g?.applyPlugin === 'function') {
          try { g.applyPlugin(jsPDFCtor); } catch(e) {}
        }
      }
    }
  }

  function getAutoTableInvoker(doc) {
    if (typeof doc.autoTable === 'function') return (opts)=>doc.autoTable(opts);
    if (typeof window.autoTable === 'function') return (opts)=>window.autoTable(doc, opts);
    const cands = [window.jspdfAutoTable, window.jspdf_autotable, window['jspdf-autotable']];
    for (const c of cands) {
      if (!c) continue;
      if (typeof c === 'function')   return (opts)=>c(doc, opts);
      if (typeof c?.default === 'function') return (opts)=>c.default(doc, opts);
      if (typeof c?.autoTable === 'function') return (opts)=>c.autoTable(doc, opts);
    }
    if (typeof (window.jspdf?.jsPDF?.API?.autoTable) === 'function') {
      return (opts)=>window.jspdf.jsPDF.API.autoTable.call(doc, opts);
    }
    return null;
  }

  // ====== Fonts (optional) ======
  function ensureArabicFont() {
    const FONT_URL = '#APP_FILES#NotoNaskhArabic-Regular.ttf';
    return fetch(FONT_URL, { cache: 'reload' })
      .then(r => r.ok ? r.arrayBuffer() : Promise.reject('no font'))
      .then(buf => {
        const b64 = btoa(String.fromCharCode(...new Uint8Array(buf)));
        const API = (window.jspdf && window.jspdf.jsPDF && window.jspdf.jsPDF.API);
        if (API && API.addFileToVFS && API.addFont) {
          API.addFileToVFS('NotoNaskh.ttf', b64);
          API.addFont('NotoNaskh.ttf', 'noto', 'normal');
        }
      }).catch(() => {});
  }
  function pickFontName(doc) {
    try { doc.setFont('noto', 'normal'); return 'noto'; } catch(e) {}
    return 'helvetica';
  }

  // ====== Column analysis and widths ======
  function pickPageFormat(colCount){
    if (colCount > 16) return { format: 'a3', orientation: 'landscape' };
    if (colCount > 10) return { format: 'a3', orientation: 'landscape' };
    if (colCount > 6)  return { format: 'a4', orientation: 'landscape' };
    return { format: 'a4', orientation: 'portrait' };
  }

  function classifyColumns(headers, rows) {
    const sampleN = Math.min(rows.length, 200);
    const isNum  = v => /^-?\d+(\.\d+)?$/.test(String(v).replace(/,/g,'').trim());
    const isDate = v => /\d{1,4}[\/\-]\d{1,2}[\/\-]\d{1,4}/.test(String(v));
    const isMail = v => /@/.test(String(v));

    const lengths = (ci) => {
      let max = 0, avg = 0;
      for (let r=0; r<sampleN; r++) {
        const s = String(rows[r]?.[ci] ?? '');
        const L = s.length; max = Math.max(max, L); avg += L;
      }
      return { max, avg: sampleN ? (avg/sampleN) : 0 };
    };

    const numericCols = headers.map((_, ci) => rows.some(r => isNum(r?.[ci])));
    const dateCols    = headers.map((_, ci) => rows.some(r => isDate(r?.[ci])));
    const emailCols   = headers.map((_, ci) => rows.some(r => isMail(r?.[ci])));
    const longCols    = headers.map((h, ci) => {
      const { max, avg } = lengths(ci);
      return (max > 35 || avg > 28) && !numericCols[ci] && !dateCols[ci];
    });

    const keyPattern = /(^(id|code|key)$)|name|title|date|status|number|no\.?/i;
    const keyCols = headers.map((h, i) => ({h, i}))
      .filter(x => x.i === 0 || keyPattern.test(x.h || ''))
      .slice(0, 3)
      .map(x => x.i);

    return { numericCols, dateCols, emailCols, longCols, keyCols };
  }

  function computeStretchWidths(headers, rows, classes, usableW, fontSize) {
    const charPt = 5.2 * (fontSize / 9);
    const minW = (ci) => classes.numericCols[ci] ? 64
                    : classes.dateCols[ci]    ? 90
                    : classes.emailCols[ci]   ? 140
                    : classes.longCols[ci]    ? 160
                    : 100;
    const maxW = (ci) => classes.emailCols[ci] ? 320
                    : classes.longCols[ci]    ? 280
                    : 220;

    const est = headers.map((h, ci) => {
      const hLen = String(h||'').length;
      let maxL = hLen, sum = hLen, n = 1;
      const M = Math.min(rows.length, 300);
      for (let r=0; r<M; r++) {
        const s = String(rows[r]?.[ci] ?? '');
        const L = s.length;
        if (L > maxL) maxL = L;
        sum += L; n++;
      }
      const avgL = sum / n;
      const contentLen = 0.85 * maxL + 0.15 * avgL;
      const natural = Math.max(minW(ci), Math.min(maxW(ci), (contentLen * charPt) + 14, (hLen * charPt) * 1.25 + 12));
      return natural;
    });

    let sum = est.reduce((a,b)=>a+b,0);
    if (sum === 0) return headers.map(()=>Math.floor(usableW/headers.length));

    const scale = usableW / sum;
    let widths = est.map(w => Math.max(40, Math.floor(w * scale)));
    let diff = usableW - widths.reduce((a,b)=>a+b,0);
    widths[widths.length - 1] += diff;
    return widths;
  }

  // ====== Common helpers ======
  function currentTimestamp() {
    const d = new Date(), pad = n => String(n).padStart(2,'0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}_${pad(d.getHours())}-${pad(d.getMinutes())}-${pad(d.getSeconds())}`;
  }
  function buildDataset(state) {
    const visIdx = state.visibleCols.map((v,i)=>v?i:-1).filter(i=>i>=0);
    const headers = visIdx.map(i => (state.table.tHead.rows[0].cells[i].textContent || '').trim());
    const rows = state.filteredIdx.map(ri => {
      const tr = state.rows[ri];
      return visIdx.map(ci => (tr.cells[ci]?.textContent || '').trim());
    });
    return { headers, rows };
  }
  function buildHtml(state, title) {
    const { headers, rows } = buildDataset(state);
    const esc = s => String(s).replace(/[&<>"']/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const headRow = `<tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}</tr>`;
    const bodyRows = rows.map(r=>`<tr>${r.map(c=>`<td>${esc(c)}</td>`).join('')}</tr>`).join('');
    const css = `
      body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:24px;}
      h1{font-size:18px;margin:0 0 12px;}
      table{border-collapse:collapse;width:100%}
      th,td{border:1px solid #e5e5e5;padding:6px 8px;text-align:left;font-size:12px}
      thead th{background:#fafafa}
      footer{margin-top:12px;font-size:11px;opacity:.7}
      @media print { body{margin:0 } h1{margin:8px 0} }
    `;
    return `<!doctype html><html><head><meta charset="utf-8"><title>${esc(title)}</title>
<style>${css}</style></head><body>
<h1>${esc(title)}</h1>
<table><thead>${headRow}</thead><tbody>${bodyRows}</tbody></table>
<footer>Generated ${new Date().toLocaleString()}</footer>
</body></html>`;
  }
  function download(filename, mime, data) {
    const blob = data instanceof Blob ? data : new Blob([data], {type: mime});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = filename;
    document.body.appendChild(a); a.click();
    setTimeout(()=>{ URL.revokeObjectURL(url); a.remove(); }, 0);
  }

  // ====== Enhancer (toolbar) ======
  function enhance(regionId) {
    const region = document.getElementById(regionId);
    if (!region) return;
    region.querySelectorAll('.sql-results').forEach(wrapOne);
  }

  function wrapOne(wrapper) {
    if (wrapper.dataset.enhanced === '1') return;
    const table = wrapper.querySelector('table'); if (!table) return;
    wrapper.dataset.enhanced = '1';

    const toolbar = document.createElement('div');
    toolbar.className = 'sql-toolbar';
    toolbar.innerHTML = `
      <div class="left">
        <input type="search" placeholder="Search…" aria-label="Search all columns">
        <div class="menu">
          <button type="button" class="btn btn-columns">Columns ▾</button>
          <div class="menu-panel"></div>
        </div>
      </div>
      <div class="right">
        <label>Rows:</label>
        <select class="rpp">
          <option value="16" selected>16</option>
          <option value="25">25</option>
          <option value="50">50</option>
          <option value="100">100</option>
          <option value="0">All</option>
        </select>
        <span class="sep"></span>
        <button type="button" class="btn prev">‹</button>
        <span class="counter">Page <span class="cur">1</span> of <span class="tot">1</span></span>
        <button type="button" class="btn next">›</button>
        <span class="sep"></span>
        <div class="menu export-menu">
          <button type="button" class="btn btn-export">Export ▾</button>
          <div class="menu-panel">
            <button type="button" class="menu-item csv"  data-act="csv"><span class="ico">📄</span><div><div class="caption">Export CSV</div></div></button>
            <button type="button" class="menu-item pdf"  data-act="pdf"><span class="ico">🧾</span><div><div class="caption">Export PDF</div></div></button>
            <button type="button" class="menu-item html" data-act="html"><span class="ico">🌐</span><div><div class="caption">Export HTML</div></div></button>
            <button type="button" class="menu-item email" data-act="email"><span class="ico">✉️</span><div><div class="caption">Email Report</div></div></button>
          </div>
        </div>
      </div>
    `;
    wrapper.insertBefore(toolbar, table);

    const state = initState(table);
    buildColumnMenu(toolbar.querySelector('.left .menu .menu-panel'), state);
    bindHandlers(toolbar, state);
    render(state);
  }

  function initState(table) {
    const thead = table.tHead, tbody = table.tBodies[0];
    const headers = Array.from(thead ? thead.rows[0].cells : []).map((th,i)=>(th.textContent||`COL${i+1}`).trim());
    const rows = Array.from(tbody ? tbody.rows : []);
    rows.forEach((tr, idx) => (tr.dataset._ix = idx));
    return {
      table, headers, rows,
      visibleCols: headers.map(()=>true),
      filter: '', rpp: 16, page: 1,
      filteredIdx: rows.map((_,i)=>i),
      _updateCounters: function(){}
    };
  }

  function buildColumnMenu(panel, state) {
    panel.innerHTML = '';
    state.headers.forEach((h, i) => {
      const id = `col_${i}_${Math.random().toString(36).slice(2,7)}`;
      const row = document.createElement('label');
      row.innerHTML = `<input type="checkbox" id="${id}" data-col="${i}" checked> <span>${escapeHtml(h) || ('COL ' + (i+1))}</span>`;
      panel.appendChild(row);
    });
  }

  function bindHandlers(toolbar, state) {
    const search  = toolbar.querySelector('input[type="search"]');
    const rppSel  = toolbar.querySelector('select.rpp');
    const prevBtn = toolbar.querySelector('.prev');
    const nextBtn = toolbar.querySelector('.next');
    const colBtn  = toolbar.querySelector('.btn-columns');
    const colPanel= toolbar.querySelector('.left .menu .menu-panel');
    const expMenu = toolbar.querySelector('.export-menu');
    const expBtn  = expMenu.querySelector('.btn-export');
    const expPanel= expMenu.querySelector('.menu-panel');

    document.addEventListener('click', (e) => {
      if (!colPanel.contains(e.target) && !colBtn.contains(e.target)) colPanel.style.display = 'none';
      if (!expPanel.contains(e.target) && !expBtn.contains(e.target)) expPanel.style.display = 'none';
    });
    colBtn.addEventListener('click', () => { colPanel.style.display = colPanel.style.display === 'block' ? 'none' : 'block'; });
    expBtn.addEventListener('click', () => { expPanel.style.display = expPanel.style.display === 'block' ? 'none' : 'block'; });

    colPanel.addEventListener('change', (e) => {
      const cb = e.target.closest('input[type="checkbox"]'); if (!cb) return;
      const col = +cb.dataset.col; state.visibleCols[col] = cb.checked; applyColumnVisibility(state);
    });

    let t = null;
    search.addEventListener('input', () => {
      clearTimeout(t);
      t = setTimeout(() => {
        state.filter = search.value.trim().toLowerCase();
        recomputeFilter(state); state.page = 1; render(state);
      }, 120);
    });

    rppSel.addEventListener('change', () => { state.rpp = +rppSel.value; state.page = 1; render(state); });
    prevBtn.addEventListener('click', () => { if (state.page > 1) { state.page--; render(state); } });
    nextBtn.addEventListener('click', () => { if (state.page < totalPages(state)) { state.page++; render(state); } });

    expPanel.addEventListener('click', (e) => {
      const mi = e.target.closest('.menu-item'); if (!mi) return;
      const act = mi.dataset.act;
      if (act === 'csv')   exportCsv(state);
      if (act === 'html')  exportHtml(state);
      if (act === 'pdf')   exportPdf(state);
      if (act === 'email') openEmailModal(state);
      expPanel.style.display = 'none';
    });

    const counterCur = toolbar.querySelector('.cur');
    const counterTot = toolbar.querySelector('.tot');
    state._updateCounters = function () {
      counterCur.textContent = String(state.page);
      counterTot.textContent = String(totalPages(state));
      prevBtn.disabled = state.page <= 1;
      nextBtn.disabled = state.page >= totalPages(state);
    };

    applyColumnVisibility(state);
  }

  function recomputeFilter(state) {
    if (!state.filter) { state.filteredIdx = state.rows.map((_,i)=>i); return; }
    const q = state.filter;
    state.filteredIdx = state.rows.map((tr,i)=>({tr,i}))
      .filter(({tr}) => tr.innerText.toLowerCase().includes(q))
      .map(({i}) => i);
  }
  function totalPages(state) {
    if (state.rpp === 0) return 1;
    return Math.max(1, Math.ceil(state.filteredIdx.length / state.rpp));
  }
  function render(state) {
    const { rows, rpp } = state;
    rows.forEach(tr => tr.style.display = 'none');
    const tot = totalPages(state); if (state.page > tot) state.page = tot;
    let start = 0, end = state.filteredIdx.length;
    if (rpp !== 0) { start = (state.page - 1) * rpp; end = Math.min(start + rpp, state.filteredIdx.length); }
    for (let k=start; k<end; k++) rows[state.filteredIdx[k]].style.display = '';
    state._updateCounters();
  }
  function applyColumnVisibility(state) {
    const { table, visibleCols } = state;
    const thead = table.tHead, tbody = table.tBodies[0];
    if (thead && thead.rows[0]) Array.from(thead.rows[0].cells).forEach((th,i)=>{ th.style.display = visibleCols[i] ? '' : 'none'; });
    Array.from(tbody.rows).forEach(tr => Array.from(tr.cells).forEach((td,i)=>{ td.style.display = visibleCols[i] ? '' : 'none'; }));
  }

  // ====== Exports ======
  function safeCell(txt) {
    const t = (txt || '').replace(/\r?\n/g,' ').replace(/"/g,'""').trim();
    return /[",\n]/.test(t) ? `"${t}"` : t;
  }
  function exportCsv(state) {
    const visIdx = state.visibleCols.map((v,i)=>v?i:-1).filter(i=>i>=0);
    const head = visIdx.map(i => safeCell(state.table.tHead.rows[0].cells[i].textContent));
    const lines = [head.join(',')];
    state.filteredIdx.forEach(ri => {
      const tr = state.rows[ri];
      const row = visIdx.map(ci => safeCell(tr.cells[ci]?.textContent || ''));
      lines.push(row.join(','));
    });
    download(`report_${currentTimestamp()}.csv`, 'text/csv;charset=utf-8;', lines.join('\r\n'));
  }
  function exportHtml(state) {
    download(`report_${currentTimestamp()}.html`, 'text/html;charset=utf-8', buildHtml(state,'Report'));
  }

  function exportPdf(state){
    ensureJsPdf()
      .then(() => ensureArabicFont())
      .then(() => {
        const jsPDFCtor = (window.jspdf && window.jspdf.jsPDF) || window.jsPDF;
        if (!jsPDFCtor) { apex.message.alert("jsPDF not available."); return; }

        const { headers, rows } = buildDataset(state);
        const classes = classifyColumns(headers, rows);

        const nf = new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 });
        const fmtRows = rows.map(r => r.map((v, ci) => {
          const raw = String(v ?? '').trim();
          if (!classes.numericCols[ci]) return raw;
          const num = Number(raw.replace(/,/g,'')); return isNaN(num) ? raw : nf.format(num);
        }));
        const totalsAll = (function buildTotals(headers, rows, numericCols){
          const t = headers.map((_, ci) => {
            if (!numericCols[ci]) return '';
            let sum = 0; rows.forEach(r => { const x = Number(String(r[ci]).replace(/,/g,'')); if (!isNaN(x)) sum += x; });
            return nf.format(sum);
          });
          if (t.length) t[0] = 'Total';
          return t;
        })(headers, rows, classes.numericCols);

        const MAX_COLS_PER_PAGE = 10;
        const repeatCols = Array.from(new Set(classes.keyCols)).filter(i => i >= 0 && i < headers.length);
        const allIdx = headers.map((_,i)=>i);
        const rest = allIdx.filter(i => !repeatCols.includes(i));
        const chunkSize = Math.max(1, MAX_COLS_PER_PAGE - repeatCols.length);
        const segments = [];
        if (headers.length <= MAX_COLS_PER_PAGE) {
          segments.push(allIdx);
        } else {
          for (let k=0; k<rest.length; k += chunkSize) {
            const chunk = rest.slice(k, k + chunkSize);
            segments.push(repeatCols.concat(chunk));
          }
        }

        const maxSegCols = Math.max(...segments.map(s => s.length));
        const pageFmt = pickPageFormat(maxSegCols);
        const doc = new jsPDFCtor({
          orientation: pageFmt.orientation,
          unit: "pt",
          format: pageFmt.format
        });

        const fontName = pickFontName(doc);
        const pageW = doc.internal.pageSize.getWidth();
        const pageH = doc.internal.pageSize.getHeight();
        const margins = { top: 60, left: 40, right: 40, bottom: 26 };
        const usableW = pageW - margins.left - margins.right;

        const title  = (window.apex && apex.item && apex.item('P_REPORT_TITLE')) ? (apex.item('P_REPORT_TITLE').getValue() || 'SQL Report') : 'SQL Report';
        const stamp  = new Date().toLocaleString();

        const autoTable = getAutoTableInvoker(doc);
        if (!autoTable) { apex.message.alert("PDF plugin (AutoTable) is not available."); return; }

        const baseFont = (maxSegCols > 16) ? 7 : (maxSegCols > 12 ? 8 : 9);
        const headFont = Math.max(baseFont + 1, 9);

        const drawHeader = () => {
          doc.setFont(fontName, "normal");
          doc.setFontSize(15); doc.setTextColor(30);
          doc.text(title, margins.left, 36, { align: 'left' });
          doc.setFontSize(10); doc.setTextColor(110);
          doc.text(`Generated ${stamp}`, pageW - margins.right, 36, { align: "right" });
          doc.setDrawColor(200); doc.setLineWidth(0.8);
          doc.line(margins.left, 44, pageW - margins.right, 44);
        };

        segments.forEach((segIdx, segNo) => {
          if (segNo > 0) doc.addPage();

          const cols = segIdx.map(i => i);
          const headersSub = cols.map(i => headers[i]);
          const rowsSub = fmtRows.map(r => cols.map(i => r[i]));

          const classesSub = {
            numericCols: cols.map(i => classes.numericCols[i]),
            dateCols:    cols.map(i => classes.dateCols[i]),
            emailCols:   cols.map(i => classes.emailCols[i]),
            longCols:    cols.map(i => classes.longCols[i])
          };

          const widths = computeStretchWidths(headersSub, rowsSub, classesSub, usableW, baseFont);
          const columnStyles = Object.fromEntries(headersSub.map((_, j) => ([
            j,
            {
              cellWidth: widths[j],
              minCellWidth: 40,
              halign: classesSub.numericCols[j] ? 'right' : (classesSub.dateCols[j] ? 'center' : 'left'),
              valign: 'top'
            }
          ])));

          const footRow = (segNo === segments.length - 1)
            ? [ cols.map(i => totalsAll[i] ?? '') ]
            : undefined;

          autoTable({
            head: [headersSub],
            body: rowsSub,
            foot: footRow,
            showFoot: footRow ? 'lastPage' : 'never',
            theme: 'grid',
            margin: margins,
            tableWidth: usableW,
            styles: {
              font: fontName,
              fontSize: baseFont,
              cellPadding: { top: 3, right: 4, bottom: 3, left: 4 },
              lineWidth: 0.2,
              lineColor: 200,
              overflow: 'linebreak',
              cellWidth: 'auto',
              valign: 'top',
              textColor: 30
            },
            headStyles: {
              font: fontName,
              fontSize: headFont,
              fillColor: [252, 208, 202], // #FCD0CA
              textColor: 20,
              fontStyle: 'bold',
              halign: 'center'
            },
            alternateRowStyles: { fillColor: [245, 248, 255] },
            footStyles: {
              fillColor: [236, 239, 241],
              textColor: 20,
              fontStyle: 'bold'
            },
            columnStyles,
            willDrawPage: () => {
              drawHeader();
            },
            didDrawPage: () => {
              doc.setFont(fontName, "normal");
              doc.setFontSize(9); doc.setTextColor(110);
              const cur = doc.internal.getCurrentPageInfo().pageNumber;
              const tot = doc.internal.getNumberOfPages();
              doc.text(`Page ${cur} of ${tot}`, pageW - margins.right, pageH - 18, { align: 'right' });
            }
          });
        });

        const safeTitle = (title || 'SQL_Report').replace(/[^\w\-]+/g, '_');
        const file  = `report_${safeTitle}_${new Date().toISOString().slice(0,19).replace(/[:T]/g,'-')}.pdf`;
        doc.save(file);
      })
      .catch((err) => {
        console.error('[SqlToolbar] PDF generation failed:', err);
        apex.message.alert("Failed to generate PDF. Check console for details.");
      });
  }

// --- Email modal UI ---
let MAIL_UI = null;

function ensureMailModal() {
  if (MAIL_UI) return MAIL_UI;

  const overlay = document.createElement('div');
  overlay.className = 'sql-mail-overlay';

  const dlg = document.createElement('div');
  dlg.className = 'sql-mail-dialog';
  dlg.innerHTML = `
    <header>Send report by email</header>
    <div class="sql-mail-body">
      <div class="sql-mail-row">
        <label for="sql-mail-to">Send to</label>
        <input id="sql-mail-to" type="text" placeholder="user@example.com, other@domain.com">
      </div>
      <div class="sql-mail-row">
        <label for="sql-mail-subj">Subject</label>
        <input id="sql-mail-subj" type="text" placeholder="Subject">
      </div>
      <div class="sql-mail-row">
        <label for="sql-mail-msg">Message</label>
        <textarea id="sql-mail-msg" placeholder="Write a short message (optional)"></textarea>
      </div>
      <div class="sql-mail-error" id="sql-mail-err"></div>
    </div>
    <div class="sql-mail-actions">
      <button type="button" class="sql-mail-btn" id="sql-mail-cancel">Cancel</button>
      <button type="button" class="sql-mail-btn primary" id="sql-mail-send">Send</button>
    </div>
  `;

  document.body.appendChild(overlay);
  document.body.appendChild(dlg);

  const ui = {
    overlay,
    dlg,
    to: dlg.querySelector('#sql-mail-to'),
    subj: dlg.querySelector('#sql-mail-subj'),
    msg: dlg.querySelector('#sql-mail-msg'),
    err: dlg.querySelector('#sql-mail-err'),
    btnSend: dlg.querySelector('#sql-mail-send'),
    btnCancel: dlg.querySelector('#sql-mail-cancel'),
    open() { overlay.style.display = 'block'; dlg.style.display = 'block'; ui.to.focus(); },
    close() { overlay.style.display = 'none'; dlg.style.display = 'none'; ui.setError(''); ui.setBusy(false); },
    setBusy(b) {
      ui.btnSend.disabled = b;
      ui.btnSend.textContent = b ? 'Sending…' : 'Send';
    },
    setError(t) {
      ui.err.textContent = t || '';
      ui.err.style.display = t ? 'block' : 'none';
    }
  };

  overlay.addEventListener('click', () => ui.close());
  ui.btnCancel.addEventListener('click', () => ui.close());
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && dlg.style.display === 'block') ui.close();
  });

  MAIL_UI = ui;
  return ui;
}

function openEmailModal(state) {
  const ui = ensureMailModal();

  const getVal = (id) => (window.apex && apex.item && apex.item(id)) ? apex.item(id).getValue() : null;
  const defaultTo = getVal('P_EMAIL_TO') || getVal('P1_EMAIL_TO') || '';
  const defaultSubj = (window.apex && apex.item && apex.item('P_REPORT_TITLE'))
    ? (apex.item('P_REPORT_TITLE').getValue() || 'SQL Report')
    : 'SQL Report';

  ui.to.value = defaultTo;
  ui.subj.value = `${defaultSubj} ${currentTimestamp().replace('_',' ').replace(/-/g,':')}`;
  ui.msg.value = '';
  ui.setError('');
  ui.setBusy(false);
  ui.open();

  ui.btnSend.onclick = () => {
    const toStr = ui.to.value.trim();
    const subj  = ui.subj.value.trim() || 'SQL Report';
    const note  = ui.msg.value.trim();

    const val = validateEmailList(toStr);
    if (!val.ok) {
      ui.setError('Please enter valid email addresses separated by comma or semicolon.');
      return;
    }

    ui.setBusy(true);
    const html = buildHtmlEmail(state, subj, note);

    apex.server.process('SEND_REPORT_EMAIL', {
      x01: val.emails.join(','),
      x02: subj,
      clob01: html
    },{
      success: function(){
        ui.setBusy(false);
        ui.close();
        apex.message.showPageSuccess('Report email queued.');
      },
      error: function(){
        ui.setBusy(false);
        ui.setError('Failed to send email. Please try again.');
      }
    });
  };
}

function validateEmailList(str) {
  const emails = str.split(/[;,]+/).map(s => s.trim()).filter(Boolean);
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (emails.length === 0) return { ok:false, emails:[], invalid:[] };
  const invalid = emails.filter(e => !re.test(e));
  return { ok: invalid.length === 0, emails, invalid };
}

function buildHtmlEmail(state, title, message) {
  const { headers, rows } = buildDataset(state);
  const esc = s => String(s).replace(/[&<>"']/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const headRow = `<tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}</tr>`;
  const bodyRows = rows.map(r=>`<tr>${r.map(c=>`<td>${esc(c)}</td>`).join('')}</tr>`).join('');
  const msgHtml = message ? `<div class="intro"><pre>${esc(message)}</pre></div>` : '';
  const css = `
    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:24px;}
    h1{font-size:18px;margin:0 0 12px;}
    .intro{margin:0 0 12px 0;padding:12px;border:1px solid #eee;border-radius:8px;background:#fafafa;white-space:pre-wrap}
    table{border-collapse:collapse;width:100%}
    th,td{border:1px solid #e5e5e5;padding:6px 8px;text-align:left;font-size:12px;vertical-align:top}
    thead th{background:#fafafa}
    footer{margin-top:12px;font-size:11px;opacity:.7}
  `;
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>${esc(title)}</title>
<style>${css}</style></head>
<body>
<h1>${esc(title)}</h1>
${msgHtml}
<table><thead>${headRow}</thead><tbody>${bodyRows}</tbody></table>
<footer>Generated ${new Date().toLocaleString()}</footer>
</body></html>`;
}


  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (m) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  }

  return { enhance };
})();



