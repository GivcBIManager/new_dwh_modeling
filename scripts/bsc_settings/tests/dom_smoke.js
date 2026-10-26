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
