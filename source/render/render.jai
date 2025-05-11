
Texture :: struct {
    id: GLuint;
    width, height: s32;
    channels: s32;
}

load_texture :: (path: string, log_errors := false) -> Texture, bool {
    tex: Texture;

    data := stbi_load(path.data, *tex.width, *tex.height, *tex.channels, 0);
    if data == null {
        print("At path \"%\" Error: %\n", path, to_string(stbi_failure_reason()));
        return tex, false;
    }
    
    glGenTextures(1, *tex.id);
    glBindTexture(GL_TEXTURE_2D, tex.id);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    //glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, xx tex.width, xx tex.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    glGenerateMipmap(GL_TEXTURE_2D);

    stbi_image_free(data);
    glBindTexture(GL_TEXTURE_2D, 0);
    return tex, true;
}

draw_rect_with_outline :: (rect: Rect, thickness: int, vao: GLuint, vbo: GLuint) {
    for 0..thickness-1 {
        draw_line(.{rect.x+it, rect.y+it}, .{rect.x+rect.w-it, rect.y+it}, vao, vbo);
        draw_line(.{rect.x+rect.w-it, rect.y+it}, .{rect.x+rect.w-it, rect.y+rect.h-it}, vao, vbo);
        draw_line(.{rect.x+rect.w-it, rect.y+rect.h-it}, .{rect.x+it, rect.y+rect.h-it}, vao, vbo);
        draw_line(.{rect.x+it, rect.y+rect.h-it}, .{rect.x+it, rect.y+it - 1}, vao, vbo);
    }
}

draw_line :: (p1: Vector2, p2: Vector2, vao: GLuint, vbo: GLuint) {
    vertices := float32.[
        p1.x,         p1.y,         0,
        p2.x,         p2.y,         0
    ];

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(float32) * vertices.count, vertices.data, GL_STATIC_DRAW);

    // position
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * size_of(float32), null);
    glEnableVertexAttribArray(0);

    glDrawArrays(GL_LINES, 0, 2);
    glBindVertexArray(0);
}

draw_texture :: (source: Rect, dest: Rect, tex: *Texture, vao: GLuint, vbo: GLuint) {
    draw_texture(source, dest, .{xx tex.width, xx tex.height}, vao, vbo);
}

draw_texture :: (source: Rect, dest: Rect, texture_size: v2i, vao: GLuint, vbo: GLuint) {
    u1, u2, v1, v2 : float32;
    u1 = source.x / texture_size.x;
    u2 = (source.x + source.w) / texture_size.x;
    v1 = source.y / texture_size.y;
    v2 = (source.y + source.h) / texture_size.y;

    vertices := float32.[
        dest.x,         dest.y,         0,  u1, v1,
        dest.x+dest.w,  dest.y,         0,  u2, v1,
        dest.x+dest.w,  dest.y+dest.h,  0,  u2, v2,
        dest.x,         dest.y+dest.h,  0,  u1, v2
    ];

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(float32) * 20, *vertices, GL_STATIC_DRAW);

    glDisableVertexAttribArray(2);
    glVertexAttrib1f(2, 1.0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * size_of(float32), null);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * size_of(float32), xx (3 * size_of(float32)));
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glBindVertexArray(0);
}

draw_radial_texture :: (source: Rect, center: Vector2, radius: float, progress: float, tex: *Texture, vao: GLuint, vbo: GLuint) {
    draw_radial_texture(source, center, radius, progress, .{xx tex.width, xx tex.height}, vao, vbo);
}

