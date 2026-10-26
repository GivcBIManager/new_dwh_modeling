// Drives the BSC settings page in jsdom against dom_harness.py. Prints PASS/FAIL lines.
const {JSDOM, VirtualConsole} = require(process.env.JSDOM_PATH);
const {spawn} = require("child_process");
const readline = require("readline");
const path = require("path");

const py = spawn("python", [path.join(__dirname, "dom_harness.py")], {env: {...process.env, PYTHONDONTWRITEBYTECODE: "1"}});
py.stderr.on("data", (d) => process.stderr.write("[py] " + d));
const lines = []; let waiter = null;
readline.createInterface({input: py.stdout}).on("line", (l) => { if (waiter) { const w = waiter; waiter = null; w(l); } else lines.push(l); });
const nextLine = () => lines.length ? Promise.resolve(lines.shift()) : new Promise((r) => (waiter = r));
async function cmd(o) { py.stdin.write(JSON.stringify(o) + "\n"); return JSON.parse(await nextLine()); }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, what, ms = 4000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { try { const v = fn(); if (v) return v; } catch (e) { /* retry */ } await sleep(20); }
  throw new Error("timeout waiting for: " + what);
}
const results = [];
const check = (name, ok, detail) => results.push((ok ? "PASS " : "FAIL ") + name + (ok || !detail ? "" : " -- " + detail));

