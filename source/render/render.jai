Texture :: struct {
    width, height: s32;
    id: GLuint;
    channels: s32;
}

load_texture :: (path: string) -> Texture {
    tex: Texture;

    data := stbi_load(path.data, *tex.width, *tex.height, *tex.channels, 0);
    if data == null {
        print("No data!\n");
        return tex;
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
    return tex;
}


draw_texture :: (source: Rect, dest: Rect, tex: *Texture, vao: GLuint, vbo: GLuint) {
    u1, u2, v1, v2 : float32;
    u1 = source.x / tex.width;
    u2 = (source.x + source.w) / tex.width;
    v1 = source.y / tex.height;
    v2 = (source.y + source.h) / tex.height;

    vertices := float32.[
        dest.x,         dest.y,         0,  u1, v1,
        dest.x+dest.w,  dest.y,         0,  u2, v1,
        dest.x+dest.w,  dest.y+dest.h,  0,  u2, v2,
        dest.x,         dest.y+dest.h,  0,  u1, v2
    ];

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(float32) * 20, *vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * size_of(float32), null);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * size_of(float32), xx (3 * size_of(float32)));
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glBindVertexArray(0);
}

// draw_texture :: (source: Rect, dest: Rect, texture_size: v2i) {
//     u1, u2, v1, v2 : float32;
//     u1 = source.x / texture_size.x;
//     u2 = (source.x + source.w) / texture_size.x;
//     v1 = source.y / texture_size.y;
//     v2 = (source.y + source.h) / texture_size.y;

//     vertices := float32.[
//         dest.x,         dest.y,         0,  u1, v1,
//         dest.x+dest.w,  dest.y,         0,  u2, v1,
//         dest.x+dest.w,  dest.y+dest.h,  0,  u2, v2,
//         dest.x,         dest.y+dest.h,  0,  u1, v2
//     ];

//     glBindVertexArray(intermediate_vao);
//     glBindBuffer(GL_ARRAY_BUFFER, intermediate_vbo);
//     glBufferData(GL_ARRAY_BUFFER, size_of(float32) * 20, *vertices, GL_STATIC_DRAW);

//     glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * size_of(float32), null);
//     glEnableVertexAttribArray(0);
//     glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * size_of(float32), xx (3 * size_of(float32)));
//     glEnableVertexAttribArray(1);
//     glBindBuffer(GL_ARRAY_BUFFER, 0);

//     glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
//     glBindVertexArray(0);
// }




#load "mesh.jai";