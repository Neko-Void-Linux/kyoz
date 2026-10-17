const std = @import("std");

fn runCommand(alloc: std.mem.Allocator, argv: []const []const u8) !u8 {
    var child = std.process.Child.init(argv, alloc);
    const term = try child.spawnAndWait();
    return switch (term) {
        .Exited => |code| code,
        else => 1,
    };
}

pub fn install(alloc: std.mem.Allocator, args: []const []const u8) !u8 {
    const stdout = std.io.getStdOut().writer();
    if (args.len != 0) {
        const list = try std.mem.join(alloc, " ", args);
        defer alloc.free(list);
        try stdout.print("Installing {s}...\n", .{list});
    } else {
        try stdout.print("Installing...\n", .{});
    }

    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();
    try argv.append("sudo");
    try argv.append("xbps-install");
    try argv.append("-S");
    try argv.appendSlice(args);
    return runCommand(alloc, argv.items);
}

pub fn update(alloc: std.mem.Allocator) !u8 {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Updating...\n", .{});
    const argv = &[_][]const u8{ "sudo", "xbps-install", "-Syu" };
    return runCommand(alloc, argv);
}

pub fn clean(alloc: std.mem.Allocator) !u8 {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Cleaning...\n", .{});
    const argv = &[_][]const u8{ "sudo", "xbps-remove", "-oO" };
    return runCommand(alloc, argv);
}

pub fn remove(alloc: std.mem.Allocator, args: []const []const u8) !u8 {
    const stdout = std.io.getStdOut().writer();
    if (args.len != 0) {
        const list = try std.mem.join(alloc, " ", args);
        defer alloc.free(list);
        try stdout.print("Removing {s}...\n", .{list});
    } else {
        try stdout.print("Removing...\n", .{});
    }

    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();
    try argv.append("sudo");
    try argv.append("xbps-remove");
    try argv.append("-o");
    try argv.appendSlice(args);
    return runCommand(alloc, argv.items);
}

pub fn search(alloc: std.mem.Allocator, args: []const []const u8) !u8 {
    const stdout = std.io.getStdOut().writer();
    if (args.len != 0) {
        const list = try std.mem.join(alloc, " ", args);
        defer alloc.free(list);
        try stdout.print("Searching for {s}...\n", .{list});
    } else {
        try stdout.print("Searching...\n", .{});
    }

    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();
    try argv.append("sudo");
    try argv.append("xbps-query");
    try argv.append("-Rs");
    try argv.appendSlice(args);
    return runCommand(alloc, argv.items);
}

pub fn usage() void {
    const stdout = std.io.getStdOut().writer();
    _ = stdout.write(
        \\Usage: kyo {install|update|remove|search|clean} [arguments...]
        \\
        \\Commands:
        \\  install, i   <package...>   Install packages
        \\  update, u                    Update the system
        \\  remove, r    <package...>   Remove packages (with -o)
        \\  search, s    <term...>      Search for packages
        \\  clean, c                     Clean orphans and obsolete packages
        \\
    ) catch {};
}

pub fn dispatch(alloc: std.mem.Allocator, cmd: []const u8, rest: []const []const u8) !u8 {
    if (std.mem.eql(u8, cmd, "install") or std.mem.eql(u8, cmd, "i")) return install(alloc, rest);
    if (std.mem.eql(u8, cmd, "update") or std.mem.eql(u8, cmd, "u")) return update(alloc);
    if (std.mem.eql(u8, cmd, "remove") or std.mem.eql(u8, cmd, "r")) return remove(alloc, rest);
    if (std.mem.eql(u8, cmd, "search") or std.mem.eql(u8, cmd, "s")) return search(alloc, rest);
    if (std.mem.eql(u8, cmd, "clean") or std.mem.eql(u8, cmd, "c")) return clean(alloc);

    try std.io.getStdErr().writer().print("Unknown command: {s}\n", .{cmd});
    usage();
    return 1;
}
