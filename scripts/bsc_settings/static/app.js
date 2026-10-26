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
    const o = Object.keys(m.hospitals).map(Number).sort((a, b) => a - b).map((i) => [i, i + " · " + m.hospitals[String(i)]]);
    return col.ref === "branch_or_all" ? [[0, "0 · All hospitals"]].concat(o) : o;
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
  const focus = focusOf();
  const box = el("div", {});
  fill($("content"), el("h2", {}, s.label), box);
  if (views[state.view]) views[state.view](box, s); else renderGrid(box, s);
  restoreFocus(focus);
}

// A re-render replaces the inputs. Editors carry data-fid (table, key, column) so focus survives it.
function focusOf() {
  const a = document.activeElement;
  if (!a || !a.dataset || !a.dataset.fid || !$("content").contains(a)) return null;
  let start = null, end = null;
  try { start = a.selectionStart; end = a.selectionEnd; } catch (e) { /* not a text input */ }
  return {fid: a.dataset.fid, start, end};
}
function restoreFocus(f) {
  if (!f) return;
  const n = [...$("content").querySelectorAll("[data-fid]")].find((x) => x.dataset.fid === f.fid);
  if (!n) return;
  n.focus();
  try { if (f.start != null) n.setSelectionRange(f.start, f.end); } catch (e) { /* not a text input */ }
}
const fidOf = (s, row, col) => s.name + "|" + JSON.stringify(keyValues(s, row)) + "|" + col.name;

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
    else td.append(cellEditor(s, c, r, tr));
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

function cellEditor(s, c, r, tr) {
  const o = options(s.name, c);
  const cur = r.row[c.name];
  const commit = (v) => editCell(s, r, c, v, tr);
  if (o) {
    const sel = el("select", {"data-fid": fidOf(s, r.row, c), onchange: (e) => commit(e.target.value)}, o.map((p) => el("option", {value: String(p[0])}, p[1])));
    if (!o.some((p) => String(p[0]) === String(cur))) sel.prepend(el("option", {value: String(cur)}, String(cur)));
    sel.value = String(cur);
    return sel;
  }
  return el("input", {"data-fid": fidOf(s, r.row, c), value: cur == null ? "" : String(cur), onchange: (e) => commit(e.target.value)});
}

// An edit updates the pending list and this row in place: the inputs are not rebuilt, so the
// cell the user clicked or tabbed into keeps its focus.
function editCell(s, r, col, value, tr) {
  const row = {};
  for (const c of s.columns) row[c.name] = r.row[c.name];
  row[col.name] = value;
  const kv = keyValues(s, row), pk = pkey(s.name, kv);
  const base = r.pend ? r.pend.base_changed_at : (r.stored ? r.stored.changed_at : null);
  const reverted = r.stored && s.columns.every((c) => sameVal(c, row[c.name], r.stored[c.name])) && !r.stored.is_deleted;
  if (reverted) state.pending.delete(pk);
  else state.pending.set(pk, {table: s.name, op: "upsert", row, base_changed_at: base});
  state.review = null;
  r.row = row; r.pend = state.pending.get(pk);
  renderPending();
  refreshRow(s, r, tr, kv);
}
function refreshRow(s, r, tr, kv) {
  s.columns.forEach((c, i) => {
    if (s.key.includes(c.name)) return;
    tr.children[i].className = r.stored && !sameVal(c, r.row[c.name], r.stored[c.name]) ? "ch" : "";
  });
  fill(tr.children[s.columns.length + 1], rowActions(s, r, kv));
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
  } catch (e) {
    if (e.status !== 401) fill($("content"), el("p", {class: "bad"}, "Saved, but the table could not be reloaded: " + e.message + ". Pick the table again."));
    return;
  }
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

// ---------------------------------------------------------------- special views
// Both views follow the generic grid's rule: an edit updates state.pending and the cell in place,
// the inputs are never rebuilt, so focus and caret stay where the user is typing.
// null = empty, NaN = not a number, else the number
function parseNum(text) {
  const t = String(text).trim();
  if (t === "") return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : NaN;
}
const showNum = (v) => (v == null ? "" : String(v));
const hospitalIds = () => Object.keys(state.meta.hospitals).map(Number).sort((a, b) => a - b);
const hospitalName = (id) => (state.meta.hospitals[String(id)] != null ? state.meta.hospitals[String(id)] : String(id));

