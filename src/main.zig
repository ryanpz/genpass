const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const build_config = @import("build_config");

const words = build_config.words;
const max_word_len = build_config.max_word_len;

const NUM_PASSPHRASE_WORDS = 6;
const DELIMITER = "-";

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

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stderr_file = std.io.getStdErr().writer();
    var bwe = std.io.bufferedWriter(stderr_file);
    const stderr = bwe.writer();

    const opts = getOpts(argv, stderr) catch {
        try printUsage(std.fs.path.basename(argv[0]), stderr);
        try bwe.flush();
        return;
    };

    if (opts.help) {
        try printUsage(std.fs.path.basename(argv[0]), stderr);
        try bwe.flush();
        return;
    }

    var passphrase = std.ArrayList(u8).init(gpa);
    defer passphrase.deinit();

    const rng = Rng.init(std.crypto.random);

    var word_buffer: [max_word_len + 1]u8 = undefined;
    var i: u8 = 0;
    while (i < opts.num_words) : (i += 1) {
        const chosen_word = words[rng.gen(words.len - 1)];
        const formatted = formatWord(&word_buffer, rng, chosen_word);
        try passphrase.writer().print("{s}{s}", .{ formatted, if (i == opts.num_words - 1) "\n" else DELIMITER });
    }

    try stdout.print("{s}", .{passphrase.items});
    try bw.flush();
}

const Opts = struct {
    num_words: u8 = NUM_PASSPHRASE_WORDS,
    help: bool = false,
};

const OptParseError = error{ MissingArgs, InvalidArgs };

fn printUsage(prog_name: []const u8, writer: anytype) !void {
    try writer.print(
        \\NAME
        \\    {0s} - generate a random passphrase
        \\
        \\SYNOPSIS
        \\    {0s} [OPTIONS...]
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

/// Parses runtime arguments for POSIX-style short options.
fn getOpts(argv: [][:0]u8, err_writer: anytype) !Opts {
    var opts = Opts{};

    var optind: usize = 1;
    while (optind < argv.len and argv[optind][0] == '-') {
        const opt = argv[optind];

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
                try err_writer.print("error: invalid passphrase word length: '{s}'\n\n", .{optarg});
                return error.InvalidArgs;
            };
        } else {
            try err_writer.print("error: illegal option: {s}\n\n", .{opt});
            return error.InvalidArgs;
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

    pub fn gen(self: Rng, up_to: u32) u32 {
        return self.r.intRangeAtMost(u32, 0, up_to);
    }

    pub fn init(rand: std.Random) Rng {
        return Rng{ .r = rand };
    }
};
