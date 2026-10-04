#!/usr/bin/env python3
"""Render picker thumbnails from one desktop capture and the actual ShojiWM shader."""
import ctypes
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def render_shader(image, filename, uniforms, windows=()):
    # Isolate preview rendering from the WM and its GPU context.
    os.environ["PYOPENGL_PLATFORM"] = "egl"
    os.environ["EGL_PLATFORM"] = "surfaceless"
    os.environ["LIBGL_ALWAYS_SOFTWARE"] = "true"
    os.environ["__EGL_VENDOR_LIBRARY_FILENAMES"] = "/usr/share/glvnd/egl_vendor.d/50_mesa.json"
    from OpenGL import EGL, GLES2 as gl
    from OpenGL.GLES2.shaders import compileProgram, compileShader
    from PIL import Image

    width, height = image.size
    display = EGL.eglGetDisplay(EGL.EGL_DEFAULT_DISPLAY)
    if not EGL.eglInitialize(display, None, None):
        raise RuntimeError("Could not initialize preview renderer")
    surface = EGL.EGL_NO_SURFACE
    context = EGL.EGL_NO_CONTEXT
    try:
        attributes = (EGL.EGLint * 13)(
            EGL.EGL_SURFACE_TYPE, EGL.EGL_PBUFFER_BIT,
            EGL.EGL_RENDERABLE_TYPE, EGL.EGL_OPENGL_ES2_BIT,
            EGL.EGL_RED_SIZE, 8, EGL.EGL_GREEN_SIZE, 8,
            EGL.EGL_BLUE_SIZE, 8, EGL.EGL_ALPHA_SIZE, 8, EGL.EGL_NONE)
        configs = (EGL.EGLConfig * 1)()
        count = EGL.EGLint()
        if not EGL.eglChooseConfig(display, attributes, configs, 1, count) or count.value < 1:
            raise RuntimeError("No preview EGL config")
        EGL.eglBindAPI(EGL.EGL_OPENGL_ES_API)
        surface = EGL.eglCreatePbufferSurface(display, configs[0], (EGL.EGLint * 5)(
            EGL.EGL_WIDTH, width, EGL.EGL_HEIGHT, height, EGL.EGL_NONE))
        context = EGL.eglCreateContext(display, configs[0], EGL.EGL_NO_CONTEXT,
            (EGL.EGLint * 3)(EGL.EGL_CONTEXT_CLIENT_VERSION, 2, EGL.EGL_NONE))
        EGL.eglMakeCurrent(display, surface, surface, context)
        vertex = """
            attribute vec2 position;
            varying vec2 uv;
            void main() {
                // Captured image rows and shader coordinates start at the top.
                uv = vec2(position.x * 0.5 + 0.5, 0.5 - position.y * 0.5);
                gl_Position = vec4(position, 0.0, 1.0);
            }
        """
        shader = (Path.home() / ".config/shojiwm/src/effect" / filename).read_text()
        fragment = """
            precision highp float;
            varying vec2 uv;
            uniform sampler2D tex;
            uniform vec2 size;
            struct EffectContext {
                vec2 texture_uv; vec2 texture_size_px;
                vec4 content_rect_px; vec4 frame_rect_px;
            };
        """ + shader + """
            void main() {
                gl_FragColor = shader_main(EffectContext(uv, size,
                    vec4(0.0, 0.0, size), vec4(0.0, 0.0, size)));
            }
        """
        program = compileProgram(compileShader(vertex, gl.GL_VERTEX_SHADER),
            compileShader(fragment, gl.GL_FRAGMENT_SHADER))
        gl.glUseProgram(program)
        texture = gl.glGenTextures(1)
        gl.glActiveTexture(gl.GL_TEXTURE0)
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture)
        for parameter in (gl.GL_TEXTURE_MIN_FILTER, gl.GL_TEXTURE_MAG_FILTER):
            gl.glTexParameteri(gl.GL_TEXTURE_2D, parameter, gl.GL_LINEAR)
        for parameter in (gl.GL_TEXTURE_WRAP_S, gl.GL_TEXTURE_WRAP_T):
            gl.glTexParameteri(gl.GL_TEXTURE_2D, parameter, gl.GL_CLAMP_TO_EDGE)
        gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, width, height, 0,
            gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, image.tobytes())
        gl.glUniform1i(gl.glGetUniformLocation(program, "tex"), 0)
        gl.glUniform2f(gl.glGetUniformLocation(program, "size"), width, height)
        for name, value in uniforms.items():
            location = gl.glGetUniformLocation(program, name)
            if isinstance(value, (list, tuple)):
                gl.glUniform2f(location, *value)
            else:
                gl.glUniform1f(location, value)
        if filename == "aquarium-water.frag":
            bounds = list(windows[:16])
            gl.glUniform1f(gl.glGetUniformLocation(program, "aquarium_window_count"), len(bounds))
            bounds += [[0, 0, 0, 0]] * (16 - len(bounds))
            values = (ctypes.c_float * 64)(*(component for rect in bounds for component in rect))
            gl.glUniform4fv(gl.glGetUniformLocation(program, "aquarium_windows[0]"), 16, values)
        vertices = (ctypes.c_float * 8)(-1, -1, 1, -1, -1, 1, 1, 1)
        buffer = gl.glGenBuffers(1)
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, buffer)
        gl.glBufferData(gl.GL_ARRAY_BUFFER, ctypes.sizeof(vertices), vertices, gl.GL_STATIC_DRAW)
        position = gl.glGetAttribLocation(program, "position")
        gl.glEnableVertexAttribArray(position)
        gl.glVertexAttribPointer(position, 2, gl.GL_FLOAT, False, 0, ctypes.c_void_p(0))
        gl.glViewport(0, 0, width, height)
        gl.glDrawArrays(gl.GL_TRIANGLE_STRIP, 0, 4)
        pixels = (ctypes.c_ubyte * (width * height * 4))()
        gl.glReadPixels(0, 0, width, height, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, pixels)
        return Image.frombytes("RGBA", image.size, bytes(pixels)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    finally:
        EGL.eglMakeCurrent(display, EGL.EGL_NO_SURFACE, EGL.EGL_NO_SURFACE, EGL.EGL_NO_CONTEXT)
        if context != EGL.EGL_NO_CONTEXT:
            EGL.eglDestroyContext(display, context)
        if surface != EGL.EGL_NO_SURFACE:
            EGL.eglDestroySurface(display, surface)
        EGL.eglTerminate(display)


def save_image(image, target, scene=None):
    from PIL.PngImagePlugin import PngInfo
    metadata = PngInfo()
    if scene is not None:
        metadata.add_text("shoji_scene", json.dumps(scene))
    with tempfile.NamedTemporaryFile(dir=target.parent, suffix=".png", delete=False) as handle:
        temporary = Path(handle.name)
    try:
        image.save(temporary, format="PNG", pnginfo=metadata)
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)
    return target.as_uri()