// ---- manual values
function defaultPeriod() {
  const d = new Date(), m = d.getMonth(); // 0-based, so this is the last full month 1-based
  return m === 0 ? {year: d.getFullYear() - 1, month: 12} : {year: d.getFullYear(), month: m};
}
state.mv = null;        // {year, month}
state.mvDrafts = {};    // pkey -> typed values of a cell that is not complete yet

function renderManual(box, s) {
  const mv = state.mv || (state.mv = defaultPeriod());
  const kpis = state.meta.kpis.filter((k) => k.value_source === "manual" && k.status === "active")
    .sort((a, b) => Number(a.kpi_num) - Number(b.kpi_num));
  const stored = new Map();
  for (const r of state.tables[s.name].current) {
    if (Number(r.year) === mv.year && Number(r.month) === mv.month) stored.set(r.kpi_code + "|" + Number(r.branch_id), r);
  }
  const thisYear = new Date().getFullYear(), years = [];
  for (let y = thisYear - 3; y <= thisYear + 1; y++) years.push(y);
  if (!years.includes(mv.year)) years.push(mv.year);
  const pick = (name, vals, labelFn) => {
    const sel = el("select", {"data-fid": "mv|" + name, onchange: (e) => { mv[name] = Number(e.target.value); renderView(); }},
      vals.map((v) => el("option", {value: String(v)}, labelFn(v))));
    sel.value = String(mv[name]);
    return sel;
  };
  const ids = hospitalIds();
  const head = el("tr", {}, el("th", {}, "KPI"), ids.map((i) => el("th", {}, i + " · " + hospitalName(i))));
  const body = kpis.map((k) => el("tr", {},
    el("td", {}, el("b", {}, k.kpi_code), " ", k.kpi_name,
      el("div", {class: "small"}, state.meta.manual_hints[k.kpi_code] || state.meta.default_manual_hint)),
    ids.map((b) => manualCell(s, k, b, mv, stored.get(k.kpi_code + "|" + b) || null))));
  box.append(
    el("div", {class: "bar"}, el("label", {}, "Year ", pick("year", years, String)),
      el("label", {}, "Month ", pick("month", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], String)),
      el("span", {class: "small"}, "Red = no value yet. Fill numerator and denominator; a cell with only one is not added.")),
    el("div", {class: "gridwrap"}, el("table", {class: "g mv"}, el("thead", {}, head), el("tbody", {}, body))));
  if (!kpis.length) box.append(el("p", {class: "small"}, "No active manual KPIs."));
}

function manualCell(s, k, b, mv, st) {
  const row0 = {kpi_code: k.kpi_code, branch_id: b, year: mv.year, month: mv.month};
  const kv = keyValues(s, row0), pk = pkey(s.name, kv);
  const p = state.pending.get(pk);
  const shown = state.mvDrafts[pk] || (p && p.op === "upsert" ? p.row : st) || {};
  const mk = (col, ph) => el("input", {"data-fid": fidOf(s, row0, {name: col}), value: showNum(shown[col]), placeholder: ph,
    "aria-label": k.kpi_code + " hospital " + b + " " + col, ...(col === "note" ? {tabindex: "-1"} : {}),
    onchange: commit});
  const nIn = mk("numerator", "numerator"), dIn = mk("denominator", "denominator"), noteIn = mk("note", "note");
  const td = el("td", {class: "mc"}, nIn, dIn, noteIn, st ? el("button", {class: "lnk", tabindex: "-1", onclick: () => showHistory(s.name, kv)}, "History") : null);
  const paint = () => {
    const empty = !st && nIn.value.trim() === "" && dIn.value.trim() === "";
    td.className = "mc" + (state.mvDrafts[pk] ? " inc" : state.pending.has(pk) ? " ch" : empty ? " mt" : "");
    td.title = state.mvDrafts[pk] ? "Needs a numerator and a denominator, both numbers" : "";
  };
  function reset() {
    nIn.value = st ? showNum(st.numerator) : ""; dIn.value = st ? showNum(st.denominator) : ""; noteIn.value = st ? showNum(st.note) : "";
  }
  function commit() {
    const n = parseNum(nIn.value), d = parseNum(dIn.value), note = noteIn.value.trim();
    delete state.mvDrafts[pk];
    state.pending.delete(pk);
    if (n === null && d === null) reset(); // both cleared: the change is dropped, a stored row stays
    else if (n === null || d === null || Number.isNaN(n) || Number.isNaN(d)) state.mvDrafts[pk] = {numerator: nIn.value, denominator: dIn.value, note: noteIn.value};
    else {
      const stRow = storedAny(s.name, kv);
      const same = st && !st.is_deleted && Number(st.numerator) === n && Number(st.denominator) === d && String(st.note == null ? "" : st.note).trim() === note;
      if (!same) state.pending.set(pk, {table: s.name, op: "upsert", base_changed_at: stRow ? stRow.changed_at : null,
        row: {kpi_code: k.kpi_code, branch_id: b, year: mv.year, month: mv.month, numerator: n, denominator: d, note}});
    }
    state.review = null;
    renderPending();
    paint();
  }
  paint();
  return td;
}
registerView("map_bsc_manual_value", renderManual);

