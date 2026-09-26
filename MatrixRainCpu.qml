// Matrix rain drawn with ordinary Text items: the CPU renderer.
//
// MatrixRain.qml only loads this when the GPU version cannot run -- a
// software scene graph, or a shader that failed to load. It animates a stack
// of Text items per column and re-lays-out their glyphs as they flicker, which
// costs roughly a quarter of a CPU core at 1920x1080 (measured 2026-09-27)
// against ~2% for MatrixRainGpu.qml. Kept because it works everywhere.

import QtQuick
import qs.Commons

Item {
  id: rain

  property bool playing: true

  // Freezes every stream mid-fall and resumes it exactly where it stopped.
  //
  // Deliberately NOT done by clearing `playing`: that stops the
  // SequentialAnimation outright, and a *stopped* animation restarts at its
  // opening ScriptAction with `scattered` already true, so every column re-enters
  // at `-trail` together and the whole screen visibly rains in from the top --
  // the regression 03a6671 fixed and 8a9a67d kept out of the tree. Pausing does
  // not run that ScriptAction at all, so the scatter state is never disturbed.
  property bool paused: false

  // `columns` and `rows` are independent bindings off width and height, and the
  // Repeater rebuilds every delegate the moment `columns` updates -- which can
  // start a column's animation while `rows` still holds its pre-resize value.
  // On a surface going 0x0 -> full screen that means rows == 1: the first pass
  // ends immediately and each stream re-enters from the top edge, which is what
  // made the whole screen fill from the top. Dropping `ready` on any size
  // change and raising it a turn later lets both bindings settle first.
  property bool ready: false
  onWidthChanged: { ready = false; settle.restart() }
  onHeightChanged: { ready = false; settle.restart() }

  Timer {
    id: settle
    interval: 0
    repeat: false
    onTriggered: rain.ready = rain.width > 0 && rain.height > 0
  }

  // Tunables. `cell` is the glyph grid pitch in pixels; everything else is
  // expressed in grid rows so the look holds across displays.
  readonly property int cell: 16
  readonly property real minSpeed: 2.5    // rows per second
  readonly property real maxSpeed: 8.0
  readonly property int minTrail: 14      // glyphs per falling stream
  readonly property int maxTrail: 48
  readonly property int churnInterval: 90 // ms between glyph mutations
  readonly property real churnFraction: 0.12

  // Halfwidth katakana and digits, the classic alphabet. JetBrainsMono has no
  // katakana, so fontconfig falls back to Noto Sans CJK for those glyphs.
  // Rows stay aligned anyway: line height is fixed and each column centres its
  // own text inside a cell-wide box, so a glyph of odd advance only shifts
  // itself, never the grid.
  readonly property string alphabet: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789"

  readonly property int columns: Math.max(1, Math.ceil(width / cell))
  readonly property int rows: Math.max(1, Math.ceil(height / cell))

  // The screensaver's gradient: near-white head, theme-coloured body, and a
  // tail that falls away toward black.
  readonly property color headColor: rain.blend(Color.accent, 0.78, 1.0)
  readonly property color bodyColor: Color.accent
  readonly property color midColor: rain.blend(Color.accent, 0.38, 0.0)
  readonly property color tailColor: rain.blend(Color.accent, 0.70, 0.0)

  function blend(c, pct, target) {
    return Qt.rgba(c.r + (target - c.r) * pct,
                   c.g + (target - c.g) * pct,
                   c.b + (target - c.b) * pct,
                   1.0)
  }

  function randomGlyph() {
    return alphabet.charAt(Math.floor(Math.random() * alphabet.length))
  }

  function randomGlyphs(n) {
    var s = ""
    for (var i = 0; i < n; i++) s += randomGlyph()
    return s
  }

  // One glyph per line, so a whole run of the stream is a single Text item.
  function stack(glyphs, start, len) {
    if (len <= 0) return ""
    return glyphs.slice(start, start + len).split("").join("\n")
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
  }

  Repeater {
    id: streams
    model: rain.columns

    Item {
      id: column

      required property int index

      x: column.index * rain.cell
      width: rain.cell
      height: rain.height

      property int trail: rain.minTrail
      property real speed: rain.minSpeed
      property int startDelay: 0
      property string glyphs: ""

      // Grid row of the leading glyph. The stream extends upward from here.
      property real headRow: -trail

      // Row the current pass enters from. -trail (just above the top edge) for
      // every pass but the first, which is scattered down the screen so a
      // freshly mapped surface is already full of rain. At minSpeed a stream
      // needs the better part of a minute to fall the height of a 4K display,
      // so without this the effect opens on a near-empty screen with a few
      // streams trickling in from the top -- most visible on a surface that is
      // built cold every time it is shown, such as the lock screen.
      // Initialised to a literal, never a binding: `-trail` here would bind
      // startRow to `trail`, which respawn() reassigns from inside this same
      // animation -- QML then flags a binding loop. The opening ScriptAction
      // sets this, and the animation's from/to/duration, before every pass.
      property real startRow: 0

      // Four flat colour bands instead of a true per-column gradient. A
      // gradient would mean a layer effect, and a layer effect per column is
      // one framebuffer per column — at ~100 columns that costs far more than
      // the banding saves.
      readonly property int tailLen: Math.floor(trail * 0.40)
      readonly property int midLen: Math.floor(trail * 0.30)
      readonly property int bodyLen: Math.max(0, trail - 1 - tailLen - midLen)

      function respawn() {
        trail = rain.minTrail + Math.floor(Math.random() * (rain.maxTrail - rain.minTrail + 1))
        speed = rain.minSpeed + Math.random() * (rain.maxSpeed - rain.minSpeed)
        startDelay = Math.floor(Math.random() * 500)
        glyphs = rain.randomGlyphs(trail)
      }

      // Swap a single glyph in place; the flicker is what sells the effect.
      function mutate() {
        if (trail < 1 || glyphs.length < trail) return
        var i = Math.floor(Math.random() * trail)
        glyphs = glyphs.slice(0, i) + rain.randomGlyph() + glyphs.slice(i + 1)
      }

      // Set once the first pass has been scattered, so later passes enter from
      // the top edge like normal.
      property bool scattered: false

      Component.onCompleted: respawn()

      // Only this wrapper's y is animated, so a frame costs one property
      // update per column rather than one per Text item.
      Item {
        id: stream
        width: rain.cell
        y: (column.headRow - column.trail + 1) * rain.cell

        Glyphs {
          y: 0
          width: rain.cell
          text: rain.stack(column.glyphs, 0, column.tailLen)
          color: rain.tailColor
        }

        Glyphs {
          y: column.tailLen * rain.cell
          width: rain.cell
          text: rain.stack(column.glyphs, column.tailLen, column.midLen)
          color: rain.midColor
        }

        Glyphs {
          y: (column.tailLen + column.midLen) * rain.cell
          width: rain.cell
          text: rain.stack(column.glyphs, column.tailLen + column.midLen, column.bodyLen)
          color: rain.bodyColor
        }

        Glyphs {
          y: (column.trail - 1) * rain.cell
          width: rain.cell
          text: column.glyphs.charAt(column.trail - 1)
          color: rain.headColor
        }
      }

      SequentialAnimation {
        running: rain.playing && rain.ready
        // Only ever asserted while the animation is actually running -- Qt logs
        // "setPaused() cannot be used when animation isn't running" for a bare
        // `paused:` binding, once per column here.
        paused: running && rain.paused
        loops: Animation.Infinite

        ScriptAction {
          script: {
            if (column.scattered) {
              column.startRow = -column.trail
            } else {
              column.scattered = true
              column.startRow = -column.trail + Math.random() * (rain.rows + column.trail)
            }
            // `from`, `to` and `duration` are ASSIGNED here, never bound on the
            // NumberAnimation. Each of them reads a column property that this
            // same animation reassigns -- startRow just above, trail and speed
            // in the closing respawn() -- and re-evaluating a binding on a
            // running animation re-enters it, so QML flags whichever one it
            // evaluates first as a binding loop. Fixing only `from` just moves
            // the warning to `duration`; all three have to be assignments.
            headAnim.from = column.startRow
            headAnim.to = rain.rows + column.trail
            headAnim.duration = Math.max(1, Math.round((rain.rows + column.trail - column.startRow) / column.speed * 1000))
          }
        }
        PauseAnimation {
          duration: column.startDelay
        }
        NumberAnimation {
          id: headAnim
          target: column
          property: "headRow"
        }
        // Re-randomise between passes so streams drift out of phase instead of
        // settling into a visible repeating pattern.
        ScriptAction {
          script: column.respawn()
        }
      }
    }
  }

  // One timer churning a slice of the columns each tick, rather than a timer
  // per column.
  Timer {
    running: rain.playing && rain.visible && !rain.paused
    interval: rain.churnInterval
    repeat: true
    onTriggered: {
      var n = Math.max(1, Math.round(rain.columns * rain.churnFraction))
      for (var i = 0; i < n; i++) {
        var c = streams.itemAt(Math.floor(Math.random() * rain.columns))
        if (c) c.mutate()
      }
    }
  }

  // Shared look for every glyph run. Fixed line height is what keeps the rows
  // on the grid when fontconfig substitutes a CJK face for the katakana.
  component Glyphs: Text {
    font.family: Style.fontFamily
    font.pixelSize: Math.round(rain.cell * 0.92)
    lineHeight: rain.cell
    lineHeightMode: Text.FixedHeight
    horizontalAlignment: Text.AlignHCenter
    textFormat: Text.PlainText
  }
}
