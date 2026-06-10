import type React from "react"
import type { Metadata } from "next"
import localFont from "next/font/local"
import {
  Inter,
  DM_Sans,
  Roboto,
  Poppins,
  Nunito,
  Outfit,
  Plus_Jakarta_Sans,
  Montserrat,
  Lato,
  Space_Grotesk,
  Manrope
} from "next/font/google"
import { cookies } from "next/headers"
import { Analytics } from "@vercel/analytics/react"
import { SpeedInsights } from "@vercel/speed-insights/next"
import { ThemeProvider } from "@/components/theme-provider"
import { Toaster } from "@/components/ui/sonner"
import NextTopLoader from "nextjs-toploader"
import { resolveTheme, resolvePalette, resolveFont } from "@/lib/display-preferences"
import { getInitialAppContextData } from "@/features/app-context/server"

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

const montserrat = Montserrat({
  subsets: ["latin"],
  variable: "--font-montserrat",
  display: "swap"
})

const lato = Lato({
  subsets: ["latin"],
  weight: ["300", "400", "700"],
  variable: "--font-lato",
  display: "swap"
})

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-space-grotesk",
  display: "swap"
})

const manrope = Manrope({
  subsets: ["latin"],
  variable: "--font-manrope",
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

export default async function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode
}>) {
  const cookieStore = await cookies()

  // DB preferences take priority over cookies (see lib/display-preferences.ts).
  // getInitialAppContextData is wrapped in React cache(), so the nested
  // app/(app)/layout.tsx call reuses this fetch within the same request.
  const { preferences } = await getInitialAppContextData()

  const defaultTheme = resolveTheme(preferences?.theme, cookieStore.get("NEXT_THEME")?.value)
  const defaultPalette = resolvePalette(preferences?.palette, cookieStore.get("NEXT_PALETTE")?.value)
  const defaultFont = resolveFont(preferences?.uiFont, cookieStore.get("NEXT_UI_FONT")?.value)

  const fontClasses = [
    geistSans.variable,
    geistMono.variable,
    inter.variable,
    dmSans.variable,
    roboto.variable,
    poppins.variable,
    nunito.variable,
    outfit.variable,
    plusJakartaSans.variable,
    montserrat.variable,
    lato.variable,
    spaceGrotesk.variable,
    manrope.variable
  ].join(" ")

  return (
    <html
      lang="en"
      suppressHydrationWarning
      data-palette={defaultPalette}
      data-font={defaultFont}
      className={defaultTheme === "dark" ? `${fontClasses} dark` : fontClasses}
    >
      <head>
        {/*
         * Blocking script — runs synchronously in <head> before any paint.
         *
         * data-palette and data-font are resolved DB-first on the server and
         * rendered directly on <html>, so no JS is needed for those.
         *
         * The dark class is also SSR'd when the resolved theme is "dark", but
         * next-themes stores the per-device choice in localStorage, which the
         * server cannot read. This script reconciles localStorage (and
         * prefers-color-scheme for "system") against the SSR markup before
         * first paint, using the same precedence next-themes applies after
         * mount: localStorage first, then the SSR-resolved default.
         */}
        <script
          suppressHydrationWarning
          dangerouslySetInnerHTML={{
            __html: `(function(){try{
var d=document.documentElement,t=null;
try{t=localStorage.getItem("theme")}catch(e){}
if(!t)t=${JSON.stringify(defaultTheme)};
d.classList.toggle("dark",!!(t==="dark"||(t!=="light"&&window.matchMedia&&window.matchMedia("(prefers-color-scheme: dark)").matches)));
}catch(e){}})();`
          }}
        />
      </head>
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
