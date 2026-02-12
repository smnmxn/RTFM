import { Controller } from "@hotwired/stimulus"

// Temporary dev tool — remove when palette is finalized
const FONTS = [
  { name: "Inter",                 family: "'Inter'",                  gf: "Inter:wght@400;500;600;700;800" },
  { name: "Space Grotesk",        family: "'Space Grotesk'",          gf: "Space+Grotesk:wght@400;500;600;700" },
  { name: "Outfit",               family: "'Outfit'",                 gf: "Outfit:wght@400;500;600;700;800" },
  { name: "Sora",                 family: "'Sora'",                   gf: "Sora:wght@400;500;600;700;800" },
  { name: "Manrope",              family: "'Manrope'",                gf: "Manrope:wght@400;500;600;700;800" },
  { name: "Plus Jakarta Sans",    family: "'Plus Jakarta Sans'",      gf: "Plus+Jakarta+Sans:wght@400;500;600;700;800" },
  { name: "DM Sans",              family: "'DM Sans'",                gf: "DM+Sans:wght@400;500;600;700" },
  { name: "Poppins",              family: "'Poppins'",                gf: "Poppins:wght@400;500;600;700;800" },
  { name: "Bricolage Grotesque",  family: "'Bricolage Grotesque'",    gf: "Bricolage+Grotesque:wght@400;500;600;700;800" },
  { name: "Unbounded",            family: "'Unbounded'",              gf: "Unbounded:wght@400;500;600;700;800" },
  { name: "Instrument Serif",     family: "'Instrument Serif'",       gf: "Instrument+Serif" },
  { name: "Playfair Display",     family: "'Playfair Display'",       gf: "Playfair+Display:wght@400;500;600;700;800" },
  { name: "Fraunces",             family: "'Fraunces'",               gf: "Fraunces:wght@400;500;600;700;800" },
  { name: "Work Sans",            family: "'Work Sans'",              gf: "Work+Sans:wght@400;500;600;700;800" },
  { name: "Rubik",                family: "'Rubik'",                  gf: "Rubik:wght@400;500;600;700;800" },
]