// ---- weights
state.wv = {profile: "corporate", pillar: "", copyOpen: false, msg: ""};
state.wvDrafts = {};   // pkey -> typed text that is not a number

// weight per KPI of a profile: stored, with pending changes applied (and one typed value, if given)
function effectiveWeights(profile, typed) {
  const out = new Map();
  for (const r of state.tables.map_bsc_weight.current) if (r.profile === profile) out.set(r.kpi_code, Number(r.weight));
  for (const c of state.pending.values()) {
    if (c.table !== "map_bsc_weight" || c.row.profile !== profile) continue;
    if (c.op === "remove") out.delete(c.row.kpi_code); else out.set(c.row.kpi_code, Number(c.row.weight));
  }
  if (typed) { if (typed.value == null) out.delete(typed.kpi); else out.set(typed.kpi, typed.value); }
  return out;
}
function totalOf(profile, typed) {
  let t = 0;
  for (const v of effectiveWeights(profile, typed).values()) t += v;
  return t;
}
function paintTotal(node, profile, typed) {
  const t = totalOf(profile, typed);
  node.textContent = "Profile total: " + t.toFixed(4);
  node.className = "total " + (t.toFixed(4) === "1.0000" ? "ok" : "bad");
}

function renderWeights(box, s) {
  const wv = state.wv, m = state.meta;
  const profiles = ["corporate"].concat(hospitalIds().map((i) => "branch:" + i));
  const profLabel = (p) => (p.startsWith("branch:") ? p + " · " + hospitalName(p.slice(7)) : p);
  const pillarOf = (k) => { const o = m.objectives.find((x) => x.objective_code === k.objective_code); return o || null; };
  const pillars = [];
  for (const o of m.objectives.slice().sort((a, b) => Number(a.pillar_order) - Number(b.pillar_order))) if (!pillars.includes(o.pillar)) pillars.push(o.pillar);
  const profSel = el("select", {"data-fid": "wv|profile", onchange: (e) => { wv.profile = e.target.value; wv.msg = ""; wv.copyOpen = false; renderView(); }},
    profiles.map((p) => el("option", {value: p}, profLabel(p))));
  profSel.value = wv.profile;
  const pilSel = el("select", {"data-fid": "wv|pillar", onchange: (e) => { wv.pillar = e.target.value; renderView(); }},
    el("option", {value: ""}, "All pillars"), pillars.map((p) => el("option", {value: p}, p)));
  pilSel.value = wv.pillar;
  const totalNode = el("span", {});
  paintTotal(totalNode, wv.profile);

  const stored = new Map();
  for (const r of state.tables[s.name].current) if (r.profile === wv.profile) stored.set(r.kpi_code, r);
  const rows = [];
  const kpis = m.kpis.slice().sort((a, b) => Number(a.kpi_num) - Number(b.kpi_num));
  for (const pillar of pillars.concat([null])) {
    if (wv.pillar && pillar !== wv.pillar) continue;
    const mine = kpis.filter((k) => { const o = pillarOf(k); return (o ? o.pillar : null) === pillar; });
    if (!mine.length) continue;
    rows.push(el("tr", {class: "pillar"}, el("th", {colspan: "3"}, pillar == null ? "No pillar" : pillar)));
    for (const k of mine) rows.push(weightRow(s, k, stored.get(k.kpi_code) || null, totalNode));
  }
  const copyBar = wv.copyOpen ? el("div", {class: "bar"}, el("span", {}, "Copy " + wv.profile + " to"),
    (() => {
      const sel = el("select", {class: "copyto", "data-fid": "wv|copyto"},
        hospitalIds().map((i) => "branch:" + i).filter((p) => p !== wv.profile).map((p) => el("option", {value: p}, profLabel(p))));
      return sel;
    })(),
    el("button", {class: "btn", onclick: () => copyProfile(s, $("content").querySelector("select.copyto").value)}, "Copy"),
    el("button", {class: "o", onclick: () => { wv.copyOpen = false; renderView(); }}, "Cancel")) : null;
  box.append(...[
    el("div", {class: "bar"}, el("label", {}, "Profile ", profSel), el("label", {}, "Pillar ", pilSel),
      el("button", {class: "o", onclick: () => { wv.copyOpen = true; wv.msg = ""; renderView(); }}, "Copy profile to a hospital…")),
    copyBar,
    wv.msg ? el("p", {class: "ok"}, wv.msg) : null,
    el("div", {class: "gridwrap"}, el("table", {class: "g"}, el("thead", {}, el("tr", {}, el("th", {}, "KPI"), el("th", {}, "Weight"), el("th", {}))),
      el("tbody", {}, rows))),
    el("p", {}, totalNode),
    el("p", {class: "small"}, "A profile's weights should add up to 1.0000. A blank weight means this profile has no row for the KPI.")].filter((n) => n != null));
}

