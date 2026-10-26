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
  await until(() => doc.readyState === "complete" && !$("signin").hidden, "sign-in shown");

  await step("sign-in", async () => {
    $("signin-user").value = "tester"; $("signin-pass").value = "pw-123";
    fire($("signin-form"), "submit");
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
