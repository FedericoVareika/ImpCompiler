const std = @import("std");
const print = std.debug.print;

const token = @import("token.zig");
const lexer = @import("lexer.zig");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    while (true) {
        try stdout.print("> ", .{});
        var buffer: [1024]u8 = undefined;

        const result = try stdin.readUntilDelimiter(&buffer, '\n');
        _ = result;

        var l: lexer.Lexer = .{ .input = &buffer };
        l.readChar();
        while (l.value != 0 and l.value != '\n') {
            const t = l.nextToken();
            print("type: {s}, literal: {s}\n", .{
                std.enums.tagName(token.TokenType, t.type) orelse break,
                t.literal,
            });
        }
        try stdout.print("{s}", .{l.input});
    }
}
