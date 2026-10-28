# Omarchy Image Picker Styles

[🇷🇺 Русский](README.ru.md)

Six styles for the [Omarchy](https://omarchy.org) image picker — the overlay behind the theme switcher and
the wallpaper switcher. A clone of the stock `omarchy.image-picker`; navigation, search and selection are
unchanged.

![Styles](screenshots/styles.webp)

`slices` (stock), `cards`, `coverflow`, `polaroid`, `strip`, `wide`.

## Install

```sh
omarchy plugin add https://github.com/KamradSmeshnyavy/omarchy-image-picker-styles --enable
omarchy restart shell
echo '{"style": "coverflow"}' > ~/.config/omarchy/image-picker.json
```

Open it as usual: Super+Shift+Ctrl+Space (themes) or Super+Ctrl+Space (wallpapers). Back to the stock
picker: `omarchy plugin enable omarchy.image-picker`.

Tested on Omarchy 4.0.6 with Quickshell 0.3.2.

## Settings — `~/.config/omarchy/image-picker.json`

Read on the fly. `style` picks a preset; every other key overrides one number of it. `0` / `-1` or a missing
key means "use the style's (or the theme's) value".

| Key | |
|---|---|
| `style` | `slices` `cards` `coverflow` `polaroid` `strip` `wide` |
| `expandedWidth`, `expandedHeight` | size of the selected image |
| `sliceWidth`, `sliceHeight` | size of the others |
| `spacing` | gap between them (negative = overlap) |
| `skew` | slant of the slices |
| `cardRadius` | corner radius |
| `dim` | dimming of unselected images, 0–1 (default 0.42) |
| `selectedBorder` | border width of the selected one (default 3) |
| `animMs` | animation length (default 160) |
| `scrimAlpha` | background scrim alpha; -1 — from the theme |
| `labels` | `true` — always show names |

Changes against the stock `ImagePicker.qml` are marked `// picker:`.

In [my dotfiles](https://github.com/KamradSmeshnyavy/dotfiles) the style and numbers are tuned in the
Customizer overlay, which can also pre-cache thumbnails after every theme change — that is what makes the
pickers open instantly with hundreds of wallpapers.

## License

MIT. Based on `omarchy.image-picker` from [Omarchy](https://github.com/basecamp/omarchy) (MIT, © David
Heinemeier Hansson).
