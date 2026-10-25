"use client"

import { useCallback, useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { useLocale } from "@/features/settings"
import {
  createApiTokenAction,
  listApiTokensAction,
  revokeApiTokenAction,
  type ApiTokenRow
} from "../api/actions"

function formatDate(iso: string, locale: string): string {
  return new Date(iso).toLocaleDateString(locale)
}

export function ApiTokensSettings() {
  const { t, locale } = useLocale()
  const s = t.settings.apiTokens
  const [tokens, setTokens] = useState<ApiTokenRow[]>([])
  const [name, setName] = useState("")
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  // Plaintext token: transient state, shown once, never persisted or logged.
  const [revealed, setRevealed] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  const refresh = useCallback(async () => {
    try {
      setTokens(await listApiTokensAction())
    } catch {
      setError(s.loadError)
    }
  }, [s.loadError])

  useEffect(() => {
    void refresh()
  }, [refresh])

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    if (!name.trim() || busy) return
    setBusy(true)
    setError(null)
    try {
      const { token } = await createApiTokenAction(name)
      setRevealed(token)
      setCopied(false)
      setName("")
      await refresh()
    } catch {
      setError(s.createError)
    } finally {
      setBusy(false)
    }
  }

  async function handleRevoke(id: string) {
    setError(null)
    try {
      await revokeApiTokenAction(id)
      await refresh()
    } catch {
      setError(s.revokeError)
    }
  }

  async function handleCopy() {
    if (!revealed) return
    try {
      await navigator.clipboard.writeText(revealed)
      setCopied(true)
    } catch {
      // Clipboard unavailable; the user can select the field manually.
    }
  }

  function closeReveal() {
    setRevealed(null)
    setCopied(false)
  }

  return (
    <section className="space-y-5">
      <div>
        <h2 className="text-base font-semibold tracking-tight">{s.title}</h2>
        <p className="text-sm text-muted-foreground mt-0.5">{s.description}</p>
      </div>

      <form onSubmit={handleCreate} className="flex items-end gap-2 max-w-md">
        <div className="flex-1 space-y-1.5">
          <Label htmlFor="api-token-name">{s.nameLabel}</Label>
          <Input
            id="api-token-name"
            value={name}
            maxLength={80}
            placeholder={s.namePlaceholder}
            onChange={(e) => setName(e.target.value)}
          />
        </div>
        <Button type="submit" disabled={busy || !name.trim()}>
          {busy ? s.creating : s.create}
        </Button>
      </form>

      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}

      {revealed && (
        <div className="space-y-2 rounded-lg border bg-muted/40 p-4 max-w-xl">
          <p className="text-sm font-medium">{s.revealTitle}</p>
          <div className="flex gap-2">
            <Input readOnly value={revealed} aria-label={s.revealTitle} className="font-mono text-xs" />
            <Button type="button" variant="outline" onClick={handleCopy}>
              {copied ? s.copied : s.copy}
            </Button>
            <Button type="button" variant="ghost" onClick={closeReveal}>
              {s.close}
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">{s.revealWarning}</p>
        </div>
      )}

      {tokens.length === 0 ? (
        <p className="text-sm text-muted-foreground">{s.empty}</p>
      ) : (
        <ul className="divide-y rounded-lg border">
          {tokens.map((tok) => (
            <li key={tok.id} className="flex items-center justify-between gap-3 px-4 py-3">
              <div className="min-w-0 space-y-0.5">
                <p className="truncate text-sm font-medium">{tok.name}</p>
                <p className="text-xs text-muted-foreground">
                  {s.createdOn.replace("{date}", formatDate(tok.created_at, locale))}
                  {" · "}
                  {tok.last_used_at
                    ? s.lastUsed.replace("{date}", formatDate(tok.last_used_at, locale))
                    : s.neverUsed}
                </p>
              </div>
              {tok.revoked_at ? (
                <Badge variant="secondary">{s.revoked}</Badge>
              ) : (
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  aria-label={s.revokeAria.replace("{name}", tok.name)}
                  onClick={() => handleRevoke(tok.id)}
                >
                  {s.revoke}
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
