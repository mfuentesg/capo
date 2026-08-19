"use client"

import { useState } from "react"
import { Loader2, Music4 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter
} from "@/components/ui/dialog"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { useTranslation } from "@/hooks/use-translation"
import { importSongFromCifraClubAction } from "../api/actions"
import type { CifraClubParseError, CifraClubParsedSong } from "../types/cifraclub-import.types"

type DialogStep = "input" | "loading" | "confirm-replace" | "error"

interface CifraClubImportDialogProps {
  mode: "create" | "replace-lyrics"
  hasExistingLyrics?: boolean
  open: boolean
  onOpenChange: (open: boolean) => void
  onImported: (result: CifraClubParsedSong) => void
}

export function CifraClubImportDialog({
  mode,
  hasExistingLyrics = false,
  open,
  onOpenChange,
  onImported
}: CifraClubImportDialogProps) {
  const { t } = useTranslation()
  const [url, setUrl] = useState("")
  const [step, setStep] = useState<DialogStep>("input")
  const [error, setError] = useState<CifraClubParseError | null>(null)
  const [pendingResult, setPendingResult] = useState<CifraClubParsedSong | null>(null)

  const errorMessages: Record<CifraClubParseError, string> = {
    invalid_url: t.songs.cifraImport.errors.invalidUrl,
    wrong_host: t.songs.cifraImport.errors.unsupportedHost,
    network: t.songs.cifraImport.errors.network,
    http_status: t.songs.cifraImport.errors.network,
    no_chord_block: t.songs.cifraImport.errors.parseFailed,
    unexpected: t.songs.cifraImport.errors.unknown
  }

  const reset = () => {
    setUrl("")
    setStep("input")
    setError(null)
    setPendingResult(null)
  }

  const handleOpenChange = (nextOpen: boolean) => {
    if (!nextOpen) reset()
    onOpenChange(nextOpen)
  }

  const handleImport = async () => {
    setStep("loading")
    setError(null)
    const result = await importSongFromCifraClubAction(url)

    if (!result.success) {
      setError(result.error)
      setStep("error")
      return
    }

    if (mode === "replace-lyrics" && hasExistingLyrics) {
      setPendingResult(result.data)
      setStep("confirm-replace")
      return
    }

    onImported(result.data)
    handleOpenChange(false)
  }

  const handleConfirmReplace = () => {
    if (!pendingResult) return
    onImported(pendingResult)
    handleOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {mode === "create"
              ? t.songs.cifraImport.dialogTitleCreate
              : t.songs.cifraImport.dialogTitleReplace}
          </DialogTitle>
        </DialogHeader>

        {step === "confirm-replace" ? (
          <div className="space-y-4">
            <Alert variant="destructive">
              <AlertDescription>{t.songs.cifraImport.confirmReplaceDescription}</AlertDescription>
            </Alert>
            <DialogFooter>
              <Button variant="outline" onClick={() => setStep("input")}>
                {t.common.cancel}
              </Button>
              <Button onClick={handleConfirmReplace}>{t.songs.cifraImport.confirmReplaceTitle}</Button>
            </DialogFooter>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="cifraclub-url">{t.songs.cifraImport.urlLabel}</Label>
              <Input
                id="cifraclub-url"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder={t.songs.cifraImport.urlPlaceholder}
                autoFocus
                disabled={step === "loading"}
              />
            </div>

            {step === "error" && error && (
              <Alert variant="destructive">
                <AlertDescription>{errorMessages[error]}</AlertDescription>
              </Alert>
            )}

            <DialogFooter>
              <Button variant="outline" onClick={() => handleOpenChange(false)}>
                {t.common.cancel}
              </Button>
              <Button disabled={!url.trim() || step === "loading"} onClick={handleImport}>
                {step === "loading" ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    {t.songs.cifraImport.importing}
                  </>
                ) : (
                  <>
                    <Music4 className="h-4 w-4" />
                    {t.songs.cifraImport.importButton}
                  </>
                )}
              </Button>
            </DialogFooter>
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
