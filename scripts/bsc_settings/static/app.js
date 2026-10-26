"use strict";
// BSC settings page. Plain JS, no framework. Every value from the API is shown with textContent.

const state = {meta: null, tables: {}, pending: new Map(), view: null, drafts: {}, showRemoved: {},
               filters: {}, note: "", user: null, review: null};
const views = {};
let token = null; // kept only in this variable: a reload means signing in again

// ---------------------------------------------------------------- helpers
function el(tag, attrs, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (k === "class") e.className = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (v === true) e.setAttribute(k, "");
    else if (v !== false && v != null) e.setAttribute(k, v);
  }
  for (const kid of kids.flat()) if (kid != null && kid !== false) e.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  return e;
}
const $ = (id) => document.getElementById(id);
function fill(node, ...kids) { node.replaceChildren(...kids.flat().filter((k) => k != null)); }
const spec = (name) => state.meta.tables.find((t) => t.name === name);

class ApiError extends Error {
  constructor(status, payload) { super((payload && payload.error) || ("Request failed (" + status + ")")); this.status = status; this.payload = payload || {}; }
}

async function api(method, path, body) {
  const headers = {};
  if (token) headers["X-BSC-Session"] = token;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  let res;
  try {
    res = await fetch(path, {method, headers, body: body === undefined ? undefined : JSON.stringify(body)});
  } catch (e) {
    throw new ApiError(0, {error: "Could not reach the page server: is start_bsc_settings still running?"});
  }
  let payload = {};
  try { payload = await res.json(); } catch (e) { /* keep {} */ }
  if (res.status === 401 && path !== "/api/signin") {
    showSignIn((payload && payload.error) || "Signed out: sign in again.");
    throw new ApiError(401, payload);
  }
  if (!res.ok) throw new ApiError(res.status, payload);
  return payload;
}

// ---------------------------------------------------------------- values and labels
function norm(col, v) {
  if (col.kind === "str") return v == null ? "" : String(v).trim();
  if (v === "" || v == null) return "";
  const n = Number(v);
  return Number.isNaN(n) ? String(v) : n;
}
const keyCols = (s) => s.columns.filter((c) => s.key.includes(c.name));
const dataCols = (s) => s.columns.filter((c) => !s.key.includes(c.name));
function keyValues(s, row) { return s.key.map((k) => norm(s.columns.find((c) => c.name === k), row[k])); }
const pkey = (table, kv) => table + "|" + JSON.stringify(kv);

function refOptions(table, col) {
  const m = state.meta;
  if (col.ref === "kpi" || col.ref === "kpi_or_default") {
    const o = m.kpis.map((k) => [k.kpi_code, k.kpi_code + " · " + k.kpi_name]);
    return col.ref === "kpi_or_default" ? [["*", "Default for every KPI"]].concat(o) : o;
  }
  if (col.ref === "objective") return m.objectives.map((o) => [o.objective_code, o.objective_code + " · " + o.objective_title]);
  if (col.ref === "branch" || col.ref === "branch_or_all") {
    const o = Object.keys(m.hospitals).map(Number).sort((a, b) => a - b).map((i) => [i, m.hospitals[String(i)]]);
    return col.ref === "branch_or_all" ? [[0, "All hospitals"]].concat(o) : o;
  }
  return null;
}
// a KPI or objective code is typed, not picked, in the table that defines it
function isOwnCode(table, col) { return (table === "map_bsc_kpi" && col.name === "kpi_code") || (table === "map_bsc_objective" && col.name === "objective_code"); }
function options(table, col) {
  if (col.allowed) return col.allowed.map((a) => [a, a]);
  if (col.kind === "flag") return [[0, "No"], [1, "Yes"]];
  if (col.name === "month") {
    const o = [];
    for (let i = table === "map_bsc_manual_value" ? 1 : 0; i <= 12; i++) o.push([i, i === 0 ? "Whole year" : String(i)]);
    return o;
  }
  return isOwnCode(table, col) ? null : refOptions(table, col);
}
function label(table, col, v) {
  const o = options(table, col);
  if (o) { const hit = o.find((p) => String(p[0]) === String(v)); if (hit) return hit[1]; }
  return v == null ? "" : String(v);
}
const sameVal = (col, a, b) => norm(col, a) === norm(col, b);

