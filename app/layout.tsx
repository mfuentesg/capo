import type React from "react"
import type { Metadata } from "next"
import localFont from "next/font/local"
import { Inter, DM_Sans, Roboto, Poppins, Nunito, Outfit, Plus_Jakarta_Sans } from "next/font/google"
import { cookies } from "next/headers"
import { Analytics } from "@vercel/analytics/react"
import { SpeedInsights } from "@vercel/speed-insights/next"
import { ThemeProvider } from "@/components/theme-provider"
import { Toaster } from "@/components/ui/sonner"
import NextTopLoader from "nextjs-toploader"
import { isValidPalette, DEFAULT_PALETTE } from "@/lib/palette"
import { isValidUIFont, DEFAULT_UI_FONT } from "@/lib/font"

import "./globals.css"

const geistSans = localFont({
  src: "./fonts/GeistVF.woff2",
  variable: "--font-geist-sans",
  weight: "100 900",
  display: "swap"
})

const geistMono = localFont({
  src: "./fonts/GeistMonoVF.woff2",
  variable: "--font-geist-mono",
  weight: "100 900",
  display: "swap"
})

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap"
})

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-dm-sans",
  display: "swap"
})

const roboto = Roboto({
  subsets: ["latin"],
  weight: ["300", "400", "500", "700"],
  variable: "--font-roboto",
  display: "swap"
})

const poppins = Poppins({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
  variable: "--font-poppins",
  display: "swap"
})

const nunito = Nunito({
  subsets: ["latin"],
  variable: "--font-nunito",
  display: "swap"
})

const outfit = Outfit({
  subsets: ["latin"],
  variable: "--font-outfit",
  display: "swap"
})

const plusJakartaSans = Plus_Jakarta_Sans({
  subsets: ["latin"],
  variable: "--font-plus-jakarta-sans",
  display: "swap"
})

const APP_DESCRIPTION =
  "Your personal song library for practice and performance. Organize songs with chords and lyrics, build setlists, and collaborate with your band."

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? "https://capo.mfuentesg.dev"),
  title: {
    template: "%s · Capo",
    default: "Capo — Song library for musicians"
  },
  description: APP_DESCRIPTION,
  openGraph: {
    type: "website",
    siteName: "Capo",
    title: "Capo — Song library for musicians",
    description: APP_DESCRIPTION,
    images: [{ url: "/img/optimized/capo.webp", width: 1200, height: 630, alt: "Capo" }]
  },
  twitter: {
    card: "summary_large_image",
    title: "Capo — Song library for musicians",
    description: APP_DESCRIPTION,
    images: ["/img/optimized/capo.webp"]
  },
  manifest: "/site.webmanifest",
  icons: {
    icon: [
      {
        url: "/favicon-16x16.png",
        sizes: "16x16",
        type: "image/png"
      },
      {
        url: "/favicon-32x32.png",
        sizes: "32x32",
        type: "image/png"
      },
      {
        url: "/favicon.ico"
      }
    ],
    apple: "/apple-touch-icon.png",
    other: {
      rel: "mask-icon",
      url: "/safari-pinned-tab.svg",
      color: "#000000"
    }
  }
}

const VALID_THEMES = ["light", "dark", "system"] as const
type Theme = (typeof VALID_THEMES)[number]

export default async function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode
}>) {
  const cookieStore = await cookies()

  const themeCookie = cookieStore.get("NEXT_THEME")
  const defaultTheme: Theme =
    themeCookie && (VALID_THEMES as readonly string[]).includes(themeCookie.value)
      ? (themeCookie.value as Theme)
      : "system"

  const paletteCookie = cookieStore.get("NEXT_PALETTE")
  const defaultPalette = isValidPalette(paletteCookie?.value) ? paletteCookie.value : DEFAULT_PALETTE

  const fontCookie = cookieStore.get("NEXT_UI_FONT")
  const defaultFont = isValidUIFont(fontCookie?.value) ? fontCookie.value : DEFAULT_UI_FONT

  const fontClasses = [
    geistSans.variable,
    geistMono.variable,
    inter.variable,
    dmSans.variable,
    roboto.variable,
    poppins.variable,
    nunito.variable,
    outfit.variable,
    plusJakartaSans.variable
  ].join(" ")

  return (
    <html
      lang="en"
      suppressHydrationWarning
      data-palette={defaultPalette}
      data-font={defaultFont}
      className={fontClasses}
    >
      <head />
      <body className="antialiased">
        <NextTopLoader color="#f97316" showSpinner={false} />
        <ThemeProvider
          attribute="class"
          defaultTheme={defaultTheme}
          enableSystem
          disableTransitionOnChange
        >
          {children}
          <Toaster />
        </ThemeProvider>
        {process.env.NODE_ENV === "production" && <Analytics />}
        {process.env.NODE_ENV === "production" && <SpeedInsights />}
      </body>
    </html>
  )
}
