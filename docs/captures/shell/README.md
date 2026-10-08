# WinUI shell captures

D00 T02 §3, 2026-10-08. Both captures show the same implementation, with native theme resources and the empty-grimoire surface.

- [100 percent, light](winui-100.png): 96 DPI on a disposable GitHub-hosted Windows VM, CI [37819517650](https://github.com/rizonesoft/Spellbook/actions/runs/37819517650), candidate `23b873a452c2ecae480582997f0ec13cd6cf8067`. The app runs from a folder outside the checkout with zero registered Windows App Runtime packages. Native minimum-size readback: 480 by 320 pixels.
- [150 percent, dark](winui-150.png): 144 DPI on the local Windows desktop. Native minimum-size readback: 720 by 480 pixels, equivalent to 480 by 320 DIPs. The initial outer window is 1440 by 960 pixels, equivalent to 960 by 640 DIPs.

Evidence: `build/winui-evidence/hosted-proof-37819517650/window.json`, its `smoke.log`, `final-window-150.json`, and `probe-r2-equality.json`. The capture helper uses DPI-aware `PrintWindow`; both windows were closed after capture. The separate hosted script is guarded against local and self-hosted execution.
