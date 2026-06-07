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

  return (
    <div onPointerUp={revealToolbar} onKeyUp={revealToolbar}>
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
