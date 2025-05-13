#run build();

build :: () {
    // Build executable
    {
        w := compiler_create_workspace();

        options := get_build_options();
        options.output_executable_name = "first";
        set_optimization(*options, .DEBUG);

        set_build_options(*options, w);
        add_build_file("source/main.jai", w);

        set_build_options_dc(.{do_output=false});
    }

    // Build DLL
    {
        w := compiler_create_workspace();

        options := get_build_options();
        options.output_path = ".build";
        options.output_executable_name = "game";
        options.output_type = .DYNAMIC_LIBRARY;
        options.stack_trace = false;
        set_optimization(*options, .DEBUG);

        set_build_options(*options, w);
        add_build_file("source/game.jai", w);

        set_build_options_dc(.{do_output=false});
    }
}

#import "Compiler";