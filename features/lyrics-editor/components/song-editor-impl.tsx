"use client"

import { useCallback, useMemo, useRef, useState } from "react"
import CodeMirror from "@uiw/react-codemirror"
import type { ReactCodeMirrorRef } from "@uiw/react-codemirror"
import { EditorView } from "@codemirror/view"
import type { ViewUpdate } from "@codemirror/view"
import { useTheme } from "next-themes"
import { catppuccinLatte, catppuccinMocha } from "@catppuccin/codemirror"
import { toast } from "sonner"
import { useTranslation } from "@/hooks/use-translation"
import { chordProExtensions } from "../utils/chordpro-lang"
import { pasteConvertExtension } from "../utils/paste-convert-extension"
import { shiftLyricsChords } from "../utils/shift-chords"
import { wrapWithSection } from "../utils/section-wrap"
import type { SectionType } from "../utils/section-wrap"
import { SectionWrapToolbar } from "./section-wrap-toolbar"

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
  const editorRef = useRef<ReactCodeMirrorRef>(null)
  const selectionRef = useRef<{ from: number; to: number } | null>(null)
  const [hasSelection, setHasSelection] = useState(false)

  const extensions = useMemo(
    () => [
      ...baseExtensions,
      pasteConvertExtension({
        onConversion: () => toast.success(t.toasts.lyricsConvertedToChordPro)
      })
    ],
    [t.toasts.lyricsConvertedToChordPro]
  )

  const handleUpdate = useCallback((viewUpdate: ViewUpdate) => {
    if (viewUpdate.selectionSet) {
      const { from, to } = viewUpdate.state.selection.main
      if (from !== to) {
        selectionRef.current = { from, to }
        // Do NOT call setHasSelection(true) here — showing the toolbar mid-drag
        // causes a layout shift that pushes the editor down and disrupts selection.
        // The toolbar appears on pointerUp / keyUp instead.
      } else {
        selectionRef.current = null
        setHasSelection(false)
      }
    }
  }, [])

  const revealToolbar = useCallback(() => {
    if (selectionRef.current) setHasSelection(true)
  }, [])

  const hideToolbar = useCallback(() => {
    selectionRef.current = null
    setHasSelection(false)
  }, [])

  const handleWrap = useCallback(
    (sectionType: SectionType) => {
      const view = editorRef.current?.view
      const sel = selectionRef.current
      if (!view || !sel) return

      const currentContent = view.state.doc.toString()
      const selectedText = view.state.sliceDoc(sel.from, sel.to)
      const wrapped = wrapWithSection(selectedText, sectionType, currentContent)
      view.dispatch({ changes: { from: sel.from, to: sel.to, insert: wrapped } })
    },
    []
  )

  // Rewrites the chords in the selection (or the whole text) in the stored lyrics.
  // Does not touch the song's key, capo or transpose settings.
  const handleShift = useCallback(
    (semitones: number) => {
      const view = editorRef.current?.view
      if (!view) return
      const { from, to } = view.state.selection.main
      const hasRange = from !== to
      const start = hasRange ? from : 0
      const end = hasRange ? to : view.state.doc.length
      const original = view.state.sliceDoc(start, end)
      const shifted = shiftLyricsChords(original, semitones)
      if (shifted !== original) view.dispatch({ changes: { from: start, to: end, insert: shifted } })
    },
    []
  )

  return (
    <div onPointerUp={revealToolbar} onKeyUp={revealToolbar}>
      {onChange && (
        <div className="flex items-center gap-1.5 px-3 py-2 border-b bg-muted/30 flex-wrap">
          <span className="text-xs text-muted-foreground shrink-0 mr-0.5">
            {t.songs.lyrics.shiftChords}
          </span>
          {[-1, 1].map((n) => (
            <button
              key={n}
              type="button"
              className="inline-flex items-center rounded-md border bg-background px-2 py-0.5 text-xs font-medium hover:bg-muted transition-colors cursor-pointer"
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => handleShift(n)}
              title={t.songs.lyrics.shiftChordsHint}
            >
              {n > 0 ? "+1" : "−1"} {t.songs.lyrics.semitone}
            </button>
          ))}
        </div>
      )}
      <SectionWrapToolbar visible={hasSelection && !!onChange} onWrap={handleWrap} />
      <CodeMirror
        ref={editorRef}
        value={content}
        height="600px"
        theme={resolvedTheme === "dark" ? catppuccinMocha : catppuccinLatte}
        extensions={extensions}
        onChange={(value) => onChange?.(value)}
        onUpdate={handleUpdate}
        onBlur={hideToolbar}
        basicSetup={{
          lineNumbers: false,
          foldGutter: false,
          highlightActiveLine: false,
          autocompletion: false
        }}
        data-cy="song-editor"
      />
    </div>
  )
}
