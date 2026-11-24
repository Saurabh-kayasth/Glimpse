#!/usr/bin/env python3
"""Reads the last probe run from ~/Library/Logs/Glimpse-probe.log and checks P0.1 and P0.2's "done when".

    python3 tools/ax-probe/check-log.py            # last run
    python3 tools/ax-probe/check-log.py --all      # every run in the log
    python3 tools/ax-probe/check-log.py --live     # one line per sample while the probe runs

Read-only: it reads the log and the names in ~/Desktop, nothing else.
"""
import json
import os
import statistics
import sys
from urllib.parse import unquote, urlparse

LOG = os.path.expanduser("~/Library/Logs/Glimpse-probe.log")
DESKTOP = os.path.expanduser("~/Desktop")
SOURCES = ("axFinder", "axSystemWide")
RULES = ("desktopRulePlanned", "desktopRuleSkipDock")


def load(all_runs):
    lines = [json.loads(l) for l in open(LOG) if l.strip()]
    if not all_runs:
        starts = [i for i, o in enumerate(lines) if o.get("event") == "start"]
        lines = lines[starts[-1]:] if starts else lines
    start = next((o for o in lines if o.get("event") == "start"), {})
    return start, [o for o in lines if "cursor" in o]


def desktop_items():
    names = [n for n in os.listdir(DESKTOP) if not n.startswith(".")]
    folders = {n for n in names if os.path.isdir(os.path.join(DESKTOP, n)) and not os.path.splitext(n)[1] in (".app", ".bundle", ".pkg")}
    return names, folders


def match_name(shown, names):
    """A shown name -> exactly one desktop item, allowing a hidden extension."""
    if not shown:
        return None
    exact = [n for n in names if n == shown]
    if len(exact) == 1:
        return exact[0]
    stem = [n for n in names if os.path.splitext(n)[0] == shown]
    return stem[0] if len(stem) == 1 else None


def resolve(ax, finder_pid, names):
    """The first element in the chain (hit, then parents) that names a desktop item.
    Returns (item, how, level, frame) or a reason string."""
    if not ax:
        return "not asked (--no-ax)"
    if "chain" not in ax:
        return f"AX error {ax.get('error')}"
    chain = ax["chain"]
    if chain[0]["pid"] != finder_pid:
        return f"not Finder: {chain[0]['app']} {chain[0]['role']}"
    for level, el in enumerate(chain):
        if el["pid"] != finder_pid:
            break
        if "url" in el:
            u = urlparse(el["url"])
            path = unquote(u.path).rstrip("/")
            if os.path.dirname(path) == DESKTOP and os.path.basename(path) in names:
                return os.path.basename(path), "AXURL", level, el.get("frame")
        if el.get("filename") in names:
            return el["filename"], "AXFilename", level, el.get("frame")
        for key in ("title", "value", "description"):
            item = match_name(el.get(key), names)
            if item:
                frame = el.get("frame") or next((p.get("frame") for p in chain[level + 1:] if p.get("frame")), None)
                return item, f"AX{key.capitalize()}", level, frame
    return f"Finder {chain[0].get('role')}/{chain[0].get('subrole', '')}, no item"


def contains(frame, p):
    return bool(frame) and frame[0] <= p[0] <= frame[0] + frame[2] and frame[1] <= p[1] <= frame[1] + frame[3]


def live():
    """One short line per sample as the probe writes it. Ctrl-C to stop."""
    import time
    names, _ = desktop_items()
    finder_pid = None
    with open(LOG) as f:
        f.seek(0, os.SEEK_END)
        print(f"Watching {LOG} (Ctrl-C to stop)…", flush=True)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.2)
                continue
            o = json.loads(line)
            if "event" in o:
                finder_pid = o.get("finderPID", finder_pid)
                print(f"-- {o['event']}", flush=True)
                continue
            cur = o["cursor"]
            out = [f"{cur[0]:5.0f},{cur[1]:4.0f}",
                   f"desktop {'YES' if o['desktopRuleSkipDock']['showing'] else 'no '} ({o['desktopRuleSkipDock']['decidedBy']})"]
            for src, label in (("axFinder", "finder-only"), ("axSystemWide", "system-wide")):
                r = resolve(o.get(src), finder_pid, names)
                if isinstance(r, tuple):
                    out.append(f"{label}: {r[0]} [{r[1]}@{r[2]} {'box✓' if contains(r[3], cur) else 'box✗'}]")
                else:
                    out.append(f"{label}: {r}")
            print("  |  ".join(out), flush=True)


