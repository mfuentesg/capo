"use client"

import { useState, useCallback } from "react"
import { midiToNote } from "../utils/midi-to-note"

// Module-level singleton — one Sampler shared across all hook instances
let samplerReady = false
let samplerLoading: Promise<void> | null = null
let sampler: import("tone").Sampler | null = null

async function loadSampler(): Promise<void> {
  if (samplerReady) return
  if (samplerLoading) return samplerLoading

  samplerLoading = new Promise<void>((resolve) => {
    import("tone").then(({ Sampler }) => {
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
        }
      ).toDestination()
    })
  })
  return samplerLoading
}

export function useChordAudio() {
  const [isLoading, setIsLoading] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)

  const play = useCallback(async (midiNotes: number[]) => {
    if (!midiNotes.length) return

    if (!samplerReady) {
      setIsLoading(true)
      await loadSampler()
      setIsLoading(false)
    }

    if (!sampler) return

    const Tone = await import("tone")
    await Tone.start()

    setIsPlaying(true)
    const now = Tone.now()
    midiNotes.forEach((midi, i) => {
      sampler!.triggerAttack(midiToNote(midi), now + i * 0.025)
    })

    setTimeout(() => setIsPlaying(false), 800)
  }, [])

  return { play, isLoading, isPlaying }
}
