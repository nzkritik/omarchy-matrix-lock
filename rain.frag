#version 440
// Matrix rain, one fragment per pixel. Every column is a closed-form function
// of time, so nothing is animated on the CPU: QML only advances `time`.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // item size in logical px
    float cell;         // grid pitch in logical px
    float time;         // seconds
    float glyphCount;   // glyphs in the atlas row
    float minSpeed;     // rows per second
    float maxSpeed;
    float minTrail;     // glyphs per stream
    float maxTrail;
    float churn;        // glyph swaps per second, per glyph
    vec4 background;
    vec4 headColor;
    vec4 bodyColor;
    vec4 midColor;
    vec4 tailColor;
};

layout(binding = 1) uniform sampler2D atlas;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    float col = floor(px.x / cell);
    float rows = ceil(size.y / cell);

    // Per-column constants: speed, trail length, phase, and a pause between
    // passes (the old per-pass 0-500 ms start delay, in rows).
    float speed = mix(minSpeed, maxSpeed, hash(vec2(col, 1.0)));
    float trail = floor(mix(minTrail, maxTrail + 1.0, hash(vec2(col, 2.0))));
    float gap = speed * 0.5 * hash(vec2(col, 3.0));
    float span = rows + trail + gap;
    // The random phase is what makes a freshly shown surface already full of
    // rain instead of every stream entering from the top together.
    float travel = time * speed + hash(vec2(col, 4.0)) * span;
    float pass = floor(travel / span);
    float headRow = mod(travel, span) - 1.0;

    // Position within the stream: 0 at its top (tail end), trail-1 at the head.
    float local = px.y / cell - (headRow - trail + 1.0);
    vec4 color = background;
    if (local >= 0.0 && local < trail) {
        float j = floor(local);
        float tailLen = floor(trail * 0.40);
        float midLen = floor(trail * 0.30);
        vec4 tint = j >= trail - 1.0 ? headColor
                  : j < tailLen ? tailColor
                  : j < tailLen + midLen ? midColor
                  : bodyColor;

        // Glyphs belong to the stream and ride down with it; each one also
        // flickers to a new glyph on its own random schedule.
        float seed = hash(vec2(col * 7.0 + j, pass));
        float flip = floor(time * churn + seed * 97.0);
        float glyph = floor(hash(vec2(seed * 131.0, flip)) * glyphCount);

        vec2 inCell = vec2(fract(px.x / cell), fract(local));
        float a = texture(atlas, vec2((glyph + inCell.x) / glyphCount, inCell.y)).a;
        color = mix(background, tint, a);
    }
    fragColor = color * qt_Opacity;
}
