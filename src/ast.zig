const std = @import("std");
const token = @import("token.zig");

pub const Statement = union(token.TokenType) {
    Illegal: void, 
    EOF: void, 

    // Identifiers + Constructors
    Identifier: void, 
    // Constructor,  // Cannot determine if its an id or constructor in lexer
    
    // Operators
    Assign: Assignment, 
    Arrow: void, 

    // Delimiters
    Semicolon: void, 
    Comma: void, 

    LeftParen: void, 
    RightParen: void, 
    LeftBracket: void, 
    RightBracket: void, 
    LeftCurlyBracket: void, 
    RightCurlyBracket: void, 

    // Keywords
    Local: void,

    Case: void, 
    CaseOf: void, 

    While: void, 
    WhileIs: void, 

    DefineFunction: void, 
    FunctionReturns: void, 
    CallOn: void, 
};

pub const Assignment = struct {
    vars: []Variable,
    expressions: []Expression,
};

pub const ExpressionType = enum {
    Constructor, 
    Variable,
};

pub const Expression = union(ExpressionType) {
    Constructor: Constructor,
    Variable: Variable,
};

pub const Constructor = struct {
    literal: token.Token.LiteralType, 
    parameters: []Expression,
};

pub const Variable = struct {
    name: token.Token.LiteralType,
};

pub const Program = struct {
    const StatementsType = std.ArrayList(Statement); 
    const programAllocator = std.heap.page_allocator;
    statements: StatementsType,

    pub fn init() Program {
        return .{ .statements = StatementsType.init(programAllocator) }; 
    }
};
