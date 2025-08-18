const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const words = parseWordlist(b, "data/wordlist.txt") catch |err| {
        std.debug.panic("Failed to parse wordlist: {}\n", .{err});
    };

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const options = b.addOptions();
    options.addOption([]const []const u8, "words", words);
    exe_mod.addOptions("build_config", options);

    const exe = b.addExecutable(.{
        .name = "genpass",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

pub fn parseWordlist(b: *std.Build, input_filepath: []const u8) ![]const []const u8 {
    var words = std.ArrayList([]const u8).init(b.allocator);

    var word_list = try std.fs.cwd().openFile(input_filepath, .{});
    defer word_list.close();
    var br = std.io.bufferedReader(word_list.reader());
    var reader = br.reader();

    var buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len > 0) {
            try words.append(b.dupe(trimmed));
        }
    }
    return words.toOwnedSlice();
}
