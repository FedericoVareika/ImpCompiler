const std = @import("std");

pub const TokenType = enum {
    Illegal, 
    EOF, 

    // Identifiers + Constructors
    Identifier, 
    // Constructor,  // Cannot determine if its an id or constructor in lexer
    
    // Operators
    Assign, 
    Arrow, 

    // Delimiters
    Semicolon, 
    Comma, 

    LeftParen, 
    RightParen, 
    LeftBracket, 
    RightBracket, 
    LeftBrace, 
    RightBrace, 

    // Keywords
    Local,

    Case, 
    CaseOf, 

    While, 
    WhileIs, 

    DefineFunction, 
    FunctionReturns, 
    CallOn, 


    const multiCharacterLookup = std.StaticStringMap(TokenType).initComptime(.{
        .{ ":=", .Assign }, 
        .{ "->", .Arrow }, 
        .{ "local", .Local }, 
        .{ "case", .Case }, 
        .{ "of", .CaseOf }, 
        .{ "while", .While }, 
        .{ "is", .WhileIs }, 
        .{ "def", .DefineFunction }, 
        .{ "returns", .FunctionReturns }, 
        .{ "on", .CallOn }, 
    });

    pub fn parse(str: []const u8) ?TokenType {
        return multiCharacterLookup.get(str);
    }
};

pub const Token = struct {
    const literalLength = 100;

    type: TokenType, 
    literal: [literalLength:0]u8 = std.mem.zeroes([literalLength:0]u8),
};
