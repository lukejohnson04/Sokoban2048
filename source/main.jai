
window : *SDL_Window;

#import "Remap_Context";

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    if SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) != 0 {
        print("Failed to initialize SDL!\n");
        return;
    }

    if TTF_Init() != 0 {
        print("Error: %s\n", TTF_GetError()); 
        return;
    }

    if Mix_OpenAudio( 44100, MIX_DEFAULT_FORMAT, 2, 2048 ) < 0 {
        print("SDL_mixer could not initialize! SDL_mixer Error: %\n", Mix_GetError());
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, cast(s32) SDL_GL_CONTEXT_PROFILE_CORE);

    window = SDL_CreateWindow("Hello",
                              SDL_WINDOWPOS_UNDEFINED,
                              SDL_WINDOWPOS_UNDEFINED,
                              WINDOW_WIDTH,
                              WINDOW_HEIGHT,
                              SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);

    glContext : SDL_GLContext = SDL_GL_CreateContext(window);
    if !glContext {
        print("Error making SDL GL context!\n");
    }

    SDL_GL_MakeCurrent(window, glContext);

    gl_load(*gl);

    imgui_context := ImGui.CreateContext();
    ImGui.SetCurrentContext(imgui_context);
    ImGui_ImplSdl_Init(window);

    // Setup style
    ImGui.StyleColorsDark();

    io := ImGui.GetIO();

    glViewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
    glEnable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    SDL_GL_SetSwapInterval(cast(s32) VSYNC);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    screenSurface := SDL_GetWindowSurface(window);


    global_game_code: win32_game_code;
    LoadGameCode(*global_game_code);
    game_memory : *void = VirtualAlloc(null, 1024*1024*1024, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if game_memory == null {
        print("Error: Failed to allocate game memory!\n");
    }

    input := Input_State.{};
    last_refresh_time := seconds_since_init();
    just_reloaded_dll := false;
    while input.just_closed_window == false {
        curr_time := seconds_since_init();
        time := curr_time - last_refresh_time;
        if time > 0.1 {
            last_refresh_time = curr_time;
            new_WriteTime := Win32GetLastWriteTime(".build/game.dll");
            if (CompareFileTime(*new_WriteTime, *global_game_code.LastWriteTime) != 0) {
                UnloadGameCode(*global_game_code);
                LoadGameCode(*global_game_code);
                just_reloaded_dll = true;
            }
        }

        poll_input(*input);
        if global_game_code.UpdateAndRender != null {
            global_game_code.UpdateAndRender(game_memory, *input, window, *just_reloaded_dll, imgui_context);
        }
    }

    SDL_DestroyWindow(window);
    SDL_Quit();
}


WINDOW_WIDTH :: 1280;
WINDOW_HEIGHT :: 720;
VSYNC :: true;

#import "Windows";
#import "String";
#import "SDL";
#import "SDL_ttf";
#import "SDL_mixer";
#import "GL";
#import "File";
#import "stb_image";

#load "math.jai";
#load "input.jai";
#load "imgui.jai";
#load "win32/code_reload.jai";