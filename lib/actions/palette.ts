"use server"

import { createClient } from "@/lib/supabase/server"
import { cookies } from "next/headers"

export const VALID_PALETTES = ["catppuccin", "aura", "nord", "rose-pine"] as const
export type Palette = (typeof VALID_PALETTES)[number]

export function isValidPalette(v: unknown): v is Palette {
  return VALID_PALETTES.includes(v as Palette)
}

export const DEFAULT_PALETTE: Palette = "catppuccin"

export async function setPaletteAction(palette: Palette) {
  if (!isValidPalette(palette)) {
    throw new Error("Invalid palette")
  }

  const cookieStore = await cookies()
  cookieStore.set("NEXT_PALETTE", palette, {
    path: "/",
    maxAge: 31536000,
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production"
  })

  try {
    const supabase = await createClient()
    const {
      data: { user }
    } = await supabase.auth.getUser()
    if (user) {
      await supabase.rpc("merge_user_preference", {
        p_user_id: user.id,
        p_key: "palette",
        p_value: palette
      })
    }
  } catch {
    // cookie already set — DB write is best-effort
  }
}
