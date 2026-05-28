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
  type BarreDatum = { barreFret: number; minSi: number; maxSi: number; fingerNum: number }

  // Explicit barres: split into contiguous segments so a gap (string at a
  // different fret inside the range) doesn't get a bar drawn over it.
  const explicitBarreData: BarreDatum[] = barres.flatMap((barreFret) => {
    const barredSi = frets
      .map((f, si) => (f === barreFret ? si : -1))
      .filter((si) => si >= 0)
    if (barredSi.length < 2) return []

    const fingerNum =
      Math.min(...barredSi.map((si) => fingers[si]).filter((f) => f > 0)) || 1

    const segments: BarreDatum[] = []
    let segStart = barredSi[0]
    for (let i = 1; i <= barredSi.length; i++) {
      if (i === barredSi.length || barredSi[i] !== barredSi[i - 1] + 1) {
        if (barredSi[i - 1] - segStart >= 1) {
          segments.push({ barreFret, minSi: segStart, maxSi: barredSi[i - 1], fingerNum })
        }
        if (i < barredSi.length) segStart = barredSi[i]
      }
    }
    return segments
  })

  // Inferred barres: same finger on 2+ strings at the same fret → bar from
  // outermost to outermost (standard notation; other fingers press on top).
  const inferredBarreData: BarreDatum[] = []
  const fingerFretGroups = new Map<string, number[]>()
  frets.forEach((fret, si) => {
    if (fret <= 0) return
    const fn = fingers[si]
    if (fn <= 0) return
    const key = `${fn}-${fret}`
    const group = fingerFretGroups.get(key)
    if (group) group.push(si)
    else fingerFretGroups.set(key, [si])
  })
  fingerFretGroups.forEach((siList, key) => {
    if (siList.length < 2) return
    const [fnStr, fretStr] = key.split("-")
    const barreFret = parseInt(fretStr)
    const fingerNum = parseInt(fnStr)
    const minSi = Math.min(...siList)
    const maxSi = Math.max(...siList)
    // Skip if already covered by an explicit barre segment
    if (explicitBarreData.some((b) => b.barreFret === barreFret && b.minSi <= minSi && b.maxSi >= maxSi))
      return
    inferredBarreData.push({ barreFret, minSi, maxSi, fingerNum })
  })

  const seen = new Set<string>()
  const barreData = [...explicitBarreData, ...inferredBarreData].filter((b) => {
    const k = `${b.barreFret}-${b.minSi}-${b.maxSi}`
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })

  // Strings whose dot is already covered by a barre bar segment
  const barreCovered = new Set<string>()
  barreData.forEach((b) => {
    for (let si = b.minSi; si <= b.maxSi; si++) {
      barreCovered.add(`${si}-${b.barreFret}`)
    }
  })

  // Strings physically blocked by a barre: fret < barreFret on a string within
  // the barre's full span (min..max of all barred strings). A barre finger lies
  // flat across the neck — it covers every string in that range, making any
  // lower-fret note on those strings impossible to sound.
  const barreBlocked = new Set<number>()
  barres.forEach((barreFret) => {
    const barredSi = frets
      .map((f, si) => (f === barreFret ? si : -1))
      .filter((si) => si >= 0)
    if (barredSi.length < 2) return
    const overallMin = Math.min(...barredSi)
    const overallMax = Math.max(...barredSi)
    for (let si = overallMin; si <= overallMax; si++) {
      if (frets[si] > 0 && frets[si] < barreFret) barreBlocked.add(si)
    }
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
        const barreCx = (barreLeft + barreRight) / 2
        return (
          <g key={`${b.barreFret}-${b.minSi}-${b.maxSi}`}>
            <rect
              x={barreLeft - 9} y={dotY(b.barreFret) - 10}
              width={barreRight - barreLeft + 18} height={20}
              rx={10}
              fill="currentColor" opacity="0.85"
            />
            {b.fingerNum > 0 && (
              <text
                x={barreCx} y={dotY(b.barreFret) + 4}
                textAnchor="middle" fontSize="11" fontWeight="bold"
                className="fill-white dark:fill-zinc-950"
              >
                {b.fingerNum}
              </text>
            )}
          </g>
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

      {/* Individual dots (skip barre-covered and barre-blocked positions) */}
      {frets.map((fret, si) => {
        if (fret <= 0) return null
        if (barreCovered.has(`${si}-${fret}`)) return null
        if (barreBlocked.has(si)) return null
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
