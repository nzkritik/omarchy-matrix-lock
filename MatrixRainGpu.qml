// Matrix rain drawn by one fragment shader: the GPU renderer.
//
// The CPU version (MatrixRainCpu.qml) animates a stack of Text items per
// column and re-lays-out their glyphs on every flicker; at 1920x1080 that is
// ~120 columns and roughly a quarter of a CPU core. Here every column is a
// closed-form function of time evaluated on the GPU (rain.frag), so the only
// per-frame CPU work is advancing `time`: ~2% of a core (measured 2026-09-27).
//
// The glyphs come from an atlas: the alphabet laid out once as ordinary Text,
// so fontconfig's fallback still supplies the katakana, and captured into a
// texture the shader samples.
//
// rain.frag.qsb is compiled from rain.frag by tools/build-shaders.sh.

import QtQuick
import QtQuick.Window
import qs.Commons

Item {
  id: rain

  property bool playing: true
  // Holds the rain still without resetting it; clearing `playing` does the same.
  property bool paused: false

  // Tunables, as before. `cell` is the grid pitch in logical pixels; the rest
  // is in grid rows so the look holds across displays.
  readonly property int cell: 16
  readonly property real minSpeed: 2.5    // rows per second
  readonly property real maxSpeed: 8.0
  readonly property int minTrail: 14      // glyphs per falling stream
  readonly property int maxTrail: 48
  // How often each glyph flickers to another, per second. Matches the old
  // "12% of columns every 90 ms" rate spread over an average trail.
  readonly property real churn: 0.045

  readonly property string alphabet: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789"

  // Near-white head, theme-coloured body, and a tail falling away to black.
  readonly property color headColor: blend(Color.accent, 0.78, 1.0)
  readonly property color bodyColor: Color.accent
  readonly property color midColor: blend(Color.accent, 0.38, 0.0)
  readonly property color tailColor: blend(Color.accent, 0.70, 0.0)

  function blend(c, pct, target) {
    return Qt.rgba(c.r + (target - c.r) * pct, c.g + (target - c.g) * pct, c.b + (target - c.b) * pct, 1.0)
  }

  // Seconds of rain so far. Wrapped well before float precision matters in the
  // shader; the wrap is a single-frame reshuffle once every few hours.
  property real time: 0
  FrameAnimation {
    running: rain.playing && rain.visible && rain.width > 0
    paused: running && rain.paused
    // The fastest stream moves ~130 px/s, which 30 updates a second draw just
    // as smoothly; skipping the frames in between lets the scene graph idle.
    property real pending: 0
    onTriggered: {
      pending += frameTime
      if (pending < 1 / 30) return
      rain.time = (rain.time + pending) % 10000
      pending = 0
    }
  }

  // The alphabet, one glyph per cell-sized box. Never shown directly.
  Row {
    id: atlasRow
    visible: false
    Repeater {
      model: rain.alphabet.length
      Text {
        required property int index
        width: rain.cell
        height: rain.cell
        text: rain.alphabet.charAt(index)
        color: "white"
        font.family: Style.fontFamily
        font.pixelSize: Math.round(rain.cell * 0.92)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
      }
    }
  }

  ShaderEffectSource {
    id: atlas
    sourceItem: atlasRow
    hideSource: true
    // Rendered once. Rendering it at device resolution keeps the glyphs sharp
    // on a scaled display.
    live: false
    textureSize: Qt.size(atlasRow.width * Screen.devicePixelRatio, atlasRow.height * Screen.devicePixelRatio)
    smooth: true
    visible: false
  }

  // Raised if the shader cannot be loaded or compiled; MatrixRain.qml then
  // swaps in the CPU renderer.
  readonly property bool failed: shader.status === ShaderEffect.Error

  ShaderEffect {
    id: shader
    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("rain.frag.qsb")

    property size size: Qt.size(width, height)
    property real cell: rain.cell
    property real time: rain.time
    property real glyphCount: rain.alphabet.length
    property real minSpeed: rain.minSpeed
    property real maxSpeed: rain.maxSpeed
    property real minTrail: rain.minTrail
    property real maxTrail: rain.maxTrail
    property real churn: rain.churn
    property color background: Color.background
    property color headColor: rain.headColor
    property color bodyColor: rain.bodyColor
    property color midColor: rain.midColor
    property color tailColor: rain.tailColor
    property variant atlas: atlas
  }
}
