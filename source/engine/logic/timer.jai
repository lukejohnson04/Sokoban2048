// Usage
// timer := create_timer(2.0, false);
// .. in game loop ..
//      if timer_timeout(*timer) {
//          print("Timer is done!");
//      }
//

// Todo: There should I be a way for the timer to work relative to a certain timer
// For example, if the game is paused, timers will automatically continue accumulating.
// To fix this, instead of using seconds_since_init(), we would replace it with our own
// procedure like "seconds_since_game_started()". start_time in the timer would be
// set to this on init, and the procudure would be tied to a float64 that would start
// at 0 and only be incremented by delta when the game is running / in a certain context.

// We could perhaps have a global timer that we call timer_tick on by a delta. Every timer
// has a timer reference and it defaults to this global timer. timer_tick is called every
// frame. Then we could control when timers accumulate without having to iterate and
// pause/unpause a bunch of them. We also wouldn't have to remember to call timer_tick
// for every timer, we'd just need it for the global ones.       


Timer :: struct {
    start_time: float64;
    length: float64;
    repeat := false;
    running := false;
}

create_timer :: (length: float64, repeat: bool) -> Timer {
    return Timer.{seconds_since_init(), length, repeat, true};
}

timer_timeout :: (timer: *Timer) -> bool {
    if timer.running == false || timer.length == 0 {
        return false;
    }

    time := seconds_since_init();
    timeout := false;
    if time - timer.start_time >= timer.length {
        timeout = true;
        if timer.repeat {
            timer.start_time = time;
        } else {
            timer.running = false;
        }
    }
    return timeout;
}

timer_elapsed :: (timer: *Timer) -> float64 {
    time := seconds_since_init();
    elapsed := time - timer.start_time;
    return elapsed;
}

timer_stop :: (timer: *Timer) {
    timer.running = false;
}

timer_play :: (timer: *Timer) {
    timer.start_time = seconds_since_init();
    timer.running = true;
}