const PRESETS = [
  // --- Dark themes ---
  {
    name: "Violet Dream",
    bg: "#020617", orb1: "#7c3aed", orb2: "#a855f7", orb3: "#6366f1",
    heroFrom: "#8b5cf6", heroVia: "#a855f7", heroTo: "#c084fc",
    text: "#94a3b8", accent: "#8b5cf6", surface: "#334155",
    ctaBg: "#ffffff", ctaText: "#0f172a", opacity: 20
  },
  {
    name: "Ocean Abyss",
    bg: "#0a0f1e", orb1: "#0891b2", orb2: "#0ea5e9", orb3: "#2563eb",
    heroFrom: "#22d3ee", heroVia: "#38bdf8", heroTo: "#818cf8",
    text: "#7dd3e8", accent: "#22d3ee", surface: "#1e3a4f",
    ctaBg: "#ffffff", ctaText: "#0a0f1e", opacity: 18
  },
  {
    name: "Emerald Night",
    bg: "#021a0f", orb1: "#059669", orb2: "#10b981", orb3: "#14b8a6",
    heroFrom: "#34d399", heroVia: "#2dd4bf", heroTo: "#5eead4",
    text: "#6ee7b7", accent: "#34d399", surface: "#1a3a2a",
    ctaBg: "#ffffff", ctaText: "#021a0f", opacity: 15
  },
  {
    name: "Solar Flare",
    bg: "#120b00", orb1: "#ea580c", orb2: "#f59e0b", orb3: "#dc2626",
    heroFrom: "#fb923c", heroVia: "#fbbf24", heroTo: "#fde68a",
    text: "#d4a574", accent: "#f59e0b", surface: "#3d2a10",
    ctaBg: "#ffffff", ctaText: "#120b00", opacity: 16
  },
  {
    name: "Rose Quartz",
    bg: "#0f0715", orb1: "#e11d48", orb2: "#ec4899", orb3: "#a855f7",
    heroFrom: "#fb7185", heroVia: "#f472b6", heroTo: "#e879f9",
    text: "#d4a0b9", accent: "#ec4899", surface: "#3d1f35",
    ctaBg: "#ffffff", ctaText: "#0f0715", opacity: 18
  },
  {
    name: "Arctic Ice",
    bg: "#030712", orb1: "#1d4ed8", orb2: "#7c3aed", orb3: "#0284c7",
    heroFrom: "#60a5fa", heroVia: "#a78bfa", heroTo: "#c4b5fd",
    text: "#93a8d0", accent: "#60a5fa", surface: "#1e2d4a",
    ctaBg: "#ffffff", ctaText: "#030712", opacity: 22
  },
  {
    name: "Cyber Lime",
    bg: "#050a05", orb1: "#65a30d", orb2: "#22d3ee", orb3: "#16a34a",
    heroFrom: "#a3e635", heroVia: "#4ade80", heroTo: "#34d399",
    text: "#86c98a", accent: "#4ade80", surface: "#1a2e1a",
    ctaBg: "#ffffff", ctaText: "#050a05", opacity: 14
  },
  {
    name: "Warm Ember",
    bg: "#110805", orb1: "#b45309", orb2: "#dc2626", orb3: "#9a3412",
    heroFrom: "#f97316", heroVia: "#ef4444", heroTo: "#fca5a5",
    text: "#c4937a", accent: "#f97316", surface: "#3d2010",
    ctaBg: "#ffffff", ctaText: "#110805", opacity: 17
  },
  {
    name: "Lavender Haze",
    bg: "#0c0a1a", orb1: "#7c3aed", orb2: "#ec4899", orb3: "#3b82f6",
    heroFrom: "#c084fc", heroVia: "#f0abfc", heroTo: "#93c5fd",
    text: "#b4a0d4", accent: "#c084fc", surface: "#2d1f4a",
    ctaBg: "#ffffff", ctaText: "#0c0a1a", opacity: 20
  },
  {
    name: "Monochrome",
    bg: "#09090b", orb1: "#71717a", orb2: "#a1a1aa", orb3: "#52525b",
    heroFrom: "#e4e4e7", heroVia: "#a1a1aa", heroTo: "#f4f4f5",
    text: "#a1a1aa", accent: "#a1a1aa", surface: "#27272a",
    ctaBg: "#ffffff", ctaText: "#09090b", opacity: 12
  },

  // --- Light themes ---
  {
    name: "Clean Slate",
    bg: "#f8fafc", orb1: "#8b5cf6", orb2: "#a78bfa", orb3: "#6366f1",
    heroFrom: "#6d28d9", heroVia: "#7c3aed", heroTo: "#8b5cf6",
    text: "#64748b", accent: "#7c3aed", surface: "#e2e8f0",
    ctaBg: "#1e293b", ctaText: "#ffffff", opacity: 12
  },
  {
    name: "Warm Paper",
    bg: "#fefcf3", orb1: "#f59e0b", orb2: "#fb923c", orb3: "#f97316",
    heroFrom: "#b45309", heroVia: "#d97706", heroTo: "#f59e0b",
    text: "#78716c", accent: "#d97706", surface: "#e7e5e4",
    ctaBg: "#292524", ctaText: "#ffffff", opacity: 10
  },
  {
    name: "Mint Fresh",
    bg: "#f0fdfa", orb1: "#0d9488", orb2: "#14b8a6", orb3: "#2dd4bf",
    heroFrom: "#0f766e", heroVia: "#0d9488", heroTo: "#14b8a6",
    text: "#64748b", accent: "#0d9488", surface: "#ccfbf1",
    ctaBg: "#134e4a", ctaText: "#ffffff", opacity: 12
  },
  {
    name: "Rose Petal",
    bg: "#fff1f2", orb1: "#e11d48", orb2: "#f43f5e", orb3: "#fb7185",
    heroFrom: "#be123c", heroVia: "#e11d48", heroTo: "#f43f5e",
    text: "#71717a", accent: "#e11d48", surface: "#ffe4e6",
    ctaBg: "#1c1917", ctaText: "#ffffff", opacity: 10
  },
  {
    name: "Sky Day",
    bg: "#f0f9ff", orb1: "#0284c7", orb2: "#38bdf8", orb3: "#0ea5e9",
    heroFrom: "#0369a1", heroVia: "#0284c7", heroTo: "#0ea5e9",
    text: "#64748b", accent: "#0284c7", surface: "#e0f2fe",
    ctaBg: "#0c4a6e", ctaText: "#ffffff", opacity: 12
  },
  {
    name: "Lavender Field",
    bg: "#faf5ff", orb1: "#9333ea", orb2: "#c084fc", orb3: "#a855f7",
    heroFrom: "#7e22ce", heroVia: "#9333ea", heroTo: "#a855f7",
    text: "#6b7280", accent: "#9333ea", surface: "#f3e8ff",
    ctaBg: "#581c87", ctaText: "#ffffff", opacity: 10
  },
  {
    name: "Sand Dune",
    bg: "#faf9f6", orb1: "#a16207", orb2: "#ca8a04", orb3: "#d4a017",
    heroFrom: "#854d0e", heroVia: "#a16207", heroTo: "#ca8a04",
    text: "#6b7280", accent: "#a16207", surface: "#e8e4db",
    ctaBg: "#422006", ctaText: "#ffffff", opacity: 8
  },
  {
    name: "Forest Canopy",
    bg: "#f0fdf4", orb1: "#16a34a", orb2: "#22c55e", orb3: "#4ade80",
    heroFrom: "#15803d", heroVia: "#16a34a", heroTo: "#22c55e",
    text: "#6b7280", accent: "#16a34a", surface: "#dcfce7",
    ctaBg: "#14532d", ctaText: "#ffffff", opacity: 10
  },
  {
    name: "Peach Glow",
    bg: "#fff7ed", orb1: "#ea580c", orb2: "#f97316", orb3: "#fb923c",
    heroFrom: "#c2410c", heroVia: "#ea580c", heroTo: "#f97316",
    text: "#78716c", accent: "#ea580c", surface: "#fed7aa",
    ctaBg: "#431407", ctaText: "#ffffff", opacity: 10
  },
  {
    name: "Snow White",
    bg: "#ffffff", orb1: "#d4d4d8", orb2: "#a1a1aa", orb3: "#e4e4e7",
    heroFrom: "#18181b", heroVia: "#3f3f46", heroTo: "#52525b",
    text: "#71717a", accent: "#3f3f46", surface: "#f4f4f5",
    ctaBg: "#18181b", ctaText: "#ffffff", opacity: 6
  },
]

