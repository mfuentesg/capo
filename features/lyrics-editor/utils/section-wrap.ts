export interface SectionType {
  label: string
  key: string
  start: string
  end: string
}

export const SECTION_TYPES: SectionType[] = [
  { label: "Verse", key: "verse", start: "sov", end: "eov" },
  { label: "Pre-Chorus", key: "prechorus", start: "sopc", end: "eopc" },
  { label: "Chorus", key: "chorus", start: "soc", end: "eoc" },
  { label: "Bridge", key: "bridge", start: "sob", end: "eob" },
  { label: "Intro", key: "intro", start: "soi", end: "eoi" },
  { label: "Outro", key: "outro", start: "soo", end: "eoo" },
]

export function computeSectionName(type: SectionType, lyrics: string): string {
  const regex = new RegExp(`\\{(?:${type.start}|start_of_${type.key})`, "gi")
  const count = (lyrics.match(regex) || []).length
  return count === 0 ? type.label : `${type.label} ${count + 1}`
}

export function wrapWithSection(
  selectedText: string,
  sectionType: SectionType,
  fullLyrics: string
): string {
  const name = computeSectionName(sectionType, fullLyrics)
  return `{${sectionType.start}: ${name}}\n${selectedText}\n{${sectionType.end}}`
}
