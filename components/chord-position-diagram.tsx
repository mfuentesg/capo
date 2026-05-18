"use client"

/**
 * Shared chord-diagram SVG renderer.
 * Used by the chords glossary, chord analyzer, and lyrics editor.
 */

// ── SVG layout ────────────────────────────────────────────────────────────────
const S  = 40   // string spacing
const F  = 36   // fret spacing
const PL = 36   // pad-left  (baseFret label)
const PT = 30   // pad-top   (X / O symbols)
const PR = 16   // pad-right (must be ≥ dot radius to avoid clipping)
const PB = 12   // pad-bottom
const NF = 4    // frets shown
const NS = 6    // strings
const DOT_R = 12 // dot radius

export const DIAGRAM_W = PL + (NS - 1) * S + PR  // 242
export const DIAGRAM_H = PT + NF * F + PB          // 186

// ── Types ─────────────────────────────────────────────────────────────────────
export interface ChordPosition {
  frets: number[]    // -1 muted, 0 open, 1..4 relative fret
  fingers: number[]  // 0 = none, 1..4 = finger
  baseFret: number
  barres: number[]   // relative fret numbers where a barre occurs
  capo?: boolean
  midi?: number[]
}

// ── Finger auto-assignment (used when fingers[] is all zeros) ─────────────────
export function autoAssignFingers(frets: number[], baseFret: number): number[] {
  const pressed = frets
    .map((f, si) => (f > 0 ? { si, absF: baseFret + f - 1 } : null))
    .filter((x): x is { si: number; absF: number } => x !== null)

  const uniqueFrets = [...new Set(pressed.map((p) => p.absF))].sort((a, b) => a - b)
  const map = new Map<number, number>()
  uniqueFrets.slice(0, 4).forEach((absF, idx) => map.set(absF, idx + 1))

  return frets.map((f) => {
    if (f <= 0) return 0
    return map.get(baseFret + f - 1) ?? 0
  })
}

// ── Main diagram component ────────────────────────────────────────────────────
interface ChordPositionDiagramProps {
  position: ChordPosition
  /** Flip vertically so the nut is at the bottom (player's looking-down view) */
  flipVertical?: boolean
  /** Mirror horizontally for left-handed players */
  mirror?: boolean
}

