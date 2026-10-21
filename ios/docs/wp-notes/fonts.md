# Fonts

The app bundles Geist (Regular, Medium, SemiBold, Bold) and Geist Mono (Regular, Bold) as static TTFs in
`CapoDesign/Resources/Fonts`, converted from the web's `GeistVF.woff2` / `GeistMonoVF.woff2`.
License: SIL OFL 1.1, copyright Vercel (`Resources/Fonts/OFL.txt`). `CapoFonts.register()` registers them
once at startup; `CapoFont` exposes Dynamic-Type-aware helpers. Spanish glyphs (ñ á é í ó ú ü ¿ ¡) verified
present in every file's cmap.
