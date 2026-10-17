const std = @import("std");
const term = @import("term.zig");
const xbps = @import("xbps.zig");

const Action = enum { install, search, update, remove, clean, quit };

const MenuItem = struct {
    icon: []const u8,
    label: []const u8,
    action: Action,
};

const menu_items = [_]MenuItem{
    .{ .icon = "󰉍", .label = "Install New Package", .action = .install },
    .{ .icon = "󰍉", .label = "Search Packages", .action = .search },
    .{ .icon = "󰚰", .label = "Update Applications", .action = .update },
    .{ .icon = "󰆴", .label = "Uninstall Application", .action = .remove },
    .{ .icon = "󰃢", .label = "Clean Orphans", .action = .clean },
    .{ .icon = "󰈆", .label = "Exit", .action = .quit },
};

fn repeat(out: anytype, text: []const u8, count: usize) !void {
    var index: usize = 0;
    while (index < count) : (index += 1) try out.writeAll(text);
}

fn moveTo(out: anytype, row: usize, col: usize) !void {
    try out.print("\x1b[{d};{d}H", .{ row, col });
}

fn drawTopRow(out: anytype, cols: usize, row: usize, title: []const u8) !void {
    const inner = if (cols >= 2) cols - 2 else 0;
    const fixed = 2 + term.displayWidth(title) + 1;
    const dashes = if (inner > fixed) inner - fixed else 0;
    try moveTo(out, row, 1);
    try out.writeAll("\x1b[1;36m╭─ ");
    try out.writeAll(title);
    try out.writeAll(" ");
    try repeat(out, "─", dashes);
    try moveTo(out, row, cols);
    try out.writeAll("╮\x1b[0m");
}

fn drawBottomRow(out: anytype, cols: usize, row: usize) !void {
    const inner = if (cols >= 2) cols - 2 else 0;
    try moveTo(out, row, 1);
    try out.writeAll("\x1b[1;36m╰");
    try repeat(out, "─", inner);
    try moveTo(out, row, cols);
    try out.writeAll("╯\x1b[0m");
}

fn drawBlankRow(out: anytype, cols: usize, row: usize) !void {
    const inner = if (cols >= 2) cols - 2 else 0;
    try moveTo(out, row, 1);
    try out.writeAll("│");
    try repeat(out, " ", inner);
    try moveTo(out, row, cols);
    try out.writeAll("│");
}

fn drawTextRow(out: anytype, cols: usize, row: usize, text: []const u8, left: usize) !void {
    const inner = if (cols >= 2) cols - 2 else 0;
    const right = if (inner > left + term.displayWidth(text)) inner - left - term.displayWidth(text) else 0;
    try moveTo(out, row, 1);
    try out.writeAll("│");
    try repeat(out, " ", left);
    try out.writeAll(text);
    try repeat(out, " ", right);
    try moveTo(out, row, cols);
    try out.writeAll("│");
}

fn drawMenuRow(out: anytype, cols: usize, row: usize, item: MenuItem, selected: bool, block_left: usize) !void {
    const inner = if (cols >= 2) cols - 2 else 0;
    const marker = if (selected) "▶" else " ";
    const assumed = 6 + item.label.len;
    const left = if (block_left + assumed <= inner) block_left else 0;
    const right = if (inner > left + assumed) inner - left - assumed else 0;

    try moveTo(out, row, 1);
    try out.writeAll("│");
    try repeat(out, " ", left);
    if (selected) try out.writeAll("\x1b[1;7m");
    try out.writeAll(marker);
    try out.writeAll(" ");
    try out.writeAll(item.icon);
    try out.writeAll(" ");
    try out.writeAll(item.label);
    if (selected) try out.writeAll("\x1b[0m");
    try repeat(out, " ", right);
    try moveTo(out, row, cols);
    try out.writeAll("│");
}

fn drawMenu(out: anytype, size: term.Size, selected: usize) !void {
    const cols = size.cols;
    const rows = size.rows;
    const inner = if (cols >= 2) cols - 2 else 0;
    const interior = if (rows >= 2) rows - 2 else 0;
    const menu_len = menu_items.len;

    try out.writeAll("\x1b[2J\x1b[?25l");
    try drawTopRow(out, cols, 1, "KYOZ PACKAGE MANAGER");

    var max_label: usize = 0;
    for (menu_items) |item| {
        if (item.label.len > max_label) max_label = item.label.len;
    }
    const block_width = 6 + max_label;
    const block_left = if (inner > block_width) (inner - block_width) / 2 else 0;

    var menu_start: usize = 0;
    if (interior > menu_len) menu_start = (interior - menu_len) / 2;

    var index: usize = 0;
    while (index < interior) : (index += 1) {
        const row = index + 2;
        if (index >= menu_start and index < menu_start + menu_len) {
            const item_index = index - menu_start;
            try drawMenuRow(out, cols, row, menu_items[item_index], item_index == selected, block_left);
        } else if (index == interior - 1) {
            const hint = "^/v move   Enter select   i info   q quit";
            const left = if (inner > term.displayWidth(hint)) (inner - term.displayWidth(hint)) / 2 else 0;
            try drawTextRow(out, cols, row, hint, left);
        } else {
            try drawBlankRow(out, cols, row);
        }
    }

    try drawBottomRow(out, cols, rows);
    try moveTo(out, rows, 1);
}

