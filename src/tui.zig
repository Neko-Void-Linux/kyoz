const std = @import("std");
const term = @import("term.zig");
const xbps = @import("xbps.zig");

pub const Lang = enum { en, es };

const Action = enum { install, search, list, update, remove, clean, quit };

const Label = struct { en: []const u8, es: []const u8 };

const MenuItem = struct {
    icon: []const u8,
    label: Label,
    action: Action,
};

const menu_items = [_]MenuItem{
    .{ .icon = "󰉍", .label = .{ .en = "Install New Package", .es = "Instalar paquete" }, .action = .install },
    .{ .icon = "󰍉", .label = .{ .en = "Search Packages", .es = "Buscar paquetes" }, .action = .search },
    .{ .icon = "󰉋", .label = .{ .en = "List Installed Packages", .es = "Listar paquetes instalados" }, .action = .list },
    .{ .icon = "󰚰", .label = .{ .en = "Update Applications", .es = "Actualizar aplicaciones" }, .action = .update },
    .{ .icon = "󰆴", .label = .{ .en = "Uninstall Application", .es = "Desinstalar aplicación" }, .action = .remove },
    .{ .icon = "󰃢", .label = .{ .en = "Clean Orphans", .es = "Limpiar huérfanos" }, .action = .clean },
    .{ .icon = "󰈆", .label = .{ .en = "Exit", .es = "Salir" }, .action = .quit },
};

fn labelText(label: Label, lang: Lang) []const u8 {
    return if (lang == .es) label.es else label.en;
}

fn titleText(lang: Lang) []const u8 {
    return if (lang == .es) "KYOZ · GESTOR DE PAQUETES" else "KYOZ PACKAGE MANAGER";
}

fn hintText(lang: Lang) []const u8 {
    return if (lang == .es)
        "^/v mover   Enter seleccionar   i info   l idioma   q salir"
    else
        "^/v move   Enter select   i info   l language   q quit";
}

fn returnText(lang: Lang) []const u8 {
    return if (lang == .es)
        "\n[pulsa Enter para volver al menú] "
    else
        "\n[press Enter to return to menu] ";
}

fn promptText(lang: Lang, action: Action) []const u8 {
    return switch (action) {
        .install => if (lang == .es) "Paquete(s) a instalar: " else "Package(s) to install: ",
        .remove => if (lang == .es) "Paquete(s) a eliminar: " else "Package(s) to remove: ",
        .search => if (lang == .es) "Buscar: " else "Search: ",
        else => "",
    };
}

const info_en = [_][]const u8{
    "kyoz",
    "Wrapper for xbps (Void Linux)",
    "Version:       " ++ xbps.version,
    "",
    "Creator:       JavierC (javiercplus)",
    "Collaborator:  Ars-byte",
    "Repository:    github.com/Neko-Void-Linux/kyoz",
    "License:       WTFPL",
    "Made with:     Zig",
    "",
    "Press any key to return",
};

const info_es = [_][]const u8{
    "kyoz",
    "Wrapper para xbps (Void Linux)",
    "Versión:       " ++ xbps.version,
    "",
    "Creador:       JavierC (javiercplus)",
    "Colaborador:   Ars-byte",
    "Repositorio:   github.com/Neko-Void-Linux/kyoz",
    "Licencia:      WTFPL",
    "Hecho con:     Zig",
    "",
    "Pulsa cualquier tecla para volver",
};

fn infoLines(lang: Lang) []const []const u8 {
    return if (lang == .es) &info_es else &info_en;
}

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

fn drawMenuRow(out: anytype, cols: usize, row: usize, item: MenuItem, selected: bool, block_left: usize, lang: Lang) !void {
    const inner = if (cols >= 2) cols - 2 else 0;
    const text = labelText(item.label, lang);
    const marker = if (selected) "▶" else " ";
    const assumed = 6 + term.displayWidth(text);
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
    try out.writeAll(text);
    if (selected) try out.writeAll("\x1b[0m");
    try repeat(out, " ", right);
    try moveTo(out, row, cols);
    try out.writeAll("│");
}

fn drawMenu(out: anytype, size: term.Size, selected: usize, lang: Lang) !void {
    const cols = size.cols;
    const rows = size.rows;
    const inner = if (cols >= 2) cols - 2 else 0;
    const interior = if (rows >= 2) rows - 2 else 0;
    const menu_len = menu_items.len;

    try out.writeAll("\x1b[2J\x1b[?25l");
    try drawTopRow(out, cols, 1, titleText(lang));

    var max_label: usize = 0;
    for (menu_items) |item| {
        const width = term.displayWidth(labelText(item.label, lang));
        if (width > max_label) max_label = width;
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
            try drawMenuRow(out, cols, row, menu_items[item_index], item_index == selected, block_left, lang);
        } else if (index == interior - 1) {
            const hint = hintText(lang);
            const left = if (inner > term.displayWidth(hint)) (inner - term.displayWidth(hint)) / 2 else 0;
            try drawTextRow(out, cols, row, hint, left);
        } else {
            try drawBlankRow(out, cols, row);
        }
    }

    try drawBottomRow(out, cols, rows);
    try moveTo(out, rows, 1);
}

