# 01 · The desktop today (checked on this Mac, 2026-11-24)

[← Back to the overview](README.md) · Before this: [00 · in plain words](00-hover-preview-explained.md)

This page covers what macOS gives us to work with on this Mac: screens, how the desktop's layers stack, Finder's desktop
settings and what's on the desktop. Everything here was read from the running system on 2026-11-24 (macOS 26.4.1, build
25E253). The window and screen checks need no permissions; the script is
[tools/window-check.swift](../tools/window-check.swift).

```bash
cd Glimpse
swift tools/window-check.swift
```

## Tools on this Mac

| Tool | Version |
|---|---|
| macOS | 26.4.1 (25E253) |
| Xcode | 26.4.1 (17E202) |
| Swift | 6.3.1 |

## Screens

| # | Screen | Size (points) | Usable area | Scale |
|---|---|---|---|---|
| 0 | Built-in Retina Display | 1470 × 956 | y 51 … 923 (Dock below, menu bar above) | 2× |

There's **one screen** (checked 2026-11-24). Glimpse started as main screen only and works on all screens since
[P4.1](rollout/P4.1-all-screens.md) ([D1](03-rollout-plan.md#decisions)). The
main screen is always the first one macOS lists (`NSScreen.screens[0]`), the one with the menu bar. It is not
`NSScreen.main`, which is whichever screen has the active window.

macOS uses two coordinate systems, and the app has to convert between them:

```
Cocoa (cursor position, our panel):   origin bottom-left,  y grows up
Quartz / Accessibility (window list, Finder's answers):   origin top-left,  y grows down

same point:   Cocoa (1400, 866)  ==  Quartz (1400, 956 - 866) = (1400, 90)
```

## The desktop is a stack of windows

Every on-screen window has a **layer** (its place in the stack; higher is on top). These are the windows below the
normal app layer (0), front to back, as the script printed them:

| Owner | Layer | Covers (Quartz x, y, w, h) | What it is |
|---|---|---|---|
| Notification Centre | -2147483601 | 8, 41, 180 × 180 | a **desktop widget** placed at the top left |
| Window Server | -2147483602 | 0, 0, 1470 × **81** | an unnamed strip across the **top 81 points**, above the icons ([Q2](03-rollout-plan.md#open-questions)) |
| **Finder** | **-2147483603** | 0, 0, 1470 × 956 | **the desktop icons**; matches macOS's "desktop icon" level exactly |
| Dock | -2147483624 | 0, 0, 1470 × 956 | the wallpaper (window name `Wallpaper-`) |
| Window Server | -2147483626 | 0, 0, 1470 × 956 | backdrop |

App windows sit far above these, at layer 0 and up. Floating panels are at layer 3.

**Above the app windows** (found on 2026-11-24 while building the [P0 probe](rollout/P0.1-ax-probe.md); the first
version of the script only printed layers below 0, so it missed these):

| Owner | Layer | Covers (Quartz x, y, w, h) | What it is |
|---|---|---|---|
| Control Centre | 25 | 7 small boxes in the menu bar's right end | menu-bar status items |
| Window Server | 24 | 0, 0, 1470 × 33 | the menu bar (window name `Menubar`) |
| **Dock** | **20** | **0, 0, 1470 × 956** | a **full-screen Dock window in front of every app window**, there in every check. Most likely the see-through window the Dock draws itself in. |

- **The Dock window covers the whole screen.** A rule that says "the frontmost window here must be Finder's" sees the
  Dock first at every point, so it would never say yes. The rule has to skip it, or not rely on the window list alone.
  This joined [Q2](03-rollout-plan.md#open-questions); [P0.2](03-rollout-plan.md#p02-is-the-desktop-showing-at-this-point)
  logs both versions of the rule.

- **One full-screen Finder window holds all desktop icons.** So "is the desktop showing at this point?" can be answered
  from the window list: the frontmost window at that point should be Finder's, on a layer below 0. Finder's normal
  windows are on layer 0, so the layer also separates the desktop from Finder windows.
- **Widgets cover icons.** The widget at the top left is a separate window above the icons. A widget in front of an
  icon has to win.
- **The 81-point Window Server strip is a trap.** It's above the icons and covers the top of the screen, where
  the first row of icons sits (on Finder's grid the first row starts just under the 33-point menu bar; not measured
  yet, [P0.2](03-rollout-plan.md#p02-is-the-desktop-showing-at-this-point) checks it). A naive "frontmost window must be
  Finder" check would ignore every icon in the top row. What the strip is (perhaps the area that reveals the menu bar,
  or a notch-related area on this display) isn't known; it is [Q2](03-rollout-plan.md#open-questions).
- **Window names are hidden** without the Screen Recording permission, apart from the Dock's wallpaper. The app
  doesn't need names: owner, layer and bounds are enough.

## Finder's desktop settings

| Setting | Value | Why it matters |
|---|---|---|
| Arrange by | name | Icons sit in a grid that Finder keeps sorted; they move when items are added |
| Icon size | 64 pt | The icon's box is about 64 × 64 plus the label |
| Grid spacing | 54 | |
| Label | below icon, 12 pt text | The label belongs to the item too; hovering the name should count |
| Show all file extensions | off (not set) | Finder shows `report` for `report.pdf`, so a displayed name can differ from the file name |
| Hard disks on desktop | off | Only files and folders from `~/Desktop` are shown |
| Stage Manager | off | With it on, macOS can hide desktop items; not a case to handle now |
| Desktop in iCloud | off (`~/Library/Mobile Documents/com~apple~CloudDocs/Desktop` doesn't exist) | Desktop items are plain local files in `~/Desktop` |

## What's on the desktop

Six folders, no loose files (hidden `.DS_Store` and `.localized` aside):

| Folder | Visible items inside |
|---|---|
| Notes | 7 |
| Archive[1] | 64 |
| Documents | 25 |
| Projects | 25 |
| a work folder | 47 |
| Test files | 2 |

So the panel needs to scroll. 64 rows don't fit next to an icon in an 872-point-tall usable area.

## What can't be checked yet

**Accessibility.** Asking Finder "what's at this point?" needs the Accessibility permission. This session runs inside
VS Code, which doesn't have it (`AXIsProcessTrusted()` returned `false` on 2026-11-24). So these are unknown:

- whether Finder answers for desktop icons at all;
- whether the answer carries a file path (`AXURL`), a file name (`AXFilename`) or only the shown name (`AXTitle`);
- whether the answer includes the icon's box (`AXPosition`, `AXSize`), and whether the label is part of it.

These are [Q1](03-rollout-plan.md#open-questions), answered by
[P0.1](03-rollout-plan.md#p01-ask-finder-what-is-under-the-cursor).

## What's missing

macOS has no built-in way to do any of the following, so the app has to add each one:

| # | What's missing | Today | Added in |
|---|---|---|---|
| 1 | An event for "cursor is over this desktop icon" | Finder keeps it to itself | [P1.3](03-rollout-plan.md#p13-hover-detection) |
| 2 | Knowing whether the desktop is visible at the cursor | Must be worked out from the window list (with the 81-point strip and the Dock's full-screen window in the way) | [P0.2](03-rollout-plan.md#p02-is-the-desktop-showing-at-this-point), [P1.3](03-rollout-plan.md#p13-hover-detection) |
| 3 | Turning Finder's answer into a real folder path | Shown names may hide extensions | [P1.3](03-rollout-plan.md#p13-hover-detection) |
| 4 | A panel that floats beside the icon without taking focus from your app | Needs a non-activating panel | [P1.2](03-rollout-plan.md#p12-preview-panel) |
| 5 | Reading a desktop folder's contents | Needs the one-time Desktop folder permission | [P1.2](03-rollout-plan.md#p12-preview-panel) |

Next: [02 · design](02-design.md).