// ---------------------------------------------------------------- sign-in
function showSignIn(message) {
  token = null;
  state.meta = null; state.tables = {}; state.pending = new Map(); state.review = null; state.drafts = {};
  $("shell").hidden = true;
  $("signin").hidden = false;
  for (const d of document.querySelectorAll("dialog")) if (d.open) d.close();
  $("signin-msg").textContent = message || "";
  $("signin-pass").value = "";
  $("signin-user").focus();
}

async function signIn(ev) {
  ev.preventDefault();
  const user = $("signin-user").value.trim(), password = $("signin-pass").value;
  $("signin-pass").value = ""; // cleared as soon as it is read
  $("signin-msg").textContent = "Signing in...";
  try {
    const r = await api("POST", "/api/signin", {user, password});
    token = r.token; state.user = r.user;
    await start();
  } catch (e) {
    if (e.status !== 401 || !token) $("signin-msg").textContent = e.message;
  }
}

async function start() {
  state.meta = await api("GET", "/api/meta");
  $("signin").hidden = true; $("shell").hidden = false;
  $("signin-msg").textContent = "";
  $("banner").textContent = "Signed in to ClickHouse as " + state.meta.user + ". Saved changes show in the report tomorrow morning.";
  $("banner2").hidden = !state.meta.hospitals_fallback;
  $("banner2").textContent = "Hospital names could not be read; showing numbers.";
  renderNav();
  await selectTable(state.view && spec(state.view) ? state.view : state.meta.tables[0].name);
}

// ---------------------------------------------------------------- menu and table loading
function renderNav() {
  const kids = [];
  for (const g of state.meta.groups) {
    kids.push(el("h5", {}, g));
    for (const t of state.meta.tables.filter((x) => x.group === g)) {
      kids.push(el("button", {class: t.name === state.view ? "on" : "", onclick: () => selectTable(t.name)}, t.label));
    }
  }
  fill($("nav"), kids);
}

async function loadTable(name) {
  state.tables[name] = await api("GET", "/api/table?name=" + encodeURIComponent(name));
}

async function selectTable(name) {
  state.view = name;
  renderNav();
  fill($("content"), el("p", {class: "small"}, "Loading..."));
  try { await loadTable(name); } catch (e) { if (e.status !== 401) fill($("content"), el("p", {class: "bad"}, e.message)); return; }
  renderView();
  renderPending();
}

function registerView(table, renderFn) { views[table] = renderFn; }

function renderView() {
  if (!state.view || !state.tables[state.view]) return;
  const s = spec(state.view);
  const box = el("div", {});
  fill($("content"), el("h2", {}, s.label), box);
  if (views[state.view]) views[state.view](box, s); else renderGrid(box, s);
}

// ---------------------------------------------------------------- generic grid
function storedRows(table) {
  const t = state.tables[table], s = spec(table);
  const map = new Map();
  for (const r of t.current) map.set(JSON.stringify(keyValues(s, r)), {row: r, removed: false});
  if (state.showRemoved[table]) for (const r of t.removed) map.set(JSON.stringify(keyValues(s, r)), {row: r, removed: true});
  return map;
}
function storedAny(table, kv) {
  const t = state.tables[table], s = spec(table), k = JSON.stringify(kv);
  return t.current.concat(t.removed).find((r) => JSON.stringify(keyValues(s, r)) === k) || null;
}

