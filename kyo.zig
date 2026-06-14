const std = @import("std");

fn install(alloc: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const list = try std.mem.join(alloc, " ", args);
    defer alloc.free(list);
    try stdout.print("Installing {s}...\n", .{list});

    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();
    try argv.append("sudo");
    try argv.append("xbps-install");
    try argv.append("-S");
    try argv.appendSlice(args);

    var child = std.process.Child.init(argv.items, alloc);
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) std.process.exit(code),
        else => std.process.exit(1),
    }
}

fn update(alloc: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Updating...\n", .{});

    const argv = &[_][]const u8{ "sudo", "xbps-install", "-Syu" };
    var child = std.process.Child.init(argv, alloc);
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) std.process.exit(code),
        else => std.process.exit(1),
    }
}

fn clean(alloc: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Cleaning...\n", .{});

    const argv = &[_][]const u8{ "sudo", "xbps-remove", "-oO" };
    var child = std.process.Child.init(argv, alloc);
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) std.process.exit(code),
        else => std.process.exit(1),
    }
}

fn remove(alloc: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const list = try std.mem.join(alloc, " ", args);
    defer alloc.free(list);
    try stdout.print("Removing {s}...\n", .{list});

    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();
    try argv.append("sudo");
    try argv.append("xbps-remove");
    try argv.append("-o");
    try argv.appendSlice(args);

    var child = std.process.Child.init(argv.items, alloc);
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) std.process.exit(code),
        else => std.process.exit(1),
    }
}

fn search(alloc: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const list = try std.mem.join(alloc, " ", args);
    defer alloc.free(list);
    try stdout.print("searching in deepweb {s}...\n", .{list});

    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();
    try argv.append("sudo");
    try argv.append("xbps-query");
    try argv.append("-Rs");
    try argv.appendSlice(args);

    var child = std.process.Child.init(argv.items, alloc);
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) std.process.exit(code),
        else => std.process.exit(1),
    }
}

fn usage() void {
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        usage();
        std.process.exit(1);
    }

    const cmd = args[1];
    const rest = args[2..];

    if (std.mem.eql(u8, cmd, "install") or std.mem.eql(u8, cmd, "i")) {
        try install(alloc, rest);
    } else if (std.mem.eql(u8, cmd, "update") or std.mem.eql(u8, cmd, "u")) {
        try update(alloc);
    } else if (std.mem.eql(u8, cmd, "remove") or std.mem.eql(u8, cmd, "r")) {
        try remove(alloc, rest);
    } else if (std.mem.eql(u8, cmd, "search") or std.mem.eql(u8, cmd, "s")) {
        try search(alloc, rest);
    } else if (std.mem.eql(u8, cmd, "clean") or std.mem.eql(u8, cmd, "c")) {
        try clean(alloc);
    } else {
        try std.io.getStdErr().writer().print("Unknown command: {s}\n", .{cmd});
        usage();
        std.process.exit(1);
    }
}
