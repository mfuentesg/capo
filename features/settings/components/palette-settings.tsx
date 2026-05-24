"use client"

import { cn } from "@/lib/utils"
import { useLocale } from "@/features/settings"
import { usePalette } from "@/features/settings/contexts/palette-context"
import { useFont } from "@/features/settings/contexts/font-context"
import type { Palette } from "@/lib/actions/palette"
import type { UIFont } from "@/lib/actions/font"

interface PalettePreviewColors {
  bg: string
  primary: string
  accent1: string
  accent2: string
}

const PALETTES: Array<{
  id: Palette
  light: PalettePreviewColors
  dark: PalettePreviewColors
}> = [
  {
    id: "catppuccin",
    light: { bg: "#eff1f5", primary: "#fe640b", accent1: "#1e66f5", accent2: "#8839ef" },
    dark: { bg: "#1e1e2e", primary: "#fab387", accent1: "#89b4fa", accent2: "#cba6f7" }
  },
  {
    id: "aura",
    light: { bg: "#f5f3ff", primary: "#7c3aed", accent1: "#0099b8", accent2: "#5e0dac" },
    dark: { bg: "#15141b", primary: "#a277ff", accent1: "#82e2ff", accent2: "#61ffca" }
  },
  {
    id: "nord",
    light: { bg: "#eceff4", primary: "#5e81ac", accent1: "#81a1c1", accent2: "#a3be8c" },
    dark: { bg: "#2e3440", primary: "#88c0d0", accent1: "#81a1c1", accent2: "#a3be8c" }
  },
  {
    id: "rose-pine",
    light: { bg: "#faf4ed", primary: "#b4637a", accent1: "#56949f", accent2: "#907aa9" },
    dark: { bg: "#191724", primary: "#eb6f92", accent1: "#9ccfd8", accent2: "#c4a7e7" }
  }
]

const PALETTE_LABELS: Record<Palette, { name: string; desc: string }> = {
  catppuccin: { name: "Catppuccin", desc: "Warm pastel tones" },
  aura: { name: "Aura", desc: "Deep purple, vivid" },
  nord: { name: "Nord", desc: "Arctic blue-grey" },
  "rose-pine": { name: "Rosé Pine", desc: "Warm rose & pine" }
}

interface FontEntry {
  id: UIFont
  name: string
  cssVar: string
  desc: string
}

const FONTS: FontEntry[] = [
  { id: "geist", name: "Geist", cssVar: "var(--font-geist-sans)", desc: "Clean & modern" },
  { id: "inter", name: "Inter", cssVar: "var(--font-inter)", desc: "Versatile sans-serif" },
  { id: "dm-sans", name: "DM Sans", cssVar: "var(--font-dm-sans)", desc: "Soft & friendly" }
]

function PaletteCard({
  palette,
  isActive,
  onSelect
}: {
  palette: (typeof PALETTES)[number]
  isActive: boolean
  onSelect: () => void
}) {
  const { name, desc } = PALETTE_LABELS[palette.id]
  const { light, dark } = palette

  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        "relative flex flex-col rounded-xl border overflow-hidden cursor-pointer select-none transition",
        "active:scale-[0.97]",
        isActive
          ? "border-primary/60 shadow-sm ring-1 ring-primary/40"
          : "border-border hover:border-primary/30"
      )}
    >
      {/* Split light/dark preview */}
      <div className="flex h-12">
        <div
          className="flex-1 flex items-center justify-center gap-1.5"
          style={{ background: light.bg }}
        >
          <div
            className="h-3.5 w-3.5 rounded-full shadow-sm"
            style={{ background: light.primary }}
          />
          <div className="h-2 w-2 rounded-full opacity-75" style={{ background: light.accent1 }} />
          <div className="h-2 w-2 rounded-full opacity-60" style={{ background: light.accent2 }} />
        </div>
        <div className="w-px" style={{ background: "rgba(128,128,128,0.2)" }} />
        <div
          className="flex-1 flex items-center justify-center gap-1.5"
          style={{ background: dark.bg }}
        >
          <div
            className="h-3.5 w-3.5 rounded-full shadow-sm"
            style={{ background: dark.primary }}
          />
          <div className="h-2 w-2 rounded-full opacity-75" style={{ background: dark.accent1 }} />
          <div className="h-2 w-2 rounded-full opacity-60" style={{ background: dark.accent2 }} />
        </div>
      </div>
      {/* Label */}
      <div className="px-2.5 py-2 bg-card">
        <p className="text-xs font-semibold leading-none text-foreground">{name}</p>
        <p className="text-[10px] text-muted-foreground mt-0.5">{desc}</p>
      </div>
      {isActive && (
        <span className="absolute bottom-1.5 left-1/2 h-1 w-4 -translate-x-1/2 rounded-full bg-primary" />
      )}
    </button>
  )
}

function FontCard({
  font,
  isActive,
  onSelect
}: {
  font: FontEntry
  isActive: boolean
  onSelect: () => void
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        "relative flex flex-col items-center gap-1.5 rounded-xl border px-3 py-3.5 cursor-pointer select-none transition",
        "active:scale-[0.97]",
        isActive
          ? "border-primary/60 bg-primary/8 shadow-sm ring-1 ring-primary/40"
          : "border-border bg-muted/40 hover:bg-muted hover:border-primary/30"
      )}
    >
      <span
        className="text-2xl font-semibold leading-none text-foreground"
        style={{ fontFamily: font.cssVar }}
      >
        Aa
      </span>
      <span className="text-xs font-medium text-foreground leading-none">{font.name}</span>
      <span className="text-[10px] text-muted-foreground">{font.desc}</span>
      {isActive && (
        <span className="absolute bottom-1.5 left-1/2 h-1 w-4 -translate-x-1/2 rounded-full bg-primary" />
      )}
    </button>
  )
}

export function PaletteSettings() {
  const { t } = useLocale()
  const { palette, setPalette } = usePalette()
  const { font, setFont } = useFont()

  return (
    <>
      <section className="space-y-4">
        <div>
          <h2 className="text-base font-black tracking-tighter">{t.settings.palette}</h2>
          <p className="text-sm text-muted-foreground mt-0.5">{t.settings.paletteDescription}</p>
        </div>
        <div
          className="grid grid-cols-2 gap-2"
          role="radiogroup"
          aria-label={t.settings.palette}
        >
          {PALETTES.map((p) => (
            <PaletteCard
              key={p.id}
              palette={p}
              isActive={palette === p.id}
              onSelect={() => setPalette(p.id)}
            />
          ))}
        </div>
      </section>

      <section className="space-y-4">
        <div>
          <h2 className="text-base font-black tracking-tighter">{t.settings.font}</h2>
          <p className="text-sm text-muted-foreground mt-0.5">{t.settings.fontDescription}</p>
        </div>
        <div
          className="grid grid-cols-3 gap-2"
          role="radiogroup"
          aria-label={t.settings.font}
        >
          {FONTS.map((f) => (
            <FontCard
              key={f.id}
              font={f}
              isActive={font === f.id}
              onSelect={() => setFont(f.id)}
            />
          ))}
        </div>
      </section>
    </>
  )
}