export default class extends Controller {
  static targets = [
    "page", "orb1", "orb2", "orb3", "headline", "bodyText", "panel",
    "accentText", "accentGlow",
    "surfaceInput", "surfaceBtn", "footerEl",
    "ctaBtn", "logoImg"
  ]

  connect() {
    this.collapsed = false
    this.presetIndex = 0
    this.colors = [
      { label: "Background",     target: "page", value: "#020617" },
      { label: "Orb 1",          target: "orb1", value: "#7c3aed" },
      { label: "Orb 2",          target: "orb2", value: "#a855f7" },
      { label: "Orb 3",          target: "orb3", value: "#6366f1" },
      { label: "Headline from",  key: "heroFrom", value: "#8b5cf6" },
      { label: "Headline via",   key: "heroVia",  value: "#a855f7" },
      { label: "Headline to",    key: "heroTo",   value: "#c084fc" },
      { label: "Body text",      key: "text",     value: "#94a3b8" },
      { label: "Accent",         key: "accent",   value: "#8b5cf6" },
      { label: "Surface",        key: "surface",  value: "#334155" },
      { label: "CTA button",     key: "ctaBg",    value: "#ffffff" },
      { label: "CTA text",       key: "ctaText",  value: "#0f172a" },
    ]
    this.orbOpacity = 20
    this.headlineFont = 0 // index into FONTS
    this.bodyFont = 0
    this.loadedFonts = new Set(["Inter"])
    this.buildPanel()
  }

