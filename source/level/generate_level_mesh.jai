
Level_Mesh :: struct {
    floor: Mesh;
    tiles: Mesh;
    goal: Mesh;
    gold: Mesh;
    timer: Mesh;

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
    mesh_free(*mesh.timer);
    
    mesh_init(*mesh.floor);
    mesh_init(*mesh.tiles);
    mesh_init(*mesh.gold);
    mesh_init(*mesh.goal);
    mesh_init(*mesh.timer);

    light_count = 0;

    generate_mesh_of_layer :: (blocks: *type_of(Level.grid), mesh_layer: *Mesh, generate_lights: bool) #expand {
        for x: 0..level.dimensions.x-1 {
            for y: 0..level.dimensions.y-1 {
                block := blocks.*[x][y];
                if block.flags & .TIMER {
                    if timer_is_active(block) == false {
                        continue;
                    }
                }
                // Empty block
                is_player := level.player_pos.x == xx x && level.player_pos.y == xx y;
                if block.id == 0 && is_player == false continue;
                if generate_lights {
                    if is_player || block_is_light_source(block) {
                        light := *lights[light_count];
    
                        light_pos := (Vector2.{xx x, xx y} + Vector2.{0.5, 0.5}) * 64;
                        color := ifx is_player then Vector4.{1,1,1,1} else Vector4.{1,1,0,1};
                        init_light(light, light_pos, 5.5 * 64, color);

                        compute_light_points(light);
                        
                        array_add(*light.mesh, light.mesh[1]);
                        for *corner: light.mesh {
                            corner.x -= light.pos.x;
                            corner.y -= light.pos.y;
                            corner.x += light.radius;
                            corner.y += light.radius;
                        }

                        light_count += 1;
                    }
                }

                empty_block :: Block.{};
                if block == empty_block continue;

                if editor.editing_level == false && field[x][y].visible == false {
                    continue;
                }

                source, dest: Rect;

                source = get_block_source(blocks.*[x][y]);
                dest = Rect.{xx (x * 64), xx (y * 64), 64, 64};
                
                u1, u2, v1, v2 : float32;
                u1 = source.x / sprites.width;
                u2 = (source.x + source.w) / sprites.width;
                v1 = source.y / sprites.height;
                v2 = (source.y + source.h) / sprites.height;

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
            }
        }
    }


    generate_mesh_of_layer(*level.floor, *mesh.floor, false);
    generate_mesh_of_layer(*level.grid, *mesh.tiles, true);

    // Note to self: the main performance issue I have identified so far is the light point compute time in the
    // "compute_light_points" procedure. Profile this procedure further. It might be faster to do all the
    // compute_light_point calls in one big batch because right now it could be a bit random when it does the calls.
    mesh_generate(*mesh.floor);
    mesh_generate(*mesh.tiles);
    mesh_generate(*mesh.gold);
    mesh_generate(*mesh.goal);
    mesh_generate(*mesh.timer);

    if mesh.light_buffer.id == 0 {
        mesh.light_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);
    }
}
