# 00 · In plain words: how an app can tell which folder you're pointing at

[← Back to the overview](README.md) · Details: [01 · the desktop today](01-current-macos-desktop.md),
[02 · design](02-design.md)

This page explains how Glimpse works without macOS jargon. It also covers the two other ways it could work and why we
didn't pick them. The [last section](#the-real-names) maps the plain words to the real names.

## How the desktop works today

The desktop is a stack of see-through sheets, drawn on top of each other:

```
top      your app windows (Safari, VS Code, …)
         widgets you placed on the desktop
         desktop icons      ← drawn by Finder
bottom   wallpaper          ← drawn by the Dock
```

The icons belong to **Finder**. Only Finder knows that the picture at a given spot is the folder `Projects`. When the
cursor moves over an icon, Finder notices (it highlights the icon when you click), but **it doesn't tell other apps.**
There's no "the cursor is over this folder" message another app can listen for.

## The problem

We want a panel to appear when the cursor rests on a folder. Finder can't be changed or given plug-ins. So the panel has
to come from **another app**, and that app has to work out by itself which folder is under the cursor.

## The idea: ask Finder "what's at this spot?"

Think of a museum guard. You can't put sensors on the paintings, but you can ask the guard "what's hanging here?"
whenever someone stops in front of something.

**1. The app watches the cursor.** Many times a second it notes where the cursor is. It ignores everything until the
cursor stops moving.

```
cursor at (1400, 90) … (1400, 90) … still for 0.35 s → ask
```

**2. It checks that the desktop is what's showing at that spot.** If a window or a widget covers that spot, the cursor
is over that, not over an icon, and the app does nothing.

**3. It asks Finder what is at that spot.** macOS has a way for one app to ask another "what's at this point on the
screen?". Screen readers like VoiceOver use it to read out what's under the cursor. Finder answers with something like:

```
item:      "Projects"
position:  x 1375…1439, y 45…109   (the icon's box)
```

**4. It looks inside the folder and shows the panel.** The app reads the folder's list of files and shows them in a
small floating panel next to the icon:

```
┌ Projects ─────────── 12 items ┐
│ 📁 designs                      │
│ 📁 invoices                     │
│ 📁 website                      │
│ 📄 notes.txt                    │
│ …                               │
└─────────────────────────────────┘
```

When the cursor leaves the icon and the panel, the panel goes away. You can move the cursor into the panel to scroll it,
or click an item to open it.

### What you end up with

A menu-bar icon (a small folder) that you can switch off or quit at any time. Finder, the desktop and your files stay
exactly as they are. The app only reads names and draws its own panel on top.

## The other ways

**Get Finder's floor plan.** Instead of asking about one spot, ask Finder once for the position of every desktop icon,
then compare the cursor with that list yourself. Finder can answer that through AppleScript. The catch: the list goes
stale whenever you drag an icon, add a file or change the icon size, and it gives only each icon's centre, not how big
the icon and its label are.

**Build our own desktop.** Hide Finder's desktop icons (there's a setting for that) and draw our own icons, so we always
know which one is under the cursor. The catch: we'd have to rebuild everything Finder's desktop does, such as drag and
drop, renaming, selecting several items and Quick Look. That's a whole product, not a hover panel.

## The options side by side

| | **A. Ask Finder at the spot** (chosen) | **B. Finder's floor plan** | **C. Our own desktop** |
|---|---|---|---|
| How it finds the icon | Asks Finder about one point when the cursor stops | Asks for every icon's position, compares itself | Draws the icons, so it already knows |
| Permission | Accessibility | Automation ("control Finder") | None to find icons |
| Follows icons you move | Yes, it asks fresh each time | Only after asking again | Yes |
| Knows the icon's size | Yes, Finder reports the box | No, centre only | Yes |
| Changes to your Mac | None | None | Finder's desktop icons switched off |
| Effort | Small | Small, but fiddly to keep right | Very large |
| Breaks if Apple changes Finder | Possibly, in one function | Possibly | No, but it's a different product |

In short:
- **A** is small and accurate, but it depends on how Finder describes its icons, which isn't verified yet
  ([P0.1](03-rollout-plan.md#p01-ask-finder-what-is-under-the-cursor)).
- **B** needs no Accessibility permission, but it goes stale and doesn't know icon sizes.
- **C** gives full control, but it replaces Finder's desktop.

**The rest of these docs describe option A.** If [P0.1](03-rollout-plan.md#p01-ask-finder-what-is-under-the-cursor)
shows Finder doesn't answer usefully, B is the fallback. Only [step P1.3](03-rollout-plan.md#p13-hover-detection) and
the permission prompt would change.

## The real names

| Plain words | Real name | More |
|---|---|---|
| see-through sheet | window, with a *window level* (its place in the stack) | [01 · the stack](01-current-macos-desktop.md#the-desktop-is-a-stack-of-windows) |
| "what's at this spot?" | `AXUIElementCopyElementAtPosition` (Accessibility API) | [02 · step 4](02-design.md#the-flow-step-by-step) |
| is the desktop showing here? | `CGWindowListCopyWindowInfo`, the list of on-screen windows | [02 · step 3](02-design.md#the-flow-step-by-step) |
| floating panel | `NSPanel`, non-activating, floating level | [02 · step 6](02-design.md#the-flow-step-by-step) |
| menu-bar icon | `NSStatusItem` in an app with no Dock icon (`LSUIElement`) | [P1.1](03-rollout-plan.md#p11-app-skeleton) |
| floor plan | AppleScript `desktop position of every item` | [option B](#the-other-ways) |
| main screen | the display with the menu bar, `NSScreen.screens[0]`; both coordinate systems are measured from it | [D1](03-rollout-plan.md#decisions), [P4.1](rollout/P4.1-all-screens.md) |

Next: [01 · the desktop today](01-current-macos-desktop.md).
