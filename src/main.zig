const std = @import("std");
const evio = @import("evio");
const mi_allocator = @import("mimalloc").default_allocator;

const ascii = std.ascii;
const fmt = std.fmt;
const mem = std.mem;

var uid: usize = 0;
var clients: std.AutoHashMap(*evio.Conn, void) = undefined;

const UData = struct {
    nick: []u8,
};

fn opened(c: *evio.Conn) void {
    std.debug.print("Connected client addr={any}\n", .{c.raddr});
    uid += 1;
    const udata = mi_allocator.create(UData) catch unreachable;
    const nick = fmt.allocPrint(mi_allocator, "user:{}", .{uid}) catch unreachable;
    udata.nick = nick;
    c.udata = @ptrCast(udata);
    clients.put(c, {}) catch unreachable;
    c.write("Welcome Simple Chat! Use /nick to change nick name.\n");
}

fn data(c: *evio.Conn, in: []const u8) void {
    const b = mem.trim(u8, in, &ascii.whitespace);
    if (b.len == 0) return;
    const udata: *UData = @ptrCast(@alignCast(c.udata));

    if (b[0] == '/') {
        if (b.len >= 5 and mem.eql(u8, b[0..5], "/nick")) {
            if (mem.indexOfScalarPos(u8, b, 5, ' ')) |i| {
                const newnick = mem.trim(u8, b[i + 1 ..], &ascii.whitespace);
                const nick = mi_allocator.realloc(udata.nick, newnick.len) catch unreachable;
                @memcpy(nick, newnick);
                udata.nick = nick;
            } else {
                c.write("Usage: /nick newnick\n");
            }
        } else {
            c.write("Unsupport command\n");
        }
        return;
    }

    const msg = fmt.allocPrint(mi_allocator, "{s}> {s}\n", .{ udata.nick, b }) catch unreachable;
    defer mi_allocator.free(msg);
    var it = clients.keyIterator();
    while (it.next()) |conn| {
        if (conn.*.fd == c.fd) continue;
        conn.*.write(msg);
    }
}

fn closed(c: *evio.Conn) void {
    std.debug.print("Disconnected client addr={any}\n", .{c.raddr});
    const udata: *UData = @ptrCast(@alignCast(c.udata));
    mi_allocator.free(udata.nick);
    mi_allocator.destroy(udata);
    _ = clients.remove(c);
}

pub fn main() !void {
    clients = std.AutoHashMap(*evio.Conn, void).init(mi_allocator);
    defer clients.deinit();

    try evio.serve(
        mi_allocator,
        .{
            .opened = opened,
            .data = data,
            .closed = closed,
        },
        &[_]std.net.Address{
            try std.net.Address.parseIp4("0.0.0.0", 7711),
        },
    );
}
