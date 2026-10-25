# Fonts

The app bundles Geist (Regular, Medium, SemiBold, Bold) and Geist Mono (Regular, Bold) as static TTFs in
`CapoDesign/Resources/Fonts`, converted from the web's `GeistVF.woff2` / `GeistMonoVF.woff2`.
License: SIL OFL 1.1, copyright Vercel (`Resources/Fonts/OFL.txt`). `CapoFonts.register()` registers them
once at startup; `CapoFont` exposes Dynamic-Type-aware helpers. Spanish glyphs (ñ á é í ó ú ü ¿ ¡) verified
present in every file's cmap.

## UI fonts (web `lib/font.ts`, W2-B)

The eleven alternative UI fonts are bundled from the google/fonts repository (all SIL OFL 1.1; each licence
is `OFL-<Family>.txt` next to the fonts). To keep the app small they are subset to Latin + Latin-1 +
Latin Extended-A + common punctuation (covers EN/ES) with fontTools. Variable families (Inter, DM Sans,
Roboto, Nunito, Outfit, Plus Jakarta Sans, Montserrat, Space Grotesk, Manrope) ship one `<Family>-Variable.ttf`
with the `wght` axis (Inter and DM Sans pinned to opsz 14, Roboto to wdth 100, like the web's next/font
load); the weight is applied through `kCTFontVariationAttribute`. Poppins (Regular/Medium/SemiBold/Bold) and
Lato (Regular/Bold, the same 400/700 the web loads) are static. Geist stays the default; Geist Mono is
always used for lyrics and chords.

| Font | Licence | Copyright holder |
|---|---|---|
| Geist, Geist Mono | OFL 1.1 | Vercel / basement.studio |
| Inter | OFL 1.1 | The Inter Project Authors |
| DM Sans | OFL 1.1 | The DM Sans Project Authors |
| Roboto | OFL 1.1 | The Roboto Project Authors |
| Nunito | OFL 1.1 | The Nunito Project Authors |
| Outfit | OFL 1.1 | The Outfit Project Authors |
| Plus Jakarta Sans | OFL 1.1 | The Plus Jakarta Sans Project Authors |
| Montserrat | OFL 1.1 | The Montserrat.Git Project Authors |
| Space Grotesk | OFL 1.1 | The Space Grotesk Project Authors |
| Manrope | OFL 1.1 | The Manrope Project Authors |
| Poppins | OFL 1.1 | The Poppins Project Authors |
| Lato | OFL 1.1 | tyPoland Lukasz Dziedzic |
