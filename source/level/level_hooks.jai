
Hook :: struct {
    timer : float32 = 0.0;
    start_time : float32;
    active := false;
    stage := 0;
}

hook_update :: (using hook: *Hook) {
    using context.game_state;
    if start_time == 0.0 {
        start_time = xx global_timer;
    }
    timer += delta;
    elapsed_total := global_timer - start_time;

    start, end := get_camera_level_bounds(camera, *level);
    start += .{6, 6};
    end -= .{6, 6};
    stage = 1;
    if stage == 0 {
        // Spawn
        spawn_delta := 1.0;
        spawn_count := 8;
        spawn_cycles := 5;
        spawn_length := spawn_cycles * spawn_delta;
        cycle_end_margin := 1.0;
        burst_length := 0.25;
        cycle_length := spawn_length + cycle_end_margin + burst_length + cycle_end_margin;

        if elapsed_total < spawn_length + 0.1 {
            if timer > spawn_delta {
                spawns: [..]v2i;
                spawns.allocator = temp;
                for 0..spawn_count-1 {
                    pos: v2i;
                    pos.x = xx (Random.random_get() % xx (end.x-start.x));
                    pos.y = xx (Random.random_get() % xx (end.y-start.y));
                    pos += start;
                    array_add(*spawns, pos);
                }

                for spawns {
                    block := *level.floor[it.x][it.y];
                    block.* = .{};
                    block.id = 172;
                }

                timer -= spawn_delta;
            }
        } else if elapsed_total > spawn_length && elapsed_total < spawn_length + cycle_end_margin {
        } else if elapsed_total > spawn_length + cycle_end_margin && elapsed_total < spawn_length + cycle_end_margin + burst_length {
            for x: start.x..end.x {
                for y: start.y..end.y {
                    block := *level.floor[x][y];
                    elapsed := global_timer - block.spawn_time;
                    if block.id == 172 {
                        block.id = 173;
                    }
                }
            }
        } else if elapsed_total > cycle_length - cycle_end_margin && elapsed_total < cycle_length {
            for x: start.x..end.x {
                for y: start.y..end.y {
                    block := *level.floor[x][y];
                    elapsed := global_timer - block.spawn_time;
                    if block.id == 173 {
                        block.* = BLOCK_NONE;
                    }
                }
            }
        } else {
            start_time = xx global_timer;
            timer = 0.0;
            stage += 1;
        }
    } else if stage == 1 {
        spawn_delta := 2.0;
        spawn_cycles := 5;
        spawn_length := spawn_cycles * spawn_delta;
        if timer > spawn_delta {
            timer -= spawn_delta;
            // Spawn meteor
            pos: v2i;
            pos.x = xx (Random.random_get() % xx (end.x-start.x));
            pos.y = xx (Random.random_get() % xx (end.y-start.y));
            pos += start;
            block := *level.floor[pos.x][pos.y];
            block.* = .{};
            block.id = 172;

            start_pos := Vector2.{pos.x * 64.0, (start.y - 6) * 64.0};
            start_pos += .{32, 32};
            dest := Vector2.{pos.x * 64.0, pos.y * 64.0};
            dest += .{32, 32};
            meteor := add_sprite(.{.{192, 176, 32, 32}, dest});//Vector2.{pos.x * 64.0, (start.y - 6) * 64.0}});
            create_tween(*meteor.pos.y, start=start_pos.y, end=dest.y, len=2.0);

            // Spawned last meteor
            if elapsed_total > spawn_delta * spawn_cycles {
                stage = 1;
                timer = 0;
                start_time = xx global_timer;
            }
        }
    }
}
