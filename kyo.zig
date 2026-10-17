const std = @import("std");
const xbps = @import("src/xbps.zig");
const tui = @import("src/tui.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        if (std.posix.isatty(std.posix.STDIN_FILENO)) {
            try tui.run(alloc);
        } else {
            xbps.usage();
            std.process.exit(1);
        }
        return;
    }

    const cmd = args[1];
    const rest = args[2..];

    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "-h") or
        std.mem.eql(u8, cmd, "--h") or std.mem.eql(u8, cmd, "--help"))
    {
        xbps.usage();
        return;
    }

    if (std.mem.eql(u8, cmd, "tui") or std.mem.eql(u8, cmd, "menu")) {
        try tui.run(alloc);
        return;
    }

    std.process.exit(try xbps.dispatch(alloc, cmd, rest));
}
