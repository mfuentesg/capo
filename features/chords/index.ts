"use client"

export { ChordsPage } from "./components/chords-page"
export { ChordGlossary } from "./components/chord-glossary"
export { ChordAnalyzer } from "./components/chord-analyzer"

export { getAllChords, searchChords, getChordsByKey, getAvailableKeys, keyLabel, toDbKey, isValidChordPosition } from "./utils/chord-db-helpers"
export type { ChordEntry, ChordPosition } from "./utils/chord-db-helpers"

export { identifyChord, getNotesFromFrets, NOTE_NAMES } from "./utils/chord-identifier"
export type { IdentifiedChord } from "./utils/chord-identifier"

export { useChordSearch } from "./hooks/use-chord-search"
export { useChordAnalyzer } from "./hooks/use-chord-analyzer"
export { useChordOrientation } from "@/hooks/use-chord-orientation"