  // --- Helpers ---

  loadFont(index) {
    const font = FONTS[index]
    if (this.loadedFonts.has(font.name)) return
    this.loadedFonts.add(font.name)
    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = `https://fonts.googleapis.com/css2?family=${font.gf}&display=swap`
    document.head.appendChild(link)
  }

  hexToRgbStr(hex) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return `${r} ${g} ${b}`
  }

  hexToRgba(hex, alpha) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }

  lighten(hex, amount) {
    let r = parseInt(hex.slice(1, 3), 16)
    let g = parseInt(hex.slice(3, 5), 16)
    let b = parseInt(hex.slice(5, 7), 16)
    r = Math.min(255, r + amount)
    g = Math.min(255, g + amount)
    b = Math.min(255, b + amount)
    return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`
  }

  isLight(hex) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return (r * 299 + g * 587 + b * 114) / 1000 > 128
  }

  // --- Panel UI ---

  buildPanel() {
    const panel = document.createElement("div")
    panel.dataset.colorPickerTarget = "panel"
    panel.className = "fixed bottom-4 right-4 z-50 bg-slate-900 border border-slate-700 rounded-xl shadow-2xl text-xs text-slate-300 w-72 overflow-hidden"
    panel.style.fontFamily = "system-ui, sans-serif"

    const header = document.createElement("div")
    header.className = "px-3 py-2 bg-slate-800 flex items-center justify-between cursor-pointer select-none"
    header.innerHTML = `<span class="font-semibold text-slate-200">Palette</span><span class="text-slate-500" data-toggle>&#9660;</span>`
    header.addEventListener("click", () => this.toggle())
    panel.appendChild(header)

    const body = document.createElement("div")
    body.className = "px-3 py-3 flex flex-col gap-2"
    this.panelBody = body

    // Preset selector
    const presetRow = document.createElement("div")
    presetRow.className = "flex items-center justify-between gap-2 pb-2 mb-1 border-b border-slate-800"

    const prevBtn = document.createElement("button")
    prevBtn.className = "px-2 py-1 bg-slate-800 hover:bg-slate-700 rounded text-slate-400 transition-colors"
    prevBtn.innerHTML = "&#9664;"
    prevBtn.addEventListener("click", (e) => { e.stopPropagation(); this.prevPreset() })

    this.presetLabel = document.createElement("span")
    this.presetLabel.className = "font-medium text-slate-200 text-center flex-1"
    this.presetLabel.textContent = `${PRESETS[0].name} (1/${PRESETS.length})`

    const nextBtn = document.createElement("button")
    nextBtn.className = "px-2 py-1 bg-slate-800 hover:bg-slate-700 rounded text-slate-400 transition-colors"
    nextBtn.innerHTML = "&#9654;"
    nextBtn.addEventListener("click", (e) => { e.stopPropagation(); this.nextPreset() })

    presetRow.appendChild(prevBtn)
    presetRow.appendChild(this.presetLabel)
    presetRow.appendChild(nextBtn)
    body.appendChild(presetRow)

    // Color rows
    this.colorInputs = []
    this.hexLabels = []

    this.colors.forEach((c, i) => {
      const row = document.createElement("div")
      row.className = "flex items-center justify-between gap-2"

      const label = document.createElement("span")
      label.className = "text-slate-400 flex-shrink-0"
      label.textContent = c.label

      const inputWrap = document.createElement("div")
      inputWrap.className = "flex items-center gap-1.5"

      const input = document.createElement("input")
      input.type = "color"
      input.value = c.value
      input.className = "w-7 h-7 rounded border border-slate-600 cursor-pointer bg-transparent p-0"
      input.style.appearance = "none"
      input.style.WebkitAppearance = "none"

      const hex = document.createElement("span")
      hex.className = "text-slate-500 font-mono w-14 text-right"
      hex.textContent = input.value

      input.addEventListener("input", (e) => {
        hex.textContent = e.target.value
        this.colors[i].value = e.target.value
        this.applyColor(i, e.target.value)
      })

      this.colorInputs.push(input)
      this.hexLabels.push(hex)

      inputWrap.appendChild(input)
      inputWrap.appendChild(hex)
      row.appendChild(label)
      row.appendChild(inputWrap)
      body.appendChild(row)
    })

    // Orb opacity slider
    const opacityRow = document.createElement("div")
    opacityRow.className = "flex items-center justify-between gap-2 pt-1 border-t border-slate-800 mt-1"
    opacityRow.innerHTML = `<span class="text-slate-400">Orb opacity</span>`
    this.opacitySlider = document.createElement("input")
    this.opacitySlider.type = "range"
    this.opacitySlider.min = "0"
    this.opacitySlider.max = "100"
    this.opacitySlider.value = "20"
    this.opacitySlider.className = "w-24 accent-violet-500"
    this.opacitySlider.addEventListener("input", (e) => {
      this.orbOpacity = parseInt(e.target.value)
      this.reapplyOrbs()
    })
    opacityRow.appendChild(this.opacitySlider)
    body.appendChild(opacityRow)

    // Font selectors
    const fontSection = document.createElement("div")
    fontSection.className = "flex flex-col gap-2 pt-2 mt-1 border-t border-slate-800"

    const selectClass = "w-full bg-slate-800 border border-slate-700 text-slate-300 rounded px-2 py-1.5 text-xs cursor-pointer"

    // Headline font
    const headRow = document.createElement("div")
    headRow.className = "flex items-center justify-between gap-2"
    const headLabel = document.createElement("span")
    headLabel.className = "text-slate-400 flex-shrink-0"
    headLabel.textContent = "Headline"
    this.headlineFontSelect = document.createElement("select")
    this.headlineFontSelect.className = selectClass
    FONTS.forEach((f, i) => {
      const opt = document.createElement("option")
      opt.value = i
      opt.textContent = f.name
      this.headlineFontSelect.appendChild(opt)
    })
    this.headlineFontSelect.addEventListener("change", (e) => {
      this.headlineFont = parseInt(e.target.value)
      this.loadFont(this.headlineFont)
      this.reapplyFonts()
    })
    headRow.appendChild(headLabel)
    headRow.appendChild(this.headlineFontSelect)
    fontSection.appendChild(headRow)

    // Body font
    const bodyRow = document.createElement("div")
    bodyRow.className = "flex items-center justify-between gap-2"
    const bodyLabel = document.createElement("span")
    bodyLabel.className = "text-slate-400 flex-shrink-0"
    bodyLabel.textContent = "Body"
    this.bodyFontSelect = document.createElement("select")
    this.bodyFontSelect.className = selectClass
    FONTS.forEach((f, i) => {
      const opt = document.createElement("option")
      opt.value = i
      opt.textContent = f.name
      this.bodyFontSelect.appendChild(opt)
    })
    this.bodyFontSelect.addEventListener("change", (e) => {
      this.bodyFont = parseInt(e.target.value)
      this.loadFont(this.bodyFont)
      this.reapplyFonts()
    })
    bodyRow.appendChild(bodyLabel)
    bodyRow.appendChild(this.bodyFontSelect)
    fontSection.appendChild(bodyRow)

    body.appendChild(fontSection)

    // Copy button
    const copyBtn = document.createElement("button")
    copyBtn.className = "mt-1 w-full py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-md transition-colors text-xs font-medium"
    copyBtn.textContent = "Copy values"
    copyBtn.addEventListener("click", () => this.copyValues())
    body.appendChild(copyBtn)

    panel.appendChild(body)
    document.body.appendChild(panel)
  }

  // --- Presets ---

  nextPreset() {
    this.presetIndex = (this.presetIndex + 1) % PRESETS.length
    this.applyPreset(PRESETS[this.presetIndex])
  }

  prevPreset() {
    this.presetIndex = (this.presetIndex - 1 + PRESETS.length) % PRESETS.length
    this.applyPreset(PRESETS[this.presetIndex])
  }

  applyPreset(preset) {
    this.presetLabel.textContent = `${preset.name} (${this.presetIndex + 1}/${PRESETS.length})`

    const vals = [
      preset.bg, preset.orb1, preset.orb2, preset.orb3,
      preset.heroFrom, preset.heroVia, preset.heroTo,
      preset.text, preset.accent, preset.surface,
      preset.ctaBg, preset.ctaText
    ]
    vals.forEach((v, i) => {
      this.colors[i].value = v
      this.colorInputs[i].value = v
      this.hexLabels[i].textContent = v
    })

    this.orbOpacity = preset.opacity
    this.opacitySlider.value = preset.opacity

    this.applyAll()
  }

  // --- Apply logic ---

  applyAll() {
    this.pageTarget.style.backgroundColor = this.colors[0].value
    this.reapplyOrbs()
    this.reapplyGradient()
    this.reapplyText()
    this.reapplyAccent()
    this.reapplySurface()
    this.reapplyCta()
    this.reapplyLogo()
    this.reapplyFonts()
  }

  applyColor(index, hex) {
    const c = this.colors[index]
    if (c.target === "page") {
      this.pageTarget.style.backgroundColor = hex
      this.reapplyLogo()
    } else if (c.target && c.target.startsWith("orb")) {
      this.reapplyOrbs()
    } else if (c.key?.startsWith("hero")) {
      this.reapplyGradient()
    } else if (c.key === "text") {
      this.reapplyText()
    } else if (c.key === "accent") {
      this.reapplyAccent()
    } else if (c.key === "surface") {
      this.reapplySurface()
    } else if (c.key === "ctaBg" || c.key === "ctaText") {
      this.reapplyCta()
    }
  }

  reapplyOrbs() {
    const alpha = Math.round(this.orbOpacity * 2.55).toString(16).padStart(2, "0")
    if (this.hasOrb1Target) this.orb1Target.style.backgroundColor = this.colors[1].value + alpha
    if (this.hasOrb2Target) this.orb2Target.style.backgroundColor = this.colors[2].value + alpha
    if (this.hasOrb3Target) this.orb3Target.style.backgroundColor = this.colors[3].value + alpha
  }

  reapplyGradient() {
    const from = this.colors[4].value
    const via = this.colors[5].value
    const to = this.colors[6].value
    if (this.hasHeadlineTarget) {
      this.headlineTarget.style.background = `linear-gradient(135deg, ${from} 0%, ${via} 50%, ${to} 100%)`
      this.headlineTarget.style.WebkitBackgroundClip = "text"
      this.headlineTarget.style.WebkitTextFillColor = "transparent"
      this.headlineTarget.style.backgroundClip = "text"
    }
  }

  reapplyText() {
    const color = this.colors[7].value
    this.bodyTextTargets.forEach((el) => { el.style.color = color })
  }

  reapplyAccent() {
    const accent = this.colors[8].value
    const rgb = this.hexToRgbStr(accent)

    // CSS variable for glow-pulse keyframe
    this.pageTarget.style.setProperty("--lp-accent-rgb", rgb)

    // Accent-colored text (header sign-in link, invite text)
    this.accentTextTargets.forEach((el) => { el.style.color = accent })

    // Video container shadow
    if (this.hasAccentGlowTarget) {
      this.accentGlowTarget.style.boxShadow = `0 25px 50px -12px ${this.hexToRgba(accent, 0.15)}`
    }
  }

  reapplySurface() {
    const surface = this.colors[9].value
    const lighter = this.lighten(surface, 30)

    this.surfaceInputTargets.forEach((el) => {
      el.style.backgroundColor = this.hexToRgba(surface, 0.5)
      el.style.borderColor = surface
    })

    this.surfaceBtnTargets.forEach((el) => {
      el.style.backgroundColor = surface
      el.style.borderColor = surface
    })

    if (this.hasFooterElTarget) {
      this.footerElTarget.style.borderColor = this.hexToRgba(surface, 0.5)
      this.footerElTarget.style.color = lighter
    }
  }

  reapplyCta() {
    const bg = this.colors[10].value
    const text = this.colors[11].value

    this.ctaBtnTargets.forEach((el) => {
      el.style.backgroundColor = bg
      el.style.color = text
    })
  }

  reapplyFonts() {
    const headFont = FONTS[this.headlineFont]
    const bodyFont = FONTS[this.bodyFont]

    // Body font applies to the whole page wrapper (cascades to everything)
    this.pageTarget.style.fontFamily = `${bodyFont.family}, system-ui, sans-serif`

    // Headline font overrides just the h1
    if (this.hasHeadlineTarget) {
      this.headlineTarget.style.fontFamily = `${headFont.family}, system-ui, sans-serif`
    }

    // Also apply to CTA button
    this.ctaBtnTargets.forEach((el) => {
      el.style.fontFamily = `${bodyFont.family}, system-ui, sans-serif`
    })
  }

  reapplyLogo() {
    const bgLight = this.isLight(this.colors[0].value)
    this.logoImgTargets.forEach((el) => {
      // On light bg: show original logo (remove invert). On dark bg: invert to white.
      el.style.filter = bgLight ? "none" : "brightness(0) invert(1)"
    })
  }

  // --- Toggle & copy ---

  toggle() {
    this.collapsed = !this.collapsed
    this.panelBody.style.display = this.collapsed ? "none" : "flex"
    const arrow = this.element.querySelector("[data-toggle]")
    if (arrow) arrow.innerHTML = this.collapsed ? "&#9650;" : "&#9660;"
  }

  copyValues() {
    const preset = PRESETS[this.presetIndex]
    const lines = [
      `/* Palette: ${preset?.name || "Custom"} */`,
      `Background: ${this.colors[0].value}`,
      `Orb 1: ${this.colors[1].value} (opacity: ${this.orbOpacity}%)`,
      `Orb 2: ${this.colors[2].value} (opacity: ${this.orbOpacity}%)`,
      `Orb 3: ${this.colors[3].value} (opacity: ${this.orbOpacity}%)`,
      `Hero gradient: ${this.colors[4].value} → ${this.colors[5].value} → ${this.colors[6].value}`,
      `Body text: ${this.colors[7].value}`,
      `Accent: ${this.colors[8].value}`,
      `Surface: ${this.colors[9].value}`,
      `CTA bg: ${this.colors[10].value}`,
      `CTA text: ${this.colors[11].value}`,
      `Headline font: ${FONTS[this.headlineFont].name}`,
      `Body font: ${FONTS[this.bodyFont].name}`,
    ]
    navigator.clipboard.writeText(lines.join("\n"))

    const btn = this.panelBody.querySelector("button")
    const orig = btn.textContent
    btn.textContent = "Copied!"
    setTimeout(() => btn.textContent = orig, 1500)
  }

  disconnect() {
    const panel = document.querySelector("[data-color-picker-target='panel']")
    if (panel) panel.remove()
  }
}
