const std = @import("std");
const token = @import("token.zig");

inline fn printIndented(
    writer: anytype,
    comptime str: []const u8,
    indent: ?usize,
    args: anytype
) !void {
    if (indent != null)
        try writer.print("{[0]:>[1]}", .{ "\t", indent });
    try writer.print(str, args);    
}

pub const Statement = union(enum) {
    Illegal: void, 
    Assign: Assignment, 
    Local: Local, 
    Case: Case,
    While: While,
    DefineFunction: DefineFunction,
    CallFunction: CallFunction,
};

pub const Assignment = struct {
    vars: []Variable,
    expressions: []Expression,

};

pub const Local = struct {
    vars: []Variable,
    scope: Program,    
};

pub const Case = struct {
    variable: Variable,
    branches: []Branch,    
};

pub const While = struct {
    variable: Variable,
    branches: []Branch,    
};

pub const Branch = struct {
    constructorName: token.Token.LiteralType, 
    captureParameters: []Variable,
    branchProgram: Program,
};

pub const DefineFunction = struct {
    name: token.Token.LiteralType,
    parameters: []Variable,
    returns: Variable,
    program: Program, 
};

pub const CallFunction = struct {
    name: token.Token.LiteralType,
    parameters: []Expression,
    on: Variable,
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
    const LiteralType = token.Token.LiteralType;
    name: LiteralType = std.mem.zeroes(LiteralType),
};

pub const Program = struct {
    statements: []Statement,
};

