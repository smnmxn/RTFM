"""
Generates browser-ready CSS containing Tailwind's preflight reset
and ~200 common utility classes. Used as a fallback when Tailwind
source compilation fails inside the Docker container.

Usage: python3 /tailwind_fallback.py >> /output/compiled_css.txt
"""

# ── Preflight (Tailwind's modern-normalize-based reset) ──────────────────────

PREFLIGHT = """\
/* Tailwind CSS Fallback — preflight + common utilities */
*, ::before, ::after {
  box-sizing: border-box;
  border-width: 0;
  border-style: solid;
  border-color: #e5e7eb;
}
html {
  line-height: 1.5;
  -webkit-text-size-adjust: 100%;
  -moz-tab-size: 4;
  tab-size: 4;
  font-family: ui-sans-serif, system-ui, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
  font-feature-settings: normal;
  font-variation-settings: normal;
}
body { margin: 0; line-height: inherit; }
hr { height: 0; color: inherit; border-top-width: 1px; }
h1, h2, h3, h4, h5, h6 { font-size: inherit; font-weight: inherit; }
a { color: inherit; text-decoration: inherit; }
b, strong { font-weight: bolder; }
code, kbd, samp, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; font-size: 1em; }
small { font-size: 80%; }
sub, sup { font-size: 75%; line-height: 0; position: relative; vertical-align: baseline; }
sub { bottom: -0.25em; }
sup { top: -0.5em; }
table { text-indent: 0; border-color: inherit; border-collapse: collapse; }
button, input, optgroup, select, textarea { font-family: inherit; font-feature-settings: inherit; font-variation-settings: inherit; font-size: 100%; font-weight: inherit; line-height: inherit; color: inherit; margin: 0; padding: 0; }
button, select { text-transform: none; }
button, [type='button'], [type='reset'], [type='submit'] { -webkit-appearance: button; background-color: transparent; background-image: none; }
:-moz-focusring { outline: auto; }
:-moz-ui-invalid { box-shadow: none; }
progress { vertical-align: baseline; }
::-webkit-inner-spin-button, ::-webkit-outer-spin-button { height: auto; }
[type='search'] { -webkit-appearance: textfield; outline-offset: -2px; }
::-webkit-search-decoration { -webkit-appearance: none; }
::-webkit-file-upload-button { -webkit-appearance: button; font: inherit; }
summary { display: list-item; }
blockquote, dl, dd, h1, h2, h3, h4, h5, h6, hr, figure, p, pre { margin: 0; }
fieldset { margin: 0; padding: 0; }
legend { padding: 0; }
ol, ul, menu { list-style: none; margin: 0; padding: 0; }
dialog { padding: 0; }
textarea { resize: vertical; }
input::placeholder, textarea::placeholder { opacity: 1; color: #9ca3af; }
button, [role="button"] { cursor: pointer; }
:disabled { cursor: default; }
img, svg, video, canvas, audio, iframe, embed, object { display: block; vertical-align: middle; }
img, video { max-width: 100%; height: auto; }
[hidden] { display: none; }
"""

# ── Utility definitions ──────────────────────────────────────────────────────

def spacing(n):
    return f"{n * 0.25}rem"

UTILITIES = {}

# Display
for name, val in [
    ("block", "block"), ("inline-block", "inline-block"), ("inline", "inline"),
    ("flex", "flex"), ("inline-flex", "inline-flex"), ("grid", "grid"),
    ("inline-grid", "inline-grid"), ("hidden", "none"), ("table", "table"),
    ("table-row", "table-row"), ("table-cell", "table-cell"),
]:
    UTILITIES[name] = f"display: {val}"

