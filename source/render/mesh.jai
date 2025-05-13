
Vertex_Component :: enum_flags {
    NONE :: 0;
    LIGHT :: 1;
    UV_DISABLED :: 2;
}

Vertex :: struct($T: Vertex_Component = .NONE) {
    x, y, z: float32;
    #if (T & .UV_DISABLED) == 0 {
        u, v: float32;
    }

    #if T & .LIGHT {
        light: float32;
    }
}

Mesh :: struct($T: Vertex_Component = .NONE) {
    vao: GLuint;
    vbo: GLuint;
    vertices: [..]Vertex(T);
}

mesh_free :: (mesh: *Mesh) {
    if mesh.vertices.count > 0 {
        mesh.vertices.count = 0;
        glDeleteBuffers(1, *mesh.vbo);
        glDeleteVertexArrays(1, *mesh.vao);
    }
}

mesh_init :: (mesh: *Mesh) {
    glGenBuffers(1, *mesh.vbo);
    glGenVertexArrays(1, *mesh.vao);
}

mesh_generate :: (mesh: *Mesh($T)) {
    glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(mesh.vertices[0])) * mesh.vertices.count, mesh.vertices.data, GL_STATIC_DRAW);
    
    param_size : u32 = size_of(float32) * 6;

    attr : u32 = 0;

    glBindVertexArray(mesh.vao);
    // position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, param_size, null);
    glEnableVertexAttribArray(0);
    attr += 1;
    // uv attribute
    glVertexAttribPointer(attr, 2, GL_FLOAT, GL_FALSE, param_size, cast(*void)(size_of(float32) * 3));
    glEnableVertexAttribArray(attr);
    attr += 1;

    // light attribute
    #if mesh.T & .LIGHT {
        glVertexAttribPointer(attr, 1, GL_FLOAT, GL_FALSE, param_size, cast(*void)(size_of(float32) * 5));
        glEnableVertexAttribArray(attr);
        attr += 1;
    }
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}



mesh_draw :: (mesh: *Mesh) {
    glBindVertexArray(mesh.vao);
    glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
    glDrawArrays(GL_TRIANGLES, 0, xx mesh.vertices.count);
}

mesh_cylinder :: (mesh_body: *Mesh, mesh_ceiling: *Mesh, sides: s64, radius: float32, height: float32) {
    polygon_points : [..]Vector2;
    polygon_points.allocator = temp;

    for side: 0..sides-1 {
        point := Vector2.{radius, 0};
        point = rotate(point, (cast(float32)side / cast(float32)sides) * PI * 2);
        array_add(*polygon_points, point);
    }

    array_add(*mesh_ceiling.vertices, Vertex.{0, height, 0, 0, 0});
    for ind: 0..sides-1 {
        // Create vertices from this point to the next
        p1 := polygon_points[ind];
        p2 := ifx ind < sides-1 then polygon_points[ind+1] else polygon_points[0];

        vertex := Vertex.{p1.x, 0, p1.y, 0, 0};
        array_add(*mesh_ceiling.vertices, .{p1.x, height, p1.y, 0, 0});
        array_add(*mesh_body.vertices, vertex);
        vertex = .{p2.x, 0, p2.y, 1, 0};
        array_add(*mesh_body.vertices, vertex);
        vertex = .{p2.x, height, p2.y, 1, 1};
        array_add(*mesh_body.vertices, vertex);
        array_add(*mesh_body.vertices, vertex);
        vertex = .{p1.x, height, p1.y, 0, 1};
        array_add(*mesh_body.vertices, vertex);
        vertex = .{p1.x, 0, p1.y, 0, 0};
        array_add(*mesh_body.vertices, vertex);
    }
    array_add(*mesh_ceiling.vertices, .{polygon_points[0].x, height, polygon_points[0].y, 0, 0});

    glGenBuffers(1, *mesh_body.vbo);
    glGenBuffers(1, *mesh_ceiling.vbo);
    glGenVertexArrays(1, *mesh_body.vao);
    glGenVertexArrays(1, *mesh_ceiling.vao);

    glBindVertexArray(mesh_body.vao);
    glBindBuffer(GL_ARRAY_BUFFER, mesh_body.vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * mesh_body.vertices.count, mesh_body.vertices.data, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(float32) * 3));
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);

    glBindVertexArray(mesh_ceiling.vao);
    glBindBuffer(GL_ARRAY_BUFFER, mesh_ceiling.vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * mesh_ceiling.vertices.count, mesh_ceiling.vertices.data, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(float32) * 3));
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}


#load "mesh_data.jai";