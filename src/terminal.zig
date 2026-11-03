const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const linux = std.os.linux;

const red = "\x1b[31m";
const green = "\x1b[32m";

const hide_cursor = "\x1b[?25l";
const show_cursor = "\x1b[?25h";

const cursor_up = "\x1b[1A";

const reset = "\x1b[0m";

pub const Screen = struct {
    rows: usize = 0,
    cols: usize = 0,
};

const Dir = enum {
    up,
    down,
    left,
    right,

    fn inverse(self: Dir) Dir {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }
};

pub const Key = union(enum) {
    ctrl: u8,
    char: u8,
    function: u8,
    arrow: Dir,
    del: void,
    home: void,
    ins: void,
    end: void,
    enter: void,
    page_up: void,
    page_down: void,
    esc: void,
    backspace: void,

    fn print(self: Key) void {
        switch (self) {
            .char => |c| std.debug.print("{c}", .{c}),
            .ctrl => |c| std.debug.print("ctrl+{c}", .{c}),
            .function => |f| std.debug.print("f{}", .{f}),
            .arrow => |d| switch (d) {
                .up => std.debug.print("arrow_up", .{}),
                .down => std.debug.print("arrow_down", .{}),
                .left => std.debug.print("arrow_left", .{}),
                .right => std.debug.print("arrow_right", .{}),
            },
            .del => std.debug.print("del", .{}),
            .home => std.debug.print("home", .{}),
            .ins => std.debug.print("ins", .{}),
            .end => std.debug.print("end", .{}),
            .enter => std.debug.print("enter", .{}),
            .page_up => std.debug.print("page_up", .{}),
            .page_down => std.debug.print("page_down", .{}),
            .esc => std.debug.print("esc", .{}),
            .backspace => std.debug.print("backspace", .{}),
        }
    }

    fn toDir(self: Key) ?Dir {
        switch (self) {
            .arrow => |d| return d,
            .char => |c| switch (c) {
                'k' => return .up,
                'j' => return .down,
                'h' => return .left,
                'l' => return .right,
                else => return null,
            },
            else => return null,
        }
    }
};

const esc_key = 27;
const backspace = 0x7f;

