# Offline chat

The Android app runs Qwen2.5-1.5B-Instruct Q4_K_M locally using llama.cpp through
`llamadart` 0.16.4. No backend, API key, or sign-in is needed for offline chat.

## Using it

1. Select **Open offline chat** on cloud setup or sign-in, or select **AI → Offline**
   after signing in. Offline chat is also accessible while account loading is
   waiting for the network or has failed.
2. Select **Download model · 1.12 GB** while connected, preferably over Wi-Fi.
   Keep the app open. Downloads can be paused and resumed, including after restart.
3. After verification, disable internet and ask a question. The first message
   loads the model into memory; subsequent messages reuse it.
4. Use **Stop response** to stop generation, **New offline chat** to clear the
   conversation, or the menu to remove the model. Messages are held in memory
   only and cleared when leaving the offline screen. The model persists across
   restarts in app-private application-support storage.

**AI → Cloud** retains Gemini, administrator-scoped saved conversations, live
attendance, visual observations and PDF retrieval. Switching modes starts a
separate conversation; offline messages are never automatically sent to cloud.
Offline mode has no access to cloud attendance or PDFs and cannot answer from
those sources. Camera scanning and authentication still require their existing
cloud services.

## Model and runtime

- Model repository: <https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF>
- Immutable revision: `91cad51170dc346986eccefdc2dd33a9da36ead9`
- File: `qwen2.5-1.5b-instruct-q4_k_m.gguf`
- Size: 1,117,320,736 bytes (1.12 GB / 1.04 GiB)
- SHA-256: `6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e`
- License: Apache 2.0; full upstream license is included in
  `assets/licenses/qwen2.5-LICENSE.txt` and registered with Flutter's license page.
- Runtime license: MIT; Flutter includes the package license.
- CPU inference, 2,048-token context, at most 384 new tokens per response. The
  runtime trims older turns to fit the context. User input is limited to 1,000
  characters. No GPU driver support is required.

Downloads stream to `.part`, resume with HTTP Range, verify SHA-256 off the UI
isolate and rename only after verification. An interrupted download never becomes
an installed model. A server that ignores Range restarts the download safely.
The installed model is checked again before native loading. Downloads and active
generation pause/stop when the app is backgrounded. Leaving during a native load
waits for it to finish before disposing resources.

Recommend a 64-bit phone with at least 4 GB RAM and 2 GB free storage. This is a
starting recommendation, not a measured minimum. Model speed, peak RAM, thermal
behavior and answer quality must be assessed on client devices.

## Build and validation

Use Flutter 3.47.5, matching CI. The package build hook downloads and bundles the
native runtime at build time; only model weights download at app setup. The
`llamadart_native_runtimes` setting limits packaging to llama.cpp. Android runtime
artifacts are provided for ARM64 devices and x86-64 emulators, not 32-bit ARM.

```powershell
flutter pub get
flutter analyze
flutter test
.\tools\run_edge_ai.ps1 -Action build-apk -Portable
```

The packaged model is deliberately not embedded in the APK. First-ever offline
use therefore requires completing the download beforehand. iOS/macOS packaging
has not been qualified; it additionally needs the runtime's supported deployment
targets and Apple packaging configuration.

Before delivering to the client, test on a physical Android device:

1. Download, interrupt halfway, restart, and resume to completion.
2. Enable airplane mode, force-stop and reopen the app, open offline chat without
   signing in, and send several follow-up questions.
3. Stop a reply, send another, rotate/background the app, and switch modes.
4. Check that offline mode does not claim to read live attendance or PDFs.
5. Measure load time, tokens/second, memory and battery/heat on target devices.
6. Remove the model and verify that setup is offered again.