# Flex / Grid
UTILITIES.update({
    "items-center": "align-items: center", "items-start": "align-items: flex-start",
    "items-end": "align-items: flex-end", "items-stretch": "align-items: stretch",
    "items-baseline": "align-items: baseline",
    "justify-center": "justify-content: center", "justify-between": "justify-content: space-between",
    "justify-end": "justify-content: flex-end", "justify-start": "justify-content: flex-start",
    "justify-around": "justify-content: space-around", "justify-evenly": "justify-content: space-evenly",
    "flex-col": "flex-direction: column", "flex-row": "flex-direction: row",
    "flex-col-reverse": "flex-direction: column-reverse", "flex-row-reverse": "flex-direction: row-reverse",
    "flex-wrap": "flex-wrap: wrap", "flex-nowrap": "flex-wrap: nowrap",
    "flex-1": "flex: 1 1 0%", "flex-auto": "flex: 1 1 auto", "flex-none": "flex: none",
    "flex-shrink-0": "flex-shrink: 0", "flex-grow": "flex-grow: 1", "flex-grow-0": "flex-grow: 0",
    "self-auto": "align-self: auto", "self-start": "align-self: flex-start",
    "self-end": "align-self: flex-end", "self-center": "align-self: center",
    "self-stretch": "align-self: stretch",
    "order-first": "order: -9999", "order-last": "order: 9999", "order-none": "order: 0",
})

# Grid
for n in range(1, 13):
    UTILITIES[f"grid-cols-{n}"] = f"grid-template-columns: repeat({n}, minmax(0, 1fr))"
for n in range(1, 7):
    UTILITIES[f"col-span-{n}"] = f"grid-column: span {n} / span {n}"
UTILITIES["col-span-full"] = "grid-column: 1 / -1"

# Gap
for n in list(range(0, 13)) + [14, 16, 20, 24]:
    UTILITIES[f"gap-{n}"] = f"gap: {spacing(n)}"
    UTILITIES[f"gap-x-{n}"] = f"column-gap: {spacing(n)}"
    UTILITIES[f"gap-y-{n}"] = f"row-gap: {spacing(n)}"
UTILITIES["gap-0.5"] = "gap: 0.125rem"
UTILITIES["gap-1.5"] = "gap: 0.375rem"
UTILITIES["gap-2.5"] = "gap: 0.625rem"
UTILITIES["gap-3.5"] = "gap: 0.875rem"

# Spacing (p, px, py, pt, pb, pl, pr, m, mx, my, mt, mb, ml, mr)
spacing_sides = {
    "": [("padding", "")], "x": [("padding-left", ""), ("padding-right", "")],
    "y": [("padding-top", ""), ("padding-bottom", "")],
    "t": [("padding-top", "")], "b": [("padding-bottom", "")],
    "l": [("padding-left", "")], "r": [("padding-right", "")],
}
for n in list(range(0, 13)) + [14, 16, 20, 24, 32, 40, 48, 64]:
    val = spacing(n)
    for suffix, props in spacing_sides.items():
        UTILITIES[f"p{suffix}-{n}"] = "; ".join(f"{p}: {val}" for p, _ in props)
    for suffix, props in spacing_sides.items():
        m_props = [(p.replace("padding", "margin"), v) for p, v in props]
        UTILITIES[f"m{suffix}-{n}"] = "; ".join(f"{p}: {val}" for p, _ in m_props)

# Fractional spacing
for cls, val in [("0.5", "0.125rem"), ("1.5", "0.375rem"), ("2.5", "0.625rem"), ("3.5", "0.875rem")]:
    UTILITIES[f"p-{cls}"] = f"padding: {val}"
    UTILITIES[f"px-{cls}"] = f"padding-left: {val}; padding-right: {val}"
    UTILITIES[f"py-{cls}"] = f"padding-top: {val}; padding-bottom: {val}"
    UTILITIES[f"m-{cls}"] = f"margin: {val}"
    UTILITIES[f"mx-{cls}"] = f"margin-left: {val}; margin-right: {val}"
    UTILITIES[f"my-{cls}"] = f"margin-top: {val}; margin-bottom: {val}"