const Terminal = struct {
    orig_termios: posix.termios = undefined,
    buf: [4]u8 = undefined,
    buf_len: usize = 0,
    io: std.Io,
    raw_mode: bool,

    fn fillBuf(self: *Terminal) !void {
        while (self.buf_len < self.buf.len) {
            const x = try posix.read(posix.STDIN_FILENO, self.buf[self.buf_len .. self.buf_len + 1]);
            if (x != 1) return;
            self.buf_len += 1;
        }
    }

    fn bufRemove(self: *Terminal, ct: usize) void {
        self.buf_len -= ct;
        for (0..self.buf_len) |i| {
            self.buf[i] = self.buf[i + ct];
        }
    }

    pub fn enableRaw(self: *Terminal) !void {
        if (self.raw_mode) return;
        self.raw_mode = true;
        self.orig_termios = try posix.tcgetattr(posix.STDIN_FILENO);
        var new_termios = self.orig_termios;

        // disable ctrl+s and ctrl+q
        new_termios.iflag.IXON = false;

        // ensure 8th bit preserved
        new_termios.iflag.ISTRIP = false;

        // disable ctrl+v
        new_termios.lflag.IEXTEN = false;

        // disable showing charcters as they're typed
        new_termios.lflag.ECHO = false;

        // disable ctrl+c and ctrl+z
        new_termios.lflag.ISIG = false;

        // disable canonical mode (read byte-by-byte)
        new_termios.lflag.ICANON = false;

        // disable output processing
        new_termios.oflag.OPOST = false;

        // ensure 8 bits per character
        new_termios.cflag.CSTOPB = true;

        // set minimum bytes to read for read() to return
        new_termios.cc[@backingInt(posix.V.MIN)] = 0;

        // time in deciseconds before read() should return
        new_termios.cc[@backingInt(posix.V.TIME)] = 1;

        try posix.tcsetattr(posix.STDIN_FILENO, posix.TCSA.FLUSH, new_termios);
        const stdout = std.Io.File.stdout();
        try stdout.writeStreamingAll(self.io, hide_cursor);
    }

    pub fn disableRaw(self: *Terminal) !void {
        if (!self.raw_mode) return;
        self.raw_mode = false;
        try posix.tcsetattr(posix.STDIN_FILENO, posix.TCSA.FLUSH, self.orig_termios);
        const stdout = std.Io.File.stdout();
        try stdout.writeStreamingAll(self.io, show_cursor);
    }

    const KeyReadError = error{UnrecognizedSequence};

    fn getKeySeq(self: *Terminal) !Key {
        var result: Key = Key.esc;
        var seq_len: usize = 2;
        try self.fillBuf();

        if (self.buf_len > 1 and self.buf[0] == '[') {
            if (self.buf[1] >= '0' and self.buf[1] <= '9') {
                if (self.buf_len > 2 and self.buf[2] == '~') {
                    seq_len = 3;
                    if (self.buf[2] == '~') {
                        switch (self.buf[1]) {
                            '1' => result = Key.home,
                            '2' => result = Key.ins,
                            '3' => result = Key.del,
                            '4' => result = Key.end,
                            '5' => result = Key.page_up,
                            '6' => result = Key.page_down,
                            '7' => result = Key.home,
                            '8' => result = Key.end,
                            else => {
                                std.debug.print("unknown key code: <esc>[<0x{x}>~\r\n", .{self.buf[1]});
                                return KeyReadError.UnrecognizedSequence;
                            },
                        }
                    }
                } else if (self.buf_len > 3 and self.buf[3] == '~') {
                    seq_len = 4;
                    const code: u16 = (@as(u16, self.buf[1]) << 8) | self.buf[2];
                    switch (code) {
                        0x3135 => result = Key{ .function = 5 },
                        0x3137 => result = Key{ .function = 6 },
                        0x3138 => result = Key{ .function = 7 },
                        0x3139 => result = Key{ .function = 8 },
                        0x3230 => result = Key{ .function = 9 },
                        0x3231 => result = Key{ .function = 10 },
                        0x3234 => result = Key{ .function = 12 },
                        else => {
                            std.debug.print("unknown key code: <esc>[<0x{x:2}>~\r\n", .{code});
                            return KeyReadError.UnrecognizedSequence;
                        },
                    }
                }
            } else {
                switch (self.buf[1]) {
                    'A' => result = Key{ .arrow = Dir.up },
                    'B' => result = Key{ .arrow = Dir.down },
                    'C' => result = Key{ .arrow = Dir.right },
                    'D' => result = Key{ .arrow = Dir.left },
                    'H' => result = Key.home,
                    'F' => result = Key.end,
                    else => {
                        std.debug.print("unknown key code: <esc>[<0x{x}>\r\n", .{self.buf[1]});
                        return KeyReadError.UnrecognizedSequence;
                    },
                }
            }
        } else if (self.buf[0] == 'O') {
            switch (self.buf[1]) {
                'O'...'S' => |f| result = Key{ .function = f - 0x4f },
                else => {
                    std.debug.print("unknown key code: <esc>O<0x{x}>\r\n", .{self.buf[1]});
                    return KeyReadError.UnrecognizedSequence;
                },
            }
        }
        if (result != Key.esc) {
            self.bufRemove(seq_len);
        }
        return result;
    }

    pub fn getKey(self: *Terminal) !Key {
        var nread: usize = 0;
        var c: u8 = undefined;
        if (self.buf_len != 0) {
            c = self.buf[0];
            self.bufRemove(1);
        } else {
            while (nread != 1) {
                nread = try posix.read(posix.STDIN_FILENO, (&c)[0..1]);
            }
        }
        return switch (c) {
            esc_key => self.getKeySeq(),
            backspace => Key.backspace,
            '\n' => Key.enter,
            else => switch (c) {
                0...0x20 => Key{ .ctrl = c + (('a' | 0x1f) ^ 0x1f) },
                else => Key{ .char = c },
            },
        };
    }

    pub fn init(self: *Terminal, io: std.Io) void {
        self.* = Terminal{ .io = io, .raw_mode = false };
    }
};

pub fn getWindowSize() !Screen {
    var screen: Screen = undefined;
    var wsz: posix.winsize = undefined;
    const x = linux.ioctl(posix.STDOUT_FILENO, linux.T.IOCGWINSZ, @intFromPtr(&wsz));
    if (x == -1 or wsz.col == 0) {
        // TODO - return error
        return error.UnknownWindowSize;
    } else {
        screen.rows = wsz.row;
        screen.cols = wsz.col;
    }
    return screen;
}

pub fn moveCursor(writer: *std.Io.Writer, row: usize, col: usize) !void {
    try writer.print("\x1b[{};{}H", .{ row, col });
}

pub var terminal: Terminal = undefined;

const panic = std.debug.FullPanic(crashed);

fn crashed(msg: []const u8, trace: ?usize) noreturn {
    terminal.disableRaw() catch {};
    std.debug.defaultPanic(msg, trace);
}
