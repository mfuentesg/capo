import Link from "next/link"
import { OptimizedLogo } from "@/components/optimized-logo"
import { ThemeToggle } from "@/components/layout"
import { LanguageSwitcher } from "@/components/layout"
import { cn } from "@/lib/utils"
import type { getTranslations } from "@/lib/i18n/translations"
import { LandingFeedbackSection } from "@/components/landing-feedback-section"
import {
  Music,
  FileText,
  ListMusic,
  Users,
  Share2,
  ArrowRight,
  Check,
  Guitar,
  Github
} from "lucide-react"
import { Button } from "@/components/ui/button"

// ── Example song data (not UI text — kept out of translations) ────────────────
const RECKLESS_LOVE = {
  title: "Reckless Love",
  artist: "Cory Asbury",
  key: "A",
  chordproTitle: "{title: Reckless Love}",
  chordproArtist: "{artist: Cory Asbury}",
  chordproKey: "{key: A}",
  verseDirective: "{start_of_verse: Verse 1}",
  endVerseDirective: "{end_of_verse}",
  chorusDirective: "{start_of_chorus: Chorus}",
  endChorusDirective: "{end_of_chorus}",
  verse: [
    { chords: ["D", "A"], pre: "", line: "Before I spoke a word, You were" },
    { chords: ["E"], pre: "", line: "singing over me" },
    { chords: ["D", "A"], pre: "", line: "Before I took a breath, You breathed" },
    { chords: ["E"], pre: "", line: "life in me" }
  ],
  chorus: [
    { chords: ["A", "E"], line: "Oh, the overwhelming, never-ending" },
    { chords: ["F#m", "D"], line: "reckless love of God" }
  ],
  previewVerse: [
    { chords: "D          A", lyric: "Before I spoke a word, You were" },
    { chords: "E", lyric: "singing over me" }
  ],
  previewChorus: [
    { chords: "A              E", lyric: "Oh, the overwhelming, never-ending" },
    { chords: "F#m        D", lyric: "reckless love of God" }
  ]
}

const AQUI_ESTOY = { title: "Aquí Estoy", artist: "Hillsong en Español", key: "G", bpm: 70 }

const LIBRARY_SONGS = [
  { title: "Reckless Love", artist: "Cory Asbury", key: "A", bpm: 75 },
  { title: "Aquí Estoy", artist: "Hillsong en Español", key: "G", bpm: 70 },
  { title: "10,000 Reasons", artist: "Matt Redman", key: "G", bpm: 73 },
  { title: "Great Are You Lord", artist: "All Sons & Daughters", key: "D", bpm: 67 }
]

const TEAM_MEMBERS = [
  { name: "Marco Rodriguez", role: "admin", initial: "MR", color: "bg-primary/20 text-primary" },
  { name: "Sarah Chen", role: "member", initial: "SC", color: "bg-green-500/20 text-green-500" },
  { name: "Daniel Okafor", role: "member", initial: "DO", color: "bg-violet-500/20 text-violet-500" },
  { name: "Lucia Santos", role: "invited", initial: "LS", color: "bg-muted text-muted-foreground" }
]

const SETLISTS = ["Sunday Worship", "Ensayo #8", "Acoustic Set"]

const SHARE_SONGS = [
  `1. ${RECKLESS_LOVE.title} — ${RECKLESS_LOVE.artist}`,
  `2. ${AQUI_ESTOY.title} — ${AQUI_ESTOY.artist}`,
  "3. 10,000 Reasons — Matt Redman",
  "4. Great Are You Lord — All Sons & Daughters"
]

const FEATURE_DOTS = [
  { Icon: Music, color: "text-blue-500", bg: "bg-blue-500/10" },
  { Icon: FileText, color: "text-violet-500", bg: "bg-violet-500/10" },
  { Icon: ListMusic, color: "text-primary", bg: "bg-primary/10" },
  { Icon: Users, color: "text-green-500", bg: "bg-green-500/10" },
  { Icon: Share2, color: "text-pink-500", bg: "bg-pink-500/10" },
  { Icon: Guitar, color: "text-amber-500", bg: "bg-amber-500/10" }
]

