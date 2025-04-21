
Character :: struct {
    texture : GLuint;
    size : v2i;
    bearing : v2i;
    advance : u32;
}

Font :: struct {
    characters: [256] Character;
}

draw_text :: (text: string, position: v2i, font: *Font, vao: GLuint, vbo: GLuint) {
    xpos := position.x;
    ypos := position.y;
    for text {
        ch := *font.characters[it];
        x := xpos + ch.bearing.x;
        y := ypos - ch.bearing.y;
        w := ch.size.x;
        h := ch.size.y;
        glBindTexture(GL_TEXTURE_2D, ch.texture);
        draw_texture(.{0, 0, xx w, xx h}, .{xx x, xx y, xx w, xx h}, v2i.{xx w, xx h}, vao, vbo);
        xpos += ch.advance >> 6;
    }
}

load_font :: (path: string, font: *Font) -> bool {
    ft: FT_Library;
    if FT_Init_FreeType(*ft) {
        print("Failed to init freetype!\n");
        return false;
    }

    face: FT_Face;
    if FT_New_Face(ft, path.data, 0, *face) {
        print("Failed to load font face at path %!\n", path);
        return false;
    }

    FT_Set_Pixel_Sizes(face, 0, 48);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, face.glyph.bitmap.pitch);

    for 0..127 {
        if FT_Load_Char(face, xx it, FT_LOAD_RENDER) {
            print("Failed to load % char!\n", it);
            return false;
        }

        texture: GLuint;
        glGenTextures(1, *texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        if glGetError() != GL_NO_ERROR {
            print("OpenGL Error!\n");
            return false;
        }

        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_ALPHA,
            face.glyph.bitmap.width,
            face.glyph.bitmap.rows,
            0,
            GL_ALPHA,
            GL_UNSIGNED_BYTE,
            face.glyph.bitmap.buffer
        );

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        character := *font.characters[it];
        character.texture = texture;
        character.size = .{face.glyph.bitmap.width, face.glyph.bitmap.rows};
        character.bearing = .{face.glyph.bitmap_left, face.glyph.bitmap_top};
        character.advance = xx face.glyph.advance.x;
    }
    FT_Done_Face(face);
    FT_Done_FreeType(ft);

    return true;
}