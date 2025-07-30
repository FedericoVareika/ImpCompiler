const std = @import("std");
const token = @import("token.zig");

pub const Statement = union(enum) {
    Illegal: void, 
    Assign: Assignment, 
    Local: Local, 
    Case: Case,
    While: While,
    DefineFunction: DefineFunction,
    CallFunction: CallFunction,

    pub fn format(
        self: Statement,
        comptime fmt: []const u8, 
        options: std.fmt.FormatOptions,
        writer: anytype,     
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .Illegal => {},
            .Assign => |assignment| {
                try writer.print("Assignment (\n", .{ });
                for (assignment.vars, assignment.expressions) |variable, expression| {
                    try writer.print("{s} := ", .{
                        &variable.name,
                    });
                    printExpression(expression);
                    try writer.print("\n", .{});
                }
            }, 
            .Local => |local| {
                try writer.print("Local [", .{ });
                for (local.vars) |variable| {
                    try writer.print("{s},", .{&variable.name});
                }
                try writer.print("] (\n{s}\n)", .{ local.scope });
            }, 
            else => {}
        }
    }
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

    pub fn format(
        self: Program,
        comptime fmt: []const u8, 
        options: std.fmt.FormatOptions,
        writer: anytype,     
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("Program (\n", .{});
        for (self.statements) |stmt| {
            try writer.print("{s}", .{ stmt });
        }
        try writer.print(")\n", .{});
    }
};

fn printConstructor(constructor: Constructor) void {
    const print = std.debug.print;

    print("Constructor {s} [", .{&constructor.literal});

    for (constructor.parameters, 0..) |param, i| {
        printExpression(param);
        if (constructor.parameters.len != i + 1)
            print(", ", .{});
    }
    print("]", .{});
}

fn printExpression(expression: Expression) void {
    const print = std.debug.print;
    switch (expression) {
        .Variable => |expressionVar| {
            print("Var {s}", .{&expressionVar.name});
        },
        .Constructor => |expressionConstructor| {
            printConstructor(expressionConstructor);
        },
    }
}