function gridRows(s) {
  const map = storedRows(s.name);
  const rows = [];
  for (const p of state.pending.values()) {
    if (p.table !== s.name) continue;
    const kv = keyValues(s, p.row);
    if (!map.has(JSON.stringify(kv))) rows.push({row: p.row, pend: p, stored: storedAny(s.name, kv)});
  }
  const stored = [...map.entries()].map(([k, v]) => ({k, ...v}));
  stored.sort((a, b) => cmpKey(s, a.row, b.row));
  for (const r of stored) {
    const p = state.pending.get(pkey(s.name, JSON.parse(r.k)));
    const restoring = p && p.op === "upsert";
    rows.push({row: restoring ? p.row : r.row, pend: p, stored: r.row, removed: r.removed && !restoring});
  }
  return rows;
}
function cmpKey(s, a, b) {
  const ka = keyValues(s, a), kb = keyValues(s, b);
  for (let i = 0; i < ka.length; i++) {
    const c = String(ka[i]).localeCompare(String(kb[i]), undefined, {numeric: true});
    if (c) return c;
  }
  return 0;
}

function renderGrid(box, s) {
  const table = s.name;
  const f = state.filters[table] || (state.filters[table] = {});
  const body = el("tbody", {});
  const redraw = () => fill(body, draftRows(s, redraw), gridRows(s).filter((r) => passes(s, f, r.row)).map((r) => dataRow(s, r)));
  const bar = el("div", {class: "bar"},
    keyCols(s).map((c) => filterControl(table, c, f, redraw)),
    el("button", {class: "o", onclick: () => { (state.drafts[table] = state.drafts[table] || []).push(blankRow(s)); redraw(); }}, "+ Add row"),
    el("label", {class: "small"}, el("input", {type: "checkbox", checked: !!state.showRemoved[table],
      onchange: (e) => { state.showRemoved[table] = e.target.checked; redraw(); }}), " show removed"));
  const head = el("tr", {}, s.columns.map((c) => el("th", {}, c.label)), el("th", {}, "Last changed"), el("th", {}));
  box.append(bar, el("div", {class: "gridwrap"}, el("table", {class: "g"}, el("thead", {}, head), body)));
  redraw();
}

function filterControl(table, col, f, redraw) {
  const o = options(table, col);
  const set = (v) => { f[col.name] = v; redraw(); };
  if (o) {
    const sel = el("select", {onchange: (e) => set(e.target.value)}, el("option", {value: ""}, col.label + ": all"),
      o.map((p) => el("option", {value: String(p[0])}, p[1])));
    sel.value = f[col.name] || "";
    return sel;
  }
  return el("input", {placeholder: col.label + " contains", value: f[col.name] || "", oninput: (e) => set(e.target.value)});
}
function passes(s, f, row) {
  return keyCols(s).every((c) => {
    const want = f[c.name];
    if (!want) return true;
    return options(s.name, c) ? String(norm(c, row[c.name])) === want : String(row[c.name]).toLowerCase().includes(want.toLowerCase());
  });
}

function dataRow(s, r) {
  const gone = r.removed || (r.pend && r.pend.op === "remove");
  const tr = el("tr", {class: gone ? "gone" : (!r.stored || r.stored.is_deleted ? "new" : "")});
  const kv = keyValues(s, r.row);
  for (const c of s.columns) {
    const isKey = s.key.includes(c.name);
    const td = el("td", {});
    const changed = r.stored && !isKey && !sameVal(c, r.row[c.name], r.stored[c.name]);
    if (changed) td.className = "ch";
    if (isKey || gone) td.textContent = label(s.name, c, r.row[c.name]);
    else td.append(cellEditor(s, c, r));
    tr.append(td);
  }
  const last = r.stored || r.row;
  tr.append(el("td", {class: "small"}, last.changed_at ? last.changed_at.slice(0, 10) + " " + (last.changed_by || "") : "new"));
  tr.append(el("td", {class: "small"}, rowActions(s, r, kv)));
  return tr;
}

