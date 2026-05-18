"use client"

import { useState, useCallback, useRef, useEffect } from "react"
import { midiToNote } from "../utils/midi-to-note"

// Module-level singleton — one Sampler shared across all hook instances
let samplerReady = false
let samplerLoading: Promise<void> | null = null
let sampler: import("tone").Sampler | null = null

// Duration each note rings before release (seconds)
const NOTE_DURATION = 1.5
// How long isPlaying stays true (ms) — matches stagger + duration
const PLAYING_INDICATOR_MS = 1500

async function loadSampler(): Promise<void> {
  if (samplerReady) return
  if (samplerLoading) return samplerLoading

  samplerLoading = new Promise<void>((resolve, reject) => {
    import("tone")
      .then(({ Sampler }) => {
        sampler = new Sampler(
          {
            A2: "A2.mp3",
            A3: "A3.mp3",
            A4: "A4.mp3",
            C3: "C3.mp3",
            C4: "C4.mp3",
            C5: "C5.mp3",
            E2: "E2.mp3",
            E3: "E3.mp3",
            E4: "E4.mp3",
            G3: "G3.mp3",
            G4: "G4.mp3",
          },
          {
            baseUrl: "https://nbrosowsky.github.io/tonejs-instruments/samples/guitar-acoustic/",
            onload: () => {
              samplerReady = true
              resolve()
            },
            onerror: (err: Error) => {
              samplerLoading = null
              sampler = null
              reject(err)
            },
          }
        ).toDestination()
      })
      .catch((err: Error) => {
        samplerLoading = null
        reject(err)
      })
  })
  return samplerLoading
}

export function useChordAudio() {
  const [isLoading, setIsLoading] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)
  const playingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    return () => {
      if (playingTimerRef.current) clearTimeout(playingTimerRef.current)
    }
  }, [])

  const play = useCallback(async (midiNotes: number[]) => {
    if (!midiNotes.length) return

    if (!samplerReady) {
      setIsLoading(true)
      try {
        await loadSampler()
      } catch {
        setIsLoading(false)
        return
      }
      setIsLoading(false)
    }

    if (!sampler) return

    const Tone = await import("tone")

    try {
      await Tone.start()
      setIsPlaying(true)
      const now = Tone.now()
      midiNotes.forEach((midi, i) => {
        sampler!.triggerAttackRelease(midiToNote(midi), NOTE_DURATION, now + i * 0.025)
      })
      if (playingTimerRef.current) clearTimeout(playingTimerRef.current)
      playingTimerRef.current = setTimeout(() => setIsPlaying(false), PLAYING_INDICATOR_MS)
    } catch {
      setIsPlaying(false)
    }
  }, [])

  const stop = useCallback(() => {
    if (sampler) {
      try {
        sampler.releaseAll()
      } catch {}
    }
    if (playingTimerRef.current) clearTimeout(playingTimerRef.current)
    setIsPlaying(false)
  }, [])

  return { play, stop, isLoading, isPlaying }
}
