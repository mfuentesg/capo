"use server"

import { createClient } from "@/lib/supabase/server"
import { generateToken } from "../lib/token"

export interface ApiTokenRow {
  id: string
  name: string
  created_at: string
  last_used_at: string | null
  revoked_at: string | null
}

async function requireUser() {
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")
  return { supabase, user }
}

export async function createApiTokenAction(name: string): Promise<{ id: string; token: string }> {
  const trimmed = name.trim()
  if (!trimmed) throw new Error("Name is required")
  const { supabase, user } = await requireUser()
  const { token, hash } = generateToken()
  const { data, error } = await supabase
    .from("api_tokens")
    .insert({ user_id: user.id, name: trimmed.slice(0, 80), token_hash: hash })
    .select("id")
    .single()
  if (error) throw error
  return { id: data.id, token }
}

export async function revokeApiTokenAction(id: string): Promise<void> {
  const { supabase, user } = await requireUser()
  const { error } = await supabase
    .from("api_tokens")
    .update({ revoked_at: new Date().toISOString() })
    .eq("id", id)
    .eq("user_id", user.id)
  if (error) throw error
}

export async function listApiTokensAction(): Promise<ApiTokenRow[]> {
  const { supabase, user } = await requireUser()
  const { data, error } = await supabase
    .from("api_tokens")
    .select("id,name,created_at,last_used_at,revoked_at")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
  if (error) throw error
  return data ?? []
}
