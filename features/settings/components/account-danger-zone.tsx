"use client"

import { useState, useTransition } from "react"
import { Button } from "@/components/ui/button"
import { useLocale } from "../contexts"
import { deleteAccountAction } from "../api/actions"

export function AccountDangerZone() {
  const { t } = useLocale()
  const [confirming, setConfirming] = useState(false)
  const [isPending, startTransition] = useTransition()

  const handleDelete = () => {
    startTransition(async () => {
      await deleteAccountAction()
    })
  }

  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-base font-semibold text-destructive">{t.settings.dangerZone}</h2>
        <p className="text-sm text-muted-foreground mt-0.5">{t.settings.dangerZoneDescription}</p>
      </div>
      {!confirming ? (
        <Button variant="destructive" onClick={() => setConfirming(true)} className="transition active:scale-[0.98]">
          {t.settings.deleteAccount}
        </Button>
      ) : (
        <div className="space-y-3">
          <p className="text-sm font-medium">{t.settings.deleteAccountConfirm}</p>
          <div className="flex gap-2">
            <Button
              variant="ghost"
              disabled={isPending}
              onClick={() => setConfirming(false)}
            >
              {t.common.cancel}
            </Button>
            <Button
              variant="destructive"
              disabled={isPending}
              onClick={handleDelete}
              className="transition active:scale-[0.98]"
            >
              {isPending ? t.settings.deleteAccountPending : t.settings.deleteAccountConfirmButton}
            </Button>
          </div>
        </div>
      )}
    </section>
  )
}