// ── Main component ────────────────────────────────────────────────────────────
export function LandingPage({ t }: { t: ReturnType<typeof getTranslations> }) {
  const l = t.landing

  const features = [
    { icon: Music, title: l.features.songLibrary.title, description: l.features.songLibrary.description, color: "text-blue-500", bg: "bg-blue-500/10" },
    { icon: FileText, title: l.features.chordproEditor.title, description: l.features.chordproEditor.description, color: "text-violet-500", bg: "bg-violet-500/10" },
    { icon: ListMusic, title: l.features.smartSetlists.title, description: l.features.smartSetlists.description, color: "text-primary", bg: "bg-primary/10" },
    { icon: Users, title: l.features.teamCollab.title, description: l.features.teamCollab.description, color: "text-green-500", bg: "bg-green-500/10" },
    { icon: Share2, title: l.features.instantSharing.title, description: l.features.instantSharing.description, color: "text-pink-500", bg: "bg-pink-500/10" },
    { icon: Guitar, title: l.features.chordDiagrams.title, description: l.features.chordDiagrams.description, color: "text-amber-500", bg: "bg-amber-500/10" }
  ]

  const highlights = [
    l.highlights.chordpro,
    l.highlights.themes,
    l.highlights.multilanguage,
    l.highlights.realtime,
    l.highlights.dragdrop,
    l.highlights.publicLinks
  ]

  const songLibraryFeatures = [l.songLibrarySection.feature1, l.songLibrarySection.feature2, l.songLibrarySection.feature3, l.songLibrarySection.feature4]
  const teamsFeatures = [l.teamsSection.feature1, l.teamsSection.feature2, l.teamsSection.feature3, l.teamsSection.feature4]
  const sharingFeatures = [l.sharingSection.feature1, l.sharingSection.feature2, l.sharingSection.feature3, l.sharingSection.feature4]

  const roleLabel = (role: string) =>
    role === "admin" ? l.teamsSection.roleAdmin : role === "member" ? l.teamsSection.roleMember : l.teamsSection.roleInvited

  const roleBadgeClass = (role: string) =>
    role === "admin"
      ? "bg-primary/15 text-primary"
      : role === "invited"
        ? "bg-muted text-muted-foreground"
        : "bg-green-500/15 text-green-500"

  return (
    <div className="min-h-svh bg-background text-foreground overflow-x-hidden">
      {/* ── Navbar ─────────────────────────────────────────────────────── */}
      <header className="fixed top-0 inset-x-0 z-50 border-b border-border/40 bg-background md:bg-background/80 md:backdrop-blur-md">
        <nav className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <Link href="/" className="flex items-center">
            <OptimizedLogo
              name="capo-text"
              alt={t.common.capoLogo}
              width={80}
              height={24}
              priority
              className="dark:invert"
            />
          </Link>

          <div className="flex items-center gap-1.5">
            <ThemeToggle />
            <LanguageSwitcher />
            <Link href="/login">
              <Button variant="outline" size="sm">{l.nav.signIn}</Button>
            </Link>
          </div>
        </nav>
      </header>

      {/* ── Hero ───────────────────────────────────────────────────────── */}
      <section className="relative min-h-[100dvh] flex items-center px-6 pt-28 pb-20 overflow-hidden">
        {/* Gradient orbs */}
        <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="absolute -top-40 -left-40 h-[600px] w-[600px] rounded-full" style={{ background: "radial-gradient(circle, oklch(0.793 0.132 56 / 15%) 0%, transparent 70%)" }} />
          <div className="absolute -top-20 right-0 h-[500px] w-[500px] rounded-full" style={{ background: "radial-gradient(circle, oklch(0.749 0.160 298 / 10%) 0%, transparent 70%)" }} />
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 h-[400px] w-[800px] rounded-full" style={{ background: "radial-gradient(ellipse, oklch(0.793 0.132 56 / 8%) 0%, transparent 70%)" }} />
        </div>
        {/* Dot grid */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            backgroundImage: "radial-gradient(oklch(0.638 0.205 42 / 0.07) 1px, transparent 1px)",
            backgroundSize: "28px 28px"
          }}
        />

        <div className="relative mx-auto w-full max-w-7xl">
          <div className="grid items-center gap-16 lg:grid-cols-[3fr_2fr]">
            {/* Left column */}
            <div className="flex flex-col items-start">
              <p className="mb-5 text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
                {l.badge}
              </p>

              <h1 className="text-6xl font-bold tracking-tighter leading-[0.92] sm:text-7xl lg:text-7xl xl:text-8xl">
                {l.hero.headline1}
                <br />
                <span className="text-primary">{l.hero.headline2}</span>
              </h1>

              <div className="mt-8 h-0.5 w-14 rounded-full bg-primary" />

              <p className="mt-5 max-w-md text-base text-muted-foreground leading-relaxed sm:text-lg">
                {l.hero.description}
              </p>

              <div className="mt-8 flex flex-wrap items-center gap-3">
                <Button asChild size="lg" className="h-12 px-8 text-base font-semibold active:scale-[0.98]">
                  <Link href="/login">
                    {l.hero.startFree}
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </Link>
                </Button>
                <Button asChild variant="outline" size="lg" className="h-12 px-8 text-base active:scale-[0.98]">
                  <Link href="#features">{l.hero.exploreFeatures}</Link>
                </Button>
              </div>

              <div className="mt-8 flex flex-wrap gap-2">
                {highlights.map((item) => (
                  <span
                    key={item}
                    className="inline-flex items-center gap-1.5 rounded-full bg-muted px-3 py-1 text-xs text-muted-foreground"
                  >
                    <Check className="h-3 w-3 text-primary shrink-0" />
                    {item}
                  </span>
                ))}
              </div>
            </div>

            {/* Right column — tilted editor mock */}
            <div className="relative w-full -rotate-1 transition-transform duration-500 ease-out hover:rotate-0">
              <div aria-hidden className="absolute inset-0 -z-10 rounded-2xl bg-linear-to-br from-primary/20 via-violet-500/10 to-transparent scale-110" />
              <div className="rounded-2xl border border-border/60 bg-card/90 shadow-2xl backdrop-blur overflow-hidden">
                {/* Window chrome */}
                <div className="flex items-center gap-2 border-b border-border/60 bg-muted/30 px-4 py-3">
                  <div className="flex gap-1.5">
                    <div className="h-3 w-3 rounded-full bg-red-500/70" />
                    <div className="h-3 w-3 rounded-full bg-yellow-500/70" />
                    <div className="h-3 w-3 rounded-full bg-green-500/70" />
                  </div>
                  <div className="mx-auto flex items-center gap-2 rounded-md border border-border/50 bg-background/50 px-3 py-1 text-xs text-muted-foreground">
                    <Music className="h-3 w-3" />
                    {RECKLESS_LOVE.title} — {RECKLESS_LOVE.artist}
                  </div>
                </div>

                {/* Split-pane */}
                <div className="grid grid-cols-1 md:grid-cols-2 divide-y md:divide-y-0 md:divide-x divide-border/40 text-left">
                  {/* Editor pane */}
                  <div className="p-5 font-mono text-sm leading-7 text-muted-foreground">
                    <div className="text-primary/70">{RECKLESS_LOVE.chordproTitle}</div>
                    <div className="text-primary/70">{RECKLESS_LOVE.chordproArtist}</div>
                    <div className="text-primary/70">{RECKLESS_LOVE.chordproKey}</div>
                    <div className="mt-3 text-violet-400 font-semibold uppercase tracking-widest text-xs">
                      {RECKLESS_LOVE.verseDirective}
                    </div>
                    <div className="mt-1">
                      <span className="text-amber-400">[D]</span>
                      {" "}Before I{" "}
                      <span className="text-amber-400">[A]</span>
                      {" "}spoke a word
                    </div>
                    <div>
                      You were{" "}
                      <span className="text-amber-400">[E]</span>
                      {" "}singing over me
                    </div>
                    <div className="text-violet-400 font-semibold uppercase tracking-widest text-xs mt-1">
                      {RECKLESS_LOVE.endVerseDirective}
                    </div>
                    <div className="mt-2 text-violet-400 font-semibold uppercase tracking-widest text-xs">
                      {RECKLESS_LOVE.chorusDirective}
                    </div>
                    <div className="mt-1">
                      Oh, the{" "}
                      <span className="text-amber-400">[A]</span>
                      {" "}overwhelming,{" "}
                      <span className="text-amber-400">[E]</span>
                      {" "}never-ending
                    </div>
                    <div>
                      <span className="text-amber-400">[F#m]</span>
                      {" "}reckless{" "}
                      <span className="text-amber-400">[D]</span>
                      {" "}love of God
                    </div>
                    <div className="text-violet-400 font-semibold uppercase tracking-widest text-xs mt-1">
                      {RECKLESS_LOVE.endChorusDirective}
                    </div>
                  </div>

                  {/* Preview pane */}
                  <div className="p-5 text-sm leading-8">
                    <div className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-4">
                      {l.hero.livePreview}
                    </div>

                    {/* Verse */}
                    <div className="border-l-2 border-blue-500 pl-3 mb-4">
                      <div className="text-xs font-bold uppercase tracking-wider text-blue-500/80 mb-2">
                        {l.hero.verseLabel}
                      </div>
                      <div className="font-mono">
                        {RECKLESS_LOVE.previewVerse.map((line, i) => (
                          <div key={i}>
                            <div className="text-xs text-amber-500 font-semibold leading-5">{line.chords}</div>
                            <div>{line.lyric}</div>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* Chorus */}
                    <div className="border-l-2 border-violet-500 pl-3">
                      <div className="text-xs font-bold uppercase tracking-wider text-violet-500/80 mb-2">
                        {l.hero.chorusLabel}
                      </div>
                      <div className="font-mono">
                        {RECKLESS_LOVE.previewChorus.map((line, i) => (
                          <div key={i}>
                            <div className="text-xs text-amber-500 font-semibold leading-5">{line.chords}</div>
                            <div>{line.lyric}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Marquee ────────────────────────────────────────────────────── */}
      <div className="overflow-hidden border-y border-border/50 bg-muted/30 py-3.5 select-none" aria-hidden>
        <div className="flex will-change-transform [animation:marquee_35s_linear_infinite]">
          {[...features, ...features].map((feature, i) => {
            const Icon = feature.icon
            return (
              <span key={i} className="mx-8 inline-flex shrink-0 items-center gap-2.5 text-sm font-medium text-muted-foreground">
                <Icon className={cn("h-4 w-4 shrink-0", feature.color)} />
                {feature.title}
              </span>
            )
          })}
        </div>
      </div>

      {/* ── Features Bento ─────────────────────────────────────────────── */}
      <section id="features" className="relative px-6 py-24 sm:py-32">
        <div className="mx-auto max-w-7xl">
          <div className="mb-14">
            <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-primary/30 bg-primary/10 px-4 py-1.5 text-sm font-medium text-primary">
              {l.features.sectionBadge}
            </div>
            <h2 className="text-4xl font-bold tracking-tighter sm:text-5xl md:text-6xl">
              {l.features.sectionTitle}
            </h2>
            <p className="mt-4 max-w-lg text-lg text-muted-foreground">
              {l.features.sectionDescription}
            </p>
          </div>

          {/* Bento grid — lg: 12-col explicit placement */}
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-12 lg:grid-rows-3">
            {/* Song Library — tall, rows 1–2, cols 1–5 */}
            <div className="group relative overflow-hidden rounded-2xl border border-border/60 bg-card p-8 transition-[transform,box-shadow,border-color] duration-300 hover:-translate-y-1 hover:border-primary/30 hover:shadow-xl hover:shadow-primary/5 lg:col-span-5 lg:col-start-1 lg:row-span-2 lg:row-start-1">
              <div aria-hidden className="absolute inset-0 rounded-2xl bg-linear-to-br from-primary/5 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative">
                <div className="mb-5 inline-flex items-center justify-center rounded-xl bg-blue-500/10 p-3">
                  <Music className="h-6 w-6 text-blue-500" />
                </div>
                <h3 className="mb-2 text-xl font-bold tracking-tighter">{features[0].title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{features[0].description}</p>
                <div className="mt-6 space-y-2">
                  {LIBRARY_SONGS.slice(0, 3).map((song) => (
                    <div key={song.title} className="flex items-center gap-3 rounded-lg bg-background/60 px-3 py-2">
                      <span className="font-mono text-xs font-bold text-primary">{song.key}</span>
                      <span className="min-w-0 flex-1 truncate text-sm">{song.title}</span>
                      <span className="shrink-0 text-xs text-muted-foreground">{song.bpm}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* ChordPro Editor — row 1, cols 6–12 */}
            <div className="group relative overflow-hidden rounded-2xl border border-border/60 bg-card p-8 transition-[transform,box-shadow,border-color] duration-300 hover:-translate-y-1 hover:border-primary/30 hover:shadow-xl hover:shadow-primary/5 lg:col-span-7 lg:col-start-6 lg:row-start-1">
              <div aria-hidden className="absolute inset-0 rounded-2xl bg-linear-to-br from-primary/5 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative">
                <div className="mb-5 inline-flex items-center justify-center rounded-xl bg-violet-500/10 p-3">
                  <FileText className="h-6 w-6 text-violet-500" />
                </div>
                <h3 className="mb-2 text-xl font-bold tracking-tighter">{features[1].title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{features[1].description}</p>
                <div className="mt-5 rounded-xl bg-background/60 p-4 font-mono text-xs leading-7">
                  <span className="text-primary/70">{"{key: A}"}</span>
                  <br />
                  <span className="text-violet-400 uppercase tracking-widest text-[10px]">
                    {"{start_of_verse: Verse 1}"}
                  </span>
                  <br />
                  <span className="text-amber-400">[D]</span>
                  {" "}Before I{" "}
                  <span className="text-amber-400">[A]</span>
                  {" "}spoke a word
                  <br />
                  <span className="text-amber-400">[E]</span>
                  {" "}singing over me
                </div>
              </div>
            </div>

            {/* Smart Setlists — row 2, cols 6–9 */}
            <div className="group relative overflow-hidden rounded-2xl border border-border/60 bg-card p-8 transition-[transform,box-shadow,border-color] duration-300 hover:-translate-y-1 hover:border-primary/30 hover:shadow-xl hover:shadow-primary/5 lg:col-span-4 lg:col-start-6 lg:row-start-2">
              <div aria-hidden className="absolute inset-0 rounded-2xl bg-linear-to-br from-primary/5 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative">
                <div className="mb-5 inline-flex items-center justify-center rounded-xl bg-primary/10 p-3">
                  <ListMusic className="h-6 w-6 text-primary" />
                </div>
                <h3 className="mb-2 text-xl font-bold tracking-tighter">{features[2].title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{features[2].description}</p>
                <div className="mt-5 space-y-1.5">
                  {SETLISTS.map((name, i) => (
                    <div key={name} className="flex items-center gap-2 rounded-lg bg-background/60 px-3 py-2">
                      <div className="h-1.5 w-1.5 shrink-0 rounded-full bg-primary/60" />
                      <span className="text-xs font-medium">{name}</span>
                      <span className="ml-auto text-xs text-muted-foreground">{4 - i} songs</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Team Collaboration — row 2, cols 10–12 */}
            <div className="group relative overflow-hidden rounded-2xl border border-border/60 bg-card p-7 transition-[transform,box-shadow,border-color] duration-300 hover:-translate-y-1 hover:border-primary/30 hover:shadow-xl hover:shadow-primary/5 lg:col-span-3 lg:col-start-10 lg:row-start-2">
              <div aria-hidden className="absolute inset-0 rounded-2xl bg-linear-to-br from-primary/5 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative">
                <div className="mb-5 inline-flex items-center justify-center rounded-xl bg-green-500/10 p-3">
                  <Users className="h-6 w-6 text-green-500" />
                </div>
                <h3 className="mb-2 text-lg font-bold tracking-tighter">{features[3].title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{features[3].description}</p>
                <div className="mt-5 flex -space-x-2">
                  {TEAM_MEMBERS.slice(0, 3).map((m) => (
                    <div
                      key={m.name}
                      className={cn(
                        "flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold ring-2 ring-card",
                        m.color
                      )}
                    >
                      {m.initial}
                    </div>
                  ))}
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-muted text-xs font-bold ring-2 ring-card">
                    +2
                  </div>
                </div>
              </div>
            </div>

            {/* Instant Sharing — row 3, cols 1–8 */}
            <div className="group relative overflow-hidden rounded-2xl border border-border/60 bg-card p-8 transition-[transform,box-shadow,border-color] duration-300 hover:-translate-y-1 hover:border-primary/30 hover:shadow-xl hover:shadow-primary/5 lg:col-span-8 lg:col-start-1 lg:row-start-3">
              <div aria-hidden className="absolute inset-0 rounded-2xl bg-linear-to-br from-primary/5 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative">
                <div className="mb-5 inline-flex items-center justify-center rounded-xl bg-pink-500/10 p-3">
                  <Share2 className="h-6 w-6 text-pink-500" />
                </div>
                <h3 className="mb-2 text-xl font-bold tracking-tighter">{features[4].title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{features[4].description}</p>
                <div className="mt-5 flex items-center gap-3 rounded-xl border border-border/60 bg-background/60 px-4 py-3">
                  <span className="min-w-0 flex-1 truncate font-mono text-xs text-muted-foreground">
                    {"capo.app/shared/"}
                    <span className="font-semibold text-primary">{"xK9mR4pQ"}</span>
                  </span>
                  <div className="shrink-0 rounded-lg bg-primary/10 px-3 py-1 text-xs font-semibold text-primary">
                    Copy
                  </div>
                </div>
              </div>
            </div>

            {/* Chord Diagrams — row 3, cols 9–12 */}
            <div className="group relative overflow-hidden rounded-2xl border border-border/60 bg-card p-7 transition-[transform,box-shadow,border-color] duration-300 hover:-translate-y-1 hover:border-primary/30 hover:shadow-xl hover:shadow-primary/5 lg:col-span-4 lg:col-start-9 lg:row-start-3">
              <div aria-hidden className="absolute inset-0 rounded-2xl bg-linear-to-br from-primary/5 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative">
                <div className="mb-5 inline-flex items-center justify-center rounded-xl bg-amber-500/10 p-3">
                  <Guitar className="h-6 w-6 text-amber-500" />
                </div>
                <h3 className="mb-2 text-lg font-bold tracking-tighter">{features[5].title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{features[5].description}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Spotlight: Song Library ─────────────────────────────────────── */}
      <section className="relative px-6 py-24 sm:py-32 overflow-hidden">
        <span aria-hidden className="pointer-events-none select-none absolute right-8 top-10 hidden text-[12rem] font-bold leading-none text-foreground/[0.04] lg:block">01</span>
        <div aria-hidden className="pointer-events-none absolute top-1/2 -translate-y-1/2 -left-20 h-[500px] w-[500px] rounded-full" style={{ background: "radial-gradient(circle, oklch(0.742 0.139 257 / 8%) 0%, transparent 70%)" }} />
        <div className="mx-auto max-w-7xl">
          <div className="grid items-center gap-12 lg:grid-cols-2">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full border border-blue-500/30 bg-blue-500/10 px-4 py-1.5 text-sm font-medium text-blue-500 mb-6">
                <Music className="h-3.5 w-3.5" />
                {l.songLibrarySection.badge}
              </div>
              <h2 className="text-3xl font-bold tracking-tighter sm:text-4xl leading-tight">
                {l.songLibrarySection.headline1}
                <br />
                {l.songLibrarySection.headline2}
              </h2>
              <p className="mt-4 text-muted-foreground leading-relaxed">{l.songLibrarySection.description}</p>
              <ul className="mt-6 space-y-3">
                {songLibraryFeatures.map((item) => (
                  <li key={item} className="flex items-start gap-2.5 text-sm">
                    <div className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-blue-500/15">
                      <Check className="h-3 w-3 text-blue-500" />
                    </div>
                    {item}
                  </li>
                ))}
              </ul>
            </div>

            {/* Song library mock */}
            <div className="rounded-xl border border-border/60 bg-card overflow-hidden shadow-xl">
              <div className="border-b border-border/60 bg-muted/30 px-4 py-3 flex items-center justify-between">
                <span className="text-sm font-medium">{l.songLibrarySection.mockTitle}</span>
                <div className="flex items-center gap-2">
                  <div className="h-2 w-16 rounded-full bg-muted" />
                  <div className="h-6 w-6 rounded bg-primary/20" />
                </div>
              </div>
              <div className="border-b border-border/40 px-4 py-2.5 flex gap-2">
                {[
                  l.songLibrarySection.filterAll,
                  l.songLibrarySection.filterAMajor,
                  l.songLibrarySection.filterGMajor,
                  l.songLibrarySection.filterActive
                ].map((f, i) => (
                  <span key={f} className={`rounded-full px-3 py-1 text-xs font-medium ${i === 0 ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"}`}>
                    {f}
                  </span>
                ))}
              </div>
              <div className="divide-y divide-border/40">
                {LIBRARY_SONGS.map((song) => (
                  <div key={song.title} className="flex items-center gap-3 px-4 py-3 hover:bg-muted/30 transition-colors">
                    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-primary/15">
                      <Music className="h-4 w-4 text-primary" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="text-sm font-medium truncate">{song.title}</div>
                      <div className="text-xs text-muted-foreground truncate">{song.artist}</div>
                    </div>
                    <div className="flex shrink-0 items-center gap-2">
                      <span className="rounded-md bg-muted px-2 py-0.5 text-xs font-mono font-semibold">{song.key}</span>
                      <span className="text-xs text-muted-foreground">{song.bpm} bpm</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Spotlight: Teams ───────────────────────────────────────────── */}
      <section className="relative px-6 py-24 sm:py-32 overflow-hidden">
        <span aria-hidden className="pointer-events-none select-none absolute left-8 top-10 hidden text-[12rem] font-bold leading-none text-foreground/[0.04] lg:block">02</span>
        <div aria-hidden className="pointer-events-none absolute top-1/2 -translate-y-1/2 -right-20 h-[500px] w-[500px] rounded-full" style={{ background: "radial-gradient(circle, oklch(0.862 0.121 152 / 8%) 0%, transparent 70%)" }} />
        <div className="mx-auto max-w-7xl">
          <div className="grid items-center gap-12 lg:grid-cols-2">
            {/* Teams mock */}
            <div className="order-last lg:order-first rounded-xl border border-border/60 bg-card overflow-hidden shadow-xl">
              <div className="border-b border-border/60 bg-muted/30 px-4 py-3 flex items-center justify-between">
                <span className="text-sm font-medium">{l.teamsSection.mockTitle}</span>
                <button className="rounded-md bg-primary/15 px-3 py-1 text-xs font-medium text-primary">
                  {l.teamsSection.invite}
                </button>
              </div>
              <div className="divide-y divide-border/40">
                {TEAM_MEMBERS.map((member) => (
                  <div key={member.name} className="flex items-center gap-3 px-4 py-3">
                    <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold ${member.color}`}>
                      {member.initial}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="text-sm font-medium">{member.name}</div>
                    </div>
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${roleBadgeClass(member.role)}`}>
                      {roleLabel(member.role)}
                    </span>
                  </div>
                ))}
              </div>
              <div className="border-t border-border/40 p-4">
                <div className="text-xs text-muted-foreground mb-2 font-medium">{l.teamsSection.sharedSetlists}</div>
                <div className="flex gap-2">
                  {SETLISTS.map((pl) => (
                    <span key={pl} className="rounded-md border border-border/60 bg-muted/40 px-2.5 py-1 text-xs">{pl}</span>
                  ))}
                </div>
              </div>
            </div>

            <div>
              <div className="inline-flex items-center gap-2 rounded-full border border-green-500/30 bg-green-500/10 px-4 py-1.5 text-sm font-medium text-green-500 mb-6">
                <Users className="h-3.5 w-3.5" />
                {l.teamsSection.badge}
              </div>
              <h2 className="text-3xl font-bold tracking-tighter sm:text-4xl leading-tight">
                {l.teamsSection.headline1}
                <br />
                {l.teamsSection.headline2}
              </h2>
              <p className="mt-4 text-muted-foreground leading-relaxed">{l.teamsSection.description}</p>
              <ul className="mt-6 space-y-3">
                {teamsFeatures.map((item) => (
                  <li key={item} className="flex items-start gap-2.5 text-sm">
                    <div className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-green-500/15">
                      <Check className="h-3 w-3 text-green-500" />
                    </div>
                    {item}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* ── Spotlight: Sharing ─────────────────────────────────────────── */}
      <section className="relative px-6 py-24 sm:py-32 overflow-hidden">
        <span aria-hidden className="pointer-events-none select-none absolute right-8 top-10 hidden text-[12rem] font-bold leading-none text-foreground/[0.04] lg:block">03</span>
        <div aria-hidden className="pointer-events-none absolute top-1/2 -translate-y-1/2 left-1/4 h-[400px] w-[600px] rounded-full" style={{ background: "radial-gradient(ellipse, oklch(0.648 0.195 340 / 8%) 0%, transparent 70%)" }} />
        <div className="mx-auto max-w-7xl">
          <div className="grid items-center gap-12 lg:grid-cols-2">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full border border-pink-500/30 bg-pink-500/10 px-4 py-1.5 text-sm font-medium text-pink-500 mb-6">
                <Share2 className="h-3.5 w-3.5" />
                {l.sharingSection.badge}
              </div>
              <h2 className="text-3xl font-bold tracking-tighter sm:text-4xl leading-tight">
                {l.sharingSection.headline1}
                <br />
                {l.sharingSection.headline2}
              </h2>
              <p className="mt-4 text-muted-foreground leading-relaxed">{l.sharingSection.description}</p>
              <ul className="mt-6 space-y-3">
                {sharingFeatures.map((item) => (
                  <li key={item} className="flex items-start gap-2.5 text-sm">
                    <div className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-pink-500/15">
                      <Check className="h-3 w-3 text-pink-500" />
                    </div>
                    {item}
                  </li>
                ))}
              </ul>
            </div>

            {/* Share mock */}
            <div className="rounded-xl border border-border/60 bg-card overflow-hidden shadow-xl">
              <div className="bg-linear-to-br from-pink-500/10 via-violet-500/5 to-transparent p-6">
                <div className="flex items-center gap-3 mb-4">
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-pink-500/20">
                    <ListMusic className="h-5 w-5 text-pink-500" />
                  </div>
                  <div>
                    <div className="font-semibold">{SETLISTS[0]}</div>
                    <div className="text-xs text-muted-foreground">
                      {SHARE_SONGS.length} {l.sharingSection.mockSubtitle}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2 rounded-lg border border-border/60 bg-background/60 px-3 py-2.5">
                  <div className="min-w-0 flex-1 font-mono text-xs text-muted-foreground truncate">
                    {"capo.app/shared/"}<span className="text-primary">{"xK9mR4pQ"}</span>
                  </div>
                  <button className="shrink-0 rounded-md bg-primary px-2.5 py-1 text-xs font-semibold text-primary-foreground">
                    {l.sharingSection.copy}
                  </button>
                </div>
              </div>
              <div className="divide-y divide-border/40">
                {SHARE_SONGS.map((song) => (
                  <div key={song} className="px-4 py-2.5 text-sm text-muted-foreground hover:text-foreground hover:bg-muted/20 transition-colors">
                    {song}
                  </div>
                ))}
                <div className="px-4 py-2.5 text-xs text-muted-foreground/60">
                  +8 {l.sharingSection.moreSongs}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Feedback ────────────────────────────────────────────────────── */}
      <LandingFeedbackSection
        badge={l.feedback.badge}
        headline={l.feedback.headline}
        description={l.feedback.description}
      />

      {/* ── CTA ────────────────────────────────────────────────────────── */}
      <section className="relative px-4 py-24 sm:py-32">
        <div aria-hidden className="pointer-events-none absolute inset-0 flex items-center justify-center overflow-hidden">
          <div className="h-[600px] w-[600px] rounded-full" style={{ background: "radial-gradient(circle, oklch(0.793 0.132 56 / 12%) 0%, transparent 70%)" }} />
        </div>
        <div className="relative mx-auto max-w-2xl text-center">
          <div className="mb-6 flex justify-center">
            <OptimizedLogo name="capo" alt={t.common.capoLogo} width={72} height={72} className="opacity-90 dark:invert" />
          </div>
          <h2 className="text-4xl font-bold tracking-tighter sm:text-5xl">{l.cta.headline}</h2>
          <p className="mt-4 text-lg text-muted-foreground">{l.cta.description}</p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <Button asChild size="lg" className="h-12 px-10 text-base font-semibold active:scale-[0.98]">
              <Link href="/login">
                {l.cta.button}
                <ArrowRight className="ml-2 h-4 w-4" />
              </Link>
            </Button>
          </div>
          <p className="mt-4 text-sm text-muted-foreground">{l.cta.signInMethod}</p>
        </div>
      </section>

      {/* ── Footer ─────────────────────────────────────────────────────── */}
      <footer className="border-t border-border/40 px-4 py-8">
        <div className="mx-auto max-w-7xl">
          <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
            <div className="flex items-center gap-2.5">
              <OptimizedLogo name="capo" alt={t.common.capoLogo} width={24} height={24} className="dark:invert" />
              <span className="text-sm font-semibold">Capo</span>
              <span className="text-xs text-muted-foreground">— {l.footer.tagline}</span>
            </div>
            <div className="flex items-center gap-4 text-xs text-muted-foreground">
              <Link href="/login" className="hover:text-foreground transition-colors">
                {l.footer.signIn}
              </Link>
              <span>·</span>
              <a
                href="https://github.com/mfuentesg/capo"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 hover:text-foreground transition-colors"
              >
                <Github className="h-3.5 w-3.5" />
                {l.footer.viewOnGitHub}
              </a>
              <span>·</span>
              <span>
                {`© ${new Date().getFullYear()} `}
                <a
                  href="https://mfuentesg.dev"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-foreground transition-colors"
                >
                  mfuentesg
                </a>
              </span>
            </div>
          </div>
          {/* Feature dots — decorative, mirrors feature section palette */}
          <div aria-hidden className="mt-6 flex items-center justify-center gap-2">
            {FEATURE_DOTS.map(({ Icon, color, bg }, i) => (
              <div key={i} className={cn("flex items-center justify-center rounded-full p-1.5", bg)}>
                <Icon className={cn("h-3 w-3", color)} />
              </div>
            ))}
          </div>
        </div>
      </footer>
    </div>
  )
}