export function ChordPositionDiagram({
  position,
  flipVertical = false,
  mirror = false,
}: ChordPositionDiagramProps) {
  const { frets, baseFret, barres } = position
  const isNut = baseFret === 1

  // Auto-assign fingers when the DB entry has none
  const fingers =
    position.fingers.every((f) => f === 0)
      ? autoAssignFingers(frets, baseFret)
      : position.fingers

  // ── Coordinate helpers (orientation-aware) ─────────────────────────────────
  /** x of string si — direction depends on mirror */
  const sx = (si: number) => (mirror ? PL + si * S : PL + (NS - 1 - si) * S)
  /** y of fret divider fi (0 = nut side) — direction depends on flipVertical */
  const fy = (fi: number) => (flipVertical ? DIAGRAM_H - PT - fi * F : PT + fi * F)
  /** y midpoint of relative fret fi (1-indexed) — where the dot sits */
  const dotY = (fi: number) =>
    flipVertical ? DIAGRAM_H - PT - (fi - 0.5) * F : PT + (fi - 0.5) * F

  // Y coordinate for X / O symbols (opposite side from nut)
  const xoY = flipVertical ? DIAGRAM_H - PT + 15 : PT - 15

  // Nut / position-marker rect Y and height
  // Normal: rect extends upward from fy(0)
  // Flipped: rect extends downward from fy(0)
  const nutBarY = flipVertical ? DIAGRAM_H - PT : PT - (isNut ? 5 : 1.5)

  // ── Barre metadata ─────────────────────────────────────────────────────────
  const barreData = barres
    .map((barreFret) => {
      const barredSi = frets
        .map((f, si) => (f === barreFret ? si : -1))
        .filter((si) => si >= 0)
      if (barredSi.length < 2) return null

      // Find the barre finger: the finger covering the most strings at this fret.
      // Strings with a lower-numbered finger are individually pressed, not barred
      // (e.g. B9: A-string uses finger 2 while G/B/E are barred with finger 3).
      const fingerGroups = new Map<number, number[]>()
      barredSi.forEach((si) => {
        const f = fingers[si]
        if (f > 0) {
          if (!fingerGroups.has(f)) fingerGroups.set(f, [])
          fingerGroups.get(f)!.push(si)
        }
      })

      let barreFingerNum = 1
      let maxCount = 0
      fingerGroups.forEach((sis, f) => {
        if (sis.length > maxCount) { maxCount = sis.length; barreFingerNum = f }
      })

      // Strings with finger >= barreFingerNum (or unassigned) belong to the barre.
      // Strings with a lower finger show as individual dots instead.
      const barreSis = barredSi.filter((si) => fingers[si] === 0 || fingers[si] >= barreFingerNum)
      const effectiveSis = barreSis.length >= 2 ? barreSis : barredSi

      const minSi = Math.min(...effectiveSis)
      const maxSi = Math.max(...effectiveSis)
      return { barreFret, minSi, maxSi, fingerNum: barreFingerNum, barreSis: effectiveSis }
    })
    .filter((b): b is NonNullable<typeof b> => b !== null)

  // Strings whose dot is already covered by a barre bar
  const barreCovered = new Set<string>()
  barreData.forEach((b) => {
    b.barreSis.forEach((si) => barreCovered.add(`${si}-${b.barreFret}`))
  })

  return (
    <svg viewBox={`0 0 ${DIAGRAM_W} ${DIAGRAM_H}`} className="w-full h-auto">
      {/* Nut / position marker */}
      <rect
        x={PL} y={nutBarY}
        width={(NS - 1) * S} height={isNut ? 5 : 2}
        rx="1" fill="currentColor" opacity={isNut ? 0.75 : 0.25}
      />

      {/* Fret lines */}
      {Array.from({ length: NF }, (_, fi) => (
        <line
          key={fi}
          x1={PL} y1={fy(fi + 1)} x2={PL + (NS - 1) * S} y2={fy(fi + 1)}
          stroke="currentColor" strokeWidth="0.75" opacity="0.15"
        />
      ))}

      {/* String lines */}
      {Array.from({ length: NS }, (_, si) => (
        <line
          key={si}
          x1={sx(si)} y1={fy(0)} x2={sx(si)} y2={fy(NF)}
          stroke="currentColor" strokeWidth="0.75" opacity="0.25"
        />
      ))}

      {/* Barre bars — use min/max to handle both mirror orientations */}
      {barreData.map((b) => {
        const barreLeft = Math.min(sx(b.minSi), sx(b.maxSi))
        const barreRight = Math.max(sx(b.minSi), sx(b.maxSi))
        return (
          <rect
            key={b.barreFret}
            x={barreLeft - 9} y={dotY(b.barreFret) - 10}
            width={barreRight - barreLeft + 18} height={20}
            rx={10}
            fill="currentColor" opacity="0.85"
          />
        )
      })}

      {/* BaseFret label — rendered after barres so it's always on top */}
      {!isNut && (
        <text
          x={PL - 20} y={dotY(1) + 5}
          textAnchor="middle" fontSize="14" fontWeight="700"
          fill="currentColor"
          strokeWidth="3" paintOrder="stroke"
          className="stroke-white dark:stroke-zinc-950"
        >
          {baseFret}
        </text>
      )}

      {/* Individual dots (skip barre-covered positions) */}
      {frets.map((fret, si) => {
        if (fret <= 0) return null
        if (barreCovered.has(`${si}-${fret}`)) return null
        const fingerNum = fingers[si]
        return (
          <g key={si}>
            <circle cx={sx(si)} cy={dotY(fret)} r={DOT_R} fill="currentColor" opacity="0.85" />
            {fingerNum > 0 && (
              <text
                x={sx(si)} y={dotY(fret) + 4}
                textAnchor="middle" fontSize="11" fontWeight="bold"
                className="fill-white dark:fill-zinc-950"
              >
                {fingerNum}
              </text>
            )}
          </g>
        )
      })}

      {/* X / O above/below the nut */}
      {frets.map((fret, si) => {
        const x = sx(si)
        const y = xoY
        if (fret === -1) {
          return (
            <g key={si}>
              <line x1={x - 6} y1={y - 6} x2={x + 6} y2={y + 6}
                stroke="currentColor" strokeWidth="1.5" opacity="0.65" strokeLinecap="round" />
              <line x1={x + 6} y1={y - 6} x2={x - 6} y2={y + 6}
                stroke="currentColor" strokeWidth="1.5" opacity="0.65" strokeLinecap="round" />
            </g>
          )
        }
        if (fret === 0) {
          return (
            <circle key={si} cx={x} cy={y} r={7}
              fill="none" stroke="currentColor" strokeWidth="1.5" opacity="0.6" />
          )
        }
        return null
      })}
    </svg>
  )
}

// ── Finger legend ─────────────────────────────────────────────────────────────
export function FingerLegend() {
  return (
    <div className="flex items-center justify-center gap-4">
      {([1, 2, 3, 4] as const).map((f) => (
        <div key={f} className="flex flex-col items-center gap-1">
          <div
            className="h-6 w-6 rounded-full flex items-center justify-center text-[11px] font-bold bg-foreground text-background shadow-sm"
          >
            {f}
          </div>
        </div>
      ))}
    </div>
  )
}
