
Shader :: struct {
    id: GLuint;
}

use_shader :: (shader: Shader) {
    glUseProgram(shader.id);
}

shader_uniform :: (using shader: Shader, name: *u8, a: *Matrix4, transpose := true) {
    glUniformMatrix4fv(glGetUniformLocation(id, name), 1, xx transpose, xx a);
}

shader_uniform :: (using shader: Shader, name: *u8, a: s32) {
    glUniform1i(glGetUniformLocation(id, name), a);
}

shader_uniform :: (using shader: Shader, name: *u8, a: float32) {
    glUniform1f(glGetUniformLocation(id, name), a);
}

bind_texture :: (tex: GLuint, tex_num: GLuint = 0, tex_type: GLuint = GL_TEXTURE_2D) {
    if tex_num != 0 {
        glActiveTexture(tex_num);
    }
    glBindTexture(tex_type, tex);
}

bind_texture :: (texture: Texture, tex_num: GLuint = 0, tex_type: GLuint = GL_TEXTURE_2D) {
    if tex_num != 0 {
        glActiveTexture(tex_num);
    }
    glBindTexture(tex_type, texture.id);
}

compile_shader :: (source: string, type: GLenum) -> id: GLuint {
    shader : GLuint = glCreateShader(type);
    glShaderSource(shader, 1, *source.data, null);
    glCompileShader(shader);

    success : s32;
    glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
    if !success {
        info_log : [256] u8;
        glGetShaderInfoLog(shader, 256, null, xx *info_log);
        print("%", cast(string) info_log);
    }

    return shader;
}

create_shader :: (using shader: *Shader, vert_path: string, frag_path: string) {
    id = create_shader_program(vert_path, frag_path);
}

create_shader_program :: (vert_path: string, frag_path: string) -> GLuint {

    vert_code := read_entire_file(vert_path);
    frag_code := read_entire_file(frag_path);
    
    vert_shader := compile_shader(vert_code, GL_VERTEX_SHADER);
    frag_shader := compile_shader(frag_code, GL_FRAGMENT_SHADER);

    shader_program := glCreateProgram();
    glAttachShader(shader_program, vert_shader);
    glAttachShader(shader_program, frag_shader);
    glLinkProgram(shader_program);

    success : s32;
    glGetProgramiv(shader_program, GL_LINK_STATUS, *success);
    if !success {
        print("Failed to link shader program!\n");
    }

    glDeleteShader(vert_shader);
    glDeleteShader(frag_shader);

    return shader_program;
}