function rowActions(s, r, kv) {
  const acts = [];
  const pk = pkey(s.name, kv);
  if (r.stored) acts.push(el("button", {class: "lnk", onclick: () => showHistory(s.name, kv)}, "History"));
  if (r.pend) acts.push(el("button", {class: "lnk", onclick: () => discard(pk)}, r.pend.op === "remove" ? "Undo remove" : "Discard"));
  else if (r.stored && !r.removed) acts.push(el("button", {class: "lnk", onclick: () => addPending({table: s.name, op: "remove", row: keyRow(s, r.row), base_changed_at: r.stored.changed_at})}, "Remove"));
  return acts;
}
function keyRow(s, row) { const o = {}; for (const k of s.key) o[k] = row[k]; return o; }

function cellEditor(s, c, r) {
  const o = options(s.name, c);
  const cur = r.row[c.name];
  const commit = (v) => editCell(s, r, c, v);
  if (o) {
    const sel = el("select", {onchange: (e) => commit(e.target.value)}, o.map((p) => el("option", {value: String(p[0])}, p[1])));
    if (!o.some((p) => String(p[0]) === String(cur))) sel.prepend(el("option", {value: String(cur)}, String(cur)));
    sel.value = String(cur);
    return sel;
  }
  return el("input", {value: cur == null ? "" : String(cur), onchange: (e) => commit(e.target.value)});
}

function editCell(s, r, col, value) {
  const row = {};
  for (const c of s.columns) row[c.name] = r.row[c.name];
  row[col.name] = value;
  const kv = keyValues(s, row), pk = pkey(s.name, kv);
  const base = r.pend ? r.pend.base_changed_at : (r.stored ? r.stored.changed_at : null);
  if (r.stored && s.columns.every((c) => sameVal(c, row[c.name], r.stored[c.name])) && !r.stored.is_deleted) { discard(pk); return; }
  addPending({table: s.name, op: "upsert", row, base_changed_at: base});
}

// draft rows: a new key typed into a full row, added to the pending list when complete
function blankRow(s) {
  const row = {};
  for (const c of s.columns) row[c.name] = c.kind === "flag" ? 0 : "";
  return row;
}
function draftRows(s, redraw) {
  return (state.drafts[s.name] || []).map((d, i) => {
    const msg = el("span", {class: "bad"});
    const tr = el("tr", {class: "draft"});
    for (const c of s.columns) {
      const o = options(s.name, c);
      const set = (v) => { d[c.name] = v; };
      let w;
      if (o) {
        w = el("select", {onchange: (e) => set(e.target.value)}, c.kind === "flag" ? [] : el("option", {value: ""}, "Choose..."),
          o.map((p) => el("option", {value: String(p[0])}, p[1])));
        w.value = String(d[c.name]);
      } else w = el("input", {value: d[c.name], oninput: (e) => set(e.target.value)});
      tr.append(el("td", {}, w));
    }
    tr.append(el("td", {}, msg), el("td", {class: "small"},
      el("button", {class: "lnk", onclick: () => addDraft(s, d, i, msg, redraw)}, "Add to changes"),
      el("button", {class: "lnk", onclick: () => { state.drafts[s.name].splice(i, 1); redraw(); }}, "Cancel")));
    return tr;
  });
}
function addDraft(s, d, i, msg, redraw) {
  const missing = keyCols(s).filter((c) => String(d[c.name]).trim() === "");
  if (missing.length) { msg.textContent = "Fill in: " + missing.map((c) => c.label).join(", "); return; }
  const row = {};
  for (const c of s.columns) row[c.name] = c.kind === "str" ? String(d[c.name]) : (c.kind === "flag" ? Number(d[c.name]) : String(d[c.name]).trim());
  const stored = storedAny(s.name, keyValues(s, row));
  state.drafts[s.name].splice(i, 1);
  addPending({table: s.name, op: "upsert", row, base_changed_at: stored ? stored.changed_at : null});
}

// ---------------------------------------------------------------- pending changes
function addPending(change) {
  const s = spec(change.table);
  state.pending.set(pkey(change.table, keyValues(s, change.row)), change);
  state.review = null;
  renderPending();
  renderView();
}
function discard(pk) {
  state.pending.delete(pk);
  state.review = null;
  renderPending();
  renderView();
}