UTILITIES["mx-auto"] = "margin-left: auto; margin-right: auto"
UTILITIES["my-auto"] = "margin-top: auto; margin-bottom: auto"
UTILITIES["ml-auto"] = "margin-left: auto"
UTILITIES["mr-auto"] = "margin-right: auto"

# Space between (child combinator)
for n in [1, 2, 3, 4, 5, 6, 8]:
    UTILITIES[f"space-x-{n} > * + *"] = f"margin-left: {spacing(n)}"
    UTILITIES[f"space-y-{n} > * + *"] = f"margin-top: {spacing(n)}"

# Sizing
UTILITIES.update({
    "w-full": "width: 100%", "w-auto": "width: auto", "w-screen": "width: 100vw",
    "w-fit": "width: fit-content", "w-min": "width: min-content", "w-max": "width: max-content",
    "h-full": "height: 100%", "h-auto": "height: auto", "h-screen": "height: 100vh",
    "h-fit": "height: fit-content", "h-min": "height: min-content", "h-max": "height: max-content",
    "min-h-0": "min-height: 0", "min-h-full": "min-height: 100%", "min-h-screen": "min-height: 100vh",
    "min-w-0": "min-width: 0", "min-w-full": "min-width: 100%",
    "max-w-none": "max-width: none", "max-w-xs": "max-width: 20rem",
    "max-w-sm": "max-width: 24rem", "max-w-md": "max-width: 28rem",
    "max-w-lg": "max-width: 32rem", "max-w-xl": "max-width: 36rem",
    "max-w-2xl": "max-width: 42rem", "max-w-3xl": "max-width: 48rem",
    "max-w-4xl": "max-width: 56rem", "max-w-5xl": "max-width: 64rem",
    "max-w-6xl": "max-width: 72rem", "max-w-7xl": "max-width: 80rem",
    "max-w-full": "max-width: 100%", "max-w-screen-sm": "max-width: 640px",
    "max-w-screen-md": "max-width: 768px", "max-w-screen-lg": "max-width: 1024px",
    "max-w-screen-xl": "max-width: 1280px", "max-w-screen-2xl": "max-width: 1536px",
    "max-w-prose": "max-width: 65ch",
    "max-h-full": "max-height: 100%", "max-h-screen": "max-height: 100vh",
})
for n in list(range(0, 13)) + [14, 16, 20, 24, 32, 40, 48, 56, 64]:
    UTILITIES[f"w-{n}"] = f"width: {spacing(n)}"
    UTILITIES[f"h-{n}"] = f"height: {spacing(n)}"
    UTILITIES[f"size-{n}"] = f"width: {spacing(n)}; height: {spacing(n)}"
# Fractional sizes
for cls, val in [("0.5", "0.125rem"), ("1.5", "0.375rem"), ("2.5", "0.625rem"), ("3.5", "0.875rem")]:
    UTILITIES[f"size-{cls}"] = f"width: {val}; height: {val}"
UTILITIES["size-full"] = "width: 100%; height: 100%"
UTILITIES["size-fit"] = "width: fit-content; height: fit-content"
for num, den in [(1,2), (1,3), (2,3), (1,4), (3,4), (1,5), (2,5), (3,5), (4,5), (1,6), (5,6)]:
    pct = f"{round(num/den*100, 4)}%"
    UTILITIES[f"w-{num}/{den}"] = f"width: {pct}"
for n in range(1, 12):
    UTILITIES[f"w-{n}/12"] = f"width: {round(n/12*100, 4)}%"

