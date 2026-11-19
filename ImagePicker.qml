import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import "ImagePickerModel.js" as ImagePickerModel
import "glyph" as Glyph

Item {
  id: root

  // Injected by omarchy-shell; defaults to the session OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string stateHome: Quickshell.env("HOME") + "/.local/state"
  property string imageDirs: Quickshell.env("OMARCHY_IMAGE_SELECTOR_DIRS") || Quickshell.env("OMARCHY_IMAGE_SELECTOR_DIR") || Quickshell.env("OMARCHY_STOCK_BACKGROUNDS_DIR") || (stateHome + "/omarchy/current/theme/backgrounds")
  property string imageRows: ""
  property string loadedImageRows: ""
  property string selectionFile: Quickshell.env("OMARCHY_IMAGE_SELECTOR_SELECTION_FILE") || Quickshell.env("OMARCHY_BACKGROUND_SELECTION_FILE")
  property string selectedImage: Quickshell.env("OMARCHY_IMAGE_SELECTOR_SELECTED")
  property int selectedIndex: 0
  property bool imagesLoaded: false
  property bool opened: false
  property bool showLabels: false
  property bool filterable: false
  property bool layoutSettled: false
  property bool requestActive: false
  property int requestSerial: 0
  property int applySerial: 0
  property string doneFile: ""
  property string filterText: ""
  // picker: все / статичные / живые (видео и GIF) — j / k или ↑ / ↓; переключатель виден, если живые есть.
  property string liveMode: "all"
  readonly property var liveModes: ["all", "static", "live"]
  readonly property bool hasLive: imageArray.some(function(it) { return ImagePickerModel.isLive(it.filePath) })
  readonly property string effFilter: (hasLive && liveMode !== "all" ? "\u0001" + liveMode + "\u0001" : "") + filterText
  function stepLiveMode(dir) {
    if (!hasLive) return
    liveMode = liveModes[(liveModes.indexOf(liveMode) + dir + liveModes.length) % liveModes.length]
    updateFilter(filterText)
  }
  property var doneFilesToRelease: []
  // Bound to the central [image-picker] section in shell.toml via Commons.Color.qml.
  // `dimColor` tints unselected slices and text outlines on top of the scrim;
  // it intentionally tracks the foundational background, not a surface role.
  property color dimColor: Commons.Color.background
  property color foreground: Commons.Color.imagePicker.text
  property color scrim: Commons.Color.imagePicker.scrim
  property color selectedBorder: nierStyle ? "#463f2e" : spaceStyle || crtStyle ? Commons.Color.accent : Commons.Color.imagePicker.selectedBorder
  property color unselectedBorder: nierStyle ? Qt.rgba(70 / 255, 63 / 255, 46 / 255, 0.5) : spaceStyle ? Util.alpha(Commons.Color.accent, 0.25) : crtStyle ? Util.alpha(Commons.Color.accent, 0.3) : Commons.Color.imagePicker.unselectedBorder
  // picker: вид из ~/.config/omarchy/image-picker.json — стиль-пресет и числа поверх него.
  //   style: slices (сток) | cards | coverflow | strip | wide | polaroid | honeycomb (соты, Vitreus) | dots (сборка из точек)
  //          | glyph (переключатель обоев glyph-rice: превью на весь экран, лента кругов) | nier | space (HUD райса Space) | crt (экран SCREENS райса Retro CRT)
  property var pickerConfig: ({})
  readonly property var stylePresets: ({
    "slices":    { expandedWidth: 768,  expandedHeight: 475, sliceWidth: 108, sliceHeight: 432, spacing: -30,  skew: 28, radius: 0,  tilt: 0 },
    "cards":     { expandedWidth: 760,  expandedHeight: 470, sliceWidth: 150, sliceHeight: 400, spacing: 14,   skew: 0,  radius: 18, tilt: 0 },
    "coverflow": { expandedWidth: 640,  expandedHeight: 420, sliceWidth: 300, sliceHeight: 380, spacing: -210, skew: 0,  radius: 12, tilt: 55 },
    "strip":     { expandedWidth: 460,  expandedHeight: 290, sliceWidth: 300, sliceHeight: 190, spacing: 16,   skew: 0,  radius: 12, tilt: 0 },
    "wide":      { expandedWidth: 1040, expandedHeight: 585, sliceWidth: 64,  sliceHeight: 520, spacing: -18,  skew: 34, radius: 0,  tilt: 0 },
    "polaroid":  { expandedWidth: 600,  expandedHeight: 470, sliceWidth: 220, sliceHeight: 300, spacing: 18,   skew: 0,  radius: 4,  tilt: 0 },
    // honeycomb: сетка всех обоев шестиугольниками со скруглёнными углами (как у Vitreus): ряды через один со
    // сдвигом на полшага, выбранная клетка крупнее; slice* — размер клетки, spacing — зазор.
    "honeycomb": { expandedWidth: 640,  expandedHeight: 0,   sliceWidth: 104, sliceHeight: 120, spacing: 10,   skew: 0,  radius: 0,  tilt: 0 },
    // dots: круглые миниатюры, превью собирается из точек (shaders/dots.frag).
    "dots":      { expandedWidth: 720,  expandedHeight: 450, sliceWidth: 120, sliceHeight: 120, spacing: 18,   skew: 0,  radius: 24, tilt: 0 },
    // glyph: весь экран — превью, лента кругов внизу (glyph/GlyphWalls.qml, из glyph-rice, GPL-3.0); числа не нужны.
    "glyph":     { expandedWidth: 720,  expandedHeight: 450, sliceWidth: 120, sliceHeight: 120, spacing: 18,   skew: 0,  radius: 24, tilt: 0 },
    // nier: по мотивам WallpaperPicker из Unit-3 (samyns, MIT): бежевый экран NieR с сеткой и служебными строками по
    // углам, квадратные миниатюры в рамке чернилами, подпись выбранной — Share Tech Mono.
    "nier":      { expandedWidth: 640,  expandedHeight: 400, sliceWidth: 200, sliceHeight: 300, spacing: 14,   skew: 0,  radius: 0,  tilt: 0 },
    // space: HUD райса Space (облик стиля Space из elifouts/Dotfiles, GPL-3.0): прямые углы, рамка выбранной акцентом и
    // уголки вокруг неё, тёмная вуаль цвета фона, служебные строки капсом вразрядку по углам, подпись — JetBrains Mono.
    "space":     { expandedWidth: 720,  expandedHeight: 405, sliceWidth: 132, sliceHeight: 360, spacing: 12,   skew: 0,  radius: 0,  tilt: 0 },
    // crt: экран SCREENS райса Retro CRT (облик стиля Retro из elifouts/Dotfiles, GPL-3.0 — его wallpaper/Picker.qml и
    // retro/picker-default.png): двойная рамка во весь экран с заголовком SCREENS, прямые миниатюры в рамке цветом
    // трубки, выбранная — рамкой акцентом, подписи и подсказки Terminess капсом.
    "crt":       { expandedWidth: 640,  expandedHeight: 360, sliceWidth: 156, sliceHeight: 300, spacing: 10,   skew: 0,  radius: 0,  tilt: 0 },
    // modern: обои — ModernWalls.qml (его карусель снизу), темы — скруглённые карточки
    "modern":    { expandedWidth: 640,  expandedHeight: 360, sliceWidth: 150, sliceHeight: 300, spacing: 14,   skew: 0,  radius: 14, tilt: 0 }
  })
  readonly property bool spaceStyle: pickerStyle === "space"
  readonly property bool crtStyle: pickerStyle === "crt"
  // modern: его пикер обоев Modern (ModernWalls.qml) — карусель снизу с превью на весь экран; темы — каруселью
  readonly property bool modernStyle: pickerStyle === "modern"
  readonly property bool modernWallsMode: modernStyle && !showLabels
  readonly property string crtFont: Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") !== -1 ? "Terminess Nerd Font Mono" : "monospace"
  readonly property string spaceFont: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property bool nierStyle: pickerStyle === "nier"
  readonly property string nierFont: Qt.fontFamilies().indexOf("Share Tech Mono") !== -1 ? "Share Tech Mono" : "monospace"
  readonly property bool honeycomb: pickerStyle === "honeycomb"
  readonly property bool dotsStyle: pickerStyle === "dots"
  readonly property bool glyphStyle: pickerStyle === "glyph"
  // Соты: геометрия сетки (в координатах карусели, она в этом стиле почти на весь экран).
  readonly property real honeyAreaW: card.width
  readonly property real honeyAreaH: card.height - Style.space(30) - bottomChromeHeight
  readonly property real honeyStepX: sliceWidth + sliceSpacing
  readonly property real honeyRowH: sliceHeight * 0.75 + sliceSpacing * 0.866
  readonly property int honeyCols: Math.max(1, Math.floor((honeyAreaW - sliceWidth / 2) / honeyStepX))
  readonly property int honeyViewRows: Math.max(1, Math.floor((honeyAreaH - sliceHeight) / honeyRowH) + 1)
  readonly property int honeyCount: {
    var n = 0
    for (var i = 0; i < imageArray.length; i++) if (itemMatches(i)) n++
    return n
  }
  readonly property int honeyRows: Math.ceil(honeyCount / honeyCols)
  readonly property int honeyFirstRow: {
    var sel = Math.floor(selectedFilteredPosition() / honeyCols)
    return Math.max(0, Math.min(Math.max(0, honeyRows - honeyViewRows), sel - Math.floor(honeyViewRows / 2)))
  }
  function honeyCell(pos) {
    var row = Math.floor(pos / honeyCols), col = pos % honeyCols
    var totalW = honeyCols * honeyStepX + honeyStepX / 2 - sliceSpacing
    var rows = Math.min(honeyViewRows, honeyRows)
    var totalH = (rows - 1) * honeyRowH + sliceHeight
    var x0 = (honeyAreaW - totalW) / 2, y0 = Math.max(0, (honeyAreaH - totalH) / 2)
    return { row: row, x: x0 + col * honeyStepX + (row % 2 ? honeyStepX / 2 : 0), y: y0 + (row - honeyFirstRow) * honeyRowH,
             inView: row >= honeyFirstRow && row < honeyFirstRow + honeyViewRows }
  }
  // Ряд вверх / вниз: та же колонка в соседнем ряду (позиция ± число колонок среди отфильтрованных).
  function honeyStepRow(dir) {
    var target = selectedFilteredPosition() + dir * honeyCols
    if (target < 0 || target >= honeyCount) return
    for (var i = 0; i < imageArray.length; i++)
      if (itemMatches(i) && filteredPosition(i) === target) { select(i); return }
  }
  readonly property string pickerStyle: stylePresets[pickerConfig.style] ? String(pickerConfig.style) : "slices"
  function pickerNum(key, fallback) {
    var v = Number(pickerConfig[key])
    return pickerConfig[key] !== undefined && pickerConfig[key] !== null && isFinite(v) ? v : fallback
  }
  readonly property var preset: stylePresets[pickerStyle]
  property int expandedWidth: pickerNum("expandedWidth", preset.expandedWidth)
  property int expandedHeight: pickerNum("expandedHeight", preset.expandedHeight)
  property int sliceWidth: pickerNum("sliceWidth", preset.sliceWidth)
  property int sliceHeight: pickerNum("sliceHeight", preset.sliceHeight)
  property int sliceSpacing: pickerNum("spacing", preset.spacing)
  property int skewOffset: pickerNum("skew", preset.skew)
  readonly property real cornerRadius: pickerNum("cardRadius", preset.radius)
  readonly property real tilt: pickerNum("tilt", preset.tilt)
  readonly property real dimUnselected: pickerNum("dim", 0.42)
  readonly property int selectedBorderWidth: pickerNum("selectedBorder", spaceStyle || crtStyle ? 1 : 3)
  readonly property int animMs: pickerNum("animMs", 160)
  readonly property real scrimAlpha: pickerNum("scrimAlpha", -1)
  readonly property bool polaroid: pickerStyle === "polaroid"
  readonly property bool labelsAlways: pickerConfig.labels === true
  readonly property bool labelsShown: showLabels || labelsAlways
  property int bottomChromeHeight: labelsShown ? (filterable ? 104 : 74) : (filterable ? 60 : 30)

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/image-picker.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var v = JSON.parse(text())
        root.pickerConfig = v && typeof v === "object" ? v : ({})
      } catch (e) {
        console.warn("image-picker.json: " + e)
      }
    }
    onLoadFailed: root.pickerConfig = ({})
  }

  onOpenedChanged: if (!opened) layoutSettled = false

  function scriptPath(name) {
    return omarchyPath + "/shell/plugins/image-picker/" + name
  }

  function focusPicker() {
    if (root.opened && root.imagesLoaded && root.layoutSettled) {
      if (root.glyphStyle && glyphView.item) glyphView.item.focusIn()
      else if (root.crtScreensMode && crtScreens.item) crtScreens.item.focusIn()
      else if (root.modernWallsMode && modernWalls.item) modernWalls.item.focusIn()
      else carousel.forceActiveFocus()
    }
  }

  function revealWhenSettled(serial) {
    Qt.callLater(function() {
      if (serial === root.requestSerial && root.opened && root.imagesLoaded && root.imageArray.length > 0) {
        root.layoutSettled = true
        root.focusPicker()
      }
    })
  }

  function currentPath() {
    if (imageArray.length === 0 || !itemMatches(selectedIndex)) return ""
    return imageArray[selectedIndex].filePath
  }

  function nameForPath(path) {
    return ImagePickerModel.nameForPath(path)
  }

  function labelForPath(path) {
    return ImagePickerModel.labelForPath(path)
  }

  function currentLabel() {
    var path = currentPath()
    if (!path) return filterText ? "No matches" : ""

    return labelForPath(path)
  }

  function itemMatches(index) {
    return ImagePickerModel.itemMatches(imageArray, index, effFilter)
  }

  function firstMatchingIndex() {
    return ImagePickerModel.firstMatchingIndex(imageArray, effFilter)
  }

  function filteredPosition(index) {
    return ImagePickerModel.filteredPosition(imageArray, index, effFilter)
  }

  function selectedFilteredPosition() {
    return ImagePickerModel.selectedFilteredPosition(imageArray, selectedIndex, effFilter)
  }

  function select(index, immediate) {
    if (imageArray.length === 0) return
    if (index < 0) index = 0
    else if (index >= imageArray.length) index = imageArray.length - 1
    if (!itemMatches(index)) return
    if (index === selectedIndex && immediate !== true) return

    selectedIndex = index
  }

  // picker: клавиша по физическому месту (xkb-код = evdev + 8), а не по символу — h j k l [ ] работают на любой
  // раскладке (в русской на месте h стоит «р»). Символ тоже проверяется: на случай другой физической раскладки.
  readonly property var keyCodes: ({ h: 43, j: 44, k: 45, l: 46, "[": 34, "]": 35 })
  readonly property var keySyms: ({ h: Qt.Key_H, j: Qt.Key_J, k: Qt.Key_K, l: Qt.Key_L, "[": Qt.Key_BracketLeft, "]": Qt.Key_BracketRight })
  function keyIs(event, name) { return event.key === keySyms[name] || event.nativeScanCode === keyCodes[name] }
  function selectAdjacent(direction) {
    var count = imageArray.length
    if (count === 0) return

    var index = selectedIndex
    for (var i = 0; i < count; i++) {
      index = (index + direction + count) % count
      if (itemMatches(index)) {
        select(index)
        return
      }
    }
  }

  function updateFilter(nextFilterText) {
    filterText = nextFilterText

    if (!itemMatches(selectedIndex)) {
      var first = ImagePickerModel.nextSelectedIndexForFilter(imageArray, selectedIndex, effFilter)
      if (first >= 0) selectedIndex = first
    }
  }

  function releaseNextDoneFile() {
    if (releaseProc.running || doneFilesToRelease.length === 0) return

    var path = doneFilesToRelease.shift()
    releaseProc.command = ["bash", "-c", ": > " + Util.shellQuote(path)]
    releaseProc.running = true
  }

  function finishDoneFile(path) {
    if (!path) return
    doneFilesToRelease.push(path)
    releaseNextDoneFile()
  }

  // crt: экран SCREENS (CrtScreens.qml) — его пикер обоев вместо карусели; темы — по-прежнему каруселью
  readonly property bool crtScreensMode: crtStyle && !showLabels  // обои (выбор тем и plymouth — с подписями)
  // готовый путь в файл выбора (CrtScreens уже поставил обои сам)
  function finishWith(path) {
    if (!selectionFile) { cancel(); return }
    var activeSelectionFile = selectionFile, activeDoneFile = doneFile
    applySerial = requestSerial
    requestActive = false
    selectionFile = ""
    doneFile = ""
    applyProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(path) + " > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    applyProc.running = true
  }

  function applySelected() {
    var path = currentPath()
    if (!path || !selectionFile) {
      cancel()
      return
    }

    var activeSelectionFile = selectionFile
    var activeDoneFile = doneFile
    applySerial = requestSerial
    requestActive = false
    selectionFile = ""
    doneFile = ""

    // crt: обои ставятся уже через фильтр трубки (его wallpaper.sh --apply) — путь подменяется готовой картинкой
    var pick = crtFilters(path) ? "p=$(omarchy-crt-filter " + Util.shellQuote(path) + " 2>/dev/null) || p=" + Util.shellQuote(path) + "; " : "p=" + Util.shellQuote(path) + "; "
    applyProc.command = ["bash", "-c", pick + "printf '%s\\n' \"$p\" > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    applyProc.running = true
  }

  function cancel() {
    if (requestActive)
      finishDoneFile(doneFile)

    requestActive = false
    selectionFile = ""
    doneFile = ""
    root.opened = false
  }

  function closeSelector(nextDoneFile) {
    requestSerial += 1

    if (requestActive)
      finishDoneFile(doneFile)

    if (nextDoneFile && nextDoneFile !== doneFile)
      finishDoneFile(nextDoneFile)

    requestActive = false
    selectionFile = ""
    doneFile = ""
    filterText = ""
    root.opened = false
  }

  function loadRows(rows, reveal) {
    var newImages = ImagePickerModel.loadRows(rows)

    root.loadedImageRows = rows
    root.selectedIndex = root.indexForSelectedImage(newImages)
    root.imageArray = newImages
    root.imagesLoaded = true

    if (reveal !== false) {
      root.opened = true
      root.revealWhenSettled(root.requestSerial)
    }
  }

  function openSelector(nextImageDirs, nextImageRows, nextSelectedImage, nextSelectionFile, nextDoneFile, nextShowLabels, nextFilterable) {
    if (requestActive && doneFile && doneFile !== nextDoneFile)
      finishDoneFile(doneFile)

    requestSerial += 1

    imageDirs = nextImageDirs
    imageRows = nextImageRows
    if (crtStyle) crtProbe.running = true
    selectedImage = nextSelectedImage
    selectionFile = nextSelectionFile
    doneFile = nextDoneFile
    requestActive = !!doneFile
    showLabels = nextShowLabels === true || nextShowLabels === "true"
    filterable = nextFilterable === true || nextFilterable === "true"
    filterText = ""
    liveMode = "all"
    layoutSettled = false

    if (imageRows && imageRows === loadedImageRows && imageArray.length > 0) {
      root.select(root.selectedImageIndex(), true)
      imagesLoaded = true
      opened = true
      root.revealWhenSettled(requestSerial)
      return
    }

    if (imageRows) {
      var rowsToLoad = imageRows
      var rowsSerial = requestSerial
      imageArray = []
      selectedIndex = 0
      imagesLoaded = true
      opened = true
      Qt.callLater(function() {
        if (rowsSerial === root.requestSerial)
          root.loadRows(rowsToLoad, true)
      })
      return
    }

    imageArray = []
    selectedIndex = 0
    imagesLoaded = false
    opened = false
    startImageScan(requestSerial, imageDirs)
  }

  property var imageArray: []

  function startImageScan(serial, dirs) {
    if (loadImagesProc.running) {
      loadImagesProc.queuedSerial = serial
      loadImagesProc.queuedDirs = dirs
      return
    }

    loadImagesProc.activeSerial = serial
    loadImagesProc.queuedSerial = 0
    loadImagesProc.queuedDirs = ""
    loadImagesProc.command = [root.scriptPath("list.sh"), dirs]
    loadImagesProc.running = true
  }

  function indexForSelectedImage(images) {
    return ImagePickerModel.indexForSelectedImage(images, selectedImage)
  }

  function selectedImageIndex() {
    return indexForSelectedImage(imageArray)
  }

  Process {
    id: loadImagesProc
    property int activeSerial: 0
    property int queuedSerial: 0
    property string queuedDirs: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (loadImagesProc.activeSerial === root.requestSerial)
          root.loadRows(String(text || ""), true)
      }
    }
    onExited: {
      var serial = queuedSerial
      var dirs = queuedDirs
      activeSerial = 0
      queuedSerial = 0
      queuedDirs = ""
      if (serial > 0 && serial === root.requestSerial)
        root.startImageScan(serial, dirs)
    }
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(omarchy-theme-switcher) && [[ -n $theme ]] && setsid -f omarchy-theme-set \"$theme\" >/dev/null 2>&1"]
  }

  // Lifecycle hooks invoked by omarchy-shell summon/hide. shell.summon(id,
  // payloadJson) hands the JSON to open() here; shell.hide(id) calls close().
  // The shell host owns the stable `image-selector` IPC target and forwards
  // those lower-level positional calls here.
  function open(payload) {
    var args = {}
    if (payload) {
      try { args = JSON.parse(payload) || {} } catch (e) { args = {} }
    }
    // Omarchy 4.5: the theme menu (Super+Shift+Ctrl+Space, Super+Ctrl+T, menu → Theme) summons
    // the picker with {"source":"themes"} and expects it to list and apply themes itself.
    // Here the stock switcher does that: it builds the rows and opens this picker through
    // `image-selector open`, and the chosen theme is applied after it.
    if (args.source === "themes") {
      if (!themeSwitchProc.running) themeSwitchProc.running = true
      return
    }
    var dirs = String(args.imageDirs || imageDirs)
    var rows = String(args.imageRows || "")
    var sel = String(args.selectedImage || selectedImage)
    var selFile = String(args.selectionFile || "")
    var doneF = String(args.doneFile || "")
    var labels = args.showLabels === true || args.showLabels === "true"
    var filter = args.filterable === true || args.filterable === "true"
    openSelector(dirs, rows, sel, selFile, doneF, labels, filter)
  }

  function close() {
    cancel()
  }

  function preloadRows(nextImageRows, nextSelectedImage, nextShowLabels, nextFilterable) {
    // Theme/background set hooks can warm selector rows after a picker was
    // dismissed. Ignore those preloads while a user-visible request is open;
    // otherwise the preload resets layoutSettled without revealing again,
    // leaving only the fullscreen scrim.
    if (opened || requestActive) return

    requestSerial += 1
    imageRows = nextImageRows
    selectedImage = nextSelectedImage
    showLabels = nextShowLabels === true || nextShowLabels === "true"
    filterable = nextFilterable === true || nextFilterable === "true"
    filterText = ""
    liveMode = "all"
    layoutSettled = false

    if (imageRows && imageRows === loadedImageRows && imageArray.length > 0) {
      selectedIndex = selectedImageIndex()
      imagesLoaded = true
    } else if (imageRows) {
      loadRows(imageRows, false)
    }
  }

  // ── crt: фильтр трубки в выборе обоев (его Retro/wallpaper/Picker.qml — «превью прогоняет фильтр») ──
  // Фильтр включён у профиля темы (tube.json → filter.on) или своим (crt.json → filter.on). Выбранная картинка
  // фильтруется в фоне (omarchy-crt-filter, кэш) и показывается в карточке такой, какой встанет; при выборе обоями
  // ставится отфильтрованная. Уже готовые обои тем crt-* и кэш фильтра не фильтруются второй раз; темы — никогда.
  property bool crtFilterOn: false
  Process {
    id: crtProbe
    command: ["bash", "-c", "a=$(jq -r '.filter.on // false' ~/.local/state/omarchy/current/theme/tube.json 2>/dev/null); " +
      "b=$(jq -r '.filter.on // empty' ~/.config/omarchy/crt.json 2>/dev/null); echo ${b:-${a:-false}}"]
    stdout: StdioCollector { onStreamFinished: root.crtFilterOn = text.trim() === "true" }
  }
  function crtFilters(path) {
    return crtStyle && crtFilterOn && imageRows === "" && !!path && path.indexOf("/themes/crt-") === -1
      && path.indexOf("/crt-wall/") === -1 && /\.(png|jpe?g|webp)$/i.test(path)
  }
  property string crtFor: ""
  property string crtOut: ""
  Timer { id: crtLater; interval: 300; onTriggered: root.crtRun() }
  function crtRun() {
    var p = currentPath()
    if (!crtFilters(p) || p === crtFor || crtProc.running) return
    crtProc.src = p
    crtProc.command = ["omarchy-crt-filter", p]
    crtProc.running = true
  }
  Process {
    id: crtProc
    property string src: ""
    stdout: StdioCollector { onStreamFinished: { var o = text.trim(); if (o) { root.crtFor = crtProc.src; root.crtOut = o } } }
    onExited: if (root.currentPath() !== root.crtFor) crtLater.restart()
  }
  onSelectedIndexChanged: if (crtStyle && crtFilterOn) crtLater.restart()
  onCrtFilterOnChanged: if (crtFilterOn) crtLater.restart()

  Process {
    id: applyProc
    onExited: {
      if (root.applySerial === root.requestSerial)
        root.opened = false
    }
  }

  Process {
    id: releaseProc
    onExited: root.releaseNextDoneFile()
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-image-selector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened && root.imagesLoaded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      visible: root.opened && root.imagesLoaded && !root.glyphStyle && !root.modernWallsMode
      // picker: своя плотность затемнения фона (scrimAlpha), -1 — из темы.
      color: root.nierStyle ? Qt.rgba(214 / 255, 207 / 255, 181 / 255, 0.9) : root.crtStyle ? Util.alpha(Commons.Color.background, 0.95)
        : root.scrimAlpha >= 0 ? Util.alpha(root.scrim, root.scrimAlpha)
        : root.spaceStyle ? Util.alpha(Commons.Color.background, 0.82) : root.crtStyle ? Util.alpha(Commons.Color.background, 0.95) : root.scrim
    }

    // crt: двойная рамка SCREENS во весь экран, папка и счёт слева вверху, подсказки — в нижней черте
    Item {
      id: crtFrame
      anchors.fill: parent
      anchors.margins: 48
      visible: root.crtStyle && !root.crtScreensMode && root.opened && root.imagesLoaded
      readonly property color line: Util.alpha(Commons.Color.accent, 0.55)
      Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: crtFrame.line }
      Rectangle { anchors.fill: parent; anchors.margins: 3; color: "transparent"; border.width: 1; border.color: crtFrame.line }
      Rectangle {
        x: 10; y: -height / 2; width: crtHead.implicitWidth + 12; height: crtHead.implicitHeight
        color: Util.alpha(Commons.Color.background, 0.95)
        Text { id: crtHead; x: 6; text: "SCREENS"; font.family: root.crtFont; font.pixelSize: 14; font.letterSpacing: 1; color: Commons.Color.accent }
      }
      Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 10; y: parent.height - height / 2
        width: crtTail.implicitWidth + 12; height: crtTail.implicitHeight
        color: Util.alpha(Commons.Color.background, 0.95)
        Text { id: crtTail; x: 6; text: "ENTER-APPLY   ←→-SELECT   ESC-END"; font.family: root.crtFont; font.pixelSize: 11; font.letterSpacing: 1; color: Util.alpha(Commons.Color.foreground, 0.5) }
      }
      Column {
        x: 22; y: 28; spacing: 4
        Text { text: "folder:"; font.family: root.crtFont; font.pixelSize: 14; color: Util.alpha(Commons.Color.foreground, 0.5) }
        Text { text: "1  all"; font.family: root.crtFont; font.pixelSize: 14; color: Commons.Color.foreground }
      }
      Text {
        anchors { right: parent.right; rightMargin: 22; top: parent.top; topMargin: 28 }
        text: (root.imageArray.length ? root.selectedFilteredPosition() + 1 : 0) + " / " + root.imageArray.length
        font.family: root.crtFont; font.pixelSize: 14; color: Commons.Color.accent
      }
    }

    // space: служебные строки HUD по углам и уголки экрана
    Item {
      anchors.fill: parent
      visible: root.spaceStyle && root.opened && root.imagesLoaded
      Repeater {
        model: 4
        Item {
          required property int index
          x: index % 2 ? parent.width - 40 : 24
          y: index > 1 ? parent.height - 40 : 24
          width: 16; height: 16
          Rectangle { width: 16; height: 1; y: parent.index > 1 ? 15 : 0; color: Commons.Color.accent }
          Rectangle { width: 1; height: 16; x: parent.index % 2 ? 15 : 0; color: Commons.Color.accent }
        }
      }
      Column {
        x: 52; y: 46; spacing: 4
        Row {
          spacing: 8
          Rectangle { width: 6; height: 6; rotation: 45; color: Commons.Color.accent; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "WORLD SELECT"; font.family: root.spaceFont; font.pixelSize: 11; font.letterSpacing: 2; color: Commons.Color.foreground }
        }
        Text { text: "SECTOR // " + (Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name).toUpperCase() : ""); font.family: root.spaceFont; font.pixelSize: 10; font.letterSpacing: 1.6; color: Util.alpha(Commons.Color.foreground, 0.5) }
      }
      Text {
        anchors { right: parent.right; rightMargin: 52; top: parent.top; topMargin: 46 }
        text: (root.imageArray.length ? root.selectedFilteredPosition() + 1 : 0) + " / " + root.imageArray.length + "  WORLDS"
        font.family: root.spaceFont; font.pixelSize: 11; font.letterSpacing: 2; color: Commons.Color.accent
      }
      Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 46 }
        text: "←→  SCAN    ⏎  LAND    ESC  ABORT"
        font.family: root.spaceFont; font.pixelSize: 10; font.letterSpacing: 2; color: Util.alpha(Commons.Color.foreground, 0.45)
      }
    }

    // nier: сетка и служебные строки по углам (как у WallpaperPicker Unit-3)
    Item {
      anchors.fill: parent
      visible: root.nierStyle && root.opened && root.imagesLoaded
      Repeater { model: Math.ceil(parent.width / 40); Rectangle { x: index * 40; width: 1; height: parent.height; color: Qt.rgba(70 / 255, 63 / 255, 46 / 255, 0.07) } }
      Repeater { model: Math.ceil(parent.height / 40); Rectangle { y: index * 40; width: parent.width; height: 1; color: Qt.rgba(70 / 255, 63 / 255, 46 / 255, 0.07) } }
      Column {
        x: 30; y: 28; spacing: 2
        Row {
          spacing: 5
          Rectangle { width: 5; height: 5; radius: 3; color: "#6e2a2a"; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "WALLPAPER SELECT"; font.family: root.nierFont; font.pixelSize: 9; font.letterSpacing: 2; color: "#463f2e" }
        }
        Text { text: "NODE · " + (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""); font.family: root.nierFont; font.pixelSize: 9; font.letterSpacing: 2; color: "#463f2e" }
        Text { text: "壁紙選択"; font.pixelSize: 8; color: "#463f2e"; opacity: 0.7 }
      }
      Text {
        anchors { right: parent.right; rightMargin: 30; top: parent.top; topMargin: 28 }
        text: (root.imageArray.length ? root.selectedFilteredPosition() + 1 : 0) + " / " + root.imageArray.length + " NODES"
        font.family: root.nierFont; font.pixelSize: 9; font.letterSpacing: 2; color: "#463f2e"
      }
      Text {
        anchors { left: parent.left; leftMargin: 30; bottom: parent.bottom; bottomMargin: 28 }
        text: "←→ / SCROLL  NAVIGATE  ·  ⏎  APPLY  ·  ESC  QUIT"
        font.family: root.nierFont; font.pixelSize: 9; font.letterSpacing: 2; color: "#463f2e"
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.opened && root.imagesLoaded
      onClicked: root.cancel()
    }

    Item {
      id: card
      visible: root.opened && root.imagesLoaded && root.layoutSettled && root.imageArray.length > 0 && !root.glyphStyle && !root.crtScreensMode && !root.modernWallsMode
      // honeycomb — почти весь экран: сетка сот.
      width: root.honeycomb ? parent.width - 120 : Math.min(parent.width - 80, root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
      height: root.honeycomb ? parent.height - 140 : root.expandedHeight + Style.space(30) + root.bottomChromeHeight
      anchors.centerIn: parent

        MouseArea { anchors.fill: parent; onClicked: {} }

        Item {
          id: carousel
          anchors.top: parent.top
          anchors.topMargin: Style.space(30)
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.bottomChromeHeight
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.honeycomb ? card.width : root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
          clip: false
          focus: true

          readonly property real itemStep: root.sliceWidth + root.sliceSpacing
          readonly property real previewX: (width - root.expandedWidth) / 2

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              if (root.filterText) {
                root.updateFilter("")
              } else {
                root.cancel()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.applySelected()
              event.accepted = true
            } else if (root.honeycomb && (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                || ((root.keyIs(event, "j") || root.keyIs(event, "k")) && (!root.filterable || event.modifiers & Qt.ControlModifier)))) {
              // Соты: j / k и ↑ / ↓ — ряд вниз / вверх.
              root.honeyStepRow(event.key === Qt.Key_Down || root.keyIs(event, "j") ? 1 : -1)
              event.accepted = true
            } else if (root.hasLive && (root.keyIs(event, "[") || root.keyIs(event, "]")
                || (!root.honeycomb && (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                || ((root.keyIs(event, "j") || root.keyIs(event, "k")) && (!root.filterable || event.modifiers & Qt.ControlModifier)))))) {
              // Все / статичные / живые: [ ] везде, j / k и ↑ / ↓ — кроме сот (там это ряды).
              root.stepLiveMode(event.key === Qt.Key_Down || root.keyIs(event, "j") || root.keyIs(event, "]") ? 1 : -1)
              event.accepted = true
            } else if ((root.keyIs(event, "h") || root.keyIs(event, "l")) && (!root.filterable || event.modifiers & Qt.ControlModifier)) {
              // h / l — как ← / →.
              root.selectAdjacent(root.keyIs(event, "h") ? -1 : 1)
              event.accepted = true
            } else if (root.filterable && Util.editsFilter(event, root.filterText)) {
              root.updateFilter(Util.editedFilter(event, root.filterText))
              event.accepted = true
            } else if (event.key === Qt.Key_Left || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab) {
              root.selectAdjacent(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
              root.selectAdjacent(1)
              event.accepted = true
            } else if (root.filterable && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
              root.updateFilter(root.filterText + event.text)
              event.accepted = true
            }
          }

          Component.onCompleted: forceActiveFocus()

          Repeater {
            model: root.imageArray.length

            delegate: Item {
              id: item
              required property int index

              readonly property var imageData: root.imageArray[index]
              readonly property string filePath: imageData ? imageData.filePath : ""
              readonly property string fileName: imageData ? imageData.fileName : ""
              readonly property string thumbnailPath: imageData ? imageData.thumbnailPath : ""

              readonly property bool matched: root.itemMatches(index)
              readonly property int relativeIndex: root.filteredPosition(index) - root.selectedFilteredPosition()
              readonly property bool selected: matched && index === root.selectedIndex
              readonly property bool nearby: matched && Math.abs(relativeIndex) <= 16
              property bool sourceActivated: nearby
              onNearbyChanged: if (nearby) sourceActivated = true

              readonly property var cell: root.honeycomb && matched ? root.honeyCell(root.filteredPosition(index)) : null
              visible: root.honeycomb ? (cell !== null && cell.inView) : nearby
              onVisibleChanged: if (visible) sourceActivated = true
              x: root.honeycomb ? (cell ? cell.x : 0)
                : selected ? carousel.previewX : (relativeIndex < 0 ? carousel.previewX + relativeIndex * carousel.itemStep : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relativeIndex - 1) * carousel.itemStep)
              width: selected && !root.honeycomb ? root.expandedWidth : root.sliceWidth
              height: selected && !root.honeycomb ? root.expandedHeight : root.sliceHeight
              y: root.honeycomb ? (cell ? cell.y : 0)
                : selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
              scale: root.honeycomb && selected ? 1.18 : 1
              Behavior on scale { enabled: root.animMs > 0; NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
              z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)

              // picker: плавное перелистывание и поворот соседей (coverflow).
              Behavior on x { enabled: root.animMs > 0 && root.layoutSettled; NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
              Behavior on width { enabled: root.animMs > 0 && root.layoutSettled; NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
              Behavior on height { enabled: root.animMs > 0 && root.layoutSettled; NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
              Behavior on y { enabled: root.animMs > 0 && root.layoutSettled; NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
              transform: Rotation {
                origin.x: item.width / 2
                origin.y: item.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: item.selected || root.tilt === 0 ? 0 : (item.relativeIndex < 0 ? root.tilt : -root.tilt)
                Behavior on angle { enabled: root.animMs > 0; NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
              }
              // picker: polaroid — белая рамка, картинка внутри, подпись снизу.
              readonly property real framePad: root.polaroid ? 10 : 0
              readonly property real captionHeight: root.polaroid ? 34 : 0
              readonly property bool rounded: root.skewOffset === 0 && !root.honeycomb
              // dots: миниатюры — круги, превью — скруглённое.
              readonly property real itemRadius: root.dotsStyle && !selected ? Math.min(width, height) / 2 : root.cornerRadius
              // Вершины шестиугольника (острый верх) — для маски и рамки сот.
              // Шестиугольник (острый верх) со скруглёнными вершинами: вдоль ребра до 18 % от вершины, через вершину — кривая.
              readonly property string hexSvg: {
                var w = width, h = height
                var p = [[w / 2, 0], [w, h / 4], [w, h * 3 / 4], [w / 2, h], [0, h * 3 / 4], [0, h / 4]]
                var k = 0.18, out = ""
                for (var i = 0; i < 6; i++) {
                  var c = p[i], a = p[(i + 5) % 6], b = p[(i + 1) % 6]
                  var s0 = [c[0] + (a[0] - c[0]) * k, c[1] + (a[1] - c[1]) * k]
                  var s1 = [c[0] + (b[0] - c[0]) * k, c[1] + (b[1] - c[1]) * k]
                  out += (i === 0 ? "M " : "L ") + s0[0] + " " + s0[1] + " Q " + c[0] + " " + c[1] + " " + s1[0] + " " + s1[1] + " "
                }
                return out + "Z"
              }
              // dots: сборка превью из точек при каждом выборе.
              property real dotProgress: 1
              onSelectedChanged: if (selected && root.dotsStyle) { dotAnim.restart() }
              NumberAnimation { id: dotAnim; target: item; property: "dotProgress"; from: 0; to: 1; duration: 1100; easing.type: Easing.InOutQuad }
              readonly property real skAbs: Math.abs(root.skewOffset)
              readonly property real topLeft: root.skewOffset >= 0 ? skAbs : 0
              readonly property real topRight: root.skewOffset >= 0 ? width : width - skAbs
              readonly property real bottomRight: root.skewOffset >= 0 ? width - skAbs : width
              readonly property real bottomLeft: root.skewOffset >= 0 ? 0 : skAbs

              Item {
                id: maskShape
                anchors.fill: parent
                visible: false
                layer.enabled: true

                // picker: без скоса — маска-скруглённый прямоугольник.
                Rectangle {
                  visible: item.rounded
                  anchors.fill: parent
                  radius: item.itemRadius
                  color: "white"
                }

                Shape {
                  visible: root.honeycomb
                  anchors.fill: parent
                  antialiasing: true
                  preferredRendererType: Shape.CurveRenderer
                  ShapePath { fillColor: "white"; strokeColor: "transparent"; PathSvg { path: item.hexSvg } }
                }

                Shape {
                  visible: !item.rounded && !root.honeycomb
                  anchors.fill: parent
                  antialiasing: true
                  preferredRendererType: Shape.CurveRenderer
                  ShapePath {
                    fillColor: "white"
                    strokeColor: "transparent"
                    startX: item.topLeft; startY: 0
                    PathLine { x: item.topRight; y: 0 }
                    PathLine { x: item.bottomRight; y: item.height }
                    PathLine { x: item.bottomLeft; y: item.height }
                    PathLine { x: item.topLeft; y: 0 }
                  }
                }
              }

              Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                  maskEnabled: true
                  maskSource: maskShape
                  maskThresholdMin: 0.3
                  maskSpreadAtMin: 0.3
                }

                // picker: рамка polaroid под картинкой.
                Rectangle {
                  visible: root.polaroid
                  anchors.fill: parent
                  radius: root.cornerRadius
                  color: "#f4f1ea"
                  Text {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8; leftMargin: 10; rightMargin: 10 }
                    text: root.labelForPath(item.filePath)
                    color: "#2b2b2b"
                    font.pixelSize: Math.max(10, Style.font.body)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                  }
                }

                Image {
                  id: image
                  anchors.fill: parent
                  anchors.margins: item.framePad
                  anchors.bottomMargin: item.framePad + item.captionHeight
                  // Load only the initial/visited nearby images, but keep the
                  // source once activated so Qt does not tear textures down as
                  // selection moves through the carousel.
                  source: item.selected && root.crtFor !== "" && root.crtFor === item.filePath ? Util.fileUrl(root.crtOut)
                    : item.sourceActivated && item.thumbnailPath ? Util.fileUrl(item.thumbnailPath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: false
                  cache: true
                  smooth: true
                }

                // picker: dots — превью собирается из точек волной от центра; рисуется только у выбранного во время
                // сборки. Текстура — сама Image (ShaderEffectSource без окна ронял Quickshell). Не в Loader: внутри
                // него `item` — свойство Loader, а не эта карточка.
                ShaderEffect {
                  visible: root.dotsStyle && item.selected && item.dotProgress < 1 && image.status === Image.Ready
                  anchors.fill: image
                  property variant source: image
                  property real progress: item.dotProgress
                  property size size: Qt.size(width, height)
                  property real cell: 9
                  property color bg: root.dimColor
                  fragmentShader: Qt.resolvedUrl("shaders/dots.frag.qsb")
                }

                Rectangle {
                  anchors.fill: parent
                  color: Util.alpha(root.dimColor, item.selected ? 0 : root.dimUnselected)
                }

                // picker: живые обои (видео, GIF — играет owe) — значок ▶ в углу.
                Rectangle {
                  visible: ImagePickerModel.isLive(item.filePath)
                  anchors { right: image.right; bottom: image.bottom; margins: 8 }
                  width: 28; height: 28; radius: 14
                  color: Util.alpha("#000000", 0.55)
                  Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; text: "▶"; color: "#ffffff"; font.pixelSize: 12 }
                }
              }

              // space: уголки 9 px акцентом вокруг выбранной
              Repeater {
                model: root.spaceStyle && item.selected ? 4 : 0
                Item {
                  required property int index
                  x: index % 2 ? item.width + 1 : -10
                  y: index > 1 ? item.height + 1 : -10
                  width: 9; height: 9
                  Rectangle { width: 9; height: 1; y: parent.index > 1 ? 8 : 0; color: Commons.Color.accent }
                  Rectangle { width: 1; height: 9; x: parent.index % 2 ? 8 : 0; color: Commons.Color.accent }
                }
              }

              // picker: рамка без скоса — скруглённая.
              Rectangle {
                visible: item.rounded
                anchors.fill: parent
                radius: item.itemRadius
                color: "transparent"
                border.width: item.selected ? root.selectedBorderWidth : 1
                border.color: item.selected ? root.selectedBorder : root.unselectedBorder
              }

              Shape {
                visible: root.honeycomb
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "transparent"
                  strokeColor: item.selected ? root.selectedBorder : root.unselectedBorder
                  strokeWidth: item.selected ? root.selectedBorderWidth : 1
                  PathSvg { path: item.hexSvg }
                }
              }

              Shape {
                visible: !item.rounded && !root.honeycomb
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "transparent"
                  strokeColor: item.selected ? root.selectedBorder : root.unselectedBorder
                  strokeWidth: item.selected ? root.selectedBorderWidth : 1
                  startX: item.topLeft; startY: 0
                  PathLine { x: item.topRight; y: 0 }
                  PathLine { x: item.bottomRight; y: item.height }
                  PathLine { x: item.bottomLeft; y: item.height }
                  PathLine { x: item.topLeft; y: 0 }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: item.selected ? root.applySelected() : root.select(index)
              }
            }
          }
        }

        Text {
          id: selectedLabel
          textFormat: Text.PlainText
          visible: root.labelsShown
          anchors.top: carousel.bottom
          anchors.topMargin: Style.space(16)
          anchors.horizontalCenter: carousel.horizontalCenter
          width: root.expandedWidth
          text: root.currentLabel()
          color: root.nierStyle ? "#463f2e" : root.spaceStyle ? Commons.Color.foreground : root.crtStyle ? Commons.Color.accent : root.foreground
          style: root.nierStyle || root.spaceStyle || root.crtStyle ? Text.Normal : Text.Outline
          styleColor: Util.alpha(root.dimColor, 0.7)
          font.pixelSize: root.nierStyle ? 13 : root.spaceStyle ? 13 : root.crtStyle ? 15 : Style.font.display
          font.weight: root.nierStyle || root.spaceStyle || root.crtStyle ? Font.Normal : Font.DemiBold
          font.family: root.nierStyle ? root.nierFont : root.spaceStyle ? root.spaceFont : root.crtStyle ? root.crtFont : Style.font.family
          font.letterSpacing: root.nierStyle ? 3 : root.spaceStyle ? 2 : root.crtStyle ? 1 : 0
          font.capitalization: root.spaceStyle || root.crtStyle ? Font.AllUppercase : Font.MixedCase
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        // picker: переключатель «все / статичные / живые» над каруселью.
        Row {
          visible: root.hasLive
          anchors.bottom: carousel.top
          anchors.bottomMargin: Style.space(14)
          anchors.horizontalCenter: carousel.horizontalCenter
          spacing: Style.space(6)
          Repeater {
            model: root.liveModes
            Rectangle {
              required property string modelData
              readonly property bool on: root.liveMode === modelData
              height: chipText.implicitHeight + Style.space(10)
              width: chipText.implicitWidth + Style.space(24)
              radius: height / 2
              color: on ? root.foreground : Util.alpha(root.dimColor, 0.55)
              border.width: 1
              border.color: Util.alpha(root.foreground, on ? 1 : 0.3)
              Text {
                id: chipText
                anchors.centerIn: parent
                text: ({ all: root.honeycomb ? "All · [ ]" : "All · j/k", static: "Static", live: "▶ Animated" })[parent.modelData]
                color: parent.on ? root.dimColor : root.foreground
                font.pixelSize: Style.font.body
              }
              MouseArea { anchors.fill: parent; onClicked: { root.liveMode = parent.modelData; root.updateFilter(root.filterText) } }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.filterable && root.filterText
          anchors.top: selectedLabel.bottom
          anchors.topMargin: Style.space(8)
          anchors.horizontalCenter: carousel.horizontalCenter
          width: root.expandedWidth
          text: root.filterText
          color: root.foreground
          opacity: 0.85
          style: Text.Outline
          styleColor: Util.alpha(root.dimColor, 0.7)
          font.pixelSize: Style.font.title
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
    }

    // picker: стиль glyph — свой экран целиком; живёт, пока picker открыт (превью — две картинки под экран).
    Loader {
      id: glyphView
      anchors.fill: parent
      active: root.glyphStyle && root.opened && root.imagesLoaded && root.layoutSettled && root.imageArray.length > 0
      sourceComponent: Glyph.GlyphWalls { picker: root }
      onLoaded: root.focusPicker()
    }
    Loader {
      id: crtScreens
      anchors.fill: parent
      active: root.crtScreensMode && root.opened && root.imagesLoaded
      sourceComponent: CrtScreens { picker: root }
      onLoaded: item.focusIn()
    }
    Loader {
      id: modernWalls
      anchors.fill: parent
      active: root.modernWallsMode && root.opened && root.imagesLoaded
      sourceComponent: ModernWalls { picker: root }
      onLoaded: item.focusIn()
    }
  }
}
