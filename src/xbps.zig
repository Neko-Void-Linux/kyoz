const std = @import("std");

const Escalator = enum { sudo, doas, su };

fn runCommand(alloc: std.mem.Allocator, argv: []const []const u8) !u8 {
    var child = std.process.Child.init(argv, alloc);
    const term = try child.spawnAndWait();
    return switch (term) {
        .Exited => |code| code,
        else => 1,
    };
}

fn hasExecutable(alloc: std.mem.Allocator, name: []const u8) bool {
    const path = std.posix.getenv("PATH") orelse return false;
    var dirs = std.mem.splitScalar(u8, path, ':');
    while (dirs.next()) |dir| {
        if (dir.len == 0) continue;
        const full = std.fs.path.join(alloc, &.{ dir, name }) catch continue;
        defer alloc.free(full);
        std.fs.accessAbsolute(full, .{}) catch continue;
        return true;
    }
    return false;
}

fn detectEscalator(alloc: std.mem.Allocator) Escalator {
    if (hasExecutable(alloc, "sudo")) return .sudo;
    if (hasExecutable(alloc, "doas")) return .doas;
    return .su;
}

fn buildShellCommand(alloc: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    var buf = std.ArrayList(u8).init(alloc);
    errdefer buf.deinit();
    const writer = buf.writer();
    for (argv, 0..) |arg, index| {
        if (index != 0) try writer.writeByte(' ');
        try writer.writeByte('\'');
        for (arg) |char| {
            if (char == '\'') {
                try writer.writeAll("'\\''");
            } else {
                try writer.writeByte(char);
            }
        }
        try writer.writeByte('\'');
    }
    return buf.toOwnedSlice();
}

fn runPrivileged(alloc: std.mem.Allocator, command: []const []const u8) !u8 {
    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();

    switch (detectEscalator(alloc)) {
        .sudo => {
            try argv.append("sudo");
            try argv.appendSlice(command);
        },
        .doas => {
            try argv.append("doas");
            try argv.appendSlice(command);
        },
        .su => {
            const shell_command = try buildShellCommand(alloc, command);
            defer alloc.free(shell_command);
            try argv.append("su");
            try argv.append("-c");
            try argv.append(shell_command);
            return runCommand(alloc, argv.items);
        },
    }

    return runCommand(alloc, argv.items);
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

    var command = std.ArrayList([]const u8).init(alloc);
    defer command.deinit();
    try command.append("xbps-install");
    try command.append("-S");
    try command.appendSlice(args);
    return runPrivileged(alloc, command.items);
}

pub fn update(alloc: std.mem.Allocator) !u8 {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Updating...\n", .{});
    const command = &[_][]const u8{ "xbps-install", "-Syu" };
    return runPrivileged(alloc, command);
}

pub fn clean(alloc: std.mem.Allocator) !u8 {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Cleaning...\n", .{});
    const command = &[_][]const u8{ "xbps-remove", "-oO" };
    return runPrivileged(alloc, command);
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

    var command = std.ArrayList([]const u8).init(alloc);
    defer command.deinit();
    try command.append("xbps-remove");
    try command.append("-o");
    try command.appendSlice(args);
    return runPrivileged(alloc, command.items);
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

    var command = std.ArrayList([]const u8).init(alloc);
    defer command.deinit();
    try command.append("xbps-query");
    try command.append("-Rs");
    try command.appendSlice(args);
    return runPrivileged(alloc, command.items);
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
        \\Run with no arguments to open the interactive menu.
        \\  help, -h, --h, --help       Show this help
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