function describe(p) {
  const s = spec(p.table), kv = keyValues(s, p.row);
  const who = keyCols(s).map((c) => label(p.table, c, p.row[c.name])).join(" / ");
  if (p.op === "remove") return s.label + ": " + who + " - remove";
  const stored = storedAny(p.table, kv);
  if (!stored || stored.is_deleted) return s.label + ": " + who + " - " + (stored ? "restore" : "new row");
  const diffs = dataCols(s).filter((c) => !sameVal(c, p.row[c.name], stored[c.name]))
    .map((c) => c.label + ": " + label(p.table, c, stored[c.name]) + " → " + label(p.table, c, p.row[c.name]));
  return s.label + ": " + who + " - " + diffs.join("; ");
}

function renderPending() {
  const box = $("pending");
  const items = [...state.pending.entries()];
  if (!items.length) { fill(box, el("span", {class: "small"}, "No changes waiting.")); return; }
  const noteIn = el("input", {class: "note", value: state.note, placeholder: "Why? (required, saved on every row)",
    oninput: (e) => { state.note = e.target.value; }});
  fill(box,
    el("b", {}, items.length + (items.length === 1 ? " change waiting" : " changes waiting")),
    el("ul", {}, items.map(([pk, p]) => el("li", {}, describe(p), " ",
      el("button", {class: "lnk", onclick: () => discard(pk)}, "Discard")))),
    el("div", {class: "bar"}, el("span", {class: "small"}, "Note (for every row):"), noteIn,
      el("button", {class: "btn", onclick: openReview}, "Review & save"),
      el("button", {class: "o", onclick: () => { state.pending = new Map(); state.review = null; renderPending(); renderView(); }}, "Discard all")));
}

// ---------------------------------------------------------------- review and insert
function payload() {
  return {note: state.note.trim(), changes: [...state.pending.values()].map((p) => ({table: p.table, op: p.op, row: p.row, base_changed_at: p.base_changed_at ?? null}))};
}

async function openReview() {
  const dlg = $("review-dialog");
  if (!state.pending.size) return;
  if (!dlg.open) dlg.showModal();
  if (!state.note.trim()) { showReview(null, "Type a note first: it is saved on every row."); return; }
  fill(dlg, el("p", {class: "small"}, "Checking..."));
  try {
    state.review = await api("POST", "/api/review", payload());
  } catch (e) { if (e.status !== 401) showReview(null, e.message); return; }
  showReview(state.review);
}

function showReview(rev, error, result) {
  const dlg = $("review-dialog");
  const kids = [el("h2", {}, "Review before saving")];
  if (error) kids.push(el("p", {class: "issue error"}, error));
  if (result) kids.push(result);
  if (rev) {
    for (const i of rev.issues) kids.push(el("div", {class: "issue " + i.level}, (i.level === "error" ? "Error" : "Warning") + " - " + (spec(i.table) ? spec(i.table).label : i.table) + (i.key.length ? " (" + i.key.join(", ") + ")" : "") + ": " + i.message));
    for (const [t, rows] of Object.entries(rev.rows)) kids.push(el("h3", {}, spec(t).label + " (" + rows.length + (rows.length === 1 ? " row)" : " rows)")), rowsTable(spec(t), rows));
    if (!rev.can_insert) kids.push(el("p", {class: "bad"}, "Fix the errors, then review again. Nothing was saved."));
  }
  const acts = [];
  if (rev && !result) acts.push(el("button", {class: "btn", disabled: !rev.can_insert, onclick: doInsert}, "Insert"));
  if (!result && state.pending.size) acts.push(el("button", {class: "o", onclick: openReview}, "Review again"));
  acts.push(el("button", {class: "o", onclick: () => dlg.close()}, result ? "Close" : "Back"));
  kids.push(el("div", {class: "bar"}, acts));
  fill(dlg, kids);
}

