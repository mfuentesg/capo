import { createClient } from "@/lib/supabase/server"
import { NextResponse } from "next/server"
import { getPendingInvitations } from "@/features/teams"

export async function GET() {
  try {
    const supabase = await createClient()

    const {
      data: { user }
    } = await supabase.auth.getUser()

    if (!user?.email) {
      return NextResponse.json({ error: "Not authenticated" }, { status: 401 })
    }

    return NextResponse.json(await getPendingInvitations(supabase))
  } catch (error) {
    console.error("API error:", error)
    return NextResponse.json({ error: "Failed to fetch invitations" }, { status: 500 })
  }
}
