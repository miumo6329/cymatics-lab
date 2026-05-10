#version 330

// Fullscreen triangle covering clip space [-1, 1]^2.
// Drawn with glDrawArrays(GL_TRIANGLES, 0, 3) and no VBO.
// One triangle is cheaper than a quad and avoids diagonal seam artifacts.

out vec2 v_uv;

void main() {
    vec2 pos = vec2(
        (gl_VertexID == 1) ? 3.0 : -1.0,
        (gl_VertexID == 2) ? 3.0 : -1.0
    );
    v_uv = pos * 0.5 + 0.5;
    gl_Position = vec4(pos, 0.0, 1.0);
}
