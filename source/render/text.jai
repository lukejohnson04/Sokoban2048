
Character :: struct {
    texture : GLuint;
    size : v2i;
    bearing : v2i;
    advance : u32;
}

Font :: struct {
    characters: [256] Character;
    size: int;
}

draw_text :: (text: string, position: v2i, font: *Font, vao: GLuint, vbo: GLuint, max_width: int = 0, fancy_format: bool = false) {
    base_x  := position.x;
    base_y  := position.y;
    line_ht := font.size;           // baseline-to-baseline distance

    xpos := base_x;
    ypos := base_y;

    i : int = 0;
    while i < text.count {
        // ----------------------------------------------------------
        // 1.   Explicit newline support (when fancy_format is true)
        // ----------------------------------------------------------
        if fancy_format && text[i] == #char "\n" {
            xpos = base_x;
            ypos += line_ht;
            i += 1;
            continue;
        }

        // ----------------------------------------------------------
        // 2.   Measure the next “word” (runs up to space/newline)
        // ----------------------------------------------------------
        word_start := i;
        word_adv   : int = 0;

        while i < text.count
               && text[i] != #char " "
               && !(fancy_format && text[i] == #char "\n") {
            code     := text[i];                       // u8
            ch       := font.characters[code];    // lookup
            word_adv += ch.advance >> 6;               // FreeType stores >>6
            i += 1;
        }

        // If there *is* a space after the word, include *its* advance
        has_space := (i < text.count && text[i] == #char " ");
        if has_space {
            space_ch  := font.characters[32];          // ASCII 32 == space
            word_adv += space_ch.advance >> 6;
        }

        // ----------------------------------------------------------
        // 3.   Decide whether to wrap before drawing the word
        // ----------------------------------------------------------
        if max_width > 0 && xpos + word_adv > base_x + max_width {
            xpos = base_x;
            ypos += line_ht;
        }

        // ----------------------------------------------------------
        // 4.   Draw the word glyph-by-glyph
        // ----------------------------------------------------------
        j : int = word_start;
        while j < i {
            code := text[j];
            ch   := font.characters[code];

            w := ch.size.x;
            h := ch.size.y;
            x := xpos + ch.bearing.x;
            y := ypos - ch.bearing.y;

            glBindTexture(GL_TEXTURE_2D, ch.texture);
            draw_texture(
                .{0, 0, xx w, xx h},
                .{xx x, xx y, xx w, xx h},
                v2i.{xx w, xx h},
                vao, vbo
            );

            xpos += ch.advance >> 6;
            j += 1;
        }

        // ----------------------------------------------------------
        // 5.   Emit (and advance past) the trailing space, if any
        // ----------------------------------------------------------
        if has_space {
            space_ch := font.characters[32];
            xpos    += space_ch.advance >> 6;
            i       += 1;              // swallow the space
        }
    }
}

load_font :: (path: string, font: *Font, size: int = 48) -> bool {
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

    FT_Set_Pixel_Sizes(face, 0, xx size);
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

    font.size = size;

    return true;
}

