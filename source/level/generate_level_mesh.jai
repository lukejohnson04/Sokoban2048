
Level_Mesh :: struct {
    tiles: Mesh(.LIGHT);
    goal: Mesh(.LIGHT);
    gold: Mesh(.LIGHT);
}

compute_light_value :: (field: Visibility_Field, x: int, y: int) -> float {
    level: float;
    level = xx field[x][y].steps;
    // Block can't be reached - not visible at all
    if field[x][y].visible == false || field[x][y].visited == false {
        return 0;
    }
    level = max(0.0, (level - 1));
    level = min(level, 12);
    return 1;//pow(0.9, level);
}


compute_vertex_light :: (blocks: type_of(Level.grid), light_levels: [Level.MAX_WIDTH][Level.MAX_HEIGHT] float, x: int, y: int) -> float {
    light: float;
    samples: int;
    for dx: 0..1 {
        for dy: 0..1 {
            ax := x + dx - 1;
            ay := y + dy - 1;

            if light_levels[ax][ay] == 0 continue;
            
            light += light_levels[ax][ay];
            samples += 1;
        }
    }

    return ifx samples > 0 then (light / samples) else 0;
}


generate_level_mesh :: () {
    using context.game_state;
    mesh: *Level_Mesh = *world_mesh;
    mesh_free(*mesh.tiles);
    mesh_free(*mesh.gold);
    mesh_free(*mesh.goal);
    
    mesh_init(*mesh.tiles);
    mesh_init(*mesh.gold);
    mesh_init(*mesh.goal);

    lighting_enabled := !context.game_state.editor.editing_level;

    light_levels: [Level.MAX_WIDTH][Level.MAX_HEIGHT] float;
    for x: 0..level.dimensions.x {
        for y: 0..level.dimensions.y {
            light_levels[x][y] = compute_light_value(field, x, y);
        }
    }

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

                if block.flags & .FLIPPED_X {
                    dest.x += dest.w;
                    dest.w *= -1;
                }
                if block.flags & .FLIPPED_Y {
                    dest.y += dest.h;
                    dest.h *= -1;
                }


                vertices := Vertex(.LIGHT).[
                    .{dest.x,           dest.y,         0, u1, v1, 0},
                    .{dest.x+dest.w,    dest.y,         0, u2, v1, 0},
                    .{dest.x+dest.w,    dest.y+dest.h,  0, u2, v2, 0},

                    .{dest.x,           dest.y,         0, u1, v1, 0},
                    .{dest.x,           dest.y+dest.h,  0, u1, v2, 0},
                    .{dest.x+dest.w,    dest.y+dest.h,  0, u2, v2, 0},
                ];

                vertex_directions := v2i.[.{0, 0}, .{1, 0}, .{1, 1}, .{0, 0}, .{0, 1}, .{1, 1}];

                for *vertices {
                    if lighting_enabled {
                        pos := v2i.{x,y} + vertex_directions[it_index];
                        it.light = compute_vertex_light(blocks.*, light_levels, pos.x, pos.y);
                    } else {
                        it.light = 1;
                    }

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

    mesh_generate(*mesh.tiles);
    mesh_generate(*mesh.gold);
    mesh_generate(*mesh.goal);
}
