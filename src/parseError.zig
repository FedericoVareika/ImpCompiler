const std = @import("std");
const token = @import("token.zig");
const TokenType = token.TokenType;

pub const ParseError = union(enum) {
    UnexpectedToken: struct {
        position: u32,
        line: []const u8,
        expectedToken: TokenType,
        actualToken: TokenType, 
    },

    pub fn format(
        self: ParseError,
        comptime fmt: []const u8, 
        options: std.fmt.FormatOptions,
        writer: anytype,     
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .UnexpectedToken => |err| {
                const errMsg = 
                    \\ error: expected '{[expectedToken]s}', found '{[actualToken]s}'
                    \\    {[line]s}
                    \\    {[carat]s:[position]}
                ;
                try writer.print(errMsg, .{
                    .expectedToken = err.expectedToken,
                    .actualToken = err.actualToken,
                    .line = err.line, 
                    .position = err.position + 1,
                    .carat = "^",
                });
            }
        }
    }
};
