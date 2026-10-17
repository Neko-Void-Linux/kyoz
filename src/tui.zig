const std = @import("std");
const term = @import("term.zig");

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
