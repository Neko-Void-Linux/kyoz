const std = @import("std");
const xbps = @import("src/xbps.zig");
const tui = @import("src/tui.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const path = init.environ_map.get("PATH") orelse "";

    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, alloc);
    defer args_iter.deinit();

    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(alloc);
    while (args_iter.next()) |arg| try args.append(alloc, arg);

    if (args.items.len < 2) {
        if (std.Io.File.stdin().isTty(io) catch false) {
            try tui.run(alloc, io, path);
        } else {
            try xbps.usage(io);
            std.process.exit(1);
        }
        return;
    }

    const cmd = args.items[1];
    const rest = args.items[2..];

    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "-h") or
        std.mem.eql(u8, cmd, "--h") or std.mem.eql(u8, cmd, "--help"))
    {
        try xbps.usage(io);
        return;
    }

    if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "-v") or
        std.mem.eql(u8, cmd, "--version"))
    {
        try xbps.printVersion(io);
        return;
    }

    if (std.mem.eql(u8, cmd, "tui") or std.mem.eql(u8, cmd, "menu")) {
        try tui.run(alloc, io, path);
        return;
    }

    std.process.exit(try xbps.dispatch(alloc, io, path, cmd, rest));
}
