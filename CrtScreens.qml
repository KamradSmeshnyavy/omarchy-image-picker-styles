import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// SCREENS — выбор обоев райса Retro CRT, его Retro/wallpaper/Picker.qml (github.com/elifouts/Dotfiles, GPL-3.0) почти
// дословно: двойная рамка во весь экран, слева «folder:» (all / favorites / папки его библиотеки / theme — обои текущей
// темы) с числами, посередине сетка в 4 колонки (миниатюры окрашены в акцент, выбранная — ярче, ★ у избранных), справа
// PREVIEW — картинка, прогнанная фильтром трубки, name / folder / status и кнопки APPLY / FAVORITE / FILTER.
// Библиотека и индекс — omarchy-crt-library (~/Pictures/Wallpapers/elifouts), применение — omarchy-crt-colors --wallpaper
// (фильтр в текущие цвета; при цветах Wallpaper — ещё и перекраска pywal), FILTER — панель настроек на странице SCREEN.
// Клавиши: стрелки / hjkl, Tab — папка, f — избранное, Enter — применить, Esc — закрыть.
Item {
  id: pk
  required property var picker   // ImagePicker.qml: imageArray (обои текущей темы), finishWith(path), cancel()

  readonly property color bg: Commons.Color.background
  readonly property color fg: Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property color dim: a(fg, 0.5)
  readonly property color low: a(accent, 0.18)
  readonly property color line: a(accent, 0.55)
  readonly property string font: Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") !== -1 ? "Terminess Nerd Font Mono" : "monospace"
  readonly property int size: 14

  function focusIn() { keys.forceActiveFocus() }

  property var lib: []
  readonly property var themeWalls: (picker.imageArray || []).map(w => ({ path: w.filePath, name: w.fileName.replace(/\.[^.]+$/, ""), theme: "theme", fav: false, thumb: w.thumbnailPath }))
  readonly property var all: lib.concat(themeWalls)
  property string folder: "all"
  readonly property var folders: ["all"].concat(lib.some(w => w.fav) ? ["favorites"] : [], [...new Set(lib.map(w => w.theme))].sort(), themeWalls.length ? ["theme"] : [])
  readonly property var items: folder === "all" ? all : folder === "favorites" ? all.filter(w => w.fav) : all.filter(w => w.theme === folder)
  property int sel: 0
  readonly property var current: items[sel] ?? null
  onFolderChanged: sel = 0
  property string live: ""

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
    command: ["sh", "-c", "readlink -f ~/.local/state/omarchy/current/background; jq -r '.source // empty' ~/.local/state/omarchy/current/theme/live.json 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: { const l = text.trim().split("\n"); pk.live = l[1] || l[0] || "" } }
  }
  Process {
    running: true
    command: ["omarchy-crt-library", "index"]
    onExited: idx.reload()
  }

  // превью: его wallpaper.sh <картинка> — фильтр трубки в текущих цветах
  property string shown: ""
  Timer { id: settle; interval: 220; onTriggered: if (pk.current && !look.running) { look.command = ["omarchy-crt-filter", pk.current.path]; look.running = true } }
  onCurrentChanged: settle.restart()
  Process { id: look; stdout: StdioCollector { onStreamFinished: pk.shown = text.trim() } onExited: if (look.command[1] !== pk.current?.path) settle.restart() }

  function apply() {
    if (!current) return
    applying.command = ["omarchy-crt-colors", "--wallpaper", current.path]
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

  component T: Text {
    font.family: pk.font
    font.pixelSize: pk.size
    font.letterSpacing: 1
    font.capitalization: Font.AllUppercase
    color: pk.fg
    verticalAlignment: Text.AlignVCenter
  }
  component Btn: Rectangle {
    id: b
    property string label
    property bool primary: false
    signal pressed()
    width: bt.implicitWidth + 20; height: 22
    color: ba.containsMouse || primary ? pk.accent : "transparent"
    border.width: 1; border.color: pk.accent
    T { id: bt; anchors.centerIn: parent; text: b.label; color: ba.containsMouse || b.primary ? pk.bg : pk.fg }
    MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; onClicked: b.pressed() }
  }

  MouseArea { anchors.fill: parent; onClicked: pk.picker.cancel() }

  Rectangle {
    id: frame
    anchors.centerIn: parent
    width: Math.min(1400, pk.width - 60)
    height: Math.min(pk.height - 80, 760)
    color: pk.bg
    border.width: 1; border.color: pk.line
    Rectangle { anchors.fill: parent; anchors.margins: 3; color: "transparent"; border.width: 1; border.color: pk.line }
    Rectangle { x: 10; y: -height / 2; width: head.implicitWidth + 12; height: head.implicitHeight; color: pk.bg; T { id: head; x: 6; text: "screens"; color: pk.accent } }
    Rectangle {
      anchors.right: parent.right; anchors.rightMargin: 10; y: parent.height - height / 2
      width: tail.implicitWidth + 12; height: tail.implicitHeight; color: pk.bg
      T { id: tail; x: 6; text: "enter-apply  f-favorite  tab-folder  esc-end"; color: pk.dim; font.pixelSize: pk.size - 3 }
    }
    MouseArea { anchors.fill: parent }

    Column {
      id: folders
      x: 24; y: 28
      width: 190
      spacing: 2
      T { text: "folder:"; font.capitalization: Font.MixedCase; color: pk.dim; height: 22 }
      Repeater {
        model: pk.folders
        Item {
          id: fl
          required property string modelData
          required property int index
          readonly property bool lit: pk.folder === modelData
          width: folders.width; height: 22
          Rectangle { anchors.fill: parent; color: fa.containsMouse ? pk.accent : "transparent" }
          T { x: 4; height: parent.height; text: String(fl.index + 1); color: fa.containsMouse ? pk.bg : fl.lit ? pk.accent : pk.fg }
          T { x: 24; height: parent.height; font.capitalization: Font.MixedCase; text: fl.modelData; color: fa.containsMouse ? pk.bg : fl.lit ? pk.accent : pk.fg }
          T {
            anchors.right: parent.right; anchors.rightMargin: 4; height: parent.height
            text: String(fl.modelData === "all" ? pk.all.length : fl.modelData === "favorites" ? pk.all.filter(w => w.fav).length : pk.all.filter(w => w.theme === fl.modelData).length)
            color: fa.containsMouse ? pk.bg : pk.dim
          }
          MouseArea { id: fa; anchors.fill: parent; hoverEnabled: true; onClicked: pk.folder = fl.modelData }
        }
      }
    }

    GridView {
      id: grid
      x: folders.x + folders.width + 20
      y: 28
      width: 4 * 168
      height: frame.height - 56
      clip: true
      cellWidth: 168
      cellHeight: 112
      model: pk.items
      currentIndex: pk.sel
      highlightMoveDuration: 0
      boundsBehavior: Flickable.StopAtBounds
      delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool on: index === pk.sel
        width: 168
        height: 112
        Rectangle {
          anchors.fill: parent
          anchors.margins: 4
          color: cell.on ? pk.accent : "transparent"
          border.width: 1
          border.color: cell.on ? pk.accent : cell.modelData.path === pk.live ? pk.line : pk.low
          Image {
            id: img
            anchors.fill: parent
            anchors.margins: 3
            source: cell.modelData.thumb ? "file://" + cell.modelData.thumb : ""
            sourceSize.width: 160
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
          }
          MultiEffect {
            anchors.fill: img
            source: img
            colorization: cell.on ? 0.35 : 0.8
            colorizationColor: pk.accent
            brightness: cell.on ? 0 : -0.2
          }
          Text { visible: !!cell.modelData.fav; x: 6; y: 4; text: "★"; font.family: pk.font; font.pixelSize: pk.size; color: pk.accent; style: Text.Outline; styleColor: pk.bg }
        }
        MouseArea { anchors.fill: parent; onClicked: pk.sel === cell.index ? pk.apply() : pk.sel = cell.index }
      }
    }

    Item {
      x: grid.x + grid.width + 20
      y: 28
      width: frame.width - x - 24
      height: frame.height - 56
      T { text: "preview"; color: pk.accent; height: 22 }
      Rectangle {
        id: shot
        y: 26
        width: parent.width
        height: width * 9 / 16
        color: pk.bg
        border.width: 1
        border.color: pk.line
        Image {
          anchors.fill: parent
          anchors.margins: 1
          source: pk.shown ? "file://" + pk.shown : ""
          fillMode: Image.PreserveAspectCrop
          smooth: false
          asynchronous: true
          cache: false
        }
        T { anchors.centerIn: parent; visible: look.running || applying.running; text: applying.running ? "applying" : "rendering"; color: pk.dim }
      }
      Column {
        y: shot.y + shot.height + 14
        width: parent.width
        spacing: 2
        Repeater {
          model: pk.current ? [["name", pk.current.name], ["folder", pk.current.theme], ["status", pk.current.path === pk.live ? "on screen" : "standby"]] : []
          Item {
            required property var modelData
            width: parent.width
            height: 20
            T { text: modelData[0]; color: pk.dim; height: parent.height }
            T { anchors.right: parent.right; text: modelData[1]; height: parent.height }
          }
        }
        Item { width: 1; height: 10 }
        Row {
          spacing: 8
          Btn { label: "apply"; primary: true; onPressed: pk.apply() }
          Btn { label: pk.current?.fav ? "unfavorite" : "favorite"; onPressed: pk.fav() }
          Btn { label: "filter"; onPressed: { pk.picker.cancel(); Quickshell.execDetached(["omarchy-shell", "widgets", "openPrefsPage", "screen"]) } }
        }
      }
    }
  }

  Item {
    id: keys
    focus: true
    Keys.onEscapePressed: pk.picker.cancel()
    Keys.onReturnPressed: pk.apply()
    Keys.onEnterPressed: pk.apply()
    Keys.onPressed: e => {
      const k = e.key
      if (k === Qt.Key_Right || e.text === "l") pk.move(1)
      else if (k === Qt.Key_Left || e.text === "h") pk.move(-1)
      else if (k === Qt.Key_Down || e.text === "j") pk.move(4)
      else if (k === Qt.Key_Up || e.text === "k") pk.move(-4)
      else if (k === Qt.Key_Tab) pk.folder = pk.folders[(pk.folders.indexOf(pk.folder) + 1) % pk.folders.length]
      else if (k === Qt.Key_Backtab) pk.folder = pk.folders[(pk.folders.indexOf(pk.folder) - 1 + pk.folders.length) % pk.folders.length]
      else if (e.text === "f") pk.fav()
      else return
      e.accepted = true
    }
  }
}
