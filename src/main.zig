const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const build_config = @import("build_config");

const words = build_config.words;
const max_word_len = build_config.max_word_len;

const default_passphrase_word_count = 6;
const delimiter = "-";

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    const argv = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, argv);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    const opts = parseArgs(argv, stderr) catch {
        try printUsage(std.fs.path.basename(argv[0]), stderr);
        try stderr.flush();
        std.process.exit(1);
    };

    if (opts.help) {
        try printUsage(std.fs.path.basename(argv[0]), stderr);
        try stderr.flush();
        return;
    }

    if (opts.version) {
        try stdout.print("{s}\n", .{build_config.version});
        try stdout.flush();
        return;
    }

    var passphrase = std.ArrayList(u8).empty;
    defer passphrase.deinit(gpa);

    const rng = Rng.init(std.crypto.random);

    var word_buffer: [max_word_len + 1]u8 = undefined;
    var i: u8 = 0;
    while (i < opts.num_words) : (i += 1) {
        const chosen_word = words[rng.gen(words.len - 1)];
        const formatted = formatWord(&word_buffer, rng, chosen_word);
        try passphrase.writer(gpa).print("{s}{s}", .{
            formatted,
            if (i == opts.num_words - 1) "\n" else delimiter,
        });
    }

    try stdout.print("{s}", .{passphrase.items});
    try stdout.flush();
}

const Opts = struct {
    num_words: u8 = default_passphrase_word_count,
    help: bool = false,
    version: bool = false,
};

const OptParseError = error{ MissingArgs, InvalidArgs };

fn printUsage(prog_name: []const u8, writer: *std.Io.Writer) !void {
    try writer.print(
        \\NAME
        \\    {0s} - generate a random passphrase
        \\
        \\SYNOPSIS
        \\    {0s} [COMMAND]
        \\    {0s} [OPTIONS...]
        \\
        \\COMMANDS
        \\    version
        \\        Print the version of {0s}.
        \\
        \\OPTIONS
        \\    -n NUM_WORDS
        \\        Output a passphrase that is `NUM_WORDS` words long (max
        \\        255, defaults to 6).
        \\
        \\    -h
        \\        Print the help output for {0s}.
        \\
    , .{prog_name});
}

/// Parses runtime arguments for commands and POSIX-style short options.
fn parseArgs(argv: [][:0]u8, err_writer: *std.Io.Writer) !Opts {
    var opts: Opts = .{};

    var optind: usize = 1;
    while (optind < argv.len) {
        const opt = argv[optind];

        if (opt[0] != '-') {
            // commands
            if (std.mem.eql(u8, opt, "version")) {
                return .{ .version = true };
            } else {
                try err_writer.print("error: unknown command: {s}\n\n", .{opt});
                return error.InvalidArgs;
            }
        } else {
            // options
            if (std.mem.eql(u8, opt, "-h")) {
                opts.help = true;
                break;
            } else if (std.mem.eql(u8, opt, "-n")) {
                if (optind + 1 >= argv.len) {
                    try err_writer.print("error: option requires an argument: {s}\n\n", .{opt});
                    return error.MissingArgs;
                }
                optind += 1;
                const optarg = argv[optind];
                opts.num_words = std.fmt.parseInt(u8, optarg, 10) catch {
                    try err_writer.print(
                        "error: invalid passphrase word length: '{s}'\n\n",
                        .{optarg},
                    );
                    return error.InvalidArgs;
                };
            } else {
                try err_writer.print("error: illegal option: {s}\n\n", .{opt});
                return error.InvalidArgs;
            }
        }

        optind += 1;
    }

    return opts;
}

/// Formats the word for the passphrase using the provided buffer.
///
/// Form: `Capitalizedword<n>`, where 0 <= n <= 9
///
/// Returns a slice of the buffer containing the formatted word.
fn formatWord(buffer: []u8, rng: Rng, word: []const u8) []u8 {
    @memcpy(buffer[0..word.len], word);
    buffer[0] = std.ascii.toUpper(buffer[0]);
    buffer[word.len] = '0' + @as(u8, @intCast(rng.gen(9)));
    return buffer[0 .. word.len + 1];
}

const Rng = struct {
    r: std.Random,

    fn gen(self: Rng, up_to: u32) u32 {
        return self.r.intRangeAtMost(u32, 0, up_to);
    }

    fn init(rand: std.Random) Rng {
        return .{ .r = rand };
    }
};
