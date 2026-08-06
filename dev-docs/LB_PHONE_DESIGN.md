# LB Phone Design Reference

What LB Phone actually specifies (and doesn't) for third-party custom apps, compiled from the official docs, the official app template, and LB Phone's own shipped UI bundle. Written to answer: what building blocks already exist, and what spacing/safe-area rules apply.

Sources:
- Official docs: `docs.lbscripts.com/phone/custom-apps/`
- Official template repo: `github.com/lbphone/lb-phone-app-template` (`lb-reactts` variant, closest to our stack)
- Ground truth: the actually-shipped, compiled UI in the installed `lb-phone` resource (`ui/dist/assets/*.css`) - this is what really renders in-game, more authoritative than the template

## 1. What the official docs actually specify

Short version: almost nothing about visual design. `custom-apps/` documents wiring (`Config.CustomApps`, `AddCustomApp`/`RemoveCustomApp` exports, `fetchNui`/`onNuiEvent`/`SendCustomAppMessage` data flow), a set of injected globals and helper functions, and one visual convention:

- `data-theme` is set automatically on the document to `"dark"` or `"light"` based on the player's phone theme setting. That's the only enforced visual contract. (We already do this - see §4.)
- `setHomeIndicatorVisible()` exists as an injected component function - an app can hide/show the home-indicator bar itself. We don't currently use this.
- No spacing, color, typography, or component-library spec exists in the docs. The recommended path is "copy the template."

## 2. What the official template (`lb-reactts`) establishes as convention

Not enforced, but this is what LB Phone's own example assumes a custom app looks like:

**Colors** (`colors.css`), toggled via the same `[data-theme='dark']` attribute:
```css
:root {
    --background-primary: #f5f5f5;
    --background-highlight: rgb(220, 220, 220);
    --text-primary: #000000;
    --text-secondary: #8e8e93;
}
[data-theme='dark'] {
    --background-primary: #000000;
    --background-highlight: rgb(20, 20, 20);
    --text-primary: #f2f2f7;
    --text-secondary: #6f6f6f;
}
```

**Typography**: Google Fonts "Poppins" (weights 100-900), loaded via `<link rel="preconnect">` + stylesheet `<link>` in `index.html`. This is the font every native LB Phone app actually ships with (confirmed in the compiled bundle, §3).

**Reset**: `* { margin:0; padding:0; box-sizing:border-box; }`

**Mock phone frame** (`Frame.css` - only used for the standalone browser dev-preview, not a real in-game metric, but roughly matches the real notch/indicator sizing):
- Notch: `top: 0.75rem`, `height: 2.25rem`, `width: 30%`, centered
- Home indicator: `bottom: 0.5rem`, `width: 9rem`, `height: 0.313rem`, centered

## 3. Ground truth from LB Phone's actual shipped UI

Pulled directly from the installed resource's compiled CSS (`ui/dist/assets/index-*.css`, `AppProvider-*.css`).

### Full color token palette LB Phone itself uses
```css
--phone-color-primary: #fff;
--phone-color-opacity: #f2f2f266;
--phone-color-opacity2: #1e1e1e80;
--phone-color-highlight: #fafafa;
--phone-color-highlight2: #f0f0f0;
--phone-color-highlight3: #dcdcdc;
--phone-color-input: #f1f1f1a7;
--phone-text-primary: #000;
--phone-text-secondary: #8e8e93;
--phone-color-hover: #f0f0f0;
--phone-color-border: #c8c8c866;
--phone-color-grey: #8e8e93;
--phone-color-blue: #0a84ff;
--phone-color-green: #32d74b;
--phone-color-red: #ff3b30;
--phone-color-orange: #ff9d0a;
--phone-color-yellow: #cca250;
--app-bg: #ececec;      /* generic app background, used by Settings/Phone/etc. */
--app-bg2: #fff;
--app-secondary: #fff;
--app-secondary2: #ececec;
--app-highlight: #ccc;
--app-highlight2: #999;
--app-highlight3: #fff;
--app-border: #666;
--components-bg: #eee;
--components-secondary: #fff;
--components-highlight: #ccc;
```
Notice these match iOS system colors almost exactly (`#0a84ff` blue, `#32d74b` green, `#ff3b30` red, `#8e8e93` secondary-text grey) - LB Phone's whole design language is an iOS clone. Matching that palette family (not necessarily the exact hexes) reads as "native" instead of "third-party."

### Status bar / notch
```css
.notch-container { position:absolute; top:1.2rem; height:2.25rem; width:30%;
                    left:0; right:0; margin:0 auto; z-index:9999; pointer-events:none; }
.old-notch        { position:absolute; top:.41rem; height:2.63rem; width:40%; z-index:999; }
```
Two notch styles exist (island-style default and an older cutout style depending on player settings); both are `pointer-events:none` overlays.

### Home indicator (bottom swipe bar)
```css
.home-indicator { width:9rem; height:.3125rem; border-radius:.25rem; }
```
Matches the template exactly. Can be hidden per-app via `setHomeIndicatorVisible(false)`.

### Important structural finding: apps do not self-pad for the notch/indicator

Checked the real header/container rules of two built-in apps (Settings, Phone):
```css
.phone-app-container { height:100%; display:flex; flex-direction:column; ... }  /* no top padding */
.settings-container   { height:100%; display:flex; flex-direction:column; ... }  /* no top padding */
```
Neither adds manual top offset for the notch. The phone shell (`AppProvider`) already insets an app's own content rectangle below the status bar and above the home indicator before the app ever renders - the notch/indicator are a separate overlay layer on top of the whole phone screen, not something living inside the app's own viewport. **An app generally does not need extra top padding just to "dodge" the notch; it already gets a clean rectangle.**

This means any top padding in a custom app's own header should be treated as a deliberate design choice (breathing room, icon + title layout) rather than a mandatory safe-area workaround.

### Safe-area-inset support
LB Phone's CEF context does expose `env(safe-area-inset-bottom)` usably (we already rely on it, see §4) - treat `max(<fallback>, env(safe-area-inset-bottom))` as the correct defensive pattern rather than a hardcoded bottom margin, in case indicator visibility or layout changes.

## 4. Where Services+ stands now (applied)

All of the above has been adopted directly - Services+ now reuses LB Phone's own tokens instead of a custom palette:

| Convention | LB Phone / template | Services+ now |
| --- | --- | --- |
| `data-theme` dark/light | Required, auto-set | ✅ Handled (`[data-theme="dark"]` in `styles.css`) |
| Color palette | iOS-style tokens (`#0a84ff` blue, `#8e8e93` grey text, etc.) | ✅ Adopted directly: `--brand`/`--blue` = `--phone-color-blue` (`#0a84ff` light / `#076bcf` dark), `--accent` = `--phone-color-red` (`#ff3b30`), `--green` = `--phone-color-green` (`#32d74b`), `--orange` = `--phone-color-orange` (`#ff9d0a`), `--text`/`--muted` = `--phone-text-primary`/`--phone-text-secondary`, `--surface`/`--surface-muted` = `--app-secondary`/derived from `--app-bg` (`styles.css:1-38`). Leftover green-tinted neutrals (company card overlay, shadows, message-reaction tint) recolored to true neutral black so nothing clashes with the new blue brand hue. |
| Font | Poppins (every native app) | ✅ Adopted - `ui/index.html` loads Poppins from Google Fonts (same as the official template), `styles.css` font-family updated |
| Top safe area | Not required - shell already insets the app | ✅ `.app-header` reduced from `min-height:5.3rem; padding:1.35rem 1rem .8rem` to `min-height:3.75rem; padding:.85rem 1rem` - no more padding reserved for a notch the shell already accounts for |
| Bottom safe area | `env(safe-area-inset-bottom)` pattern | ✅ Already used (`.bottom-nav`, `.message-compose`: `max(Xrem, env(safe-area-inset-bottom))`), unchanged |
| NUI cache-busting | Not mentioned anywhere in docs/template | Not an official requirement, but a real gotcha we found ourselves: FiveM's CEF caches `index.html` indefinitely without explicit `Cache-Control`/`Pragma`/`Expires` meta tags (see `ui/index.html`) - the official template doesn't need this because it's dev-served, not deployed. Keep this. |
| Home indicator visibility | Toggleable via `setHomeIndicatorVisible()` | Not used - fine to leave as-is unless a specific full-bleed screen wants it hidden |

## 5. Practical takeaways

- Top padding is not "for the notch" - the shell already handles it. Header padding is purely a layout/breathing-room decision now (kept modest).
- Keep using `max(<value>, env(safe-area-inset-bottom))` for anything pinned to the bottom edge - confirmed working, matches LB Phone's own pattern.
- Font and color palette now intentionally match LB Phone's own native apps rather than carrying a distinct custom identity - the goal was to read as "built into the phone," not as a third-party app.
- `setHomeIndicatorVisible(false)` is still available if a future full-bleed screen (map, media view) wants to reclaim that space.