def main():
    if "--live" in sys.argv:
        try:
            live()
        except KeyboardInterrupt:
            return
    start, samples = load("--all" in sys.argv)
    if not samples:
        sys.exit(f"No samples in {LOG}. Run tools/ax-probe/build.sh --run first.")
    finder_pid = start.get("finderPID")
    names, folders = desktop_items()
    print(f"Run {start.get('t')}  {start.get('macOS')}  {len(samples)} samples  Finder pid {finder_pid}")
    print(f"Desktop: {len(folders)} folders {sorted(folders)}\n")
    if start.get("useAX") is False:
        print("⚠ This run was a window-only test (--no-ax): Finder wasn't asked, so the P0.1 checks can't pass.")
        print("  For the real run: tools/ax-probe/build.sh --run --seconds 180\n")

    # 1. Spots: consecutive samples with the same outcome.
    rows = []
    for s in samples:
        r = {src: resolve(s.get(src), finder_pid, names) for src in SOURCES}
        key = (tuple(str(r[src][0]) if isinstance(r[src], tuple) else r[src] for src in SOURCES),
               tuple(s[rule]["decidedBy"] for rule in RULES))
        if rows and rows[-1]["key"] == key:
            rows[-1]["samples"].append(s)
        else:
            rows.append({"key": key, "samples": [s], "r": r})

    print(f"{'time':8} {'n':>2}  {'cursor (x,y)':13} {'planned rule':22} {'skip-Dock rule':22} {'Finder-only ask':34} {'system-wide ask':34} pipeline")
    per_folder = {f: [] for f in folders}
    for row in rows:
        s0 = row["samples"][0]
        cur = s0["cursor"]
        cols = []
        for rule in RULES:
            cols.append(("yes " if s0[rule]["showing"] else "no  ") + s0[rule]["decidedBy"])
        for src in SOURCES:
            r = row["r"][src]
            if isinstance(r, tuple):
                item, how, level, frame = r
                cols.append(f"{item} [{how}@{level}{' box✓' if contains(frame, cur) else ' box✗'}]")
            else:
                cols.append(r)
        fr = row["r"]["axFinder"]
        pipeline = fr[0] if (isinstance(fr, tuple) and fr[0] in folders and s0["desktopRuleSkipDock"]["showing"]) else "—"
        print(f"{s0['t'][11:19]} {len(row['samples']):>2}  {f'{cur[0]:.0f},{cur[1]:.0f}':13} {cols[0][:22]:22} {cols[1][:22]:22} {cols[2][:34]:34} {cols[3][:34]:34} {pipeline}")
        for s in row["samples"]:
            for src in SOURCES:
                r = resolve(s.get(src), finder_pid, names)
                if isinstance(r, tuple) and r[0] in folders:
                    per_folder[r[0]].append((src, s, r))

    # 2. Per folder: P0.1 and P0.2.
    print("\nPer desktop folder (✓ = every sample on it passed)")
    print(f"{'folder':16} {'Finder-only':14} {'system-wide':14} {'planned rule':13} {'skip-Dock rule':15} top y")
    verdict = {k: True for k in ("axFinder", "axSystemWide", "desktopRulePlanned", "desktopRuleSkipDock")}
    for f in sorted(folders):
        hits = per_folder[f]
        cells = []
        for src in SOURCES:
            mine = [(s, r) for x, s, r in hits if x == src]
            ok = bool(mine) and all(contains(r[3], s["cursor"]) for s, r in mine)
            verdict[src] &= ok
            cells.append(f"{'✓' if ok else '✗'} {len(mine)} seen" if mine else "✗ never")
        samples_on = {id(s): s for _, s, _ in hits}.values()
        for rule in RULES:
            ok = bool(samples_on) and all(s[rule]["showing"] for s in samples_on)
            verdict[rule] &= ok
            cells.append(("✓" if ok else "✗") + f" {sum(s[rule]['showing'] for s in samples_on)}/{len(samples_on)}")
        top = min((s["cursor"][1] for s in samples_on), default=None)
        print(f"{f[:16]:16} {cells[0]:14} {cells[1]:14} {cells[2]:13} {cells[3]:15} {'' if top is None else f'{top:.0f}'}")

    # 3. Timings and what Finder offers.
    print("\nAccessibility answer time (ms):")
    for src in SOURCES:
        ms = [s[src]["ms"] for s in samples if src in s]
        if ms:
            print(f"  {src:13} median {statistics.median(ms):.1f}  max {max(ms):.1f}")
    seen = {}
    for s in samples:
        for src in SOURCES:
            for el in s.get(src, {}).get("chain", []):
                if "attributeNames" in el:
                    seen.setdefault(f"{el['role']}/{el.get('subrole', '')}", el["attributeNames"])
    if seen:
        print("\nAttributes Finder offers, per kind of element:")
        for kind, attrs in seen.items():
            print(f"  {kind}: {', '.join(attrs)}")

    print("\nVerdict")
    print(f"  P0.1 Finder-only ask names every folder, box contains cursor: {'PASS' if verdict['axFinder'] else 'FAIL'}")
    print(f"  P0.1 system-wide ask names every folder, box contains cursor: {'PASS' if verdict['axSystemWide'] else 'FAIL'}")
    print(f"  P0.2 planned rule says yes on every folder:   {'PASS' if verdict['desktopRulePlanned'] else 'FAIL'}")
    print(f"  P0.2 skip-Dock rule says yes on every folder: {'PASS' if verdict['desktopRuleSkipDock'] else 'FAIL'}")
    print("  Not-a-folder spots (widget, app window, Finder window, empty desktop): check the 'pipeline' column says — for them.")


if __name__ == "__main__":
    main()
