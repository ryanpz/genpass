const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gen_exe = b.addExecutable(.{
        .name = "gen_wordlist",
        .root_source_file = b.path("src/gen_wordlist.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_gen_exe = b.addRunArtifact(gen_exe);
    run_gen_exe.addFileArg(b.path("data/wordlist.txt"));
    const generated_words_file = run_gen_exe.addOutputFileArg("words.zon");

    const gen_write_files = b.addUpdateSourceFiles();
    gen_write_files.addCopyFileToSource(generated_words_file, "src/gen/words.zon");

    run_gen_exe.step.dependOn(&gen_exe.step);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "genpass",
        .root_module = exe_mod,
    });

    exe.step.dependOn(&gen_write_files.step);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
