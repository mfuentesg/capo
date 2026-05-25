"use server"

import { createClient } from "@/lib/supabase/server"
import { cookies } from "next/headers"
import { isValidUIFont, type UIFont } from "@/lib/font"

export async function setFontAction(font: UIFont) {
  if (!isValidUIFont(font)) {
    throw new Error("Invalid font")
  }

  const cookieStore = await cookies()
  cookieStore.set("NEXT_UI_FONT", font, {
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
        p_key: "uiFont",
        p_value: font
      })
    }
  } catch {
    // cookie already set — DB write is best-effort
  }
}
