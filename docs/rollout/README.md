# Rollout log: step by step

[← Back to the overview](../README.md) · The plan these steps follow: [03 · Rollout plan](../03-rollout-plan.md)

One file per step, written **when the step is built**: what changed, why, and how to check it yourself.

| Step | Phase | What | Status |
|---|---|---|---|
| [P0.1](../03-rollout-plan.md#p01-ask-finder-what-is-under-the-cursor) | P0 | Probe: does Finder say which icon is under the cursor? | ✅ 2026-11-24 (desktop icons proven in the [P2.1 test](P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)) |
| [P0.2](../03-rollout-plan.md#p02-is-the-desktop-showing-at-this-point) | P0 | Probe: is the desktop showing at this point? | 🟡 rows 2–6 proven; top row (Notes) to try |
| [P1.1](P1.1-app-skeleton.md) | P1 | App skeleton, menu bar, build script | ✅ 2026-11-24 |
| [P1.2](../03-rollout-plan.md#p12-preview-panel) | P1 | Preview panel (from a test menu item) | ✅ 2026-11-24 ([step doc](P1.2-preview-panel.md); on the real desktop since P2.1) |
| [P1.3](../03-rollout-plan.md#p13-hover-detection) | P1 | Hover detection (logs only) | ✅ 2026-11-24 ([step doc](P1.3-hover-detection.md)) |
| [P2.1](../03-rollout-plan.md#p21-hover-shows-the-panel) | P2 | Hover shows the panel | ✅ 2026-11-24 ([step doc](P2.1-hover-shows-panel.md), [desktop test](P2.1-hover-shows-panel.md#real-desktop-test-2026-11-24-07310739-utc)) |
| [P2.2](../03-rollout-plan.md#p22-click-to-open) | P2 | Click to open | ✅ 2026-11-24, folders; a file click to try ([step doc](P2.2-click-to-open.md)) |
| [P3.1](../03-rollout-plan.md#p31-launch-at-login) | P3 | Launch at login | 🟡 switched on 2026-11-24 (enabled, no approval needed); log-out/log-in check pending ([step doc](P3.1-launch-at-login.md)) |
| [P3.2](../03-rollout-plan.md#p32-a-grant-that-survives-rebuilds) | P3 | Accessibility that survives rebuilds | ✅ 2026-11-24 ([step doc](P3.2-stable-signing.md)) |
| [P4.1](../03-rollout-plan.md#p41-all-screens) | P4 | All screens (D1 lifted) | 🟡 built 2026-11-24, external-display check pending ([step doc](P4.1-all-screens.md)) |
| [P5.1](../03-rollout-plan.md#p51-finder-windows-in-icon-view) | P5 | Finder windows in icon view (D5 changed) | ✅ 2026-11-24 ([step doc](P5.1-finder-windows-icon-view.md)) |
| [P5.2](../03-rollout-plan.md#p52-list-and-column-views) | P5 | List and column views | ⏭ skipped 2026-11-24 (moved to Later) |
| [P6.1](../03-rollout-plan.md#p61-thumbnails) | P6 | Thumbnails in the rows | ✅ 2026-11-24 ([step doc](P6.1-thumbnails.md)) |
| [P7.1](../03-rollout-plan.md#p71-icon-about-window-readme) | P7 | Icon, About window, README | ✅ 2026-11-24 ([step doc](P7.1-icon-about-readme.md)) |
| [F1](F1-hover-reliability.md) | fix | Sometimes nothing happens on hover | ✅ 2026-11-24, your check pending |

Since [P3.1](P3.1-launch-at-login.md) the app is installed at `~/Applications/Glimpse.app` by `./build.sh`; older step
docs mention `build/Glimpse.app`, where it was built before that.

All commands assume you are in the repo folder:

```bash
cd Glimpse
```
