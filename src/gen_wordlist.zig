const std = @import("std");

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa = debug_allocator.allocator();
    defer {
        _ = debug_allocator.deinit();
    }

    const argv = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, argv);

    const input_filepath = argv[1];
    const output_filepath = argv[2];

    var word_list = try std.fs.cwd().openFile(input_filepath, .{});
    defer word_list.close();
    var br = std.io.bufferedReader(word_list.reader());
    var reader = br.reader();

    var output_file = try std.fs.cwd().createFile(output_filepath, .{});
    defer output_file.close();
    var bw = std.io.bufferedWriter(output_file.writer());
    const writer = bw.writer();

    const opener =
        \\.{
        \\    .words = .{
        \\
    ;
    const closer =
        \\    },
        \\}
        \\
    ;

    try writer.writeAll(opener);

    var buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try writer.print(
            \\        "{s}",
            \\
        , .{line});
    }

    try writer.writeAll(closer);
    try bw.flush();
}
