// Live "digital rain", drawn natively in QML.
//
// This is not the packaged screensaver running behind your windows: `omarchy
// screensaver` is ttfx inside a terminal, and a terminal is an xdg-toplevel,
// which Hyprland can never stack below the background layer. So the effect is
// reimplemented here instead. It mirrors the head/body/tail colour
// relationship that ~/.local/bin/omarchy-screensaver derives from the theme,
// but reads Color.accent from the shell rather than parsing colors.toml, so a
// theme switch recolours the rain with no extra wiring.
//
// There are two renderers behind one interface:
//   MatrixRainGpu.qml  one fragment shader; ~2% of a core at 1920x1080
//   MatrixRainCpu.qml  Text items per column; ~25% of a core, works anywhere
// The GPU one is used whenever the scene graph is hardware accelerated. The
// CPU one takes over on a software scene graph, or if the shader reports an
// error, so the rain degrades to slower rather than to nothing.

import QtQuick

Item {
  id: rain

  property bool playing: true
  // Freezes the rain mid-fall and resumes it where it stopped.
  property bool paused: false

  // Which renderer is running: "gpu", "cpu", or "" before the window exists.
  readonly property string renderer: loader.status === Loader.Ready ? (useGpu ? "gpu" : "cpu") : ""

  property bool gpuFailed: false
  // GraphicsInfo is only known once the item is in a window with a scene
  // graph, so nothing loads until then rather than guessing.
  readonly property bool graphicsKnown: GraphicsInfo.api !== GraphicsInfo.Unknown
  readonly property bool useGpu: !gpuFailed && GraphicsInfo.api !== GraphicsInfo.Software

  Loader {
    id: loader
    anchors.fill: parent
    active: rain.graphicsKnown
    source: rain.useGpu ? "MatrixRainGpu.qml" : "MatrixRainCpu.qml"
  }

  Binding {
    target: loader.item
    property: "playing"
    value: rain.playing
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: loader.item
    property: "paused"
    value: rain.paused
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }

  // Declarative on purpose: a missing or broken shader can report its error
  // while the GPU component is still being created, before the Loader has
  // published the item, so a signal handler would never hear about it. This
  // flips whether the failure lands before or after the item appears.
  readonly property bool gpuBroken: useGpu && loader.item !== null && loader.item.failed === true
  onGpuBrokenChanged: {
    if (!gpuBroken || gpuFailed) return
    console.warn("matrix rain: shader unavailable, falling back to the CPU renderer")
    gpuFailed = true
  }
}
