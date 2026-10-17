const std = @import("std");

const Escalator = enum { sudo, doas, su };

fn printOut(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

fn printErr(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

fn runCommand(io: std.Io, argv: []const []const u8) !u8 {
    var child = try std.process.spawn(io, .{ .argv = argv });
    const term = try child.wait(io);
    return switch (term) {
        .exited => |code| code,
        else => 1,
    };
}

fn hasExecutable(io: std.Io, alloc: std.mem.Allocator, path: []const u8, name: []const u8) bool {
    var dirs = std.mem.splitScalar(u8, path, ':');
    while (dirs.next()) |dir| {
        if (dir.len == 0) continue;
        const full = std.fs.path.join(alloc, &.{ dir, name }) catch continue;
        defer alloc.free(full);
        std.Io.Dir.accessAbsolute(io, full, .{}) catch continue;
        return true;
    }
    return false;
}

fn detectEscalator(io: std.Io, alloc: std.mem.Allocator, path: []const u8) Escalator {
    if (hasExecutable(io, alloc, path, "sudo")) return .sudo;
    if (hasExecutable(io, alloc, path, "doas")) return .doas;
    return .su;
}

fn buildShellCommand(alloc: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(alloc);
    for (argv, 0..) |arg, index| {
        if (index != 0) try buf.append(alloc, ' ');
        try buf.append(alloc, '\'');
        for (arg) |char| {
            if (char == '\'') {
                try buf.appendSlice(alloc, "'\\''");
            } else {
                try buf.append(alloc, char);
            }
        }
        try buf.append(alloc, '\'');
    }
    return buf.toOwnedSlice(alloc);
}

fn runPrivileged(io: std.Io, alloc: std.mem.Allocator, path: []const u8, command: []const []const u8) !u8 {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(alloc);

    switch (detectEscalator(io, alloc, path)) {
        .sudo => {
            try argv.append(alloc, "sudo");
            try argv.appendSlice(alloc, command);
        },
        .doas => {
            try argv.append(alloc, "doas");
            try argv.appendSlice(alloc, command);
        },
        .su => {
            const shell_command = try buildShellCommand(alloc, command);
            defer alloc.free(shell_command);
            try argv.append(alloc, "su");
            try argv.append(alloc, "-c");
            try argv.append(alloc, shell_command);
            return runCommand(io, argv.items);
        },
    }

    return runCommand(io, argv.items);
}

pub fn install(io: std.Io, alloc: std.mem.Allocator, path: []const u8, args: []const []const u8) !u8 {
    if (args.len != 0) {
        const list = try std.mem.join(alloc, " ", args);
        defer alloc.free(list);
        try printOut(io, "Installing {s}...\n", .{list});
    } else {
        try printOut(io, "Installing...\n", .{});
    }

    var command: std.ArrayList([]const u8) = .empty;
    defer command.deinit(alloc);
    try command.append(alloc, "xbps-install");
    try command.append(alloc, "-S");
    try command.appendSlice(alloc, args);
    return runPrivileged(io, alloc, path, command.items);
}

pub fn update(io: std.Io, alloc: std.mem.Allocator, path: []const u8) !u8 {
    try printOut(io, "Updating...\n", .{});
    const command = &[_][]const u8{ "xbps-install", "-Syu" };
    return runPrivileged(io, alloc, path, command);
}

pub fn clean(io: std.Io, alloc: std.mem.Allocator, path: []const u8) !u8 {
    try printOut(io, "Cleaning...\n", .{});
    const command = &[_][]const u8{ "xbps-remove", "-oO" };
    return runPrivileged(io, alloc, path, command);
}

pub fn remove(io: std.Io, alloc: std.mem.Allocator, path: []const u8, args: []const []const u8) !u8 {
    if (args.len != 0) {
        const list = try std.mem.join(alloc, " ", args);
        defer alloc.free(list);
        try printOut(io, "Removing {s}...\n", .{list});
    } else {
        try printOut(io, "Removing...\n", .{});
    }

    var command: std.ArrayList([]const u8) = .empty;
    defer command.deinit(alloc);
    try command.append(alloc, "xbps-remove");
    try command.append(alloc, "-o");
    try command.appendSlice(alloc, args);
    return runPrivileged(io, alloc, path, command.items);
}

pub fn search(io: std.Io, alloc: std.mem.Allocator, path: []const u8, args: []const []const u8) !u8 {
    if (args.len != 0) {
        const list = try std.mem.join(alloc, " ", args);
        defer alloc.free(list);
        try printOut(io, "Searching for {s}...\n", .{list});
    } else {
        try printOut(io, "Searching...\n", .{});
    }

    var command: std.ArrayList([]const u8) = .empty;
    defer command.deinit(alloc);
    try command.append(alloc, "xbps-query");
    try command.append(alloc, "-Rs");
    try command.appendSlice(alloc, args);
    return runPrivileged(io, alloc, path, command.items);
}

pub fn usage(io: std.Io) !void {
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    try writer.interface.writeAll(
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
    );
    try writer.interface.flush();
}

pub fn dispatch(alloc: std.mem.Allocator, io: std.Io, path: []const u8, cmd: []const u8, rest: []const []const u8) !u8 {
    if (std.mem.eql(u8, cmd, "install") or std.mem.eql(u8, cmd, "i")) return install(io, alloc, path, rest);
    if (std.mem.eql(u8, cmd, "update") or std.mem.eql(u8, cmd, "u")) return update(io, alloc, path);
    if (std.mem.eql(u8, cmd, "remove") or std.mem.eql(u8, cmd, "r")) return remove(io, alloc, path, rest);
    if (std.mem.eql(u8, cmd, "search") or std.mem.eql(u8, cmd, "s")) return search(io, alloc, path, rest);
    if (std.mem.eql(u8, cmd, "clean") or std.mem.eql(u8, cmd, "c")) return clean(io, alloc, path);

    try printErr(io, "Unknown command: {s}\n", .{cmd});
    try usage(io);
    return 1;
}
