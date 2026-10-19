# Changelog

## 1.1.0

First standalone repository release of `alertxsto.overview` for Omarchy's Quickshell plugin system.

- Live two-row, five-column workspace grid with click-to-focus, middle-click-to-close, and release-to-move interactions.
- Stable native window delegates and event-driven geometry refreshes across workspace moves.
- Preserved pointer grab offsets and clean drag cancellation when dismissed or when the source window closes.
- Correct number-key selection, including `0` for the tenth cell in the current workspace group.
- Monitor-relative geometry with scale and rotation handling.
- Fullscreen-aware preview eligibility and floating-dialog render/hit-test ordering.
- Preview surface unloading on close, while retaining the lightweight shell controller.
- Dependency-free regression tests, native Omarchy installation instructions, and documented compatibility and native-resolution capture limits.
