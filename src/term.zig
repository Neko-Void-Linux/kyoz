const std = @import("std");
const posix = std.posix;

pub const Size = struct { rows: usize, cols: usize };

pub fn getSize() Size {
    var winsize: posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    const result = posix.system.ioctl(posix.STDOUT_FILENO, posix.T.IOCGWINSZ, @intFromPtr(&winsize));
    if (posix.errno(result) == .SUCCESS and winsize.row > 0 and winsize.col > 0) {
        return .{ .rows = winsize.row, .cols = winsize.col };
    }
    return .{ .rows = 24, .cols = 80 };
}

pub fn displayWidth(text: []const u8) usize {
    var width: usize = 0;
    var index: usize = 0;
    while (index < text.len) {
        const byte = text[index];
        if (byte < 0x80) {
            index += 1;
        } else if (byte >= 0xF0) {
            index += 4;
        } else if (byte >= 0xE0) {
            index += 3;
        } else if (byte >= 0xC0) {
            index += 2;
        } else {
            index += 1;
        }
        width += 1;
    }
    return width;
}

pub fn enterRawMode() !posix.termios {
    const fd = posix.STDIN_FILENO;
    const original = try posix.tcgetattr(fd);
    var raw = original;
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;
    raw.lflag.ISIG = false;
    raw.cc[@intFromEnum(posix.V.MIN)] = 1;
    raw.cc[@intFromEnum(posix.V.TIME)] = 0;
    try posix.tcsetattr(fd, .NOW, raw);
    return original;
}

pub fn restoreMode(original: posix.termios) void {
    posix.tcsetattr(posix.STDIN_FILENO, .NOW, original) catch {};
}

pub fn readByte() ?u8 {
    var byte: [1]u8 = undefined;
    const count = posix.read(posix.STDIN_FILENO, &byte) catch return null;
    if (count == 0) return null;
    return byte[0];
}

pub fn readByteTimeout(timeout_ms: i32) ?u8 {
    var fds = [_]posix.pollfd{.{ .fd = posix.STDIN_FILENO, .events = posix.POLL.IN, .revents = 0 }};
    const ready = posix.poll(&fds, timeout_ms) catch return null;
    if (ready == 0) return null;
    return readByte();
}

pub const Key = enum { up, down, enter, info, quit, other };

pub fn readKey() Key {
    const first = readByte() orelse return .quit;
    switch (first) {
        0x1b => {
            const second = readByteTimeout(30) orelse return .other;
            if (second != '[') return .other;
            const third = readByteTimeout(30) orelse return .other;
            return switch (third) {
                'A' => .up,
                'B' => .down,
                else => .other,
            };
        },
        '\r', '\n' => return .enter,
        'q', 0x03 => return .quit,
        'k' => return .up,
        'j' => return .down,
        'i', '?' => return .info,
        else => return .other,
    }
}

pub fn readLine(alloc: std.mem.Allocator, prompt: []const u8) ![]u8 {
    const out = std.io.getStdOut().writer();
    try out.writeAll(prompt);

    var buffer = std.ArrayList(u8).init(alloc);
    errdefer buffer.deinit();

    var byte: [1]u8 = undefined;
    while (true) {
        const count = try posix.read(posix.STDIN_FILENO, &byte);
        if (count == 0) break;
        if (byte[0] == '\n') break;
        if (byte[0] == '\r') continue;
        try buffer.append(byte[0]);
    }
    return buffer.toOwnedSlice();
}

pub fn waitEnter() void {
    while (true) {
        const byte = readByte() orelse return;
        if (byte == '\n' or byte == '\r') return;
    }
}
