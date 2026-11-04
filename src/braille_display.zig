const std = @import("std");
const terminal = @import("terminal.zig");

pub const Point = struct {
    x: usize,
    y: usize,
};

const BRAILLE_HEIGHT = 4;
const BRAILLE_WIDTH = 2;

const MAX_SCREEN_HEIGHT = 400;
const MAX_SCREEN_WIDTH = 2 * MAX_SCREEN_HEIGHT;

pub const BrailleDisplay = struct {
    screen: [MAX_SCREEN_WIDTH][MAX_SCREEN_HEIGHT]u8,

    pub fn clear(self: *BrailleDisplay) void {
        self.screen = @splat(@splat(0));
    }

    fn brailleCellPrint(writer: *std.Io.Writer, cell: u8) !void {
        const braille_bytes = [_]u8{
            0xE2,
            0xA0 | ((cell >> 6) & 0x03),
            0x80 | (cell & 0x3F),
        };
        _ = try writer.write(&braille_bytes);
    }

    fn bitmask(id: comptime_int) comptime_int {
        return 1 << (id - 1);
    }

    fn brailleCellBitmask(pip_number: u3) u8 {
        switch (pip_number) {
            0 => return bitmask(1),
            1 => return bitmask(2),
            2 => return bitmask(3),
            3 => return bitmask(7),
            4 => return bitmask(4),
            5 => return bitmask(5),
            6 => return bitmask(6),
            7 => return bitmask(8),
        }
    }

    pub fn plotPoint(self: *BrailleDisplay, point: Point) void {
        var char_vec = point;

        var pip_number: u3 = @intCast(char_vec.y % BRAILLE_HEIGHT);
        pip_number += @intCast(BRAILLE_HEIGHT * (char_vec.x % BRAILLE_WIDTH));

        char_vec.y /= BRAILLE_HEIGHT;
        char_vec.x /= BRAILLE_WIDTH;

        self.screen[char_vec.y][char_vec.x] |= brailleCellBitmask(pip_number);
    }

    pub fn size() !Point {
        const screen: terminal.Screen = try terminal.getWindowSize();
        return Point{
            .x = screen.cols * BRAILLE_WIDTH,
            .y = screen.rows * BRAILLE_HEIGHT,
        };
    }

    pub fn render(self: *const BrailleDisplay, io: std.Io) !void {
        const screen: terminal.Screen = try terminal.getWindowSize();
        if (screen.rows > MAX_SCREEN_HEIGHT) {
            return error.OutOfBounds;
        }
        if (screen.rows > MAX_SCREEN_HEIGHT) {
            return error.OutOfBounds;
        }
        var buffer: [5000]u8 = undefined;
        var writer = std.Io.File.Writer.initInterface(&buffer);
        for (0..screen.rows) |y| {
            try terminal.moveCursor(&writer, y + 1, 1);
            for (0..screen.cols) |x| {
                try brailleCellPrint(&writer, self.screen[y][x]);
                if (writer.end > 3 * buffer.len / 4) {
                    try std.Io.File.stdout().writeStreamingAll(io, writer.buffered());
                    writer.end = 0;
                }
            }
        }
        try std.Io.File.stdout().writeStreamingAll(io, writer.buffered());
    }

    pub fn init(allocator: std.mem.Allocator) !*BrailleDisplay {
        const braille_display = try allocator.create(BrailleDisplay);
        braille_display.clear();
        return braille_display;
    }

    pub fn deinit(self: *BrailleDisplay, allocator: std.mem.Allocator) !void {
        allocator.destroy(self);
    }
};
