# AfriSafety design reference

Source: the owner's Claude Design canvas "AfriSafety" (icon concepts plus four
screens). Icon **B, "The Circle"**, was chosen on 2026-10-04.

- `brand/`: icon sources (SVG) and the 512 px Play Store icon
- `reference/`: the canvas's original screen files (`.dc.html`, HTML with inline
  styles). They are the **layout source of truth** for the screens below. Open
  them in a browser to view them roughly (the canvas runtime script is missing,
  but the markup and styles are complete).

Code never uses raw hex. Colours live in `app/lib/core/theme/app_colors.dart`
and the theme in `app_theme.dart`.

## Brand

### Icon: "The Circle"
You at the centre, your people around you. 240-unit grid:

| Element | Geometry | Colour |
|---|---|---|
| Ground | rounded square, r 54 | Ink `#0F1E1C` |
| Outer ring | r 78, stroke 10 | Teal `#0E6B5C` |
| Inner ring | r 52, stroke 10 | Amber `#E0A43A` |
| Member dots | r 12 at (120,42) amber, (188,159) and (52,159) light | Amber / Ground |
| You | r 20 at centre | Ground `#F3F5F4` |

Below 48 px, use the simplified mark: one amber ring (r 66, stroke 18) and a
centre dot (r 24). Implemented as `AfriSafetyLogo` (Flutter), Android adaptive
icon (`res/drawable/ic_launcher_*.xml`, with a monochrome layer for themed
icons), legacy PNGs, and the iOS AppIcon set.

### Colour tokens

| Token | Hex | Use |
|---|---|---|
| `ink` | `#0F1E1C` | Primary text, dark banners, SOS screen ground, icon ground |
| `inkRaised` | `#1B2E2B` | Cards on dark |
| `teal` | `#0E6B5C` | Primary actions, "You" marker, active toggles, progress |
| `tealDark` | `#0A4F44` | Pressed / link hover |
| `mint` | `#DCEDE8` | "Sharing your location" status pill |
| `mintOnDark` | `#8FD3BF` | Positive status on dark ("Seen", "Delivered"), "I am safe" outline |
| `amber` | `#E0A43A` | Accent shapes, member markers, pending status on dark. **Never text on light** |
| `ground` | `#F3F5F4` | App background |
| `surface` | `#FFFFFF` | Cards, sheets, chips |
| `mapGround` | `#E3EAE7` | Map land placeholder, dividers |
| `water` | `#B9D7DE` | Map water |
| `border` | `#C9D3D0` | Chip / secondary button outlines |
| `track` | `#DCE3E1` | Progress track |
| `textMuted` | `#3F4F4C` | Secondary text on light |
| `textMutedOnDark` | `#C9D3D0` | Body text on dark |
| `captionOnDark` | `#A9B7B3` | Captions on dark |
| `toggleOff` | `#8A9693` | Switch track, off |
| `sos` | `#C2410C` | SOS button and emergency fills (white text) |
| `sosText` | `#A3360A` | SOS-coloured text or outline on white |

### Type
- **Bricolage Grotesque** 500/700: headings, the SOS label, big numbers (ETA).
- **DM Sans** 400/500/700: everything else. Body 16, secondary 14, captions 13.
- Both are bundled in `app/assets/fonts` (SIL OFL), never fetched at runtime.

### Shape and spacing
Screen gutter 20 · cards radius 16 · primary buttons radius 14, height 56–60 ·
chips and pills are fully rounded, height 44 · list rows at least 56 · touch
targets at least 44 (we use 48).

## Screens → build phases

| Design screen | Phase | Key parts |
|---|---|---|
| **Home map** (`home-map`) | 1 | Header: logo, Circle switcher chip, settings. Mint status pill "Sharing your location with N people" + **Pause**. Map with member markers (initial in a circle; "You" in teal with halo), dashed Place radius. Bottom sheet "Your circle": avatar, name, status line ("At Home · since 17:40", "Offline · last seen via SMS"), freshness ("Now", "25 min"). Bottom nav: Map · Journey · **SOS** (raised 72 px orange circle) · Circle · Safety |
| **SOS alert sent** (`sos-alert-sent`) | 1 | Dark screen. Pulsing SOS rings, "Alert sent", live-sharing explanation. **Delivery** card: per member Seen / Delivered / Sending, with SMS fallback labelled. Current address. Call SAPS 10111 / Call 112. "I am safe, end alert". Disclaimer |
| **Who can see me** (`who-can-see-me`) | 1 (list, leave) · 2 (history) · 3 (reminders, per-member levels) | Ink E2EE banner. Per-member rows with sharing toggle and level ("Live location" / "SOS alerts only"). Location history retention chip ("7 days"). Sharing reminders toggle. **Pause all sharing**, **Leave Family circle** (SOS outline) |
| **Walk me home** (`walk-me-home`) | 2 | Route map card, "Heading to Home", ETA in teal, progress bar. "Watching your trip" + Edit. Check-in timer row. **Ndifikile** primary button ("I have arrived, stop sharing"). "Something is wrong, send SOS" text link |

## What the design changes in the plan

1. **Per-member sharing levels** ("Lindiwe: SOS alerts only"). With a single
   shared Circle key, every member who has the key can read every location.
   Hiding your live location from one member therefore needs **per-sender keys**:
   each member encrypts their own location with their own key, and hands it only
   to the members they've chosen (the Signal "sender keys" pattern). This also
   simplifies rotation, because a sharer only re-keys their own stream. See
   decision **D7** in `docs/plan.md`. It has to be settled before Phase 1 builds
   the key schema.
2. **"Last seen via SMS"** implies receiving locations by SMS. The only SMS path
   planned is the panic fallback (sent from the phone's SMS app, never
   automatically). So in Phase 1 this status appears only after an SMS panic
   fallback. A general inbound-SMS location channel is not planned.
3. **isiXhosa labels** ("Ndifikile"). Keep the isiXhosa word as the label in
   every language, with a translated subtitle. A first-language speaker should
   confirm the wording before release.
4. **Bottom navigation** (Map · Journey · SOS · Circle · Safety) becomes the
   Phase 1 app shell. The 10111/112 bar stays on the SOS screen and the
   temporary home screen.
