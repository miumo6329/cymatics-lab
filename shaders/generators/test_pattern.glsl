#version 330

// Placeholder generator: animated radial waves with a slow hue shift.
// Used as the default fragment shader until a real generator is wired in.
// Uniforms follow Shadertoy convention:
//   iResolution : viewport size in pixels
//   iTime       : seconds since start

in  vec2 v_uv;
out vec4 fragColor;

uniform vec2  iResolution;
uniform float iTime;

vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = v_uv;
    vec2 p  = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    float r    = length(p);
    float ang  = atan(p.y, p.x);
    float wave = 0.5 + 0.5 * sin(10.0 * r - iTime * 2.0 + 3.0 * ang);

    vec3 col = hsv2rgb(vec3(fract(0.6 + 0.1 * iTime + 0.2 * ang), 0.7, wave));
    fragColor = vec4(col, 1.0);
}
