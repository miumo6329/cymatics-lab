"""Live preview window for a single fullscreen fragment shader.

moderngl-window でウィンドウを開き、shaders/fullscreen.vert と指定の
フラグメントシェーダをロードして、iTime / iResolution を毎フレーム
送信して描画する。

頂点バッファは使わず、頂点シェーダ側で gl_VertexID から
フルスクリーン三角形を生成する (空 VAO + glDrawArrays)。
"""

from pathlib import Path

import moderngl
import moderngl_window as mglw

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SHADER_DIR = PROJECT_ROOT / "shaders"


class Preview(mglw.WindowConfig):
    gl_version = (3, 3)
    title = "Cymatics Lab"
    window_size = (1280, 720)
    aspect_ratio = None
    resizable = True
    resource_dir = SHADER_DIR

    fragment_shader_path = "generators/test_pattern.glsl"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.prog = self.load_program(
            vertex_shader="fullscreen.vert",
            fragment_shader=self.fragment_shader_path,
        )
        self.vao = self.ctx.vertex_array(self.prog, [])

    def on_render(self, time: float, frametime: float) -> None:
        self.ctx.clear(0.0, 0.0, 0.0, 1.0)
        width, height = self.wnd.buffer_size
        if "iResolution" in self.prog:
            self.prog["iResolution"].value = (float(width), float(height))
        if "iTime" in self.prog:
            self.prog["iTime"].value = time
        self.vao.render(mode=moderngl.TRIANGLES, vertices=3)


def run() -> None:
    mglw.run_window_config(Preview)


if __name__ == "__main__":
    run()
