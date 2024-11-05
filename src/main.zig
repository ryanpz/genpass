const std = @import("std");
const words = @import("words.zig").words;

const NUM_PASSPHRASE_WORDS = 6;
const DELIMITER = "-";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var passphrase = std.ArrayList(u8).init(allocator);
    defer passphrase.deinit();

    const rng = Rng.init(std.crypto.random);

    var i: u8 = 0;
    while (i < NUM_PASSPHRASE_WORDS) : (i += 1) {
        const chosen_word = words[rng.gen(words.len - 1)];
        const formatted = try formatWord(allocator, rng, chosen_word);
        defer allocator.free(formatted);
        try passphrase.writer().print("{s}{s}", .{ formatted, if (i == NUM_PASSPHRASE_WORDS - 1) "\n" else DELIMITER });
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("{s}", .{passphrase.items});
    try bw.flush();
}

/// Returns the word formatted for the passphrase.
///
/// Form: `Capitalizedword<n>`, where 0 <= n <= 9
///
/// The caller owns the formatted word's memory.
pub fn formatWord(allocator: std.mem.Allocator, rng: Rng, word: []const u8) ![]u8 {
    const word_capitalized = try allocator.dupe(u8, word);
    defer allocator.free(word_capitalized);
    word_capitalized[0] = std.ascii.toUpper(word_capitalized[0]);

    return std.fmt.allocPrint(allocator, "{s}{d}", .{ word_capitalized, rng.gen(9) });
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
