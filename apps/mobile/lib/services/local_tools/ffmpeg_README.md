# Phase B — on-device video engine (ffmpeg)

## Package choice

`ffmpeg_kit_flutter_new_video: ^2.5.0`
([pub.dev](https://pub.dev/packages/ffmpeg_kit_flutter_new_video))

- The original `ffmpeg_kit_flutter` (arthenica) was **retired in Jan 2025** and
  its binaries deleted in Apr 2025 — it must not be used.
- `ffmpeg_kit_flutter_new_video` is the **maintained community fork**
  (FFmpeg 8.1.2, Android V2 embedding, Flutter 3+).
- **Variant `video`** (not `full-gpl`): includes libass (subtitle burn-in),
  fontconfig/freetype, dav1d, vpx, webp — and **no GPL components**.

## Licensing (important)

- The `video` variant is licensed **LGPL 3.0** with **no GPL codecs**
  (no x264/x265/xvidcore/vid.stab). Safe for closed-source store distribution.
- Do **not** switch to a `-gpl` variant: x264/x265 are GPL v3, which would put
  copyleft obligations on the whole app.
- H.264 output (required by Reels/Shorts/TikTok) is produced via the
  **Android hardware encoder `h264_mediacodec`** (system API, not GPL) with an
  automatic software fallback (`mpeg4`) if MediaCodec is unavailable.
- Audio is AAC via ffmpeg's **native** `aac` encoder (LGPL-safe).
- LGPL compliance note: the ffmpeg shared libraries ship unmodified inside
  the APK; keep the "About / open-source notices" screen listing FFmpeg +
  LGPL if/when such a screen exists.

## What it powers

`lib/services/local_tools/ffmpeg_service.dart` — trim, concat, compress
(720p/1080p), audio extract, thumbnails, GIF previews, speed change,
aspect fit (9:16 / 1:1 / 16:9), rotate, background-music ducking, voiceover
mixing, caption burn-in, photo-slideshow assembly.

`lib/services/local_tools/template_video_renderer.dart` — renders a Phase A
`TemplateProject` (slots + timed captions + assets) into a finished 9:16 MP4:
slideshow → voiceover/music mix → burned captions.

## Platform notes

- `minSdk = 24` (Android 7.0+) is required by the plugin (set in
  `android/app/build.gradle.kts`).
- One render at a time: the service serializes executions; cancelling stops
  the in-flight session. Failures throw typed `FfmpegException` — the UI
  shows an honest error, never a fake result.
- Long renders are CPU-heavy: defaults target 720p for speed; 1080p is
  opt-in per action.

## APK size impact (estimate)

Native ffmpeg libs ship per ABI (~15–25 MB for the `video` variant on
`arm64-v8a`). A fat release APK (`flutter build apk --release`) therefore
grows roughly **+25–40 MB**; most of the delta is the arm64 .so files.

Mitigations (not enabled by default):
- `flutter build apk --release --split-per-abi` → one APK per ABI; the
  arm64 APK (what ~all modern phones, incl. the OPPO A5 Pro, install) carries
  only its own .so files.
- An app bundle (`.aab`) for Play Store lets Google serve per-device splits
  automatically.

Measure the real delta in CI from the APK artifact sizes.
