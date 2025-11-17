
random_unit_vector :: () -> Vector2 {
    time := current_time_monotonic();
    seed := to_microseconds(time);
    Random.random_seed(<< (cast(*u64) *seed));

    rand_num := Random.random_get_within_range(0, 360);
    return radians_to_vector(rand_num);
}