def save_preview(image, target):
    from PIL import Image
    image.thumbnail((900, 600), Image.Resampling.LANCZOS)
    return save_image(image, target)


def main():
    images = {}
    error = ""
    try:
        from PIL import Image
        output = sys.argv[1]
        scene = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        active_effect = sys.argv[3] if len(sys.argv) > 3 else "none"
        directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "shoji-shell" / "shader-previews"
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        source = directory / ("desktop-" + output.replace("/", "_") + ".png")
        if active_effect == "none":
            capture = subprocess.run(["grim", "-o", output, "-"], check=True,
                capture_output=True, timeout=4).stdout
            with Image.open(io.BytesIO(capture)) as captured:
                desktop = captured.convert("RGBA")
            save_image(desktop, source, scene)
        else:
            # Never disable the live shader or apply a second filter to its capture.
            # Older picker versions retained only a resized clean thumbnail.
            clean = source if source.exists() else directory / "none.png"
            with Image.open(clean) as captured:
                desktop = captured.convert("RGBA")
                if "shoji_scene" in captured.info:
                    scene = json.loads(captured.info["shoji_scene"])
            if clean != source:
                size = tuple(max(1, round(value)) for value in scene.get("extent", desktop.size))
                desktop = desktop.resize(size, Image.Resampling.LANCZOS)
        images["none"] = save_preview(desktop.copy(), directory / "none.png")
        for name, filename, uniforms in [
            ("retro", "retro-screen.frag", {"rows": 768, "enabled": 1}),
            ("aquarium", "aquarium-water.frag", {
                "aquarium_enabled": 1, "aquarium_phase": 0.173, "aquarium_plane": 2,
                "aquarium_slosh": [0, 0],
                "aquarium_origin": scene.get("origin", [0, 0]),
                "aquarium_extent": scene.get("extent", list(desktop.size)),
            }),
        ]:
            try:
                image = render_shader(desktop, filename, uniforms, scene.get("windows", []))
                images[name] = save_preview(image, directory / (name + ".png"))
            except Exception as failure:
                error += name + ": " + str(failure) + "; "
    except Exception as failure:
        error = "Не удалось подготовить превью: " + str(failure)
    print(json.dumps({"images": images, "error": error}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
