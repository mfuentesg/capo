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
import { setFontAction } from "@/lib/actions/font"
import { isValidUIFont, DEFAULT_UI_FONT, type UIFont } from "@/lib/font"

interface FontContextType {
  font: UIFont
  isPending: boolean
  setFont: (font: UIFont) => void
}

const FontContext = createContext<FontContextType | undefined>(undefined)

export function FontProvider({
  children,
  initialFont = DEFAULT_UI_FONT
}: {
  children: ReactNode
  initialFont?: UIFont
}) {
  const [font, setFontState] = useState<UIFont>(initialFont)
  const [isPending, startTransition] = useTransition()

  useEffect(() => {
    document.documentElement.dataset.font = font
  }, [font])

  const setFont = useCallback(
    (newFont: UIFont) => {
      if (!isValidUIFont(newFont)) return
      setFontState(newFont)
      document.documentElement.dataset.font = newFont
      startTransition(async () => {
        await setFontAction(newFont)
      })
    },
    [startTransition]
  )

  const value = useMemo(() => ({ font, isPending, setFont }), [font, isPending, setFont])

  return <FontContext.Provider value={value}>{children}</FontContext.Provider>
}

export function useFont() {
  const context = useContext(FontContext)
  if (context === undefined) {
    throw new Error("useFont must be used within a FontProvider")
  }
  return context
}
