# supportpages.io Style Guide

## Design Philosophy

supportpages.io is a developer tool that auto-generates help documentation from GitHub pull requests. The visual identity reflects the product's nature: **automated, precise, and technical**. We chose a monochrome palette and geometric sans-serif typography to signal engineering credibility without competing with the colourful content our users produce.

The design avoids trend-driven decoration. Colour is used sparingly and functionally. The overall feeling should be: a sharp tool made by people who care about craft.

---

## Typography

### Headline Font: Space Grotesk

- **Source:** [Google Fonts](https://fonts.google.com/specimen/Space+Grotesk)
- **Weights used:** 400, 500, 600, 700
- **Applied to:** Hero headline on the landing page (`h1`)
- **Why:** Space Grotesk is a proportional sans-serif with a geometric skeleton and distinctive character shapes (the single-storey `a`, squared terminals). It reads as technical and modern without resorting to a monospace font. The slightly condensed letterforms work well at large display sizes, and the name itself nods to the developer audience.

```css
font-family: 'Space Grotesk', system-ui, sans-serif;
```

### Body Font: Inter

- **Source:** [Google Fonts](https://fonts.google.com/specimen/Inter)
- **Weights used:** 400, 500, 600, 700, 800
- **Applied to:** All body text, navigation, buttons, form inputs, footer
- **Why:** Inter was designed specifically for screens and has excellent legibility at small sizes. Its large x-height, open apertures, and carefully tuned metrics make it a reliable workhorse for UI text. It pairs naturally with Space Grotesk because both share geometric DNA but serve different roles — display vs body.

```css
font-family: 'Inter', system-ui, sans-serif;
```

### Font Loading

Both fonts are loaded via Google Fonts with `preconnect` hints, scoped to the landing page only via `content_for(:head)`. The authenticated app uses the system font stack to avoid unnecessary network requests.

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Space+Grotesk:wght@400;500;600;700&display=swap" rel="stylesheet">
```

---

## Colour Palette

### Landing Page — "Monochrome" Theme

The landing page uses a dark monochrome palette built entirely from Tailwind's **zinc** scale. No accent hue is used. Contrast and hierarchy come from value (light/dark) rather than colour.

| Role | Token | Hex | Usage |
|------|-------|-----|-------|
| Background | `zinc-950` | `#09090b` | Page background |
| Surface | `zinc-800` | `#27272a` | Input backgrounds, secondary buttons |
| Surface hover | `zinc-700` | `#3f3f46` | Button hover states |
| Border | `zinc-800` | `#27272a` | Input borders, footer divider |
| Body text | `zinc-400` | `#a1a1aa` | Subtitle, nav links, descriptions |
| Muted text | `zinc-500` | `#71717a` | Waitlist label, placeholder text |
| Subdued text | `zinc-600` | `#52525b` | Footer text, legal links |
| Primary text | `white` | `#ffffff` | Hero headline (via gradient), CTA button text overlay, active nav |
| CTA button | `white` | `#ffffff` | Primary call-to-action background |
| CTA text | `zinc-950` | `#09090b` | Button label (dark-on-light inversion) |

### Hero Headline Gradient

The headline uses a subtle metallic gradient across zinc tones, giving the text dimension without introducing colour:

```css
.text-gradient-hero {
  background: linear-gradient(135deg, #e4e4e7 0%, #a1a1aa 50%, #f4f4f5 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
```

The gradient runs zinc-200 to zinc-400 to zinc-100, creating a brushed-metal shimmer that catches the eye without screaming for attention.

### CTA Glow

The primary button pulses with a soft zinc glow to draw attention. The animation is slow (3s cycle) and low-intensity so it reads as ambient rather than urgent:

```css
@keyframes glow-pulse {
  0%, 100% { box-shadow: 0 0 20px rgb(161 161 170 / 0.3), 0 0 60px rgb(161 161 170 / 0.1); }
  50%      { box-shadow: 0 0 30px rgb(161 161 170 / 0.5), 0 0 80px rgb(161 161 170 / 0.2); }
}
```

`161 161 170` is zinc-400 in RGB. This keeps the glow strictly within the monochrome family.

### Flash Messages

Flash messages use semantic colour to stand apart from the monochrome palette — this is intentional. Success and error states must be immediately recognisable:

| Type | Background | Border | Text |
|------|-----------|--------|------|
| Notice (success) | `emerald-500/10` | `emerald-500/30` | `emerald-300` |
| Alert (error) | `red-500/10` | `red-500/30` | `red-300` |

These use low-opacity backgrounds with `backdrop-blur-sm` to sit naturally on the dark surface.

### Authenticated App

The authenticated dashboard and settings pages use Tailwind's **slate** scale on a light background. This is a separate context from the landing page:

| Role | Token | Usage |
|------|-------|-------|
| Background | `gray-50` | Page background (from layout) |
| Card | `white` | Content cards |
| Primary text | `slate-900` | Headings |
| Body text | `slate-600` | Paragraphs |
| Muted text | `slate-500` | Labels, hints |
| Brand accent | `violet-600` | Links, primary buttons, focus rings |

The brand violet (`#7c3aed` to `#a855f7`) is used in the app but deliberately excluded from the landing page to keep the two contexts distinct.

---

## Layout

### Landing Page Structure

The page is a single full-viewport dark container (`bg-zinc-950 min-h-screen`) that overrides the layout's light background. Content is centered with generous vertical spacing.

```
[Transparent header]
[Animated background orbs]
[Hero headline — Space Grotesk, 5xl → 7xl responsive]
[Subtitle — Inter, lg → xl responsive]
[Video player with autoplay overlay]
[Primary CTA — white button with glow]
[Waitlist form — secondary, muted]
[Dark footer — company details + legal links]
```

**Key dimensions:**
- Max content width: `max-w-4xl` (headline), `max-w-3xl` (video), `max-w-2xl` (subtitle), `max-w-md` (waitlist)
- Top padding: `pt-28` (accounts for transparent header)
- Section spacing: `mt-12` between major blocks

### Responsive Behaviour

The headline scales across three breakpoints:
- Mobile: `text-5xl` (3rem)
- Small: `text-6xl` (3.75rem)
- Medium+: `text-7xl` (4.5rem)

All other content stacks naturally. The footer switches from stacked to side-by-side at `sm:`.

---

## Animation

### Background Orbs

Three blurred circles drift slowly across the background, creating subtle ambient movement. Each has a unique animation duration to prevent synchronisation:

| Orb | Size | Opacity | Duration | Colour |
|-----|------|---------|----------|--------|
| 1 | 600px | 12% | 20s | `zinc-500` |
| 2 | 500px | 12% | 25s | `zinc-400` |
| 3 | 400px | 12% | 22s | `zinc-600` |

All orbs use `blur-3xl` and `pointer-events-none`. The varying zinc tones create just enough depth without any colour.

### Video Player

The video autoplays silently (`muted loop playsinline`) as an ambient preview. A frosted overlay (`bg-zinc-950/60 backdrop-blur-sm`) sits on top with a play button and "Watch with sound" prompt. On click:

1. Overlay hides
2. Video restarts from 0:00
3. Unmutes with native controls
4. Loop disabled (plays once through)

This pattern gives visitors an immediate sense of the product while respecting autoplay etiquette.

---

## Component Patterns

### Buttons

**Landing page** — Two tiers only:

| Tier | Style | Usage |
|------|-------|-------|
| Primary | `bg-white text-zinc-950 rounded-xl px-8 py-4 text-lg font-semibold` + glow | GitHub sign in |
| Secondary | `bg-zinc-800 text-zinc-200 rounded-lg px-5 py-2.5 text-sm font-medium` | Waitlist submit |

The primary button is deliberately oversized and white — it's the only bright element on the page, making it the natural focal point.

**Authenticated app** — Full hierarchy defined in `application.css`:

| Class | Usage |
|-------|-------|
| `.btn-primary-{sm,md,lg}` | Main CTAs (violet gradient) |
| `.btn-secondary-{sm,md,lg}` | Alternative actions (slate) |
| `.btn-success-sm` | Accept/approve (emerald) |
| `.btn-danger-{sm,md}` | Destructive actions (red) |
| `.btn-ghost-sm` | Subtle/tertiary actions (white + border) |

### Form Inputs (Landing Page)

```
bg-zinc-800/50 border-zinc-800 text-white placeholder-zinc-500
focus:ring-2 focus:ring-zinc-400 focus:border-zinc-400
backdrop-blur-sm rounded-lg
```

The 50% opacity background with `backdrop-blur-sm` lets the orb animations show through subtly, tying the inputs into the ambient background.

### Header

The public header partial accepts a `theme` parameter:

- **`"light"` (default):** White background, slate text, violet accent on "Sign in". Used on legal pages.
- **`"dark"`:** Transparent, absolute positioned, zinc text, no accent colour. Used on landing page.

Light-themed pages are unaffected by the dark landing page — the theme is opt-in per view.

---

## Rationale: Why Monochrome?

We evaluated 20 colour palettes (10 dark, 10 light) through a custom colour picker tool during development. The Monochrome theme was chosen for several reasons:

1. **Audience alignment.** Developers respond to restraint. A monochrome palette signals that the product is serious infrastructure, not a marketing toy.

2. **Content neutrality.** supportpages.io generates documentation for other people's products. A neutral chrome avoids clashing with any user's brand colours.

3. **Timelessness.** Monochrome doesn't date. Violet, teal, and amber themes we tested all felt tied to specific trend cycles.

4. **Focus.** With no accent colour competing for attention, the white CTA button and the video player become the clear focal points. The hierarchy is effortless.

5. **Technical character.** The zinc scale has a cooler, more neutral undertone than gray or slate. It reads as "machined" rather than "designed" — appropriate for a tool that automates documentation.

---

## Files Reference

| File | What it controls |
|------|-----------------|
| `app/assets/tailwind/application.css` | Animation keyframes, gradient utilities, button/card classes |
| `app/views/sessions/new.html.erb` | Landing page layout and content |
| `app/views/shared/_public_header.html.erb` | Public header (light/dark theme) |
| `app/javascript/controllers/video_player_controller.js` | Autoplay + click-to-unmute behaviour |
| `app/javascript/controllers/color_picker_controller.js` | Dev-only colour picker (disabled, preserved for future use) |

---

## Dev Tool: Colour Picker

A full-featured colour picker with 20 presets, 12 colour channels, opacity slider, and font selector is preserved in `color_picker_controller.js`. It is currently disabled in `application.js` (import and registration commented out).

To re-enable for future design experimentation:

1. Uncomment the import and registration in `app/javascript/application.js`
2. Add `data-controller="color-picker"` to the landing page wrapper div
3. The picker panel will appear fixed to the right side of the viewport