(async () => {
  const {port} = JSON.parse(await nextLine());
  const base = "http://127.0.0.1:" + port;
  const errors = [];
  const vc = new VirtualConsole();
  vc.on("jsdomError", (e) => errors.push(String(e.message || e)));
  const dom = await JSDOM.fromURL(base + "/", {
    runScripts: "dangerously", resources: "usable", pretendToBeVisual: true, virtualConsole: vc,
    beforeParse(window) {
      window.fetch = async (p, opts = {}) => {
        const r = await fetch(new URL(p, base), {...opts, headers: {...(opts.headers || {}), Origin: base}, redirect: "manual"});
        const text = await r.text();
        return {status: r.status, ok: r.ok, json: async () => JSON.parse(text)};
      };
      const D = window.HTMLDialogElement.prototype; // jsdom has no showModal
      if (!D.showModal) {
        D.showModal = function () { this.setAttribute("open", ""); };
        D.close = function () { this.removeAttribute("open"); };
        Object.defineProperty(D, "open", {get() { return this.hasAttribute("open"); }, configurable: true});
      }
    },
  });
  const w = dom.window, doc = w.document, $ = (id) => doc.getElementById(id);
  const txt = (n) => (n ? n.textContent : "");
  const btn = (root, label) => [...root.querySelectorAll("button")].find((b) => b.textContent.trim() === label);
  const fire = (n, type) => n.dispatchEvent(new w.Event(type, {bubbles: true, cancelable: true}));
  const setv = (n, v, type = "change") => { n.value = v; fire(n, type); };
  const cell = (i) => $("content").querySelector("tbody tr").children[i].querySelector("input,select");
  const step = async (name, fn) => { try { await fn(); } catch (e) { check(name, false, "threw " + e.message); } };
  const P = () => txt($("pending"));
  const reviewBtn = () => btn($("pending"), "Review & save");
  const pendingRows = () => JSON.parse(w.eval("JSON.stringify([...state.pending.values()].map((p) => p.row))"));
  const unloadAsks = () => { const e = new w.Event("beforeunload", {cancelable: true}); w.dispatchEvent(e); return e.defaultPrevented; };
  const note = (v) => setv($("pending").querySelector("input.note"), v, "input");
  const mrows = () => [...$("content").querySelectorAll("tbody tr")];
  const mtd = (r, h) => mrows()[r].children[h];
  const mins = (r, h) => [...mtd(r, h).querySelectorAll("input")];
  await until(() => doc.readyState === "complete" && !$("signin").hidden, "sign-in shown");

  await step("sign-in", async () => {
    $("signin-user").value = "tester"; $("signin-pass").value = "pw-123";
    const sub = new w.Event("submit", {bubbles: true, cancelable: true});
    $("signin-form").dispatchEvent(sub);
    check("sign-in submit is prevented (fetch only, no form post)", sub.defaultPrevented);
    check("password cleared at once", $("signin-pass").value === "");
    await until(() => !$("shell").hidden && $("content").querySelector("h2"), "shell");
    check("banner", txt($("banner")) === "Signed in to ClickHouse as tester. Saved changes show in the report tomorrow morning.");
  });

  await step("targets grid", async () => {
    btn($("nav"), "Targets").click();
    await until(() => txt($("content").querySelector("h2")) === "Targets" && $("content").querySelector("tbody tr"), "grid");
    const hosp = txt($("content").querySelector("tbody tr").children[1]);
    check("hospital shown as code and name", /1 · Hosp1/.test(hosp), hosp);
    check("0 offered as All hospitals with its code", [...doc.querySelectorAll("#content .bar select option")].some((o) => o.textContent === "0 · All hospitals"));
    check("user text never becomes markup", !doc.querySelector("img") && !w.__xss);
  });

  await step("edit keeps focus", async () => {
    const a = cell(4), b = cell(6);
    a.focus(); b.focus();               // the user tabs on: the next cell is focused ...
    setv(a, "180");                      // ... and the change of the first one is applied
    await until(() => /1 change waiting/.test(txt($("pending"))), "pending");
    check("focus stays on the next cell", doc.activeElement === b && b.isConnected, String(doc.activeElement && doc.activeElement.tagName));
    check("edited cell marked", $("content").querySelector("tbody tr").children[4].classList.contains("ch"));
    check("inputs not rebuilt by an edit", cell(4) === a);
    b.focus(); b.value = "Board"; b.setSelectionRange(2, 3);
    w.eval("addPending({table:'map_bsc_target',op:'upsert',row:Object.assign({}, [...state.pending.values()][0].row,{source_basis:'Board'}),base_changed_at:'2026-01-01 00:00:00.000'})");
    const now = doc.activeElement;
    check("focus and caret survive a full re-render", now && now.dataset.fid === b.dataset.fid && now.isConnected && now !== b && now.selectionStart === 2, String(now && now.dataset && now.dataset.fid));
  });

  await step("review + insert", async () => {
    setv($("pending").querySelector("input.note"), "raise target", "input");
    btn($("pending"), "Review & save").click();
    await until(() => btn($("review-dialog"), "Insert"), "review");
    const shown = [...$("review-dialog").querySelectorAll("tbody td")].map((t) => t.textContent);
    check("review shows the row", shown.includes("180") && shown.includes("raise target"), shown.join(","));
    await cmd({op: "fail_select", substring: "default.map_bsc_objective"}); // the reload after the insert will fail
    btn($("review-dialog"), "Insert").click();
    await until(() => /Saved\./.test(txt($("review-dialog"))), "saved");
    const t = (await cmd({op: "dump"})).tables.map_bsc_target, last = t[t.length - 1];
    check("stub got the reviewed row", t.length === 2 && last.target_value === 180 && last.source_basis === "Board" && last.changed_by === "tester", JSON.stringify(last));
    await until(() => /could not be reloaded/.test(txt($("content"))), "reload error");
    check("reload failure is shown", /Saved, but the table could not be reloaded: .*Pick the table again\./.test(txt($("content"))), txt($("content")));
    btn($("review-dialog"), "Close").click();
  });

  await step("number cells send the typed text", async () => {
    await cmd({op: "clear_failures"});
    btn($("nav"), "Targets").click();
    await until(() => txt($("content").querySelector("h2")) === "Targets" && $("content").querySelector("tbody tr"), "targets again");
    setv(cell(4), " 0x10 ");
    const row = pendingRows()[0];
    check("target value sent as the trimmed text", row && row.target_value === "0x10", JSON.stringify(row));
    note("hex");
    reviewBtn().click();
    await until(() => /target_value/.test(txt($("review-dialog"))), "review error");
    check("the server decides: 0x10 is not a number", /target_value is not a number/.test(txt($("review-dialog"))) && btn($("review-dialog"), "Insert").disabled, txt($("review-dialog")));
    btn($("review-dialog"), "Back").click();
    btn($("pending"), "Discard all").click();
  });

  await step("manual values", async () => {
    await cmd({op: "clear_failures"});
    btn($("nav"), "Manual values").click();
    await until(() => txt($("content").querySelector("h2")) === "Manual values" && $("content").querySelector("tbody tr"), "manual grid");
    const rows = [...$("content").querySelectorAll("tbody tr")];
    check("only active manual KPIs listed", rows.length === 2, String(rows.length));
    check("hint under the KPI name", rows[0].children[0].querySelector(".small") && txt(rows[0].children[0].querySelector(".small")).length > 3);
    const d = new Date(), wantM = d.getMonth() === 0 ? 12 : d.getMonth(), wantY = d.getMonth() === 0 ? d.getFullYear() - 1 : d.getFullYear();
    const sels = $("content").querySelectorAll(".bar select");
    check("default period is the last full month", sels[0].value === String(wantY) && sels[1].value === String(wantM), sels[0].value + "/" + sels[1].value);
    const td = (r, h) => rows[r].children[h]; // hospital h is column h
    check("cell without a row is red", td(0, 1).classList.contains("mt") && !td(0, 2).classList.contains("mt"));
    check("stored cell shows its values", td(0, 2).querySelector("input").value === "50");
    const n1 = td(0, 1).querySelectorAll("input")[0], d1 = td(0, 1).querySelectorAll("input")[1], n2 = td(0, 2).querySelectorAll("input")[0];
    n1.focus(); n1.value = "7"; fire(n1, "change"); d1.focus();
    check("numerator alone is incomplete, nothing pending", td(0, 1).classList.contains("inc") && !/change waiting/.test(txt($("pending"))));
    check("focus on the denominator", doc.activeElement === d1 && d1.isConnected);
    d1.value = "70"; fire(d1, "change"); n2.focus();
    check("one change pending", /1 change waiting/.test(txt($("pending"))), txt($("pending")));
    check("focus on next hospital numerator", doc.activeElement === n2 && n2.isConnected);
    check("inputs not rebuilt", td(0, 1).querySelectorAll("input")[0] === n1);
    check("edited cell marked, no longer red", td(0, 1).classList.contains("ch") && !td(0, 1).classList.contains("mt") && !td(0, 1).classList.contains("inc"));
    check("history link only on stored cells", !btn(td(0, 1), "History") && btn(td(0, 2), "History"));
    btn(td(0, 2), "History").click();
    check("history opens", /history/.test(txt($("history-dialog"))) && $("history-dialog").open);
    btn($("history-dialog"), "Close").click();
    setv($("pending").querySelector("input.note"), "first values", "input");
    btn($("pending"), "Review & save").click();
    await until(() => btn($("review-dialog"), "Insert"), "manual review");
    btn($("review-dialog"), "Insert").click();
    await until(() => /Saved\./.test(txt($("review-dialog"))), "manual saved");
    const t = (await cmd({op: "dump"})).tables.map_bsc_manual_value, last = t[t.length - 1];
    check("stub got all 7 columns", ["kpi_code", "branch_id", "year", "month", "numerator", "denominator", "note"].every((c) => c in last) && last.numerator === 7 && last.denominator === 70 && last.branch_id === 1 && last.kpi_code === "FIN_DAYS_IN_AR" && last.changed_by === "tester", JSON.stringify(last));
    btn($("review-dialog"), "Close").click();
    await until(() => $("content").querySelector("tbody tr") && !$("content").querySelector("tbody tr").children[1].classList.contains("mt"), "reloaded cell filled");
  });

  await step("manual values: incomplete cells", async () => {
    check("nothing waiting: closing the tab is not questioned", /No changes waiting/.test(P()) && !unloadAsks(), P());
    let [n, d, nt] = mins(1, 3);
    n.value = "0,7"; fire(n, "change"); d.value = "5"; fire(d, "change");
    check("0,7 marks the cell incomplete", mtd(1, 3).classList.contains("inc"));
    check("pending bar counts the incomplete cell", /1 cell incomplete or not a number — fix or clear it/.test(P()) && !/No changes waiting/.test(P()), P());
    check("review & save disabled while a cell is incomplete", reviewBtn() && reviewBtn().disabled, P());
    check("closing the tab is questioned while a cell is incomplete", unloadAsks());
    nt = mins(1, 4)[2];
    nt.value = "only a note"; fire(nt, "change");
    check("a note alone on an empty cell is incomplete, not wiped", mtd(1, 4).classList.contains("inc") && mins(1, 4)[2].value === "only a note" && /2 cells incomplete or not numbers — fix or clear them/.test(P()), P());
    [n, d] = mins(1, 5);
    n.value = "0x10"; fire(n, "change"); d.value = "1e3"; fire(d, "change");
    check("0x10 and 1e3 are not numbers", mtd(1, 5).classList.contains("inc") && /3 cells incomplete/.test(P()), P());
    n = mins(1, 3)[0];
    n.value = " 0.7 "; fire(n, "change");
    const row = pendingRows()[0];
    check("typed numbers are sent trimmed, as text", row && row.numerator === "0.7" && row.denominator === "5", JSON.stringify(row));
    check("one change and two incomplete cells, still blocked", /1 change waiting/.test(P()) && /2 cells incomplete/.test(P()) && reviewBtn().disabled, P());
    nt = mins(1, 4)[2]; nt.value = ""; fire(nt, "change");
    check("clearing the note clears that incomplete cell", !mtd(1, 4).classList.contains("inc") && /1 cell incomplete/.test(P()), P());
    btn($("pending"), "Discard all").click();
    check("discard all clears incomplete cells", /No changes waiting/.test(P()) && mins(1, 5)[0].value === "" && !mtd(1, 5).classList.contains("inc") && !unloadAsks(), P());

    [n, d] = mins(1, 3); n.value = "1"; fire(n, "change"); d.value = "2"; fire(d, "change");
    check("closing the tab is questioned while a change waits", unloadAsks());
    note("one more");
    reviewBtn().click();
    await until(() => btn($("review-dialog"), "Insert"), "review");
    // an incomplete cell that appears while the review is open (white-box: typing would void the review)
    w.eval("(() => { const s = spec('map_bsc_manual_value'), row = {kpi_code: 'FIN_OTHER', branch_id: 6, year: state.mv.year, month: state.mv.month};"
      + " state.mvDrafts[pkey(s.name, keyValues(s, row))] = {row, numerator: '3', denominator: '', note: ''}; renderPending(); })()");
    check("incomplete cell counted during the review", /1 cell incomplete/.test(P()), P());
    btn($("review-dialog"), "Insert").click();
    await until(() => /Saved\./.test(txt($("review-dialog"))), "saved");
    btn($("review-dialog"), "Close").click();
    await until(() => mins(1, 3)[0].value === "1" && !mtd(1, 3).classList.contains("ch"), "reloaded");
    check("a successful save clears incomplete cells", /No changes waiting/.test(P()) && mins(1, 6)[0].value === "" && !mtd(1, 6).classList.contains("inc"), P());
  });

  await step("manual values: remove", async () => {
    const rm = btn(mtd(0, 2), "Remove");
    check("remove offered on a stored cell, out of the Tab order", rm && rm.getAttribute("tabindex") === "-1" && !btn(mtd(1, 7), "Remove"));
    rm.click();
    check("removed cell struck through", mtd(0, 2).classList.contains("gone") && !mtd(0, 2).querySelector("input") && /50/.test(txt(mtd(0, 2))), txt(mtd(0, 2)));
    check("one remove waiting", /1 change waiting/.test(P()) && /remove/.test(P()), P());
    btn(mtd(0, 2), "Undo remove").click();
    check("undo remove", /No changes waiting/.test(P()) && mins(0, 2)[0].value === "50", P());
    btn(mtd(0, 2), "Remove").click();
    note("drop it");
    reviewBtn().click();
    await until(() => btn($("review-dialog"), "Insert"), "remove review");
    btn($("review-dialog"), "Insert").click();
    await until(() => /Saved\./.test(txt($("review-dialog"))), "remove saved");
    const t = (await cmd({op: "dump"})).tables.map_bsc_manual_value, last = t[t.length - 1];
    check("stub got the removal with every column", last.is_deleted === 1 && last.numerator === 50 && last.denominator === 5 && last.branch_id === 2 && last.note === "seed" && last.change_note === "drop it", JSON.stringify(last));
    btn($("review-dialog"), "Close").click();
    await until(() => mtd(0, 2).classList.contains("mt"), "removed cell empty after reload");
  });

  await step("weights", async () => {
    btn($("nav"), "Weights").click();
    await until(() => txt($("content").querySelector("h2")) === "Weights" && $("content").querySelector(".total"), "weights");
    const prof = () => $("content").querySelector(".bar select");
    const total = () => $("content").querySelector(".total");
    const inputs = () => [...$("content").querySelectorAll("tbody input")];
    const copyTo = (profile) => {
      btn($("content"), "Copy profile to a hospital…").click();
      const sel = $("content").querySelector("select.copyto");
      setv(sel, profile, "change");
      btn($("content"), "Copy").click();
    };
    check("corporate total 1.0000 not red", /Profile total: 1\.0000/.test(txt(total())) && !total().classList.contains("bad"), txt(total()));
    check("pillar headings", /Financial/.test(txt($("content"))) && /Customer/.test(txt($("content"))));
    setv(prof(), "branch:1");
    await until(() => /0\.8000/.test(txt(total())), "branch:1 total");
    check("total red when not 1.0000", total().classList.contains("bad"), txt(total()));
    check("missing row shows blank", inputs().length === 3 && inputs()[2].value === "", inputs().map((i) => i.value).join(","));
    const first = inputs()[0], blank = inputs()[2];
    blank.focus(); blank.value = "0.2"; fire(blank, "input");
    check("total live while typing", /1\.0000/.test(txt(total())) && !total().classList.contains("bad"), txt(total()));
    first.focus(); fire(blank, "change");
    check("focus kept after the edit", doc.activeElement === first && first.isConnected && inputs()[2] === blank);
    check("one new key pending", /1 change waiting/.test(txt($("pending"))), txt($("pending")));
    first.value = "0.5"; fire(first, "change");
    check("total updates live to 0.9000", /0\.9000/.test(txt(total())) && total().classList.contains("bad"), txt(total()));
    check("focus kept on the edited input", doc.activeElement === first && inputs()[0] === first);
    btn($("pending"), "Discard all").click();
    check("discard resets the view", /0\.8000/.test(txt(total())), txt(total()));

    btn($("content"), "Copy profile to a hospital…").click();
    const opts = [...$("content").querySelector("select.copyto").options].map((o) => o.textContent);
    check("targets exclude the source and show names", opts.length === 7 && !opts.some((o) => /^branch:1\b/.test(o)) && opts.includes("branch:2 · Hosp2"), opts.join("|"));
    copyTo("branch:2");
    check("copy message", /3 changes added for branch:2; review before saving\./.test(txt($("content"))), txt($("content")));
    check("three pending changes", /3 changes waiting/.test(txt($("pending"))), txt($("pending")));
    const items = [...$("pending").querySelectorAll("li")].map((l) => txt(l));
    check("two upserts and one remove", items.filter((i) => /remove/.test(i)).length === 1 && items.filter((i) => /FIN_MEASURE.*remove/.test(i)).length === 1, items.join("|"));
    btn($("pending"), "Review & save").click();
    await until(() => $("review-dialog").open, "copy review");
    btn($("review-dialog"), "Back").click();
    btn($("pending"), "Discard all").click();

    setv(prof(), "corporate");
    copyTo("branch:1");
    check("copy corporate to branch:1: 3 upserts", /3 changes added for branch:1/.test(txt($("content"))) && prof().value === "branch:1" && /1\.0000/.test(txt(total())), txt($("content")));
    btn($("pending"), "Discard all").click();

    // a pending new key on the target that the source lacks is dropped by a copy
    setv(prof(), "branch:3");
    const typed = inputs()[2]; // FIN_MEASURE: branch:1 has no weight for it
    typed.value = "0.3"; fire(typed, "change");
    check("typed key pending on the target", /1 change waiting/.test(txt($("pending"))) && /0\.3000/.test(txt(total())), txt(total()));
    setv(prof(), "branch:1");
    copyTo("branch:3");
    const pend = [...$("pending").querySelectorAll("li")].map((l) => txt(l));
    check("copy drops the target's own pending key", pend.length === 2 && !pend.some((x) => /FIN_MEASURE/.test(x)) && /2 changes added for branch:3/.test(txt($("content"))), pend.join("|"));
    check("target total equals source total", /0\.8000/.test(txt(total())), txt(total()));
    btn($("pending"), "Discard all").click();

    // a weight that is not a number blocks saving until fixed or cleared
    setv(prof(), "branch:1");
    let bad = inputs()[2];
    bad.value = "0,7"; fire(bad, "change");
    check("0,7 weight is incomplete and blocks saving", bad.parentNode.classList.contains("inc") && /1 cell incomplete or not a number/.test(P()) && reviewBtn().disabled && !/No changes waiting/.test(P()), P());
    bad.value = "0x10"; fire(bad, "change");
    check("0x10 weight is not a number", bad.parentNode.classList.contains("inc") && !/change waiting/.test(P()), P());
    bad.value = " 0.25 "; fire(bad, "change");
    const wrow = pendingRows()[0];
    check("weight sent as the trimmed text", wrow && wrow.weight === "0.25" && /1 change waiting/.test(P()) && !/incomplete/.test(P()) && !reviewBtn().disabled, JSON.stringify(wrow) + " " + P());
    bad.value = "abc"; fire(bad, "change");
    btn($("pending"), "Discard all").click();
    check("discard all clears a bad weight", /No changes waiting/.test(P()) && inputs()[2].value === "" && !inputs()[2].parentNode.classList.contains("inc"), P());

    // remove one weight row, then undo
    const rowOf = (code) => [...$("content").querySelectorAll("tbody tr")].find((r) => r.querySelector("b") && txt(r.querySelector("b")) === code);
    check("no Remove on a KPI without a row", !btn(rowOf("FIN_MEASURE"), "Remove"));
    btn(rowOf("FIN_OTHER"), "Remove").click();
    check("removed weight row struck through", rowOf("FIN_OTHER").classList.contains("gone") && !rowOf("FIN_OTHER").querySelector("input") && /0\.6000/.test(txt(total())) && /1 change waiting/.test(P()) && /remove/.test(P()), txt(total()) + " " + P());
    btn(rowOf("FIN_OTHER"), "Undo remove").click();
    check("undo weight remove", /No changes waiting/.test(P()) && /0\.8000/.test(txt(total())) && rowOf("FIN_OTHER").querySelector("input").value === "0.2", P());

    // remove a whole hospital profile (never corporate)
    setv(prof(), "corporate");
    check("no Remove profile for corporate", !btn($("content"), "Remove profile"));
    setv(prof(), "branch:1");
    bad = inputs()[2]; bad.value = "0.3"; fire(bad, "change"); // the profile's own pending key goes too
    btn($("content"), "Remove profile").click();
    check("remove profile message", /2 removals added for branch:1; review before saving\./.test(txt($("content"))), txt($("content")));
    const items2 = [...$("pending").querySelectorAll("li")].map((l) => txt(l));
    check("two removes waiting, nothing else", items2.length === 2 && items2.every((i) => / - remove\b/.test(i)) && /0\.0000/.test(txt(total())), items2.join("|"));
    note("drop branch 1 weights");
    reviewBtn().click();
    await until(() => btn($("review-dialog"), "Insert"), "remove profile review");
    check("review says the hospital uses corporate", /no weights left, so the hospital uses the corporate profile/.test(txt($("review-dialog"))), txt($("review-dialog")));
    btn($("review-dialog"), "Back").click();
    btn($("pending"), "Discard all").click();
  });

  await step("partial failure", async () => {
    btn($("nav"), "Targets").click();
    await until(() => txt($("content").querySelector("h2")) === "Targets" && $("content").querySelector("tbody tr"), "targets");
    setv(cell(4), "190");
    btn($("nav"), "Manual values").click();
    await until(() => txt($("content").querySelector("h2")) === "Manual values" && $("content").querySelector("tbody tr"), "manual");
    const [n, d] = mins(1, 7);
    n.value = "1"; fire(n, "change"); d.value = "4"; fire(d, "change");
    check("two changes in two tables", /2 changes waiting/.test(P()), P());
    note("partial");
    reviewBtn().click();
    await until(() => btn($("review-dialog"), "Insert"), "review");
    await cmd({op: "fail_insert_into", table: "map_bsc_target"});
    await cmd({op: "fail_select", substring: "default.map_bsc_objective"});
    btn($("review-dialog"), "Insert").click();
    await until(() => /Only part of the changes were saved/.test(txt($("review-dialog"))), "partial message");
    await until(() => /could not be reloaded/.test(txt($("content"))), "reload error");
    check("partial failure reload message", /^Some tables were saved, but the table could not be reloaded: .*\. Pick the table again\.$/.test(txt($("content"))), txt($("content")));
    check("the failed table's change still waits", /1 change waiting/.test(P()) && /Targets/.test(P()), P());
    btn($("review-dialog"), "Close").click();
    await cmd({op: "clear_failures"});
    btn($("pending"), "Discard all").click();
  });

  await step("401 to sign-in", async () => {
    await cmd({op: "clear_sessions"});
    btn($("nav"), "KPIs").click();
    await until(() => !$("signin").hidden, "sign-in");
    check("401 shows sign-in with message", $("shell").hidden && /Signed out/.test(txt($("signin-msg"))), txt($("signin-msg")));
  });

  check("no script errors", errors.length === 0, errors.join(" | "));
  console.log(results.join("\n"));
  py.stdin.end(); w.close();
  setTimeout(() => process.exit(0), 300);
})().catch((e) => { console.log(results.join("\n")); console.error("FATAL", e); py.kill(); process.exit(1); });
