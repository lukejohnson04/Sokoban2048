Particle_System :: struct {
    count: int;
    particles: [MAX_PARTICLES] Particle;

    MAX_PARTICLES :: 256;
}

Particle :: struct {
    #as using pos: Vector2;
    life_length: float32;
    lifetime: float32;

    vel: Vector2;

    size_start: float32 = 1.0;
    size_end: float32;
}


spawn_particle :: (system: *Particle_System, dest: Vector2) {
    particle := *system.particles[system.count];
    system.count += 1;
}

spawn_particle :: (system: *Particle_System) -> *Particle {
    particle := *system.particles[system.count];
    particle.* = .{};
    system.count += 1;
    return particle;
}

particles_update_and_render :: (using system: *Particle_System) {
    using context.game_state;
    bind_texture(sprite_particles);

    ind := 0;
    while ind < count {
        defer ind += 1;
        particle := *particles[ind];

        particle.lifetime += delta;
        if particle.lifetime > particle.life_length || particle.life_length == 0 {
            particles[ind] = particles[count - 1];
            count -= 1;
            ind -= 1;
            continue;
        }

        // Update
        particle.pos += particle.vel * delta;

        // Render
        source := Rect.{0, 0, 8, 8};
        dest := Rect.{xx particle.x, xx particle.y, 16, 16};
        dest.w = lerp(16.0 * particle.size_start, 16.0 * particle.size_end, particle.lifetime / particle.life_length);
        dest.h = lerp(16.0 * particle.size_start, 16.0 * particle.size_end, particle.lifetime / particle.life_length);
        dest.x -= dest.w / 2;
        dest.y -= dest.h / 2;

        draw_texture(source, dest, sprite_particles);
    }
}
