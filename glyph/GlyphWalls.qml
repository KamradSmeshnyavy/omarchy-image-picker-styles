import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Стиль picker'а glyph — переключатель обоев из glyph-rice (wall/Walls.qml, GPL-3.0), подключённый к picker'у Omarchy.
// Не сетка картинок — экран целиком и есть превью: выбранная собирается точками волной от ленты внизу. Лента — круги-
// миниатюры точками, выбранная по центру в кольце (оно горит долей пути по коллекции), под текущими — красная точка.
// Обои: ←→ / h l / колесо — листать, tab — вид (точки / серое фото / цвет), ↑↓ — шаг точек, shift ↑↓ — яркость,
// [ ] — все / статичные / живые, ↵ или клик по выбранной — поставить, esc — как было. Вид, шаг и яркость пишутся
// в ~/.config/omarchy/wallpaper-look.json — по нему фон (kamradsmeshnyavy.background) рисует обои так же.
// Темы (picker с фильтром): вид всегда «цвет», буквы — фильтр, ←→ / tab — листать.
Item {
  id: root

  required property var picker
  readonly property bool wallMode: !picker.filterable
  readonly property var looks: ["dots", "mono", "color"]

  // Номера подходящих под фильтр картинок в порядке ленты.
  readonly property var list: {
    var out = []
    var arr = picker.imageArray
    for (var i = 0; i < arr.length; i++) if (picker.itemMatches(i)) out.push(i)
    return out
  }
  readonly property int sel: Math.max(0, list.indexOf(picker.selectedIndex))
  readonly property var cur: list.length ? picker.imageArray[list[sel]] : null
  readonly property int liveIndex: picker.selectedImageIndex()

  property int look: 0
  property int pitch: 10
  property int bright: 85
  readonly property int shownLook: wallMode ? look : 2
  readonly property real shownBright: wallMode ? bright / 100 : 1

  function go(d) {
    if (!list.length) return
    picker.select(list[Math.max(0, Math.min(list.length - 1, sel + d))])
  }
  function isLive(p) { return /\.(mp4|m4v|mov|webm|mkv|avi|gif)$/i.test(String(p || "")) }
  function previewPath(it) {
    if (!it) return ""
    // живые и GIF — превью по кадру-миниатюре, видео Image не декодирует
    return isLive(it.filePath) ? (it.thumbnailPath || "") : it.filePath
  }
  function name(it) { return it ? picker.labelForPath(it.filePath) : (picker.filterText ? "no matches" : "") }

  // вид, шаг точек и яркость — общие с фоном
  FileView {
    id: lookFile
    path: Quickshell.env("HOME") + "/.config/omarchy/wallpaper-look.json"
    printErrors: false
    blockLoading: true
    onLoaded: {
      try {
        var v = JSON.parse(text())
        var i = root.looks.indexOf(String(v.look))
        if (i >= 0) root.look = i
        if (isFinite(Number(v.pitch))) root.pitch = Math.max(4, Math.min(32, Number(v.pitch)))
        if (isFinite(Number(v.bright))) root.bright = Math.max(10, Math.min(100, Number(v.bright)))
      } catch (e) {}
    }
  }
  function apply() {
    if (wallMode)
      lookFile.setText(JSON.stringify({ look: looks[look], pitch: pitch, bright: bright }, null, 2) + "\n")
    picker.applySelected()
  }

  // превью — когда перестали листать: каждая картинка — декод под экран, на быстрой прокрутке это рывки. Лента едет сразу
  property string view: ""
  readonly property string want: previewPath(cur)
  onWantChanged: settle.restart()
  Timer { id: settle; interval: 160; onTriggered: root.view = root.want }

  // лента едет одной анимацией: pos догоняет sel, круги считают место от дробного расстояния до него
  property real pos: sel
  Behavior on pos { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
  // круг на расстоянии d: выбранный 190, соседи 128, дальше на 12 меньше, не меньше 64; между целыми — по прямой
  function size(d) { d = Math.abs(d); return d < 1 ? 190 - 62 * d : Math.max(64, 128 - (d - 1) * 12) }
  readonly property var at: {
    var a = [0]
    for (var k = 1; k <= 10; k++) a.push(a[k - 1] + (size(k - 1) + size(k)) / 2 + (k === 1 ? 44 : 22))
    return a
  }
  function off(d) {
    var a = Math.min(Math.abs(d), 9), k = Math.floor(a), x = at[k] + (at[k + 1] - at[k]) * (a - k)
    return d < 0 ? -x : x
  }

  property real t: 0
  Behavior on t { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
  Component.onCompleted: { view = want; t = 1 }

  function focusIn() { stage.forceActiveFocus() }

  // холст макета 1920×1080, растянут на экран (как Stage у glyph-rice)
  readonly property real s: Math.min(width / 1920, height / 1080)
  Item {
    id: stage
    width: root.width / root.s
    height: root.height / root.s
    scale: root.s
    transformOrigin: Item.TopLeft
    opacity: root.t
    focus: true
    readonly property real ringY: height - 230

    Keys.onPressed: function(e) {
      var up = e.key === Qt.Key_Up, down = e.key === Qt.Key_Down
      var plain = !root.picker.filterable || (e.modifiers & Qt.ControlModifier)
      if (e.key === Qt.Key_Escape) {
        if (root.picker.filterText) root.picker.updateFilter("")
        else root.picker.cancel()
      } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply()
      else if (e.key === Qt.Key_Left || (plain && root.picker.keyIs(e, "h"))) root.go(-1)
      else if (e.key === Qt.Key_Right || (plain && root.picker.keyIs(e, "l"))) root.go(1)
      else if (e.key === Qt.Key_Home) root.go(-root.list.length)
      else if (e.key === Qt.Key_End) root.go(root.list.length)
      else if (root.picker.hasLive && (root.picker.keyIs(e, "[") || root.picker.keyIs(e, "]")) && plain)
        root.picker.stepLiveMode(root.picker.keyIs(e, "]") ? 1 : -1)
      else if (root.wallMode && e.key === Qt.Key_Tab) root.look = (root.look + 1) % 3
      else if (root.wallMode && e.key === Qt.Key_Backtab) root.look = (root.look + 2) % 3
      else if (root.wallMode && (up || down) && (e.modifiers & Qt.ShiftModifier)) root.bright = Math.max(10, Math.min(100, root.bright + (up ? 5 : -5)))
      else if (root.wallMode && (up || down)) root.pitch = Math.max(4, Math.min(32, root.pitch + (up ? 1 : -1)))
      else if (!root.wallMode && (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)) root.go(e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier) ? 1 : -1)
      else if (root.picker.filterable && Util.editsFilter(e, root.picker.filterText)) root.picker.updateFilter(Util.editedFilter(e, root.picker.filterText))
      else if (root.picker.filterable && e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127
               && (e.modifiers === Qt.NoModifier || e.modifiers === Qt.ShiftModifier)) root.picker.updateFilter(root.picker.filterText + e.text)
      else return
      e.accepted = true
    }

    // фон: сетка точек — её видно, пока превью не закрыло экран
    Rectangle { anchors.fill: parent; color: GTheme.bg }
    Image {
      visible: !prev.opaque
      anchors.fill: parent
      fillMode: Image.Tile
      source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="' + GTheme.s2 + '"/></svg>')
    }
    Wall {
      id: prev
      anchors.fill: parent
      path: root.view
      look: root.shownLook
      pitch: root.pitch
      bright: root.shownBright
      origin: Qt.point(width / 2, stage.ringY)
    }

    // колесо — листать, клик мимо — вернуть фокус
    MouseArea {
      anchors.fill: parent
      property real acc: 0
      onClicked: stage.forceActiveFocus()
      onWheel: function(w) {
        acc += w.angleDelta.y || w.angleDelta.x
        while (Math.abs(acc) >= 120) {
          root.go(acc > 0 ? -1 : 1)
          acc -= Math.sign(acc) * 120
        }
      }
    }

    // поверх картинки метки должны читаться: сверху и снизу фон сходит на нет
    Rectangle {
      width: parent.width
      height: 380
      gradient: Gradient {
        GradientStop { position: 0; color: GTheme.fade(GTheme.bg, 0.85) }
        GradientStop { position: 1; color: GTheme.fade(GTheme.bg, 0) }
      }
    }
    Rectangle {
      y: parent.height - height
      width: parent.width
      height: 460
      gradient: Gradient {
        GradientStop { position: 0; color: GTheme.fade(GTheme.bg, 0) }
        GradientStop { position: 1; color: GTheme.fade(GTheme.bg, 0.9) }
      }
    }

    // номер Doto и имя
    Column {
      x: 150 - 30 * (1 - root.t)
      y: 110
      Lb {
        text: (root.wallMode ? "wallpaper" : "theme") + " · " + root.list.length
              + (root.picker.liveMode !== "all" ? " · " + root.picker.liveMode : "")
      }
      Row {
        topPadding: 18
        spacing: 10
        Num { id: idx; text: String(root.list.length ? root.sel + 1 : 0).padStart(2, "0"); font.pixelSize: 150 }
        Num { anchors.baseline: idx.baseline; text: "/" + String(root.list.length).padStart(2, "0"); font.pixelSize: 54; color: GTheme.mute }
      }
      Lb { topPadding: 22; width: 700; elide: Text.ElideRight; text: root.name(root.cur); px: 14; color: GTheme.fg }
      Lb {
        visible: root.picker.filterable
        topPadding: 10
        width: 700
        elide: Text.ElideRight
        px: 14
        color: GTheme.accent
        text: root.picker.filterText ? "/ " + root.picker.filterText : "type to filter"
        opacity: root.picker.filterText ? 1 : 0.6
      }
    }

    // вид и ручки (только обои)
    Column {
      visible: root.wallMode
      anchors { right: parent.right; rightMargin: 150 - 30 * (1 - root.t) }
      y: 110
      spacing: 30
      Pick {
        visible: root.picker.hasLive
        anchors.right: parent.right
        label: "show"
        opts: ["all", "still", "live"]
        cur: root.picker.liveModes.indexOf(root.picker.liveMode)
        onPicked: function(i) { root.picker.liveMode = root.picker.liveModes[i]; root.picker.updateFilter(root.picker.filterText); stage.forceActiveFocus() }
      }
      Pick { anchors.right: parent.right; label: "look"; opts: root.looks; cur: root.look; onPicked: function(i) { root.look = i; stage.forceActiveFocus() } }
      Row {
        anchors.right: parent.right
        spacing: 36
        Dial { size: 120; label: "dot · px"; from: 4; to: 32; live: true; value: root.pitch; onMoved: function(v) { root.pitch = v } }
        Dial { size: 120; label: "light · %"; from: 10; to: 100; step: 5; live: true; value: root.bright; onMoved: function(v) { root.bright = v } }
      }
    }

    // лента. Выбранная всегда в центре — кольцо стоит, круги едут под ним. Круги одного размера 190 и сжаты scale:
    // слой с точками (Art) отрисован один раз, а меняй width — перерисовывался бы на каждом кадре у всех
    Ring {
      x: stage.width / 2 - width / 2
      y: stage.ringY - height / 2
      width: root.size(0) + 36
      height: width
      n: 60
      dot: 4
      f: root.list.length > 1 ? root.sel / (root.list.length - 1) : 1
    }
    Repeater {
      model: root.list
      Item {
        id: th
        required property int modelData
        required property int index
        readonly property var it: root.picker.imageArray[modelData]
        readonly property real d: index - root.pos
        visible: Math.abs(d) < 7.5
        x: stage.width / 2 + root.off(d) - 95
        y: stage.ringY - 95
        width: 190
        height: 190
        scale: root.size(d) / 190
        opacity: 1 - Math.abs(d) * 0.12

        Loader {
          anchors.fill: parent
          active: th.visible && !!th.it
          sourceComponent: Art { url: GTheme.url(th.it.thumbnailPath || th.it.filePath); step: 6 }
        }
        // живые обои — ▶ у края круга
        Text {
          visible: !!th.it && root.isLive(th.it.filePath)
          anchors { right: parent.right; bottom: parent.bottom; margins: 14 }
          text: "▶"
          color: GTheme.fg
          font.pixelSize: 22
        }
        // текущие — красная точка под кругом
        Rectangle {
          visible: th.modelData === root.liveIndex
          anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: th.index === root.sel ? 36 : 22 }
          width: 10
          height: 10
          radius: 5
          color: GTheme.accent
        }
        TapHandler {
          onTapped: {
            if (th.index === root.sel) root.apply()
            else root.picker.select(th.modelData)
          }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
      }
    }

    Row {
      anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 }
      spacing: 34
      Lb { text: "←→ browse" }
      Lb { visible: root.wallMode; text: "tab look" }
      Lb { visible: root.wallMode; text: "↑↓ dot size" }
      Lb { visible: root.wallMode; text: "shift ↑↓ light" }
      Lb { visible: root.picker.hasLive; text: "[ ] live" }
      Lb { visible: !root.wallMode; text: "type to filter" }
      Lb { text: "↵ set"; TapHandler { onTapped: root.apply() } }
      Lb { text: "esc back"; TapHandler { onTapped: root.picker.cancel() } }
    }
  }
}
