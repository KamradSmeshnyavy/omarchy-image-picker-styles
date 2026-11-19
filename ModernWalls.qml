import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// modern — выбор обоев райса Modern по мотивам его Modern/wallpaper-picker/shell.qml (github.com/elifouts/Dotfiles,
// GPL-3.0; облик — v2/wallpaper-picker.gif; код свой): снизу поднимается панель с затуханием в фон темы, на весь экран —
// превью выбранных обоев (плавная смена), над панелью ряд папок (all / favorites / папки его библиотеки / theme — обои
// текущей темы), посередине карусель — текущая крупнее и ярче, под ней имя и полоска её 16 цветов pywal.
// Библиотека и индекс — omarchy-crt-library (~/Pictures/Wallpapers/elifouts, общий с Retro), применение —
// omarchy-modern-colors --wallpaper (при цветах Pywal ещё и перекраска). Клавиши: ← → / h l, Tab — папка,
// f — избранное, Enter — поставить, Esc — закрыть; колесо — по карусели.
Item {
  id: pk
  required property var picker   // ImagePicker.qml: imageArray (обои текущей темы), finishWith(path), cancel()

  readonly property color bg: Commons.Color.background
  readonly property color fg: Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
    : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property real u: Math.max(0.6, Math.min(width / 1600, height / 900))

  function focusIn() { keys.forceActiveFocus() }

  property var lib: []
  readonly property var themeWalls: (picker.imageArray || []).map(w => ({ path: w.filePath, name: w.fileName.replace(/\.[^.]+$/, ""), theme: "theme", fav: false, thumb: w.thumbnailPath, colors: [] }))
  readonly property var all: lib.concat(themeWalls)
  property string folder: "all"
  readonly property var folders: ["all"].concat(lib.some(w => w.fav) ? ["favorites"] : [], [...new Set(lib.map(w => w.theme))].sort(), themeWalls.length ? ["theme"] : [])
  readonly property var items: folder === "all" ? all : folder === "favorites" ? all.filter(w => w.fav) : all.filter(w => w.theme === folder)
  property int sel: 0
  readonly property var current: items[sel] ?? null
  onFolderChanged: sel = 0
  property string live: ""

  property real t: 0
  Component.onCompleted: rise.start()
  NumberAnimation { id: rise; target: pk; property: "t"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }

  FileView {
    id: idx
    path: Quickshell.env("HOME") + "/.cache/omarchy/crt-walls/index.json"
    printErrors: false
    onLoaded: {
      try { pk.lib = JSON.parse(text()) } catch (e) {}
      const i = pk.items.findIndex(w => w.path === pk.live)
      if (i >= 0) pk.sel = i
    }
  }
  Process {
    running: true
    command: ["sh", "-c", "readlink -f ~/.local/state/omarchy/current/background; jq -r '.source // empty' ~/.local/state/omarchy/modern-live.json 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: { const l = text.trim().split("\n"); pk.live = l[1] || l[0] || "" } }
  }
  Process {
    running: true
    command: ["omarchy-crt-library", "index"]
    onExited: idx.reload()
  }

  function apply() {
    if (!current || applying.running) return
    applying.command = ["omarchy-modern-colors", "--wallpaper", current.path]
    applying.running = true
  }
  Process {
    id: applying
    stdout: StdioCollector { onStreamFinished: { const p = text.trim().split("\n").pop(); pk.live = pk.current ? pk.current.path : ""; pk.picker.finishWith(p) } }
  }
  function fav() {
    if (!current || current.theme === "theme") return
    const p = current.path
    lib = lib.map(w => w.path === p ? Object.assign({}, w, { fav: !w.fav }) : w)
    Quickshell.execDetached(["omarchy-crt-library", "fav", p])
  }
  function move(d) { sel = Math.max(0, Math.min(items.length - 1, sel + d)) }
  function nextFolder(d) { const i = folders.indexOf(folder); folder = folders[(i + d + folders.length) % folders.length] }

  // превью на весь экран: две картинки, новая проявляется поверх
  property string shownA: ""
  property string shownB: ""
  property bool onB: false
  Timer {
    id: settle; interval: 120
    onTriggered: {
      if (!pk.current) return
      const src = "file://" + pk.current.path
      if ((pk.onB ? pk.shownB : pk.shownA) === src) return
      if (pk.onB) pk.shownA = src; else pk.shownB = src
      pk.onB = !pk.onB
    }
  }
  onCurrentChanged: settle.restart()
  Image { id: imA; anchors.fill: parent; source: pk.shownA; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1920; opacity: (!pk.onB && status === Image.Ready ? 1 : 0) * pk.t; Behavior on opacity { NumberAnimation { duration: 320 } } }
  Image { id: imB; anchors.fill: parent; source: pk.shownB; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1920; opacity: (pk.onB && status === Image.Ready ? 1 : 0) * pk.t; Behavior on opacity { NumberAnimation { duration: 320 } } }

  MouseArea { anchors.fill: parent; onClicked: pk.picker.cancel(); onWheel: w => pk.move(w.angleDelta.y < 0 ? 1 : -1) }

  // панель снизу: затухание в фон темы
  Item {
    id: panel
    anchors.left: parent.left; anchors.right: parent.right
    height: 560 * pk.u
    y: parent.height - height + (1 - pk.t) * 80 * pk.u
    opacity: pk.t
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: pk.a(pk.bg, 0) }
        GradientStop { position: 0.45; color: pk.a(pk.bg, 0.72) }
        GradientStop { position: 1; color: pk.a(pk.bg, 0.95) }
      }
    }
    MouseArea { anchors.fill: parent; onWheel: w => pk.move(w.angleDelta.y < 0 ? 1 : -1) }

    // папки
    Row {
      id: chips
      anchors.horizontalCenter: parent.horizontalCenter
      y: 150 * pk.u
      spacing: 6 * pk.u
      Repeater {
        model: pk.folders
        Rectangle {
          required property string modelData
          readonly property bool on: pk.folder === modelData
          width: cl.implicitWidth + 22 * pk.u; height: 26 * pk.u; radius: 7 * pk.u
          color: on ? pk.accent : ca.containsMouse ? pk.a(pk.fg, 0.16) : pk.a(pk.fg, 0.08)
          Behavior on color { ColorAnimation { duration: 160 } }
          Text { id: cl; anchors.centerIn: parent; text: parent.modelData; font.family: pk.font; font.pixelSize: 12 * pk.u; color: parent.on ? pk.bg : pk.fg }
          MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pk.folder = parent.modelData }
        }
      }
    }

    // карусель
    ListView {
      id: strip
      anchors.left: parent.left; anchors.right: parent.right
      y: chips.y + chips.height + 30 * pk.u
      height: 150 * pk.u
      orientation: ListView.Horizontal
      spacing: 22 * pk.u
      model: pk.items
      currentIndex: pk.sel
      interactive: false
      highlightRangeMode: ListView.StrictlyEnforceRange
      preferredHighlightBegin: width / 2 - 120 * pk.u
      preferredHighlightEnd: width / 2 + 120 * pk.u
      highlightMoveDuration: 320
      delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool on: index === pk.sel
        width: 240 * pk.u; height: strip.height
        Rectangle {
          id: card
          anchors.centerIn: parent
          width: parent.width * (cell.on ? 1 : 0.86); height: width * 9 / 16
          Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
          radius: 10 * pk.u
          color: pk.a(pk.fg, 0.08)
          border.width: cell.on ? 2 : 1
          border.color: cell.on ? pk.a(pk.fg, 0.85) : pk.a(pk.fg, 0.12)
          clip: true
          opacity: cell.on ? 1 : 0.62
          Behavior on opacity { NumberAnimation { duration: 220 } }
          Image { anchors.fill: parent; anchors.margins: parent.border.width; source: cell.modelData.thumb ? "file://" + cell.modelData.thumb : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 480 }
          Text { visible: !!cell.modelData.fav; anchors.right: parent.right; anchors.rightMargin: 8; y: 6; text: ""; font.family: pk.font; font.pixelSize: 12 * pk.u; color: pk.accent }
          Rectangle { visible: cell.modelData.path === pk.live; x: 8; y: 8; width: 8; height: 8; radius: 4; color: pk.accent }
        }
        MouseArea {
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
          onClicked: { if (cell.on) pk.apply(); else pk.sel = cell.index }
        }
      }
    }

    // имя и палитра
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: strip.y + strip.height + 18 * pk.u
      text: pk.current ? pk.current.name.replace(/-/g, " ") : ""
      font.family: pk.font; font.pixelSize: 15 * pk.u; color: pk.fg
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      y: strip.y + strip.height + 50 * pk.u
      Repeater {
        model: pk.current && pk.current.colors && pk.current.colors.length ? pk.current.colors : []
        Rectangle {
          required property string modelData
          required property int index
          width: 22 * pk.u; height: 5 * pk.u
          radius: index === 0 || index === 15 ? height / 2 : 0
          color: modelData
          Behavior on color { ColorAnimation { duration: 280 } }
        }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: 22 * pk.u
      text: applying.running ? "applying…" : "enter apply   ·   f favorite   ·   tab folder   ·   esc close"
      font.family: pk.font; font.pixelSize: 11 * pk.u; color: pk.a(pk.fg, 0.4)
    }
  }

  Item {
    id: keys
    focus: true
    Keys.onPressed: e => {
      const k = e.key
      if (k === Qt.Key_Escape) pk.picker.cancel()
      else if (k === Qt.Key_Left || k === Qt.Key_H) pk.move(-1)
      else if (k === Qt.Key_Right || k === Qt.Key_L) pk.move(1)
      else if (k === Qt.Key_Tab) pk.nextFolder(1)
      else if (k === Qt.Key_Backtab) pk.nextFolder(-1)
      else if (k === Qt.Key_F) pk.fav()
      else if (k === Qt.Key_Return || k === Qt.Key_Enter) pk.apply()
      else return
      e.accepted = true
    }
  }
}