draw_radial_texture :: (source: Rect, center: Vector2, radius: float, progress: float, texture_size: v2i, vao: GLuint, vbo: GLuint) {
    if progress > 1 then progress = 1;
    if progress >= 0.25 {
        top_right_dest := Rect.{center.x, center.y - radius, xx radius, xx radius};
        top_right_source := Rect.{source.x + source.w / 2, source.y, xx (source.w/2), xx (source.h/2)};
        draw_texture(top_right_source, top_right_dest, texture_size, vao, vbo);
    }
    if progress >= 0.50 {
        bot_right_dest := Rect.{center.x, center.y, xx radius, xx radius};
        bot_right_source := Rect.{source.x + source.w / 2, source.y + source.h / 2, xx (source.w/2), xx (source.h/2)};
        draw_texture(bot_right_source, bot_right_dest, texture_size, vao, vbo);
    }
    if progress >= 0.75 {
        bot_left_dest := Rect.{xx (center.x - radius), center.y, xx radius, xx radius};
        bot_left_source := Rect.{source.x, source.y + source.h / 2, xx (source.w/2), xx (source.h/2)};
        draw_texture(bot_left_source, bot_left_dest, texture_size, vao, vbo);
    }
    if progress == 1 {
        top_left_dest := Rect.{xx (center.x - radius), xx (center.y - radius), xx radius, xx radius};
        top_left_source := Rect.{source.x, source.y, xx (source.w/2), xx (source.h/2)};
        draw_texture(top_left_source, top_left_dest, texture_size, vao, vbo);
        return;
    }
    quad : int = cast(int, floor(progress * 4.0));

    p1, p2, p3: Vector2;
    p1 = center;

    u1, u2, u3, v1, v2, v3: float32;
    bonus_u, bonus_v: float32;
    u1 = source.x + source.w/2;
    v1 = source.y + source.h/2;
    rot_radians := progress * TAU;
    rot_vector := rotate(Vector2.{0, -1}, rot_radians);

    dir := rot_vector;
    scale_dst := radius / max(abs(dir.x), abs(dir.y));
    p3 = center + dir * scale_dst;
    bonus_point : Vector2;

    if quad == 0 {
        u2 = u1;
        v2 = source.y;
        p2 = .{center.x, center.y - radius};
        bonus_point = p1 + .{radius, -radius};
        bonus_u = source.x + source.w;
        bonus_v = source.y;
    } else if quad == 1 {
        u2 = source.x + source.w;
        v2 = v1;
        p2 = .{p1.x + radius, center.y};
        bonus_point = p1 + .{radius, radius};
        bonus_u = source.x + source.w;
        bonus_v = source.y + source.h;
    } else if quad == 2 {
        u2 = u1;
        v2 = source.y + source.w;
        p2 = .{p1.x, center.y + radius};
        bonus_point = p1 + .{-radius, radius};
        bonus_u = source.x;
        bonus_v = source.y + source.h;
    } else if quad == 3 {
        u2 = source.x;
        v2 = v1;
        p2 = .{p1.x - radius, center.y};
        bonus_point = p1 + .{-radius, -radius};
        bonus_u = source.x;
        bonus_v = source.y;
    }

    half_w := source.w * 0.5;
    scale_uv := half_w / max(abs(dir.x), abs(dir.y));

    u3 = u1 + dir.x * scale_uv;
    v3 = v1 + dir.y * scale_uv;

    vertices : [4]Vertex;
    vertices[0] = .{p1.x, p1.y, 0,  u1, v1};
    vertices[1] = .{p2.x, p2.y, 0,  u2, v2};
    ind := 2;

    is_bonus_point : bool = progress - (cast(float)(quad) / 4.0) > 0.125;
    if is_bonus_point {
        vertices[2] = .{bonus_point.x, bonus_point.y, 0, bonus_u, bonus_v};
        ind += 1;
    }
    vertices[ind] = .{p3.x, p3.y, 0,  u3, v3};

    for *vertices {
        it.u /= texture_size.x;
        it.v /= texture_size.y;
    }

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(float32) * (ifx is_bonus_point then 20 else 15), *vertices, GL_STATIC_DRAW);

    glDisableVertexAttribArray(2);
    glVertexAttrib1f(2, 1.0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * size_of(float32), null);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * size_of(float32), xx (3 * size_of(float32)));
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    draw_type : u32 = xx ifx is_bonus_point then GL_TRIANGLE_FAN else GL_TRIANGLES;
    point_count : u32 = xx ifx is_bonus_point then 4 else 3;
    glDrawArrays(draw_type, 0, point_count);
    glBindVertexArray(0);
}

#load "mesh.jai";
