import { z } from "zod"

/**
 * Shared input-validation primitives for server actions.
 *
 * Server actions are public HTTP endpoints: every argument is
 * client-controlled. RLS is the authorization layer; these schemas are
 * defense-in-depth so malformed input fails fast with a clear error
 * instead of reaching the database.
 */

export const uuidSchema = z.uuid()

export const uuidArraySchema = z.array(uuidSchema)

export const emailSchema = z.email().max(254)

/** Opaque tokens (e.g. invitation tokens) — bounded, non-empty strings. */
export const tokenSchema = z.string().trim().min(8).max(255)
