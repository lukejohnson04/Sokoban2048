Level_Mesh :: struct {
    tiles: Mesh;
    goal: Mesh;
    gold: Mesh;
}


generate_level_mesh :: (using game_state: *Game_State) {
    mesh: *Level_Mesh = *world_mesh;
    mesh_free(*mesh.tiles);
    mesh_free(*mesh.gold);
    mesh_free(*mesh.goal);
    mesh_init(*mesh.tiles);
    mesh_init(*mesh.gold);
    mesh_init(*mesh.goal);
    // vfield_generate_flood_fill(*level, field);
    
    generate_mesh_of_layer :: (blocks: *type_of(Level.grid)) #expand {
        for x: 0..level.dimensions.x {
            for y: 0..level.dimensions.y {
                block := blocks.*[x][y];
                if block == .{} continue;

                if editor.editing_level == false && field[x][y].visible == false {
                    continue;
                }

                source, dest: Rect;

                source = get_block_source(blocks.*[x][y]);
                dest = Rect.{xx (x * 64), xx (y * 64), 64, 64};
                
                u1, u2, v1, v2 : float32;
                u1 = source.x / 128.0;
                u2 = (source.x + source.w) / 128.0;
                v1 = source.y / 128.0;
                v2 = (source.y + source.h) / 128.0;

                vertices := Vertex.[
                    .{dest.x,           dest.y,         0, u1, v1},
                    .{dest.x+dest.w,    dest.y,         0, u2, v1},
                    .{dest.x+dest.w,    dest.y+dest.h,  0, u2, v2},

                    .{dest.x,           dest.y,         0, u1, v1},
                    .{dest.x,           dest.y+dest.h,  0, u1, v2},
                    .{dest.x+dest.w,    dest.y+dest.h,  0, u2, v2},
                ];

                for vertices {
                    if block_is_goal(block) {
                        if block.flags & .GOAL {
                            array_add(*mesh.goal.vertices, it);
                        } else {
                            array_add(*mesh.gold.vertices, it);
                        }
                    } else {
                        array_add(*mesh.tiles.vertices, it);
                    }
                }
            }
        }
    }
    generate_mesh_of_layer(*level.floor);
    generate_mesh_of_layer(*level.grid);

    buffers_init :: (mesh: *Mesh) #expand {
        glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
        glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * mesh.vertices.count, mesh.vertices.data, GL_STATIC_DRAW);
        
        param_size : u32 = size_of(float32) * 5;

        glBindVertexArray(mesh.vao);
        // position attribute
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, param_size, null);
        glEnableVertexAttribArray(0);
        // texture coord attribute
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, param_size, cast(*void)(size_of(float32) * 3));
        glEnableVertexAttribArray(1);
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

    buffers_init(*mesh.tiles);
    buffers_init(*mesh.gold);
    buffers_init(*mesh.goal);
}
