# Chord Audio Playback — Design Spec

**Date:** 2026-05-18  
**Status:** Approved

## Summary

Add a play button to the chord diagram dialog (lyrics editor) and chord detail sheet (chord glossary) that plays the current chord voicing using realistic guitar samples via Tone.js.

## Scope

- Chord diagram dialog (`features/lyrics-editor/components/chord-diagram.tsx`)
- Chord detail sheet (`features/chords/components/chord-detail-sheet.tsx`)
- **Not in scope:** chord tokens in the lyrics view, chord grid cards, auto-play on open

## Architecture

New feature: `features/chord-audio/`

```
features/chord-audio/
├── hooks/
│   └── use-chord-audio.ts     # Singleton Tone.js sampler + play logic
├── components/
│   └── chord-play-button.tsx  # Icon button with loading/playing states
└── index.ts                   # Public API
```

### `useChordAudio` hook

Lazy-initializes a Tone.js `Sampler` singleton on first call (dynamic import avoids SSR). Exposes:

| Field | Type | Description |
|---|---|---|
| `play(midiNotes: number[])` | function | Play chord; no-op if notes empty or loading |
| `isLoading` | boolean | True while Tone.js + samples are loading |
| `isPlaying` | boolean | True for ~800ms after `play()` fires |

**Singleton pattern:** sampler is created once at module level (after first `play` call), reused on every subsequent call. Prevents reinit across re-renders and route navigations.

**Arpeggio stagger:** notes play 25ms apart, bass to treble (index 0 → last), mimicking a downstroke. This matches the ordering in `@tombatossals/chords-db` `midi[]` arrays.

**MIDI → note name conversion:**
```
noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
noteName = noteNames[midi % 12] + String(Math.floor(midi / 12) - 1)
// e.g. 45 → "A2", 60 → "C4"
```

### `ChordPlayButton` component

Small icon button. Accepts `midiNotes: number[] | undefined`. Hidden (returns null) when `midiNotes` is undefined or empty.

| State | Visual |
|---|---|
| Default | `Volume2` icon, muted foreground |
| Loading | Spinner (Loader2 animated icon) |
| Playing | `Volume2` icon, primary color, brief scale pulse |

### Audio samples

Tone.js Sampler with acoustic guitar samples from `https://nbrosowsky.github.io/tonejs-instruments/samples/guitar-acoustic/`. Only the notes actually needed for each chord download per session; browser caches them after first load.

## Integration

### Chord detail sheet (`chord-detail-sheet.tsx`)

Add `ChordPlayButton` to `SheetHeader`, inline with chord name. Pass `(chord.positions[positionIndex] as ChordPosition).midi`.

When `positionIndex` changes (user swipes to new voicing), `midiNotes` prop updates automatically — play button plays the new voicing.

### Chord diagram dialog (`chord-diagram.tsx`)

Add `ChordPlayButton` to `DialogHeader`, inline with chord name. Pass `currentChord.midi`.

For algorithmically generated chords (`isAlgorithmic === true`), the generated `ChordPosition` objects have no `midi` field → `ChordPlayButton` receives `undefined` → renders nothing. No special case needed.

## Data flow

```
chord DB position.midi → ChordPlayButton → useChordAudio.play()
                                            ↓
                                    MIDI → note names
                                            ↓
                                    Tone.js Sampler.triggerAttack()
                                    (staggered 25ms per note)
```

## Out of scope / future

- Playing chords from chord tokens in the lyrics view
- Play button on chord grid cards (glossary list)
- Instrument selection (piano, ukulele, etc.)
- Self-hosting audio samples (CDN is fine for MVP)
