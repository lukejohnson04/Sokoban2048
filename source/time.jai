
FRAME_TIME : float32 : 1.0 / 60.0;
last_frame_time : s64 = 0;
global_clock : s64 = 0;

sleep_till_next_update :: () {
    delay_time := last_frame_time + (FRAME_TIME * 1000) - SDL_GetTicks();
    if delay_time > 0 {
        SDL_Delay(cast(u32) delay_time);
    }
    global_clock = SDL_GetTicks();
    last_frame_time = global_clock;
}
