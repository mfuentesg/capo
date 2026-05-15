"use client"

import { useMemo } from "react"
import CodeMirror from "@uiw/react-codemirror"
import { EditorView } from "@codemirror/view"
import { useTheme } from "next-themes"
import { catppuccinLatte, catppuccinMocha } from "@catppuccin/codemirror"
import { toast } from "sonner"
import { useTranslation } from "@/hooks/use-translation"
import { chordProExtensions } from "../utils/chordpro-lang"
import { pasteConvertExtension } from "../utils/paste-convert-extension"

interface Props {
  content: string
  onChange?(value: string): void
}

const editorStyle = EditorView.theme({
  "&": {
    fontSize: "16px",
    fontFamily: "var(--font-geist-mono), ui-monospace, monospace"
  },
  ".cm-line": {
    lineHeight: "1.6"
  }
})

const baseExtensions = [...chordProExtensions(), EditorView.lineWrapping, editorStyle]

export default function SongEditorImpl({ content, onChange }: Props) {
  const { resolvedTheme } = useTheme()
  const { t } = useTranslation()

  const extensions = useMemo(
    () => [
      ...baseExtensions,
      pasteConvertExtension({
        onConversion: () => toast.success(t.toasts.lyricsConvertedToChordPro)
      })
    ],
    [t.toasts.lyricsConvertedToChordPro]
  )

  return (
    <CodeMirror
      value={content}
      height="600px"
      theme={resolvedTheme === "dark" ? catppuccinMocha : catppuccinLatte}
      extensions={extensions}
      onChange={(value) => onChange?.(value)}
      basicSetup={{
        lineNumbers: false,
        foldGutter: false,
        highlightActiveLine: false,
        autocompletion: false
      }}
      data-cy="song-editor"
    />
  )
}
