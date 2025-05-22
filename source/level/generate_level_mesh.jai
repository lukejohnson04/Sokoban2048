
Level_Mesh :: struct {
    floor: Mesh;
    tiles: Mesh;
    goal: Mesh;
    gold: Mesh;

    // Overall buffer for combined render of every light mask 
    light_buffer: Framebuffer;
}

generate_level_mesh :: () {
    using context.game_state;
    mesh: *Level_Mesh = *world_mesh;
    mesh_free(*mesh.floor);
    mesh_free(*mesh.tiles);
    mesh_free(*mesh.gold);
    mesh_free(*mesh.goal);
    
    mesh_init(*mesh.floor);
    mesh_init(*mesh.tiles);
    mesh_init(*mesh.gold);
    mesh_init(*mesh.goal);

    light_count = 0;

    generate_mesh_of_layer :: (blocks: *type_of(Level.grid), mesh_layer: *Mesh) #expand {
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

                vertices := Vertex.[
                    .{dest.x,           dest.y,         0, u1, v1},
                    .{dest.x+dest.w,    dest.y,         0, u2, v1},
                    .{dest.x+dest.w,    dest.y+dest.h,  0, u2, v2},

                    .{dest.x,           dest.y,         0, u1, v1},
                    .{dest.x,           dest.y+dest.h,  0, u1, v2},
                    .{dest.x+dest.w,    dest.y+dest.h,  0, u2, v2},
                ];

                vertex_directions := v2i.[.{0, 0}, .{1, 0}, .{1, 1}, .{0, 0}, .{0, 1}, .{1, 1}];

                for *vertices {
                    if block_is_goal(block) {
                        if block.flags & .GOAL {
                            array_add(*mesh.goal.vertices, it);
                        } else {
                            array_add(*mesh.gold.vertices, it);
                        }
                    } else {
                        array_add(*mesh_layer.vertices, it);
                    }
                }

                is_player := level.player_pos.x == xx x && level.player_pos.y == xx y;
                if is_player || (block.type == .WALL && block.number == 7) {
                    light := *lights[light_count];
                    light.mesh.count = 0;

                    light_pos := (Vector2.{xx x, xx y} + Vector2.{0.5, 0.5}) * 64;
                    init_light(light, light_pos, 5.5 * 64);
                    compute_light_points(light);
                    _light_iter = light;
                    Sort.quick_sort(light.mesh, angle_sort_clockwise);
                    light_count += 1;
                }
            }
        }
    }
    generate_mesh_of_layer(*level.floor, *mesh.floor);
    generate_mesh_of_layer(*level.grid, *mesh.tiles);

    mesh_generate(*mesh.floor);
    mesh_generate(*mesh.tiles);
    mesh_generate(*mesh.gold);
    mesh_generate(*mesh.goal);

    if mesh.light_buffer.id == 0 {
        mesh.light_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);
    }
}
