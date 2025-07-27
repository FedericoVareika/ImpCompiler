const std = @import("std");

const TokenType = enum {
    Keyword,
    Identifier,
    Delimiter,
    Operator,
    Literal, // i dont know if this is necessary
};

const Token = union(TokenType) {
    Keyword: [:0]const u8,
    Identifier: [:0]const u8,
    Delimiter: u8,
    Operator: [:0]const u8,
    Literal: [:0]const u8,
};

const Cursor = struct {
    buffer: []u8,
    at: u32,

    nextWord: [100:0]u8,
    nextWordLen: u32,

    pub fn advance(self: Cursor) u8 {
        self.at += 1;
        return self.buffer[self.at];
    }

    pub fn getCharWithDelta(self: Cursor, delta: u32) ?u8 {
        if (self.at + delta > self.buffer.len) return null;
        return self.buffer[self.at + delta];
    }
    pub fn getChar(self: Cursor) ?u8 {
        return self.getCharWithDelta(0);
    }

    pub fn nextToken(self: Cursor) void {
        var skippingWord = true;
        while (self.getChar()) |char| : (self.advance()) {
            switch (char) {
                std.ascii.whitespace => {
                    if (skippingWord) skippingWord = false else continue;
                },
                _ => {
                    if (skippingWord) continue else break;
                },
            }
        }
    }

    pub fn setNextWord(self: Cursor) void {
        var i = 0;

        defer {
            self.nextWordLen = i;
            self.nextWord[i] = 0;
        }

        while (self.getCharWithDelta(i) and i < self.nextWord.len) |char| : (i += 1) {
            switch (char) {
                std.ascii.whitespace => {
                    return;
                },
                _ => self.nextWord[i] = char,
            }
        }
    }

    pub fn getNextWord(self: Cursor) [:0]u8 {
        return self.nextWord[0..self.nextWordLen :0];
    }
};

const knownTokens = [_]Token{
    .{ .Keyword = "local" },
    .{ .Keyword = "case" },
    .{ .Keyword = "of" },
    .{ .Keyword = "while" },
    .{ .Keyword = "is" },
    .{ .Keyword = "def" },
    .{ .Keyword = "returns" },
    .{ .Keyword = "on" },
    .{ .Operator = ":=" },
    .{ .Operator = ";" },
    .{ .Operator = "->" },
    .{ .Operator = "," },
    .{ .Delimiter = "[" },
    .{ .Delimiter = "]" },
    .{ .Delimiter = "(" },
    .{ .Delimiter = ")" },
};

pub fn tokenize(input: []u8) []Token {
    var cursor: Cursor = .{ input, 0 };
    var tokens = std.ArrayList(Token).init(std.heap.c_allocator);

    while (cursor.nextToken()) {
        switch (cursor.getChar()) {}
    }

    return tokens.toOwnedSlice();
}