# Typography
UTILITIES.update({
    "text-xs": "font-size: 0.75rem; line-height: 1rem",
    "text-sm": "font-size: 0.875rem; line-height: 1.25rem",
    "text-base": "font-size: 1rem; line-height: 1.5rem",
    "text-lg": "font-size: 1.125rem; line-height: 1.75rem",
    "text-xl": "font-size: 1.25rem; line-height: 1.75rem",
    "text-2xl": "font-size: 1.5rem; line-height: 2rem",
    "text-3xl": "font-size: 1.875rem; line-height: 2.25rem",
    "text-4xl": "font-size: 2.25rem; line-height: 2.5rem",
    "text-5xl": "font-size: 3rem; line-height: 1",
    "text-6xl": "font-size: 3.75rem; line-height: 1",
    "font-thin": "font-weight: 100", "font-light": "font-weight: 300",
    "font-normal": "font-weight: 400", "font-medium": "font-weight: 500",
    "font-semibold": "font-weight: 600", "font-bold": "font-weight: 700",
    "font-extrabold": "font-weight: 800", "font-black": "font-weight: 900",
    "text-left": "text-align: left", "text-center": "text-align: center",
    "text-right": "text-align: right", "text-justify": "text-align: justify",
    "uppercase": "text-transform: uppercase", "lowercase": "text-transform: lowercase",
    "capitalize": "text-transform: capitalize", "normal-case": "text-transform: none",
    "truncate": "overflow: hidden; text-overflow: ellipsis; white-space: nowrap",
    "leading-none": "line-height: 1", "leading-tight": "line-height: 1.25",
    "leading-snug": "line-height: 1.375", "leading-normal": "line-height: 1.5",
    "leading-relaxed": "line-height: 1.625", "leading-loose": "line-height: 2",
    "tracking-tighter": "letter-spacing: -0.05em", "tracking-tight": "letter-spacing: -0.025em",
    "tracking-normal": "letter-spacing: 0", "tracking-wide": "letter-spacing: 0.025em",
    "tracking-wider": "letter-spacing: 0.05em", "tracking-widest": "letter-spacing: 0.1em",
    "underline": "text-decoration-line: underline", "overline": "text-decoration-line: overline",
    "line-through": "text-decoration-line: line-through", "no-underline": "text-decoration-line: none",
    "italic": "font-style: italic", "not-italic": "font-style: normal",
    "font-mono": "font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace",
    "font-sans": "font-family: ui-sans-serif, system-ui, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji'",
    "font-serif": "font-family: ui-serif, Georgia, Cambria, 'Times New Roman', Times, serif",
    "antialiased": "-webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale",
})

