"use client"

// Client-safe entry point. `./index` re-exports server-only code (node:crypto
// token utils, "use server" actions), so client components such as the settings
// page must import the UI from "@/features/api-tokens/client" instead.
export { ApiTokensSettings } from "./components"
export type { ApiTokenRow } from "./api/actions"
