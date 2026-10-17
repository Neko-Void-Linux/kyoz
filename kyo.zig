const std = @import("std");
const xbps = @import("src/xbps.zig");
const tui = @import("src/tui.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const path = init.environ_map.get("PATH") orelse "";
    const lang = detectLang(init.environ_map);

    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, alloc);
    defer args_iter.deinit();

    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(alloc);
    while (args_iter.next()) |arg| try args.append(alloc, arg);

    if (args.items.len < 2) {
        if (std.Io.File.stdin().isTty(io) catch false) {
            try tui.run(alloc, io, path, lang);
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
        try tui.run(alloc, io, path, lang);
        return;
    }

    std.process.exit(try xbps.dispatch(alloc, io, path, cmd, rest));
}

fn detectLang(env: anytype) tui.Lang {
    const keys = [_][]const u8{ "LC_ALL", "LC_MESSAGES", "LANG" };
    for (keys) |key| {
        if (env.get(key)) |value| {
            if (value.len == 0) continue;
            if (value.len >= 2 and value[0] == 'e' and value[1] == 's') return .es;
            return .en;
        }
    }
    return .en;
}
