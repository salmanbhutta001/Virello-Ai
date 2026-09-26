# Aperçu font — licensed drop-in

Virello's Latin UI typeface is **Aperçu** (Colophon Foundry, commercial).
Until licensed files are added here, the app renders **Inter** (already bundled)
— no visual breakage, no build errors.

## What to buy
- Aperçu is NOT free. Buy from Colophon Foundry / MyFonts (per-style from ~$60 USD).
- For embedding inside the mobile app you need the **App** license option.
- Do NOT use "free download" sites — those copies are piracy and have no
  commercial license.

## Drop-in steps (2 minutes once you have the license)
1. Copy the licensed files into this folder with EXACTLY these names:
   - `Apercu-Light.otf`    (weight 300)
   - `Apercu-Regular.otf`  (weight 400)
   - `Apercu-Medium.otf`   (weight 500)
   - `Apercu-Bold.otf`     (weight 700)
   (Add ExtraBold/Black the same way if you bought them.)
2. In `pubspec.yaml`, uncomment the `Apercu` family block under `flutter > fonts`.
3. In `lib/core/theme.dart`, change `fontFamily: 'Inter'` → `fontFamily: 'Apercu'`.
4. `flutter pub get && flutter build bundle` — done.

## Script coverage note
Aperçu ships Latin only — Urdu/Arabic glyphs keep falling back to system fonts,
exactly as they do with Inter today. Nothing to change there.