# Colors (gray, slate, zinc, red, orange, amber, yellow, green, emerald, teal, cyan, blue, indigo, violet, purple, pink)
COLOR_SCALES = {
    "gray":    {50:"#f9fafb",100:"#f3f4f6",200:"#e5e7eb",300:"#d1d5db",400:"#9ca3af",500:"#6b7280",600:"#4b5563",700:"#374151",800:"#1f2937",900:"#111827",950:"#030712"},
    "slate":   {50:"#f8fafc",100:"#f1f5f9",200:"#e2e8f0",300:"#cbd5e1",400:"#94a3b8",500:"#64748b",600:"#475569",700:"#334155",800:"#1e293b",900:"#0f172a",950:"#020617"},
    "zinc":    {50:"#fafafa",100:"#f4f4f5",200:"#e4e4e7",300:"#d4d4d8",400:"#a1a1aa",500:"#71717a",600:"#52525b",700:"#3f3f46",800:"#27272a",900:"#18181b",950:"#09090b"},
    "red":     {50:"#fef2f2",100:"#fee2e2",200:"#fecaca",300:"#fca5a5",400:"#f87171",500:"#ef4444",600:"#dc2626",700:"#b91c1c",800:"#991b1b",900:"#7f1d1d",950:"#450a0a"},
    "orange":  {50:"#fff7ed",100:"#ffedd5",200:"#fed7aa",300:"#fdba74",400:"#fb923c",500:"#f97316",600:"#ea580c",700:"#c2410c",800:"#9a3412",900:"#7c2d12",950:"#431407"},
    "amber":   {50:"#fffbeb",100:"#fef3c7",200:"#fde68a",300:"#fcd34d",400:"#fbbf24",500:"#f59e0b",600:"#d97706",700:"#b45309",800:"#92400e",900:"#78350f",950:"#451a03"},
    "yellow":  {50:"#fefce8",100:"#fef9c3",200:"#fef08a",300:"#fde047",400:"#facc15",500:"#eab308",600:"#ca8a04",700:"#a16207",800:"#854d0e",900:"#713f12",950:"#422006"},
    "green":   {50:"#f0fdf4",100:"#dcfce7",200:"#bbf7d0",300:"#86efac",400:"#4ade80",500:"#22c55e",600:"#16a34a",700:"#15803d",800:"#166534",900:"#14532d",950:"#052e16"},
    "emerald": {50:"#ecfdf5",100:"#d1fae5",200:"#a7f3d0",300:"#6ee7b7",400:"#34d399",500:"#10b981",600:"#059669",700:"#047857",800:"#065f46",900:"#064e3b",950:"#022c22"},
    "teal":    {50:"#f0fdfa",100:"#ccfbf1",200:"#99f6e4",300:"#5eead4",400:"#2dd4bf",500:"#14b8a6",600:"#0d9488",700:"#0f766e",800:"#115e59",900:"#134e4a",950:"#042f2e"},
    "cyan":    {50:"#ecfeff",100:"#cffafe",200:"#a5f3fc",300:"#67e8f9",400:"#22d3ee",500:"#06b6d4",600:"#0891b2",700:"#0e7490",800:"#155e75",900:"#164e63",950:"#083344"},
    "blue":    {50:"#eff6ff",100:"#dbeafe",200:"#bfdbfe",300:"#93c5fd",400:"#60a5fa",500:"#3b82f6",600:"#2563eb",700:"#1d4ed8",800:"#1e40af",900:"#1e3a8a",950:"#172554"},
    "indigo":  {50:"#eef2ff",100:"#e0e7ff",200:"#c7d2fe",300:"#a5b4fc",400:"#818cf8",500:"#6366f1",600:"#4f46e5",700:"#4338ca",800:"#3730a3",900:"#312e81",950:"#1e1b4b"},
    "violet":  {50:"#f5f3ff",100:"#ede9fe",200:"#ddd6fe",300:"#c4b5fd",400:"#a78bfa",500:"#8b5cf6",600:"#7c3aed",700:"#6d28d9",800:"#5b21b6",900:"#4c1d95",950:"#2e1065"},
    "purple":  {50:"#faf5ff",100:"#f3e8ff",200:"#e9d5ff",300:"#d8b4fe",400:"#c084fc",500:"#a855f7",600:"#9333ea",700:"#7e22ce",800:"#6b21a8",900:"#581c87",950:"#3b0764"},
    "pink":    {50:"#fdf2f8",100:"#fce7f3",200:"#fbcfe8",300:"#f9a8d4",400:"#f472b6",500:"#ec4899",600:"#db2777",700:"#be185d",800:"#9d174d",900:"#831843",950:"#500724"},
}

for color_name, shades in COLOR_SCALES.items():
    for weight, hex_val in shades.items():
        UTILITIES[f"text-{color_name}-{weight}"] = f"color: {hex_val}"
        UTILITIES[f"bg-{color_name}-{weight}"] = f"background-color: {hex_val}"
        UTILITIES[f"border-{color_name}-{weight}"] = f"border-color: {hex_val}"

UTILITIES.update({
    "text-white": "color: #fff", "text-black": "color: #000",
    "text-transparent": "color: transparent",
    "bg-white": "background-color: #fff", "bg-black": "background-color: #000",
    "bg-transparent": "background-color: transparent",
    "border-white": "border-color: #fff", "border-black": "border-color: #000",
    "border-transparent": "border-color: transparent",
})

