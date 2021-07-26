const std = @import("std");

// entries
// entry can be iter section or key 


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
                Entry.section => | section | {
                    section.deinit();
                    self.alloc.destroy(section);
                },
                else => { }
            }
        }
        self.entries.deinit();
    }
};

pub const Section = struct {
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
                Entry.section => | section | {
                    section.deinit();
                    self.alloc.destroy(section);
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
    section: *Section,
};


fn iniTest() !Config {
    var config : Config = Config.init(std.testing.allocator);
    var section: *Section = try std.testing.allocator.create(Section);
    section.* = Section.init(std.testing.allocator);
    try section.entries.put("name", .{ .string = "Unique Player Name" });
    try section.entries.put("hp", .{ .double = 100.0 });   
    try config.entries.put("player", .{ .section = section });
    return config;
}

// TODO Make it automatic and not checked by hand?
test "Build Ini File" {
    var config = try iniTest();
    defer config.deinit();
    const main_section = config.entries.get("player");
    try std.testing.expect(main_section != null);
    if ( main_section ) | main | {
        try std.testing.expectEqual(main.section.entries.get("hp").?.double, 100.0);
    }
}