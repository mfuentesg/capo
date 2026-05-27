import type React from "react"
import { Navbar } from "@/components/layout"
import { DraftIndicator } from "@/components/layout/draft-indicator"
import { PlaylistDraftProvider } from "@/features/playlist-draft"

export default function DashboardLayout({
  children
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <PlaylistDraftProvider>
      {/* Subtle gradient orbs — keeps visual language consistent with the landing page */}
      <div aria-hidden className="pointer-events-none fixed inset-0 -z-10">
        <div
          className="absolute -top-40 right-0 h-[600px] w-[600px] rounded-full"
          style={{
            background:
              "radial-gradient(circle, oklch(0.793 0.132 56 / 12%) 0%, transparent 70%)"
          }}
        />
        <div
          className="absolute bottom-0 -left-20 h-[500px] w-[500px] rounded-full"
          style={{
            background:
              "radial-gradient(circle, oklch(0.749 0.160 298 / 10%) 0%, transparent 70%)"
          }}
        />
      </div>
      <main className="flex-1">
        <Navbar />
        {children}
        <DraftIndicator />
      </main>
    </PlaylistDraftProvider>
  )
}
