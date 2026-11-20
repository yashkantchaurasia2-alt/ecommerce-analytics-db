/* E-Commerce Analytics DB: renders saved query results from data/results.json */
(function () {
  "use strict";

  const state = { data: null, filter: "All", search: "", charts: [], erRendered: false, dashRendered: false };
  const $ = (sel) => document.querySelector(sel);
  const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 });
  const grp = new Intl.NumberFormat("en-IN", { maximumFractionDigits: 2 });

  /* ---------------- theme ---------------- */
  function storedTheme() { try { return localStorage.getItem("theme"); } catch (e) { return null; } }
  function saveTheme(t) { try { localStorage.setItem("theme", t); } catch (e) { /* private mode */ } }
  function currentTheme() {
    const set = document.documentElement.getAttribute("data-theme");
    if (set) return set;
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  const initial = storedTheme();
  if (initial) document.documentElement.setAttribute("data-theme", initial);
  $("#themeToggle").addEventListener("click", () => {
    const next = currentTheme() === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    saveTheme(next);
    rerenderVisuals();
  });

  /* ---------------- helpers ---------------- */
  function esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
  function q(prefix) {
    if (!state.data) return null;
    return state.data.queries.find((x) => x.title === prefix || x.title.startsWith(prefix + " ")) || null;
  }
  function col(query, name) {
    const i = query ? query.columns.indexOf(name) : -1;
    return i < 0 ? [] : query.rows.map((r) => r[i]);
  }
  function fmtCell(v, colName) {
    if (v === null || v === undefined) return { html: "NULL", cls: "null" };
    if (typeof v === "number") {
      const idLike = /(^|_)id$|year|level|rank|rnk|row_num|quartile|depth|seq/i.test(colName);
      return { html: idLike || Math.abs(v) < 10000 ? String(v) : grp.format(v), cls: "num" };
    }
    return { html: esc(v), cls: "" };
  }
  function tableHTML(columns, rows) {
    const head = columns.map((c) => `<th scope="col">${esc(c)}</th>`).join("");
    const body = rows.map((r) => "<tr>" + r.map((v, i) => {
      const f = fmtCell(v, columns[i]);
      return `<td class="${f.cls}">${f.html}</td>`;
    }).join("") + "</tr>").join("");
    return `<table class="data"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
  }
  const KEYWORDS = /\b(SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|CROSS|ON|AND|OR|NOT|IN|EXISTS|GROUP|BY|ORDER|HAVING|LIMIT|AS|WITH|RECURSIVE|UNION|ALL|INTERSECT|EXCEPT|DISTINCT|CASE|WHEN|THEN|ELSE|END|OVER|PARTITION|WINDOW|ROWS|BETWEEN|PRECEDING|CURRENT|ROW|UNBOUNDED|DESC|ASC|IS|NULL|LIKE|EXPLAIN|SHOW|GRANTS|FOR|USING|COUNT|SUM|AVG|MIN|MAX|RANK|DENSE_RANK|ROW_NUMBER|LAG|LEAD|NTILE|ANY|COALESCE|ROUND)\b/g;
  function highlight(sql) { return esc(sql).replace(KEYWORDS, '<span class="kw">$1</span>'); }

  /* ---------------- routing ---------------- */
  const TABS = ["overview", "schema", "normalization", "queries", "dashboard", "tests"];
  function show() {
    const id = (location.hash || "#overview").slice(1);
    const tab = TABS.includes(id) ? id : "overview";
    TABS.forEach((t) => { document.getElementById(t).hidden = t !== tab; });
    document.querySelectorAll(".tabs a").forEach((a) => a.classList.toggle("active", a.dataset.tab === tab));
    const active = document.querySelector(`.tabs a[data-tab="${tab}"]`);
    if (active && active.scrollIntoView) active.scrollIntoView({ block: "nearest", inline: "nearest" });
    if (tab === "schema") renderER();
    if (tab === "dashboard") renderDashboard();
  }
  window.addEventListener("hashchange", () => { show(); window.scrollTo(0, 0); });

  /* ---------------- overview ---------------- */
  function renderStats() {
    const c1 = q("C1"), a2 = q("A2"), b1 = q("B1"), b2 = q("B2");
    const v = (query, name) => col(query, name)[0];
    const stats = [
      { label: "Net revenue", value: inr.format(v(c1, "net_revenue") || 0), note: "successful payments", c: "--accent" },
      { label: "Paid orders", value: v(c1, "paid_orders") ?? "–", note: "not cancelled", c: "--accent-2" },
      { label: "Avg order value", value: inr.format(v(c1, "avg_order_value") || 0), note: "C1", c: "--accent-3" },
      { label: "Repeat rate", value: (v(a2, "repeat_rate_pct") ?? "–") + "%", note: `${v(a2, "repeat_customers") ?? "–"} of ${v(a2, "ordering_customers") ?? "–"} customers came back`, c: "--accent-4" },
      { label: "Top by units", value: v(b1, "product_name") || "–", note: `${v(b1, "units_sold") ?? ""} units (B1)`, c: "--accent-5", text: true },
      { label: "Top by revenue", value: v(b2, "product_name") || "–", note: `${inr.format(v(b2, "gross_value") || 0)} (B2)`, c: "--accent", text: true },
    ];
    $("#statGrid").innerHTML = stats.map((s) =>
      `<div class="stat" style="--c: var(${s.c})"><div class="label">${esc(s.label)}</div>` +
      `<div class="value${s.text ? " text" : ""}">${esc(s.value)}</div><div class="note">${esc(s.note)}</div></div>`).join("");
    const t = state.data.tests;
    $("#testCountInline").textContent = `${t.passed} automated checks, ${t.failed} failing`;
  }

  /* ---------------- ER diagram ---------------- */
  function mermaidTheme() {
    return {
      startOnLoad: false, theme: "base", securityLevel: "strict",
      er: { useMaxWidth: false },
      themeVariables: {
        fontFamily: "Inter, sans-serif", fontSize: "14px",
        primaryColor: css("--surface-2"), primaryTextColor: css("--ink"), primaryBorderColor: css("--accent"),
        lineColor: css("--ink-faint"), secondaryColor: css("--bg-soft"), tertiaryColor: css("--surface"),
        background: css("--surface"), mainBkg: css("--surface-2"), nodeBorder: css("--accent"),
        attributeBackgroundColorOdd: css("--surface"), attributeBackgroundColorEven: css("--bg-soft"),
      },
    };
  }
  function renderER(force) {
    const el = $("#erDiagram");
    if (!state.data || (state.erRendered && !force)) return;
    if (!window.mermaid) { el.textContent = "The diagram library could not load (offline?). The Mermaid source is in docs/er-diagram.md."; return; }
    el.removeAttribute("data-processed");
    el.textContent = state.data.er_mermaid;
    window.mermaid.initialize(mermaidTheme());
    window.mermaid.run({ nodes: [el] }).then(() => { state.erRendered = true; })
      .catch(() => { el.textContent = "Could not draw the diagram. The source is in docs/er-diagram.md."; });
  }

  /* ---------------- query explorer ---------------- */
  function renderChips() {
    const counts = {};
    state.data.queries.forEach((x) => { counts[x.component] = (counts[x.component] || 0) + 1; });
    const order = ["All", "DML", "DCL", "TCL", "Joins", "Subqueries", "Set operations", "Analytics", "Views", "Indexes", "Window functions & CTEs"];
    $("#componentChips").innerHTML = order.filter((c) => c === "All" || counts[c]).map((c) =>
      `<button type="button" class="chip" data-c="${esc(c)}" aria-pressed="${c === state.filter}">${esc(c)}` +
      `<span class="n">${c === "All" ? state.data.queries.length : counts[c]}</span></button>`).join("");
  }
  function renderQueries() {
    const term = state.search.trim().toLowerCase();
    const list = state.data.queries.filter((x) =>
      (state.filter === "All" || x.component === state.filter) &&
      (!term || [x.id, x.title, x.description, x.sql, x.component, x.file].join(" ").toLowerCase().includes(term)));
    $("#resultCount").textContent = `${list.length} of ${state.data.queries.length} queries`;
    if (!list.length) { $("#queryList").innerHTML = `<p class="empty">No query matches “${esc(state.search)}”.</p>`; return; }
    $("#queryList").innerHTML = list.map((x, i) => {
      const name = x.id ? x.title.slice(x.id.length).replace(/^\s*[-–]?\s*/, "") : x.title;
      return `<details class="q" data-i="${state.data.queries.indexOf(x)}">
        <summary>
          <span class="q-id">${esc(x.id || "·")}</span>
          <span class="q-title">${esc(name)}<span class="q-meta">${esc(x.component)} · sql/${esc(x.file)} · ${x.total_rows} row${x.total_rows === 1 ? "" : "s"}</span></span>
          <span class="q-chev" aria-hidden="true">›</span>
        </summary>
        <div class="q-body"></div>
      </details>`;
    }).join("");
  }
  function fillQuery(details) {
    const body = details.querySelector(".q-body");
    if (body.childElementCount) return;
    const x = state.data.queries[+details.dataset.i];
    const shown = x.rows.length < x.total_rows ? `Showing ${x.rows.length} of ${x.total_rows} rows.` : `${x.total_rows} row${x.total_rows === 1 ? "" : "s"}.`;
    const desc = esc(x.description.replace(/^[A-Z]\d+[a-z]?\.\s*/, ""))
      .replace(/Business (question|need):/g, "<b>Business $1:</b>");
    body.innerHTML =
      (x.description ? `<p class="q-desc">${desc}</p>` : "") +
      `<div class="sql-box"><button type="button" class="copy-btn">Copy SQL</button><pre><code>${highlight(x.sql)}</code></pre></div>` +
      (x.columns.length ? `<div class="table-wrap">${tableHTML(x.columns, x.rows)}</div>` : "") +
      `<p class="rows-note">${shown}</p>`;
    body.querySelector(".copy-btn").addEventListener("click", (e) => {
      const btn = e.currentTarget;
      const done = () => { btn.textContent = "Copied"; setTimeout(() => { btn.textContent = "Copy SQL"; }, 1400); };
      if (navigator.clipboard) navigator.clipboard.writeText(x.sql).then(done).catch(() => { btn.textContent = "Copy failed"; });
    });
  }
  $("#queryList").addEventListener("toggle", (e) => { if (e.target.open) fillQuery(e.target); }, true);
  $("#componentChips").addEventListener("click", (e) => {
    const b = e.target.closest(".chip");
    if (!b) return;
    state.filter = b.dataset.c;
    document.querySelectorAll(".chip").forEach((c) => c.setAttribute("aria-pressed", String(c === b)));
    renderQueries();
  });
  $("#querySearch").addEventListener("input", (e) => { state.search = e.target.value; renderQueries(); });

  /* ---------------- dashboard ---------------- */
  function palette() { return ["--accent", "--accent-2", "--accent-3", "--accent-4", "--accent-5"].map(css); }
  function baseOptions(extra) {
    const ink = css("--ink-soft"), line = css("--line");
    return Object.assign({
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { labels: { color: ink, font: { family: "Inter" }, boxWidth: 12 } },
                 tooltip: { callbacks: {} } },
      scales: {
        x: { ticks: { color: ink, font: { family: "Inter" } }, grid: { color: line } },
        y: { ticks: { color: ink, font: { family: "Inter" } }, grid: { color: line } },
      },
    }, extra || {});
  }
  function makeChart(id, config) {
    const canvas = document.getElementById(id);
    if (!window.Chart) { canvas.parentElement.innerHTML = '<p class="chart-fallback">Chart library could not load (offline?). The numbers are in the Query Explorer.</p>'; return; }
    state.charts.push(new window.Chart(canvas, config));
  }
  function renderDashboard(force) {
    if (!state.data || (state.dashRendered && !force)) return;
    state.charts.forEach((c) => c.destroy());
    state.charts = [];
    const [c1, c2, c3, c4, c5] = palette();
    const rupees = (v) => inr.format(v);
    const lakh = (v) => "₹" + (v / 100000).toFixed(1) + "L";

    const monthly = q("C4"), moving = q("W6");
    makeChart("chartMonthly", {
      type: "line",
      data: {
        labels: col(monthly, "month"),
        datasets: [
          { label: "Net revenue", data: col(monthly, "net_revenue"), borderColor: c1, backgroundColor: c1 + "33", fill: true, cubicInterpolationMode: "monotone", pointRadius: 4 },
          { label: "3-month moving avg", data: col(moving, "moving_avg_3m"), borderColor: c2, borderDash: [6, 5], cubicInterpolationMode: "monotone", pointRadius: 0 },
        ],
      },
      options: baseOptions({ scales: { x: { ticks: { color: css("--ink-soft") }, grid: { display: false } },
        y: { beginAtZero: true, ticks: { color: css("--ink-soft"), callback: lakh }, grid: { color: css("--line") } } },
        plugins: { legend: { labels: { color: css("--ink-soft"), boxWidth: 12 } }, tooltip: { callbacks: { label: (ctx) => `${ctx.dataset.label}: ${rupees(ctx.parsed.y)}` } } } }),
    });

    const methods = q("C2");
    makeChart("chartMethods", {
      type: "doughnut",
      data: { labels: col(methods, "method"), datasets: [{ data: col(methods, "net_revenue"), backgroundColor: [c1, c2, c3, c4], borderColor: css("--surface"), borderWidth: 3 }] },
      options: { responsive: true, maintainAspectRatio: false, cutout: "62%",
        plugins: { legend: { position: "bottom", labels: { color: css("--ink-soft"), boxWidth: 12 } },
                   tooltip: { callbacks: { label: (ctx) => `${ctx.label}: ${rupees(ctx.parsed)} (${col(methods, "share_pct")[ctx.dataIndex]}%)` } } } },
    });

    const fails = q("C3");
    makeChart("chartFailures", {
      type: "bar",
      data: { labels: col(fails, "method"), datasets: [{ label: "Failure rate %", data: col(fails, "failure_rate_pct"), backgroundColor: c4, borderRadius: 8 }] },
      options: baseOptions({ plugins: { legend: { display: false } },
        scales: { x: { ticks: { color: css("--ink-soft") }, grid: { display: false } }, y: { ticks: { color: css("--ink-soft"), callback: (v) => v + "%" }, grid: { color: css("--line") } } } }),
    });

    const top = q("B1");
    makeChart("chartTop", {
      type: "bar",
      data: { labels: col(top, "product_name"), datasets: [{ label: "Units sold", data: col(top, "units_sold"), backgroundColor: c2, borderRadius: 8 }] },
      options: baseOptions({ indexAxis: "y", plugins: { legend: { display: false } },
        scales: { x: { ticks: { color: css("--ink-soft") }, grid: { color: css("--line") } },
                  y: { ticks: { color: css("--ink-soft"), autoSkip: false, callback: function (v) { const l = this.getLabelForValue(v); return l.length > 26 ? l.slice(0, 25) + "…" : l; } }, grid: { display: false } } } }),
    });

    const quart = q("W7b");
    makeChart("chartQuartiles", {
      type: "bar",
      data: { labels: col(quart, "quartile"), datasets: [{ label: "Share of lifetime value %", data: col(quart, "share_pct"), backgroundColor: [c1, c3, c5, c4], borderRadius: 8 }] },
      options: baseOptions({ plugins: { legend: { display: false }, tooltip: { callbacks: { label: (ctx) => `${ctx.parsed.y}% of value · ${col(quart, "customers")[ctx.dataIndex]} customers` } } },
        scales: { x: { ticks: { color: css("--ink-soft") }, grid: { display: false } }, y: { ticks: { color: css("--ink-soft"), callback: (v) => v + "%" }, grid: { color: css("--line") } } } }),
    });

    const ties = q("W1");
    if (ties) {
      const keep = ["product_name", "units_sold", "row_num", "rnk", "dense_rnk"].map((c) => ties.columns.indexOf(c));
      $("#tiesTable").innerHTML = tableHTML(["product", "units", "ROW_NUMBER", "RANK", "DENSE_RANK"],
        ties.rows.slice(0, 8).map((r) => keep.map((i) => r[i])));
    }
    state.dashRendered = true;
  }
  function rerenderVisuals() {
    if (state.dashRendered) renderDashboard(true);
    if (state.erRendered) renderER(true);
  }

  /* ---------------- tests ---------------- */
  function renderTests() {
    const t = state.data.tests;
    $("#testSummary").innerHTML =
      `<span class="badge${t.failed ? " bad" : ""}">${t.failed ? "✗" : "✓"} ${t.passed} passed · ${t.failed} failed</span>` +
      `<span class="hint">${t.sections.length} groups of checks · click a group to see every check</span>`;
    $("#testSections").innerHTML = t.sections.map((s) => {
      const ok = s.checks.filter((c) => c.status === "PASS").length;
      return `<details><summary><span>${esc(s.name)}</span><span class="count">${ok}/${s.checks.length}</span></summary><ul>` +
        s.checks.map((c) => `<li><span class="${c.status === "PASS" ? "ok" : "ko"}">${c.status === "PASS" ? "✓" : "✗"}</span>` +
          `<span>${esc(c.name)}${c.detail ? `<span class="detail">${esc(c.detail)}</span>` : ""}</span></li>`).join("") +
        "</ul></details>";
    }).join("");
  }

  /* ---------------- boot ---------------- */
  show();
  fetch("data/results.json")
    .then((r) => { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then((data) => {
      state.data = data;
      renderStats();
      renderChips();
      renderQueries();
      renderTests();
      show();
    })
    .catch(() => {
      const msg = '<p class="empty">Could not load <code>data/results.json</code>. If you opened this file directly, run a local server instead: ' +
        '<code>python -m http.server -d website 8000</code> and open <code>http://localhost:8000</code>.</p>';
      ["#statGrid", "#queryList", "#testSections"].forEach((s) => { $(s).innerHTML = msg; });
    });
})();
