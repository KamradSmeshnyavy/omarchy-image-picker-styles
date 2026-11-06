#!/bin/bash
# Список картинок для пикера: «картинка<TAB>миниатюра» (или сама картинка, если миниатюры нет).
#
# picker: клон стокового list.sh с одним отличием — скоростью. Сток на каждую картинку запускал
# stat, awk по всему index.tsv (десятки тысяч строк) и md5sum: 13 обоев — ~0.6 с, 150 превью тем —
# ~2.2 с. Здесь: один stat на все картинки, один awk по индексу на все, md5sum — только для тех, кого
# в индексе нет. Вывод тот же (поиск по индексу, ключ md5 «путь<TAB>размер:mtime», старые миниатюры
# по md5 содержимого).

image_dirs=${1:-}
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/image-selector
index_file="$cache_dir/index.tsv"

mkdir -p "$cache_dir"

mapfile -d '' -t images < <(
  while IFS= read -r dir; do
    [[ -n $dir && -d $dir ]] || continue
    find -L "$dir" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) \
      -print0 2>/dev/null
  done <<<"$image_dirs" | sort -z
)
((${#images[@]})) || exit 0

# Подписи «размер:mtime» — одним stat: «путь\0подпись\0»; недоступный файл stat пропускает (как раньше).
declare -A sig=()
while IFS= read -r -d '' path && IFS= read -r -d '' s; do
  sig[$path]=$s
done < <(stat -L --printf '%n\0%s:%Y\0' -- "${images[@]}" 2>/dev/null)

# Хэши из индекса — одним awk на все картинки: первое совпадение пути и подписи, как раньше.
declare -A hash=()
if [[ -f $index_file ]]; then
  while IFS=$'\t' read -r path s h; do
    hash[$path]=$h
  done < <(
    for path in "${!sig[@]}"; do printf '%s\t%s\n' "$path" "${sig[$path]}"; done |
      awk -F '\t' 'NR == FNR { want[$1 "\t" $2] = 1; next }
        { k = $1 "\t" $2 } (k in want) && !(k in seen) { seen[k] = 1; print $1 "\t" $2 "\t" $3 }' - "$index_file" 2>/dev/null
  )
fi

for image in "${images[@]}"; do
  [[ -n ${sig[$image]+x} ]] || continue
  h=${hash[$image]:-}
  if [[ -z $h ]]; then
    h=$(printf '%s\t%s' "$image" "${sig[$image]}" | md5sum)
    h=${h%% *}
  fi
  thumbnail="$cache_dir/$h.jpg"
  if [[ ! -f $thumbnail ]]; then
    # Older on-demand picker code keyed fallback thumbnails by file content.
    # Keep finding those if a user still has them cached.
    legacy_hash=$(md5sum "$image" 2>/dev/null)
    legacy_hash=${legacy_hash%% *}
    [[ -n $legacy_hash && -f $cache_dir/$legacy_hash.jpg ]] && thumbnail="$cache_dir/$legacy_hash.jpg"
  fi
  if [[ -f $thumbnail ]]; then
    printf '%s\t%s\n' "$image" "$thumbnail"
  else
    printf '%s\t%s\n' "$image" "$image"
  fi
done
