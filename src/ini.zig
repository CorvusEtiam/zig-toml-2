const std = @import("std");
const IniParser = @import("./parser.zig").IniParser;
// entries
// entry can be iter table or key 

// Root of new parser file
pub const Config = struct {
    const Self = @This();
    entries: std.StringHashMap(Entry) = undefined,
    alloc: *std.mem.Allocator = undefined,

    pub fn init(alloc: *std.mem.Allocator) Config {
        return Self {
            .alloc = alloc,
            .entries = std.StringHashMap(Entry).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        var value_iterator = self.entries.valueIterator();
        while ( value_iterator.next() ) | value | {
            switch ( value.* ) {
                Entry.table => | table | {
                    table.deinit();
                    self.alloc.destroy(table);
                },
                else => { }
            }
        }
        self.entries.deinit();
    }
    
    pub fn parse(self: *Self, path: []const u8) !void {
        const content = try std.fs.cwd().readFileAlloc(self.alloc, path, std.math.maxInt(usize));
        try self.parseString(content);
    }

    pub fn parseString(self: *Self, content: []const u8) !void {
        var parser = IniParser.init(self.alloc, content);
        defer parser.deinit();
        try parser.parse(self);
    }

    pub fn dump() !void {

    }

    pub fn dumpString() ![]const u8 {

    }
};

// Array datatype for both inline arrays and normal [[array]]
pub const Array = struct {
    const Self = @This();
    alloc: *std.mem.Allocator = undefined,
    entries: std.ArrayList(Entry) = undefined,
    
    pub fn init(alloc: *std.mem.Allocator) !Self {
        return .{
            .alloc = alloc,
            .entries = std.ArrayList(Entry).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        for ( self.entries.items() ) | value | {
            switch ( value ) {
                Entry.table => | table | {
                    table.deinit();
                    self.alloc.destroy(table);
                },
                else => { }
            }
        }
    }
};
// Dictionary data type for objects, inline objects
pub const Table = struct {
    const Self = @This();
    entries: std.StringHashMap(Entry) = undefined,
    alloc: *std.mem.Allocator = undefined,

    pub fn init(alloc: *std.mem.Allocator) Self {
        return .{
            .alloc = alloc,
            .entries = std.StringHashMap(Entry).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        var value_iterator = self.entries.valueIterator();
        while ( value_iterator.next() ) | value | {
            switch ( value.* ) {
                Entry.table => | table | {
                    table.deinit();
                    self.alloc.destroy(table);
                },
                else => { }
            }
        }
        self.entries.deinit();
    }
};

pub const Entry = union(enum) {
    nil: void,
    double: f64,
    boolean: bool,
    string: []const u8,
    table: *Table,
    array: *Array,
};


fn iniTest() !Config {
    var config : Config = Config.init(std.testing.allocator);
    var table: *table = try std.testing.allocator.create(table);
    table.* = table.init(std.testing.allocator);
    try table.entries.put("name", .{ .string = "Unique Player Name" });
    try table.entries.put("hp", .{ .double = 100.0 });   
    try config.entries.put("player", .{ .table = table });
    return config;
}

// TODO Make it automatic and not checked by hand?
test "Build Ini File" {
    var config = try iniTest();
    defer config.deinit();
    const main_table = config.entries.get("player");
    try std.testing.expect(main_table != null);
    if ( main_table ) | main | {
        try std.testing.expectEqual(main.table.entries.get("hp").?.double, 100.0);
    }
}