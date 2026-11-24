# 03 · Rollout plan: from "can Finder tell us?" to daily use

[← Back to the overview](README.md) · Design: [02](02-design.md) · Step tracker: [rollout/](rollout/README.md)

## In one sentence

We build it **one step at a time, with a doc in [rollout/](rollout/README.md) for each, then stop**. We start by
proving the one thing nobody has checked yet: that Finder tells us which desktop icon is under the cursor. Each phase
ends with a Mac that works exactly as before unless the app is running. You can quit it from the menu bar at any time.

## Decisions

| # | Decision | Status | What it means |
|---|---|---|---|
| D1 | **All screens** (was: main screen only) | **Decided** 2026-11-24 | Glimpse works on whichever screen the cursor is on, and keeps the panel on the icon's screen. Main screen only from the start until [P4.1](#p41-all-screens), which you asked for on 2026-11-24. |
| D2 | **Native Swift menu-bar app**, built with Swift Package Manager and a build script | Proposed | No Xcode project to maintain. `./build.sh` produces `build/Glimpse.app`. No Dock icon. ([why native](02-design.md#why-not-the-other-ways)) |
| D3 | **Find the icon by asking Finder through Accessibility** (option A) | **Proven** 2026-11-24 on the real desktop ([test](rollout/P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)) | Fallback if P0.1 fails: Finder's floor plan via AppleScript (option B). ([options](00-hover-preview-explained.md#the-options-side-by-side)) |
| D4 | **Sign with a local self-signed certificate, "Glimpse Local"** (was: ad hoc) | **Decided** 2026-11-24 | Made once by `tools/make-signing-cert.sh`; `build.sh` signs with it, so grants survive rebuilds ([P3.2](rollout/P3.2-stable-signing.md)). Ad hoc remains the fallback when the certificate is missing. Until 2026-11-24 every rebuild needed a new grant ([the catch](02-design.md#permissions)). Revisit in [Q4](#open-questions). |
| D5 | **Desktop, and Finder windows in icon view** (was: desktop only) | **Decided** 2026-11-24 | List, column and gallery views stay as they are. A menu switch, **Finder Windows**, turns the window part off. Built in [P5.1](#p51-finder-windows-in-icon-view). |
| D6 | **Read-only** | Proposed | Lists contents, opens items on click. Never moves, renames, deletes or writes. ([safety rules](02-design.md#safety-rules)) |
| D7 | **Timing**: show after resting 0.35 s, hide 0.2 s after leaving | Proposed | Tuned in [P2.1](#p21-hover-shows-the-panel) ([Q3](#open-questions)). |
| D8 | **A subfolder click opens it in Finder** (always Finder, even if another app is the default for folders); any click then hides the panel | **Decided** 2026-11-24 | Answers [Q5](#open-questions). Built in [P2.2](rollout/P2.2-click-to-open.md). Browsing inside the panel stays in [Later](#later-not-planned-yet). |
| D9 | **Previews in the rows for pictures, PDFs and videos only**; rows 28 points tall with 24-point previews (were 22 and 16) | Proposed | Quick Look thumbnails, loaded in the background and cached. Text, code and data files keep their icon: at 24 points their preview is a blank white square. Built in [P6.1](#p61-thumbnails). |

## Phases

| Phase | What | Ends with |
|---|---|---|
| [P0](#phase-p0-prove-it) | Prove Finder answers "what's at this point" for desktop icons, and that the desktop check works | A yes/no on option A, with logs. Only a throwaway probe app is installed. |
| [P1](#phase-p1-building-blocks) | App skeleton, panel, hover detection, each testable on its own | An app you can launch and quit. Hovering logs folders; the panel opens only from a test menu item. |
| [P2](#phase-p2-wire-it-together) | Hover opens the panel; click opens items | The feature works (main screen, until P4). |
| [P3](#phase-p3-daily-use) | Launch at login, Accessibility that survives rebuilds | Runs every day without fuss. |
| [P4](#phase-p4-other-screens) | Other screens ([D1](#decisions) lifted) | Hover works on any connected screen; the panel stays on the icon's screen. |
| [P5](#phase-p5-finder-windows) | Finder windows, icon view ([D5](#decisions) changed) | Hover works on folders in icon-view Finder windows too. |
| [P6](#phase-p6-a-richer-panel) | A richer panel | Previews in the rows. |
| [P7](#phase-p7-look-like-a-product) | Look like a product | An app icon, an About window, a README for people new to it. |

---

## Phase P0: prove it

Nothing of the app is built yet. One small probe answers [Q1](#open-questions) and [Q2](#open-questions).

### P0.1 Ask Finder what is under the cursor

**Status: ✅ 2026-11-24.** Finder windows in the [first probe run](rollout/P0.1-ax-probe.md#first-run-2026-11-24-0559-utc); real desktop icons in the [P2.1 desktop test](rollout/P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc).

- **Why:** the whole design rests on it ([D3](#decisions)), and it can't be checked without the Accessibility
  permission ([01 · what can't be checked](01-current-macos-desktop.md#what-cant-be-checked-yet)).
- **Do:** build a probe at `tools/ax-probe/` as its own tiny app, ad-hoc signed and started with `open`. That way
  **you grant Accessibility to the probe, not to VS Code**. Granting VS Code would hand that power to every extension.
  Once granted, the probe logs the element under the cursor every second for 120 seconds (`--seconds N` to change)
  to `~/Library/Logs/Glimpse-probe.log`: role, title, `AXFilename`, `AXURL`, position, size, and the same for up to 3
  parents. It asks two ways, system-wide and Finder alone, because the Dock's full-screen window
  ([01](01-current-macos-desktop.md#the-desktop-is-a-stack-of-windows)) might catch the system-wide question.
  `tools/ax-probe/check-log.py` reads the log and prints the verdict. You rest the cursor on:
  - each of the 6 desktop folders, once on the icon and once on its name;
  - an empty bit of desktop;
  - the widget at the top left;
  - a Finder window and a VS Code window.
- **Done when:** for every desktop folder, the log shows a path, or a name that matches exactly one item in
  `~/Desktop`, plus a box that contains the cursor. The other spots must give no folder. **If not:** switch
  [D3](#decisions) to option B and rewrite [P1.3](#p13-hover-detection).
- Answers [Q1](#open-questions).

### P0.2 Is the desktop showing at this point

**Status: 🟡 2026-11-24: the corrected rule (skip the Dock's window, confirm with the system-wide ask) works on rows 2–6 of the desktop ([test](rollout/P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)); the top row (Notes) is still to try.**

- **Why:** a Window Server strip covers the top 81 points above the icons, and the Dock has a full-screen window at
  layer 20 in front of everything ([01 · the stack](01-current-macos-desktop.md#the-desktop-is-a-stack-of-windows)).
- **Do:** in the same probe, also log the windows containing the cursor, front to back: owner, layer and bounds.
  Log the rule's verdict twice: as planned, and also skipping the Dock's layer-20 window. Include at least one icon in
  the top row.
- **Done when:** the rule from [02 step 3](02-design.md#the-flow-step-by-step) holds for every spot in P0.1:
  "skip our own windows and Window Server's; the first other window must be Finder's with layer < 0". It must say
  yes on all 6 icons, top row included, and no on the widget and on app or Finder windows. Expected: only the
  skip-Dock version can pass. Whichever passes goes into [02 step 3](02-design.md#the-flow-step-by-step).
- Answers [Q2](#open-questions).

## Phase P1: building blocks

Each block is testable alone. **Nothing opens a panel on hover yet.**

### P1.1 App skeleton

**Status: ✅ 2026-11-24** ([rollout/P1.1](rollout/P1.1-app-skeleton.md)).

- `Package.swift` (Swift Package Manager, macOS 14 or later), `Support/Info.plist` (`local.glimpse.app`, no Dock icon,
  a Desktop-folder usage message), and `build.sh`. The script builds in release mode, wraps the binary into
  `build/Glimpse.app`, signs it ad hoc and resets the old Accessibility grant ([D4](#decisions)). `--run` relaunches it.
- Menu-bar icon with: Hover Previews (on/off), Accessibility status or "Grant Accessibility Access…", Show Log, Quit.
- Asks for Accessibility on first launch.
- **Done when:** `./build.sh --run` shows the menu-bar icon and no Dock icon. The Accessibility prompt appears; after
  granting, the menu says "granted". Quit removes the icon.

### P1.2 Preview panel

**Status: 🟡 built 2026-11-24 and tested on test folders; the real desktop folder and scrolling are waiting for your check** ([rollout/P1.2](rollout/P1.2-preview-panel.md)).

- Folder listing, read-only ([D6](#decisions)): hidden files skipped, folders first, then Finder's name order, sizes for
  files.
- The panel from [02 · The panel](02-design.md#the-panel): non-activating, floating, list layout ([Q6](#open-questions)),
  scrolls after about 12 rows, messages for empty and unreadable folders.
- A temporary menu item "Test Panel…" picks a folder and shows its panel in the middle of the screen.
- **Done when:** for the 47-item desktop folder the panel lists 47 rows, folders first, and scrolls. An empty folder shows "Empty
  folder". The app you were using stays the active one (its name stays in the menu bar).
- Fixes rows 4–5 of [what's missing](01-current-macos-desktop.md#whats-missing).

### P1.3 Hover detection

**Status: ✅ 2026-11-24** ([rollout/P1.3](rollout/P1.3-hover-detection.md), [desktop test](rollout/P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)). Top row and name labels still to try.

- Steps 1–5 of [02](02-design.md#the-flow-step-by-step): cursor timer, rest detection, the desktop check proven in
  [P0.2](#p02-is-the-desktop-showing-at-this-point), the Finder question proven in
  [P0.1](#p01-ask-finder-what-is-under-the-cursor), and turning the answer into a folder path.
- 0.25 s time-out on each Accessibility question. Log only unrecognised elements, at most 50 lines per launch.
- Not connected to the panel yet: it writes `hover: <path>` to the log.
- **Done when:** resting on each of the 6 folders, on the icon or the name, logs the right path within 0.5 s. Nothing
  is logged over the widget, an app window, a Finder window or empty desktop.
- Fixes rows 1–3 of [what's missing](01-current-macos-desktop.md#whats-missing). Depends on [Q1](#open-questions),
  [Q2](#open-questions).

## Phase P2: wire it together

### P2.1 Hover shows the panel

**Status: ✅ 2026-11-24** ([rollout/P2.1](rollout/P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)): 368–454 ms to show, hides on leave, 0.1 % idle CPU.

- Connect [P1.3](#p13-hover-detection) to [P1.2](#p12-preview-panel). Place the panel beside the icon, on the left
  near the right edge, inside the usable area. Apply the hide rule (step 7). Remove the "Test Panel…" item.
- Measure idle CPU and memory with `top -pid $(pgrep -x Glimpse)` over 60 s.
- **Done when:** on each folder the panel appears within 0.5 s, fully on screen, next to the icon. The cursor can move
  into it and scroll. It hides within 0.3 s of leaving both. Idle CPU stays under 1%. Settles
  [D7](#decisions) / [Q3](#open-questions).

### P2.2 Click to open

**Status: ✅ 2026-11-24** for folders ([desktop test](rollout/P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)); a file click still to try.

- Clicking a row opens it in its default app. A subfolder opens in Finder ([D8](#decisions), answering [Q5](#open-questions)).
- **Done when:** clicking a file opens it; clicking a subfolder does the agreed thing; the panel stays usable.

## Phase P3: daily use

### P3.1 Launch at login

**Status: 🟡 built 2026-11-24; switching it on and the log-out/log-in check are yours** ([rollout/P3.1](rollout/P3.1-launch-at-login.md)).

- A "Launch at Login" menu toggle using macOS's login-item service (`SMAppService`).
- **Done when:** after logging out and back in, the app is running and previews work.

### P3.2 A grant that survives rebuilds

**Status: ✅ 2026-11-24** ([rollout/P3.2](rollout/P3.2-stable-signing.md)). Built before [P3.1](#p31-launch-at-login), at your request, to stop the re-granting.

- Depends on [Q4](#open-questions). Proposed: make a local self-signed code-signing certificate ("Glimpse Local") in
  the login keychain and sign with it. Then macOS sees the same app across rebuilds.
- **Done when:** after a rebuild, hovering still works without granting Accessibility again.

## Phase P4: other screens

### P4.1 All screens

**Status: 🟡 built 2026-11-24; tested with made-up screen layouts and on the built-in display; a real external display is waiting for your check** ([rollout/P4.1](rollout/P4.1-all-screens.md)).

- Use the screen under the cursor instead of the main screen; skip that screen's menu bar. Keep converting
  coordinates with the **main** screen's height (both systems are measured from it).
- Recognise the empty desktop by the size of the screen under the cursor.
- Place the panel inside the **icon's** screen's usable area, so it never spills onto a neighbouring screen.
- Hide the panel when screens are added, removed or rearranged.
- **Done when:** with an external display connected, resting on a folder on either screen opens the panel beside it
  on that screen, fully visible; menu bars and the Dock on both screens do nothing; the built-in display works as
  before.

## Phase P5: Finder windows

### P5.1 Finder windows in icon view

**Status: ✅ 2026-11-24** ([rollout/P5.1](rollout/P5.1-finder-windows-icon-view.md)): 13 live hovers in icon-view windows, including folders deep inside other folders. List, column and gallery views not tried yet.

- Tell three surfaces apart from the window list: the desktop, a Finder window, anything else.
- In a Finder window, count only an `AXImage` with a file `AXURL` inside an `AXList/AXCollectionList`: Finder's icon
  view, as the [P0 probe](rollout/P0.1-ax-probe.md#first-run-2026-11-24-0559-utc) recorded it. List and column views,
  the sidebar and the toolbar don't count.
- Folders anywhere, not only in `~/Desktop`: messages for the Documents, Downloads, removable and network volume
  permissions.
- Menu switch **Finder Windows** (on by default).
- **Done when:** in an icon-view Finder window, resting on a folder (icon or name) opens its panel beside it; list,
  column and gallery views, the sidebar and the toolbar do nothing; the desktop works as before.

### P5.2 List and column views

**Status: ⏭ skipped 2026-11-24, your call:** the core feature is done, and list and column views are an extra on an
extra. Moved to [Later](#later-not-planned-yet). What was built for collecting data stays, ready for when it's picked
up: detailed logging records each chain's shape with `[url]` markers and the children of rows and cells (roles only),
and the developer option `--dump-finder-shapes <file>` reports what a hover would see on items in every open Finder
window. Its one run (08:29 UTC) found only the desktop, which Finder exposes as a window: `AXImage[url] › AXGroup ›
AXScrollArea › AXApplication`, 64 × 64, no collection list. The sidebar has no paths at all
(`AXStaticText › AXCell{AXStaticText, AXImage} › AXRow/AXOutlineRow › AXOutline`).

- **Do:** you rest on folders in list view (⌘2) and column view (⌘3), and gallery view (⌘4) to check it stays off;
  then build the rules from those shapes, with tests from the logged chains.
- **Done when:** resting on a folder row in list or column view opens its panel beside the row; files, the sidebar,
  the toolbar and column headers do nothing; icon view and the desktop work as before.

## Phase P6: a richer panel

### P6.1 Thumbnails

**Status: ✅ 2026-11-24** ([rollout/P6.1](rollout/P6.1-thumbnails.md)): checked on a test folder with pictures, a PDF, text, data, an unknown file, a subfolder and an app.

- Quick Look previews for pictures, PDFs and videos in the rows ([D9](#decisions)); everything else keeps its icon.
- In the background, only for rows on screen, cached by file and modification date: the panel opens as fast as
  before.
- **Done when:** a folder of pictures shows them as previews; text files keep their icon; the panel still opens
  within the [P2.1](#p21-hover-shows-the-panel) time.

## Phase P7: look like a product

### P7.1 Icon, About window, README

**Status: ✅ 2026-11-24** ([rollout/P7.1](rollout/P7.1-icon-about-readme.md)).

- An app icon drawn in code (`tools/make-icon.swift`), shipped as `AppIcon.icns`.
- **About Glimpse** in the menu: the standard About window with the icon, version and build.
- A README for people new to Glimpse: what it does, install, permissions, privacy, troubleshooting, uninstall; with a
  picture made from Glimpse's real panel on a made-up folder (`tools/make-hero.swift`).

## Later (not planned yet)

- Finder windows in list, column or gallery view ([P5.2](#p52-list-and-column-views), skipped; the tooling is ready).
- Browsing subfolders inside the panel (not chosen for now: [D8](#decisions)).

## Open questions

| # | Question | Who / how | Blocks |
|---|---|---|---|
| Q1 | ~~Does Finder's desktop answer "what's at this point" with a path or name, and the icon's box?~~ **Yes** (2026-11-24): `AXURL` on the icon itself, 64 × 64 box ([test](rollout/P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)). | The [P0.1](#p01-ask-finder-what-is-under-the-cursor) probe; you grant it Accessibility and rest on the icons | [P1.3](#p13-hover-detection) |
| Q2 | What is the 81-point Window Server strip at the top, and is it safe to skip in the desktop check? Same for the Dock's full-screen layer-20 window (found 2026-11-24). | The [P0.2](#p02-is-the-desktop-showing-at-this-point) probe | [P1.3](#p13-hover-detection) |
| Q3 | Do 0.35 s to show and 0.2 s to hide feel right? | You, while testing [P2.1](#p21-hover-shows-the-panel) | Tuning only |
| Q4 | ~~Keep re-granting Accessibility after each rebuild, or set up a local signing certificate?~~ **Answered 2026-11-24: a new local certificate** ([D4](#decisions)) | You | — |
| Q5 | ~~Clicking a subfolder in the panel: open it in Finder, or show its contents in the panel?~~ **Answered 2026-11-24: open in Finder** ([D8](#decisions)) | You | — |
| Q6 | Panel layout: list with names and sizes (proposed), or an icon grid like a Dock stack? | You | [P1.2](#p12-preview-panel) |

## Risks

| Risk | Mitigation (linked to the step) |
|---|---|
| Finder doesn't expose desktop icons usefully | Proven before any app code ([P0.1](#p01-ask-finder-what-is-under-the-cursor)); fallback option B |
| A macOS update changes Finder's answers | One function to fix, with logging of what it saw ([P1.3](#p13-hover-detection)) |
| Rebuilds silently break Accessibility | Fixed: stable signing ([P3.2](rollout/P3.2-stable-signing.md)); the menu still shows the status ([P1.1](#p11-app-skeleton)) |
| Panel gets in the way | Non-activating, quick to hide, on/off in the menu ([P2.1](#p21-hover-shows-the-panel)) |
| Uses CPU all day | Measured against a 1% target ([P2.1](#p21-hover-shows-the-panel)) |