function weightRow(s, k, st, totalNode) {
  const prof = state.wv.profile;
  const row0 = {profile: prof, kpi_code: k.kpi_code};
  const kv = keyValues(s, row0), pk = pkey(s.name, kv);
  const p = state.pending.get(pk);
  const shown = state.wvDrafts[pk] != null ? state.wvDrafts[pk] : p ? (p.op === "upsert" ? showNum(p.row.weight) : "") : st ? showNum(st.weight) : "";
  const inp = el("input", {"data-fid": fidOf(s, row0, {name: "weight"}), value: shown, "aria-label": "weight " + k.kpi_code,
    oninput: () => {
      const v = parseNum(inp.value);
      if (!Number.isNaN(v)) paintTotal(totalNode, prof, {kpi: k.kpi_code, value: v});
    },
    onchange: commit});
  const td = el("td", {}, inp);
  const hist = el("td", {class: "small"}, st ? el("button", {class: "lnk", onclick: () => showHistory(s.name, kv)}, "History") : null);
  const paint = () => { td.className = state.wvDrafts[pk] != null ? "inc" : state.pending.has(pk) ? "ch" : ""; };
  function commit() {
    const v = parseNum(inp.value);
    delete state.wvDrafts[pk];
    state.pending.delete(pk);
    if (v === null) inp.value = st ? showNum(st.weight) : ""; // cleared: back to what is stored
    else if (Number.isNaN(v)) state.wvDrafts[pk] = inp.value;
    else {
      const stRow = storedAny(s.name, kv);
      if (!(st && Number(st.weight) === v)) state.pending.set(pk, {table: s.name, op: "upsert", base_changed_at: stRow ? stRow.changed_at : null,
        row: {profile: prof, kpi_code: k.kpi_code, weight: v}});
    }
    state.review = null;
    renderPending();
    paintTotal(totalNode, prof);
    paint();
  }
  paint();
  return el("tr", {}, el("td", {}, el("b", {}, k.kpi_code), " ", k.kpi_name), td, hist);
}

function copyProfile(s, target) {
  const src = state.wv.profile;
  if (!target || target === src) return;
  const from = effectiveWeights(src), to = new Map();
  const tgtStored = new Map();
  for (const r of state.tables[s.name].current) if (r.profile === target) tgtStored.set(r.kpi_code, r);
  let n = 0;
  const codes = new Set([...from.keys(), ...tgtStored.keys()]);
  for (const code of codes) {
    const pk = pkey(s.name, keyValues(s, {profile: target, kpi_code: code}));
    const st = tgtStored.get(code), base = st ? st.changed_at : null;
    state.pending.delete(pk);
    delete state.wvDrafts[pk];
    if (from.has(code)) {
      if (st && Number(st.weight) === from.get(code)) continue; // already the same: no change
      state.pending.set(pk, {table: s.name, op: "upsert", base_changed_at: base, row: {profile: target, kpi_code: code, weight: from.get(code)}});
      n++;
    } else if (st) {
      state.pending.set(pk, {table: s.name, op: "remove", base_changed_at: base, row: {profile: target, kpi_code: code}});
      n++;
    }
  }
  state.review = null;
  state.wv.profile = target; state.wv.copyOpen = false;
  state.wv.msg = n ? n + (n === 1 ? " change" : " changes") + " added for " + target + "; review before saving."
    : "No changes: " + target + " already has the weights of " + src + ".";
  renderPending();
  renderView();
}
registerView("map_bsc_weight", renderWeights);

// ---------------------------------------------------------------- boot
$("signin-form").addEventListener("submit", signIn);
showSignIn("");