# Borders
UTILITIES.update({
    "border": "border-width: 1px", "border-0": "border-width: 0",
    "border-2": "border-width: 2px", "border-4": "border-width: 4px",
    "border-8": "border-width: 8px",
    "border-t": "border-top-width: 1px", "border-b": "border-bottom-width: 1px",
    "border-l": "border-left-width: 1px", "border-r": "border-right-width: 1px",
    "border-t-0": "border-top-width: 0", "border-b-0": "border-bottom-width: 0",
    "border-t-2": "border-top-width: 2px", "border-b-2": "border-bottom-width: 2px",
    "rounded-none": "border-radius: 0", "rounded-sm": "border-radius: 0.125rem",
    "rounded": "border-radius: 0.25rem", "rounded-md": "border-radius: 0.375rem",
    "rounded-lg": "border-radius: 0.5rem", "rounded-xl": "border-radius: 0.75rem",
    "rounded-2xl": "border-radius: 1rem", "rounded-3xl": "border-radius: 1.5rem",
    "rounded-full": "border-radius: 9999px",
    "rounded-t-md": "border-top-left-radius: 0.375rem; border-top-right-radius: 0.375rem",
    "rounded-b-md": "border-bottom-left-radius: 0.375rem; border-bottom-right-radius: 0.375rem",
    "rounded-t-lg": "border-top-left-radius: 0.5rem; border-top-right-radius: 0.5rem",
    "rounded-b-lg": "border-bottom-left-radius: 0.5rem; border-bottom-right-radius: 0.5rem",
    "border-solid": "border-style: solid", "border-dashed": "border-style: dashed",
    "border-dotted": "border-style: dotted", "border-none": "border-style: none",
    "divide-y > * + *": "border-top-width: 1px",
    "divide-x > * + *": "border-left-width: 1px",
})

# Shadows
UTILITIES.update({
    "shadow-sm": "box-shadow: 0 1px 2px 0 rgba(0,0,0,.05)",
    "shadow": "box-shadow: 0 1px 3px 0 rgba(0,0,0,.1), 0 1px 2px -1px rgba(0,0,0,.1)",
    "shadow-md": "box-shadow: 0 4px 6px -1px rgba(0,0,0,.1), 0 2px 4px -2px rgba(0,0,0,.1)",
    "shadow-lg": "box-shadow: 0 10px 15px -3px rgba(0,0,0,.1), 0 4px 6px -4px rgba(0,0,0,.1)",
    "shadow-xl": "box-shadow: 0 20px 25px -5px rgba(0,0,0,.1), 0 8px 10px -6px rgba(0,0,0,.1)",
    "shadow-2xl": "box-shadow: 0 25px 50px -12px rgba(0,0,0,.25)",
    "shadow-inner": "box-shadow: inset 0 2px 4px 0 rgba(0,0,0,.05)",
    "shadow-none": "box-shadow: 0 0 #0000",
})

# Ring
UTILITIES.update({
    "ring-0": "box-shadow: 0 0 0 0px var(--tw-ring-color, rgba(59,130,246,.5))",
    "ring-1": "box-shadow: 0 0 0 1px var(--tw-ring-color, rgba(59,130,246,.5))",
    "ring-2": "box-shadow: 0 0 0 2px var(--tw-ring-color, rgba(59,130,246,.5))",
    "ring-4": "box-shadow: 0 0 0 4px var(--tw-ring-color, rgba(59,130,246,.5))",
})

# Opacity
for n in [0, 5, 10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 95, 100]:
    UTILITIES[f"opacity-{n}"] = f"opacity: {n/100}"

