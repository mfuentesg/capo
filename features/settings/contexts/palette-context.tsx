"use client"

import {
  createContext,
  useContext,
  useState,
  useTransition,
  useCallback,
  useMemo,
  useEffect,
  type ReactNode
} from "react"
import {
  setPaletteAction,
  isValidPalette,
  DEFAULT_PALETTE,
  type Palette
} from "@/lib/actions/palette"

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

  useEffect(() => {
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
