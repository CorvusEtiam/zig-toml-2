// load `ini` namespace
const Lexer = @import("./lexer.zig").Lexer;
const ini = @import("./ini.zig");

fn is_ws(char: u8) bool {
    return char == ' ' or char == '\t';
}
fn is_newline(chars: []u8) bool {
    return (char[0] == '\r' and char[1] == '\n') or chars[0] == '\n';
}


const TokenType = enum {
    plus,
    minus,
    comment,
    newline,
    whitespace,
    colon,
    comma,
    dot,
    leftBrace,
    rightBrace,
    leftBracket,
    rightBracket,
    quotedString,
    keyLike,
    keyValSep,
};

const Token = struct {
    span: []const u8 = undefined, // slice of content
    tok_type: TokenType,
};


fn is_keylike_char(char: u8) bool {
    return (char >= '0' and char <= '9') or (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_' or char == '-';
}

const Tokenizer = struct {
    const Self = @This();
    lexer: Lexer,
    start_token: usize = 0,
    empty: bool = false,

    pub fn init(content: []const u8) Self {
        return .{
            .lexer = Lexer.init(content),
        };
    }

    fn createToken(self: *Self, tok_type: TokenType) Token {
        return .{ .span = self.lexer.sliceFrom(self.start_token), .tok_type = tok_type };
    }

    pub fn getToken(self: *Self) ?Token {
        if ( self.lexer.isEof() ) {
            if ( self.empty ) { 
                return null; 
            } else {
                self.empty = true;
                return Token { .span = "", .tok_type = .eof };
            }
        } 
        self.start_token = self.lexer.cursor();
        switch ( self.lexer.peekByte() ) {
            '\n' => { self.lexer.consume(); return self.createToken(.newline); },
            '\r' => { if ( self.lexer.matchAndConsumeSlice("\r\n")) { return self.createToken(.newline); } else { return self.createToken(.whitespace); } },
            '#'  => { self.lexer.skipLine(); return self.createToken(.comment); },
            '='  => { self.lexer.consume(); return self.createToken(.keyValSep); },
            '.'  => { self.lexer.consume(); return self.createToken(.dot); },
            ':'  => { self.lexer.consume(); return self.createToken(.colon); },
            ','  => { self.lexer.consume(); return self.createToken(.comma); },
            '+'  => { self.lexer.consume(); return self.createToken(.plus); },
            '-'  => { self.lexer.consume(); return self.createToken(.minus); },
            '}'  => { self.lexer.consume(); return self.createToken(.leftBrace); },
            '{'  => { self.lexer.consume(); return self.createToken(.rightBrace); },
            '['  => { self.lexer.consume(); return self.createToken(.leftBracket); },
            ']'  => { self.lexer.consume(); return self.createToken(.rightBracket); },
            ' ', '\t'  => {         
                self.lexer.skipWhitespace();
                return self.createToken(.whitespace);
            },
            '\'', '\"' => |quote| {
                self.lexer.consume();
                while ( !self.lexer.isEof() and self.lexer.peekByte() != quote ) {
                    if ( self.lexer.peekByte() == '\\' and self.lexer.peekByteForward(1) == quote ) {
                        self.lexer.consumeMany(2);
                    } else {
                        self.lexer.consume();
                    }
                }
                if ( self.lexer.isEof() ) {
                    self.empty = true; 
                    return Token { .span = "", .tok_type = .eof }; 
                }

                self.lexer.consume();
                return self.createToken(.quotedString);
            },
            else => | ch | {
                if ( is_keylike_char(ch) ) {
                    while ( !self.lexer.isEof() and is_keylike_char(self.lexer.peekByte())) {
                        self.lexer.consume();
                    }
                    return self.createToken(.keyLike);
                }
            }
        }
    }

    pub fn consumeToken(self: *Self) !void {

    }
    pub fn expectToken(self: *Self) !Token {

    }
};

pub const IniParser = struct {
    const Self = @This();
    pub const IniParserError = error {
        unexpectedCharacter,
    };
    const ParserState = enum {
        inSectionHeader,
        inKey,
        inValue,
        inErrorState,
    };
    // no default values -- it requires that struct should be created with `init`&`deinit` pair
    alloc: *std.mem.Allocator,
    tokenizer: Tokenizer,
    current_state: ParserState = .inKey,
    last_section: *Section = undefined,

    pub fn init(alloc: *std.mem.Allocator, content: []const u8) !Self {
        return .{
            .alloc = alloc,
            .tokenizer = Tokenizer.init(content),
        };
    }

    pub fn deinit(self: *Self) void {
        // deinitialization code
    }

    fn parseTableHeader(self: *Self, current_token_or_null: ?Token, section: *Section) !*Section {
        // base case
        const current_token = current_token_or_null orelse { return error.unexpectedCharacter; };
        if ( current_token.tok_type == .rightBracket ) {
            return section;
        }
        if ( current_token.tok_type == .dot ) {
            const new_token = try self.tokenizer.expectToken(.keyLike);
            var new_section = self.createSection();
            try section.entries.put(next_token.span, .{ .section = new_section });
            return self.parseTableHeader(self.tokenizer.getToken(), new_section);
        }
    }
    
    fn parseExpression(self: *Self, current_token: Token, output: *Ini) !void {
        switch ( current_token.tok_type ) {
            .comment => { 
                // # comment
                return;
                
            },
            .keyLike => {
                // key = value
                const key = current_token.span;
                try self.tokenizer.consumeToken(.whitespace); 
                try self.tokenizer.consumeToken(.keyValSep);
                try self.tokenizer.consumeToken(.whitespace);
                const value_or_null = self.tokenizer.getToken();
                if ( value_or_null == null ) {
                    return error.unexpectedCharacter;
                }
                const value = value_or_null.?;
                if ( value.tok_type == .quotedString ) {
                    self.last_section 
                }

            },
            .leftBracket => {
                // if dotted -> we should build whole tree   
                var top_level: *Section = self.createSection();
                const top_token = try self.tokenizer.expectToken(.keyLike);
                try output.entries.put(top_token.span, .{ .section = top_level});
                var deepest_level: *Section = self.parseTableHeader(top_token, top_level);
                self.last_section = deepest_level;
            }
        }
    }

    pub fn parseValue(self: *Self) !ini.Entry {
        
    }

    pub fn createSection(self: *Self) !*ini.Section {
        var section: *Section = try std.testing.allocator.create(Section);
        section.* = Section.init(std.testing.allocator);
        return section;
    }


    pub fn parse(self: *Self, output: *Ini) !void {
        while ( self.tokenizer.getToken() ) | token | {
            if ( token.tok_type == .whitespace or token.tok_type == .newline ) continue;
            try self.parseExpression(token, output);
        }
    }
};