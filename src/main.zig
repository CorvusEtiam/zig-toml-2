const std = @import("std");
const lex = @import("./lexer.zig");
const ini = @import("./ini.zig");

comptime {
    _ = lex;
    _ = ini;
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
}
