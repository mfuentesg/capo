"use client"

import {
  createContext,
  useContext,
  useState,
  useTransition,
  useCallback,
  useMemo,
  useEffect,
  useLayoutEffect,
  type ReactNode
} from "react"
import { setPaletteAction } from "@/lib/actions/palette"
import { isValidPalette, DEFAULT_PALETTE, type Palette } from "@/lib/palette"

// The SSR'd data-palette on <html> uses the same DB-first resolution as
// initialPalette (lib/display-preferences.ts), so this mount effect is
// normally a no-op safety net. useLayoutEffect keeps any rare correction from
// painting twice. On the server it is a no-op — same behaviour as useEffect.
const usePaletteLayoutEffect = typeof window === "undefined" ? useEffect : useLayoutEffect

interface PaletteContextType {
  palette: Palette
  isPending: boolean
  setPalette: (palette: Palette) => void
}

const PaletteContext = createContext<PaletteContextType | undefined>(undefined)

export function PaletteProvider({
  children,
  initialPalette = DEFAULT_PALETTE
}: {
  children: ReactNode
  initialPalette?: Palette
}) {
  const [palette, setPaletteState] = useState<Palette>(initialPalette)
  const [isPending, startTransition] = useTransition()

  usePaletteLayoutEffect(() => {
    document.documentElement.dataset.palette = palette
  }, [palette])

  const setPalette = useCallback(
    (newPalette: Palette) => {
      if (!isValidPalette(newPalette)) return
      setPaletteState(newPalette)
      document.documentElement.dataset.palette = newPalette
      startTransition(async () => {
        await setPaletteAction(newPalette)
      })
    },
    [startTransition]
  )

  const value = useMemo(
    () => ({ palette, isPending, setPalette }),
    [palette, isPending, setPalette]
  )

  return <PaletteContext.Provider value={value}>{children}</PaletteContext.Provider>
}

export function usePalette() {
  const context = useContext(PaletteContext)
  if (context === undefined) {
    throw new Error("usePalette must be used within a PaletteProvider")
  }
  return context
}