# Position
UTILITIES.update({
    "static": "position: static", "relative": "position: relative",
    "absolute": "position: absolute", "fixed": "position: fixed",
    "sticky": "position: sticky",
    "inset-0": "inset: 0", "inset-x-0": "left: 0; right: 0", "inset-y-0": "top: 0; bottom: 0",
    "top-0": "top: 0", "right-0": "right: 0", "bottom-0": "bottom: 0", "left-0": "left: 0",
    "top-1": "top: 0.25rem", "top-2": "top: 0.5rem", "top-4": "top: 1rem",
    "right-1": "right: 0.25rem", "right-2": "right: 0.5rem", "right-4": "right: 1rem",
    "bottom-1": "bottom: 0.25rem", "bottom-2": "bottom: 0.5rem", "bottom-4": "bottom: 1rem",
    "left-1": "left: 0.25rem", "left-2": "left: 0.5rem", "left-4": "left: 1rem",
    "-top-1": "top: -0.25rem", "-top-2": "top: -0.5rem",
    "-right-1": "right: -0.25rem", "-left-1": "left: -0.25rem",
})

# Z-index
for n in [0, 10, 20, 30, 40, 50]:
    UTILITIES[f"z-{n}"] = f"z-index: {n}"
UTILITIES["z-auto"] = "z-index: auto"

# Overflow
UTILITIES.update({
    "overflow-auto": "overflow: auto", "overflow-hidden": "overflow: hidden",
    "overflow-visible": "overflow: visible", "overflow-scroll": "overflow: scroll",
    "overflow-x-auto": "overflow-x: auto", "overflow-x-hidden": "overflow-x: hidden",
    "overflow-y-auto": "overflow-y: auto", "overflow-y-hidden": "overflow-y: hidden",
})

# Cursor & interaction
UTILITIES.update({
    "cursor-pointer": "cursor: pointer", "cursor-default": "cursor: default",
    "cursor-not-allowed": "cursor: not-allowed", "cursor-text": "cursor: text",
    "pointer-events-none": "pointer-events: none", "pointer-events-auto": "pointer-events: auto",
    "select-none": "user-select: none", "select-text": "user-select: text",
    "select-all": "user-select: all", "select-auto": "user-select: auto",
})

# Transitions
UTILITIES.update({
    "transition": "transition-property: color, background-color, border-color, text-decoration-color, fill, stroke, opacity, box-shadow, transform, filter, backdrop-filter; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 150ms",
    "transition-all": "transition-property: all; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 150ms",
    "transition-colors": "transition-property: color, background-color, border-color, text-decoration-color, fill, stroke; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 150ms",
    "transition-opacity": "transition-property: opacity; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 150ms",
    "transition-shadow": "transition-property: box-shadow; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 150ms",
    "transition-transform": "transition-property: transform; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 150ms",
    "transition-none": "transition-property: none",
    "duration-75": "transition-duration: 75ms", "duration-100": "transition-duration: 100ms",
    "duration-150": "transition-duration: 150ms", "duration-200": "transition-duration: 200ms",
    "duration-300": "transition-duration: 300ms", "duration-500": "transition-duration: 500ms",
    "ease-linear": "transition-timing-function: linear",
    "ease-in": "transition-timing-function: cubic-bezier(0.4, 0, 1, 1)",
    "ease-out": "transition-timing-function: cubic-bezier(0, 0, 0.2, 1)",
    "ease-in-out": "transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1)",
})

