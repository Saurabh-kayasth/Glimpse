# F1 · Fix: sometimes nothing happens on hover

[← Back to the overview](../README.md) · Step tracker: [rollout/](README.md) · Design:
[02 · step 2](../02-design.md#the-flow-step-by-step) · Code: [RestTracker.swift](../../Sources/GlimpseCore/RestTracker.swift)

Reported on 2026-11-24: "sometimes nothing happens at all on hover". The log had only successful hovers (372–492 ms,
no errors, no "Finder busy"), so the failures were silent. Reading the detector found two weak spots in **when** it
asks Finder; detailed logging then showed a third, in the window check.

## The two causes

| Cause | Before | Effect |
|---|---|---|
| **Resting meant not moving even a fraction of a point** | `p != lastPoint`, an exact comparison, restarted the 0.35 s clock | A finger lying on the trackpad nudges the cursor by fractions of a point, so the clock kept restarting and the check might never run |
| **One check per resting spot, never retried** | `checkedThisRest` was set once | If that check said "nothing", for example because Show Desktop's animation was still sliding windows away when the cursor was already over an icon, or Finder was busy, nothing happened until you moved the cursor |

## Third cause, found with detailed logging on (11:52 UTC)

Right after the fix above, you reported "still not working at all". The log answered at once: **every** check, at
every point, said `desktop not showing (Screenshot layer 24)`. macOS's Screenshot tool (`screencaptureui`, running for
nearly 2 hours) had a **full-screen, see-through window at layer 24**, which it keeps up while the ⇧⌘5 toolbar is open
or a screen recording runs. You can click through it, but the window check took it for a window covering the
desktop, the same trap as the Dock's full-screen window in [P0](P0.1-ax-probe.md#found-while-building-the-dock-covers-the-whole-screen).

**Fix:** the window check now skips every window at the Dock's layer (20) or above, which are all system overlays (Dock,
menu bar, status items, Screenshot, banners), and fully transparent windows. That's safe because the system-wide
Accessibility question decides next, and it sees through them. Checked with a new developer option, `--hit-test x y`,
while the overlay was up:

| Point | Accessibility answered | Full check, before → after |
|---|---|---|
| (700, 400), over VS Code | `Code AXGroup`, not Screenshot | `Screenshot layer 24` → `Code layer 0` (right: VS Code is in front) |
| (1404, 520), the icon column | `Code AXGroup` | `Screenshot layer 24` → `Code layer 0` (VS Code covered the icons) |
| (300, 940), open desktop | `Finder AXGroup` | `Screenshot layer 24` → `empty desktop` (reached Finder's desktop) |

If an overlay really is in the way (a Dock tile, Spotlight), Accessibility answers with that app, and nothing opens,
as before.

## The fix (causes 1 and 2)

[RestTracker](../../Sources/GlimpseCore/RestTracker.swift) in GlimpseCore, a small tested rule fed every 50 ms:

- **Resting = within 3 points** of where the cursor stopped, for 0.35 s.
- **Nothing found → ask again every 0.6 s, up to 3 more times** (until 2.15 s), while the cursor stays put.
- **Found a folder, a file, or an element we can't name → stop** until the cursor moves. Over the menu bar, off any
  screen, or over our own panel there's nothing to retry either.

The extra cost is at most 3 more checks per resting spot when nothing is there: a window-list read, plus a 2–10 ms
Accessibility question when the desktop or a Finder window is under the cursor.

## Tests (2026-11-24)

```bash
cd Glimpse
swift test
```

| Check | Result |
|---|---|
| [RestTrackerTests](../../Tests/GlimpseCoreTests/RestTrackerTests.swift): still cursor → one check at 0.35 s | ✅ |
| Wobble of 1–1.5 points → still counts as resting | ✅ |
| Real movement (10 points every 0.2 s) → never checks | ✅ |
| Nothing found → checks at 0.35, 0.95, 1.55, 2.15 s, then stops | ✅ |
| Show Desktop: first check too early, second finds the icon → stops at 0.95 s | ✅ |
| New spot → starts over | ✅ |
| Screenshot overlay (layer 24), invisible window (alpha 0), overlay over a Finder window | ✅ 3 new window-rule tests; menu-bar items now skipped by the rule as well |
| All tests | ✅ 61 tests in 12 suites; clean build; installed, still granted |
| **You:** use it as usual; any "nothing happens" left? | ❓ Detailed logging is on (`verboseHoverLog`), so the log now says why for every check |

**Worth knowing:** a 1 ms slack absorbs timer jitter and floating-point rounding, so "0.6 s later" isn't missed by a
microsecond and pushed to the next tick. The first version of the test caught exactly that.

Next: back to the [step tracker](README.md).
