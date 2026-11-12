#version 440
// picker «dots» (по мотивам glyph-rice, код свой): превью собирается из точек волной от центра.
// progress 0 → 1: сначала растут точки сетки cell (крупнее на светлом, цвет — центр клетки), потом
// они растворяются в полную картинку. Собирается в dots.frag.qsb: /usr/lib/qt6/bin/qsb --qt6 -o shaders/dots.frag.qsb shaders/dots.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 size;
    float cell;
    vec4 bg;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 c = (floor(px / cell) + 0.5) * cell;
    vec2 uvc = clamp(c / size, 0.0, 1.0);
    vec3 col = texture(source, uvc).rgb;
    // Волна: от центра к углам (d 0 … 1).
    float d = length(uvc - 0.5) * 1.414;
    float w = clamp(progress * 1.5 - d * 0.5, 0.0, 1.0);
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float r = cell * 0.5 * (0.35 + 0.65 * lum) * smoothstep(0.0, 0.45, w);
    float dist = length(px - c);
    float inDot = 1.0 - smoothstep(r - 0.8, r + 0.4, dist);
    vec3 dotted = mix(bg.rgb, col, inDot);
    float fill = smoothstep(0.8, 1.0, w);
    vec3 full = texture(source, qt_TexCoord0).rgb;
    fragColor = vec4(mix(dotted, full, fill), 1.0) * qt_Opacity;
}