function rowsTable(s, rows) {
  const cols = s.columns.map((c) => c.name).concat(["changed_at", "changed_by", "change_note", "is_deleted"]);
  return el("div", {class: "gridwrap"}, el("table", {class: "g"}, el("thead", {}, el("tr", {}, cols.map((c) => el("th", {}, c)))),
    el("tbody", {}, rows.map((r) => el("tr", {}, cols.map((c) => el("td", {}, r[c] == null ? "" : String(r[c]))))))));
}

async function doInsert() {
  const rev = state.review;
  if (!rev) return;
  fill($("review-dialog"), el("p", {class: "small"}, "Saving..."));
  try {
    const r = await api("POST", "/api/insert", {review_id: rev.review_id});
    state.pending = new Map(); state.note = ""; state.review = null;
    showReview(null, null, summary("Saved.", r.inserted));
    await reloadTouched(Object.keys(r.inserted));
  } catch (e) {
    if (e.status === 401) return;
    state.review = null;
    if (e.status === 502) await partialFailure(e.payload, rev);
    else showReview(null, e.message + " Your changes are still waiting: review again.");
  }
}

function summary(title, counts) {
  return el("div", {}, el("p", {class: "ok"}, title), el("ul", {}, Object.entries(counts).map(([t, n]) => el("li", {}, (spec(t) ? spec(t).label : t) + ": " + n + (n === 1 ? " row" : " rows")))));
}

async function partialFailure(p, rev) {
  const done = p.inserted || {};
  for (const [pk, c] of [...state.pending]) if (done[c.table]) state.pending.delete(pk);
  const name = (t) => spec(t) ? spec(t).label : t;
  const out = el("div", {},
    el("p", {class: "bad"}, "Only part of the changes were saved. " + (p.error || "")),
    el("p", {}, "Saved: " + (Object.keys(done).map(name).join(", ") || "none")),
    el("p", {}, "Failed: " + (p.failed ? name(p.failed) : "none")),
    el("p", {}, "Not saved: " + ((p.not_inserted || []).map(name).join(", ") || "none")),
    el("p", {class: "small"}, "The saved tables' changes are cleared from the list; the rest are still waiting. Review again to retry."));
  showReview(null, null, out);
  await reloadTouched(Object.keys(rev.rows));
}

async function reloadTouched(tables) {
  renderPending();
  try {
    state.meta = Object.assign(state.meta, await api("GET", "/api/meta"));
    for (const t of new Set(tables.concat(state.view ? [state.view] : []))) await loadTable(t);
  } catch (e) { return; }
  renderPending();
  renderView();
}

// ---------------------------------------------------------------- history
function showHistory(table, key) {
  const s = spec(table), dlg = $("history-dialog");
  const k = JSON.stringify(key);
  const rows = state.tables[table].all.filter((r) => JSON.stringify(keyValues(s, r)) === k)
    .sort((a, b) => (a.changed_at < b.changed_at ? 1 : -1));
  const latest = rows.length ? rows[0].changed_at : null;
  const cols = s.columns.map((c) => c.name).concat(["changed_at", "changed_by", "change_note", "is_deleted"]);
  const restore = (r) => {
    const row = {};
    for (const c of s.columns) row[c.name] = r[c.name];
    dlg.close();
    addPending({table, op: "upsert", row, base_changed_at: latest});
  };
  const tr = (r) => el("tr", {}, cols.map((c) => el("td", {}, r[c] == null ? "" : String(r[c]))),
    el("td", {}, Number(r.is_deleted) ? "" : el("button", {class: "lnk", onclick: () => restore(r)}, "Restore this version")));
  fill(dlg, el("h2", {}, s.label + ": history"), el("p", {class: "small"}, "Newest first."),
    el("div", {class: "gridwrap"}, el("table", {class: "g"}, el("thead", {}, el("tr", {}, cols.map((c) => el("th", {}, c)), el("th", {}))), el("tbody", {}, rows.map(tr)))),
    el("div", {class: "bar"}, el("button", {class: "o", onclick: () => dlg.close()}, "Close")));
  dlg.showModal();
}

// ---------------------------------------------------------------- boot
$("signin-form").addEventListener("submit", signIn);
showSignIn("");