const info_lines = [_][]const u8{
    "kyoz",
    "Wrapper for xbps (Void Linux)",
    "",
    "Creator:       JavierC (javiercplus)",
    "Collaborator:  Ars-byte",
    "Repository:    github.com/Neko-Void-Linux/kyoz",
    "License:       WTFPL",
    "Made with:     Zig",
    "",
    "Press any key to return",
};

fn drawInfo(out: anytype, size: term.Size) !void {
    const cols = size.cols;
    const rows = size.rows;
    const inner = if (cols >= 2) cols - 2 else 0;
    const interior = if (rows >= 2) rows - 2 else 0;

    try out.writeAll("\x1b[2J\x1b[?25l");
    try drawTopRow(out, cols, 1, "KYOZ · INFO");

    var max_width: usize = 0;
    for (info_lines) |line| {
        if (term.displayWidth(line) > max_width) max_width = term.displayWidth(line);
    }
    const block_left = if (inner > max_width) (inner - max_width) / 2 else 0;

    var start: usize = 0;
    if (interior > info_lines.len) start = (interior - info_lines.len) / 2;

    var index: usize = 0;
    while (index < interior) : (index += 1) {
        const row = index + 2;
        if (index >= start and index < start + info_lines.len) {
            try drawTextRow(out, cols, row, info_lines[index - start], block_left);
        } else {
            try drawBlankRow(out, cols, row);
        }
    }

    try drawBottomRow(out, cols, rows);
    try moveTo(out, rows, 1);
}

fn runMenuAction(alloc: std.mem.Allocator, action: Action) !bool {
    const out = std.io.getStdOut().writer();

    switch (action) {
        .quit => return false,
        .update => _ = try xbps.update(alloc),
        .clean => _ = try xbps.clean(alloc),
        .install, .remove, .search => {
            const prompt = switch (action) {
                .install => "Package(s) to install: ",
                .remove => "Package(s) to remove: ",
                .search => "Search: ",
                else => "",
            };
            const line = try term.readLine(alloc, prompt);
            defer alloc.free(line);

            var params = std.ArrayList([]const u8).init(alloc);
            defer params.deinit();
            var tokens = std.mem.tokenizeAny(u8, line, " \t");
            while (tokens.next()) |token| try params.append(token);

            if (params.items.len == 0) return true;

            switch (action) {
                .install => _ = try xbps.install(alloc, params.items),
                .remove => _ = try xbps.remove(alloc, params.items),
                .search => _ = try xbps.search(alloc, params.items),
                else => {},
            }
        },
    }

    try out.print("\n[press Enter to return to menu] ", .{});
    term.waitEnter();
    return true;
}

pub fn run(alloc: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut();
    const out = stdout.writer();
    const original = try term.enterRawMode();
    defer term.restoreMode(original);

    var size = term.getSize();
    var selected: usize = 0;
    try drawMenu(out, size, selected);

    var running = true;
    while (running) {
        var fds = [_]std.posix.pollfd{.{ .fd = std.posix.STDIN_FILENO, .events = std.posix.POLL.IN, .revents = 0 }};
        _ = std.posix.poll(&fds, 120) catch 0;

        const current = term.getSize();
        if (current.rows != size.rows or current.cols != size.cols) {
            size = current;
            try drawMenu(out, size, selected);
        }

        if ((fds[0].revents & std.posix.POLL.IN) == 0) continue;

        switch (term.readKey()) {
            .up => {
                selected = if (selected == 0) menu_items.len - 1 else selected - 1;
                try drawMenu(out, size, selected);
            },
            .down => {
                selected = (selected + 1) % menu_items.len;
                try drawMenu(out, size, selected);
            },
            .info => {
                try drawInfo(out, size);
                _ = term.readKey();
                size = term.getSize();
                try drawMenu(out, size, selected);
            },
            .quit => running = false,
            .enter => {
                term.restoreMode(original);
                try stdout.writeAll("\x1b[2J\x1b[H\x1b[?25h");
                running = try runMenuAction(alloc, menu_items[selected].action);
                if (running) {
                    _ = try term.enterRawMode();
                    size = term.getSize();
                    try drawMenu(out, size, selected);
                }
            },
            else => {},
        }
    }

    try stdout.writeAll("\x1b[0m\x1b[2J\x1b[H\x1b[?25h");
}