fn drawInfo(out: anytype, size: term.Size, lang: Lang) !void {
    const cols = size.cols;
    const rows = size.rows;
    const inner = if (cols >= 2) cols - 2 else 0;
    const interior = if (rows >= 2) rows - 2 else 0;
    const lines = infoLines(lang);

    try out.writeAll("\x1b[2J\x1b[?25l");
    try drawTopRow(out, cols, 1, "KYOZ · INFO");

    var max_width: usize = 0;
    for (lines) |line| {
        if (term.displayWidth(line) > max_width) max_width = term.displayWidth(line);
    }
    const block_left = if (inner > max_width) (inner - max_width) / 2 else 0;

    var start: usize = 0;
    if (interior > lines.len) start = (interior - lines.len) / 2;

    var index: usize = 0;
    while (index < interior) : (index += 1) {
        const row = index + 2;
        if (index >= start and index < start + lines.len) {
            try drawTextRow(out, cols, row, lines[index - start], block_left);
        } else {
            try drawBlankRow(out, cols, row);
        }
    }

    try drawBottomRow(out, cols, rows);
    try moveTo(out, rows, 1);
}

fn runMenuAction(alloc: std.mem.Allocator, io: std.Io, path: []const u8, action: Action, lang: Lang) !bool {
    var no_buffer: [0]u8 = .{};
    var out_writer = std.Io.File.stdout().writerStreaming(io, &no_buffer);
    const out = &out_writer.interface;

    switch (action) {
        .quit => return false,
        .update => _ = try xbps.update(io, alloc, path),
        .clean => _ = try xbps.clean(io, alloc, path),
        .list => _ = try xbps.listPackages(io, alloc, &.{}),
        .install, .remove, .search => {
            const prompt = promptText(lang, action);
            const line = try term.readLine(io, alloc, prompt);
            defer alloc.free(line);

            var params: std.ArrayList([]const u8) = .empty;
            defer params.deinit(alloc);
            var tokens = std.mem.tokenizeAny(u8, line, " \t");
            while (tokens.next()) |token| try params.append(alloc, token);

            if (params.items.len == 0) return true;

            switch (action) {
                .install => _ = try xbps.install(io, alloc, path, params.items),
                .remove => _ = try xbps.remove(io, alloc, path, params.items),
                .search => _ = try xbps.search(io, alloc, path, params.items),
                else => {},
            }
        },
    }

    try out.print("{s}", .{returnText(lang)});
    term.waitEnter();
    return true;
}

pub fn run(alloc: std.mem.Allocator, io: std.Io, path: []const u8, initial_lang: Lang) !void {
    var no_buffer: [0]u8 = .{};
    var out_writer = std.Io.File.stdout().writerStreaming(io, &no_buffer);
    const out = &out_writer.interface;
    const original = try term.enterRawMode();
    defer term.restoreMode(original);

    var lang = initial_lang;
    var size = term.getSize();
    var selected: usize = 0;
    try drawMenu(out, size, selected, lang);

    var running = true;
    while (running) {
        var fds = [_]std.posix.pollfd{.{ .fd = std.posix.STDIN_FILENO, .events = std.posix.POLL.IN, .revents = 0 }};
        _ = std.posix.poll(&fds, 120) catch 0;

        const current = term.getSize();
        if (current.rows != size.rows or current.cols != size.cols) {
            size = current;
            try drawMenu(out, size, selected, lang);
        }

        if ((fds[0].revents & std.posix.POLL.IN) == 0) continue;

        switch (term.readKey()) {
            .up => {
                selected = if (selected == 0) menu_items.len - 1 else selected - 1;
                try drawMenu(out, size, selected, lang);
            },
            .down => {
                selected = (selected + 1) % menu_items.len;
                try drawMenu(out, size, selected, lang);
            },
            .lang => {
                lang = if (lang == .en) .es else .en;
                try drawMenu(out, size, selected, lang);
            },
            .info => {
                try drawInfo(out, size, lang);
                _ = term.readKey();
                size = term.getSize();
                try drawMenu(out, size, selected, lang);
            },
            .quit => running = false,
            .enter => {
                term.restoreMode(original);
                try out.writeAll("\x1b[2J\x1b[H\x1b[?25h");
                running = try runMenuAction(alloc, io, path, menu_items[selected].action, lang);
                if (running) {
                    _ = try term.enterRawMode();
                    size = term.getSize();
                    try drawMenu(out, size, selected, lang);
                }
            },
            else => {},
        }
    }

    try out.writeAll("\x1b[0m\x1b[2J\x1b[H\x1b[?25h");
}