# Transform
UTILITIES.update({
    "scale-0": "transform: scale(0)", "scale-50": "transform: scale(.5)",
    "scale-75": "transform: scale(.75)", "scale-90": "transform: scale(.9)",
    "scale-95": "transform: scale(.95)", "scale-100": "transform: scale(1)",
    "scale-105": "transform: scale(1.05)", "scale-110": "transform: scale(1.1)",
    "scale-125": "transform: scale(1.25)", "scale-150": "transform: scale(1.5)",
    "rotate-0": "transform: rotate(0deg)", "rotate-1": "transform: rotate(1deg)",
    "rotate-2": "transform: rotate(2deg)", "rotate-3": "transform: rotate(3deg)",
    "rotate-6": "transform: rotate(6deg)", "rotate-12": "transform: rotate(12deg)",
    "rotate-45": "transform: rotate(45deg)", "rotate-90": "transform: rotate(90deg)",
    "rotate-180": "transform: rotate(180deg)",
    "translate-x-0": "transform: translateX(0)", "translate-x-1": "transform: translateX(0.25rem)",
    "translate-x-2": "transform: translateX(0.5rem)", "translate-x-4": "transform: translateX(1rem)",
    "translate-y-0": "transform: translateY(0)", "translate-y-1": "transform: translateY(0.25rem)",
    "translate-y-2": "transform: translateY(0.5rem)", "translate-y-4": "transform: translateY(1rem)",
    "-translate-x-1": "transform: translateX(-0.25rem)", "-translate-y-1": "transform: translateY(-0.25rem)",
    "translate-x-1/2": "transform: translateX(50%)", "-translate-x-1/2": "transform: translateX(-50%)",
    "translate-y-1/2": "transform: translateY(50%)", "-translate-y-1/2": "transform: translateY(-50%)",
})

# Object fit
UTILITIES.update({
    "object-contain": "object-fit: contain", "object-cover": "object-fit: cover",
    "object-fill": "object-fit: fill", "object-none": "object-fit: none",
    "object-center": "object-position: center",
})

# Whitespace & word
UTILITIES.update({
    "whitespace-normal": "white-space: normal", "whitespace-nowrap": "white-space: nowrap",
    "whitespace-pre": "white-space: pre", "whitespace-pre-line": "white-space: pre-line",
    "whitespace-pre-wrap": "white-space: pre-wrap",
    "break-normal": "overflow-wrap: normal; word-break: normal",
    "break-words": "overflow-wrap: break-word",
    "break-all": "word-break: break-all",
})

# Lists
UTILITIES.update({
    "list-none": "list-style-type: none", "list-disc": "list-style-type: disc",
    "list-decimal": "list-style-type: decimal",
    "list-inside": "list-style-position: inside", "list-outside": "list-style-position: outside",
})

# Appearance & misc
UTILITIES.update({
    "appearance-none": "appearance: none",
    "outline-none": "outline: 2px solid transparent; outline-offset: 2px",
    "outline": "outline-style: solid",
    "resize-none": "resize: none", "resize": "resize: both",
    "resize-x": "resize: horizontal", "resize-y": "resize: vertical",
})

# Accessibility
UTILITIES["sr-only"] = "position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap; border-width: 0"
UTILITIES["not-sr-only"] = "position: static; width: auto; height: auto; padding: 0; margin: 0; overflow: visible; clip: auto; white-space: normal"

# Background
UTILITIES.update({
    "bg-cover": "background-size: cover", "bg-contain": "background-size: contain",
    "bg-center": "background-position: center", "bg-top": "background-position: top",
    "bg-bottom": "background-position: bottom",
    "bg-no-repeat": "background-repeat: no-repeat", "bg-repeat": "background-repeat: repeat",
})

# Fill/stroke (SVG)
UTILITIES.update({
    "fill-current": "fill: currentColor", "fill-none": "fill: none",
    "stroke-current": "stroke: currentColor",
    "stroke-0": "stroke-width: 0", "stroke-1": "stroke-width: 1", "stroke-2": "stroke-width: 2",
})


# ── Output ───────────────────────────────────────────────────────────────────

def escape_selector(s):
    """Escape CSS selector special chars."""
    out = []
    for ch in s:
        if ch in r"\/.:![]()#%":
            out.append(f"\\{ch}")
        else:
            out.append(ch)
    return "".join(out)


if __name__ == "__main__":
    print(PREFLIGHT)

    for sel, decl in UTILITIES.items():
        # Handle child combinator selectors like "space-x-2 > * + *"
        if " > " in sel:
            base, rest = sel.split(" > ", 1)
            safe = escape_selector(base)
            print(f".{safe} > {rest} {{ {decl}; }}")
        else:
            safe = escape_selector(sel)
            print(f".{safe} {{ {decl}; }}")
