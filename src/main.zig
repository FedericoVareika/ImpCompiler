const std = @import("std");
const process = std.process;



pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    var args = process.args();
    while (args.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
    }

}
