const std = @import("std");
const token = @import("token.zig");

pub const Statement = union(enum) {
    Illegal: void, 
    Assign: Assignment, 
    Local: Local, 
};

pub const Assignment = struct {
    vars: []Variable,
    expressions: []Expression,
};

pub const Local = struct {
    vars: []Variable,
    scope: Program,    
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

fn printAssignment(assignment: Assignment) void {
    const print = std.debug.print;

    print("Assignment:\n", .{});

    for (assignment.vars, assignment.expressions) |variable, expression| {
        print("{s} := ", .{
            &variable.name,
        });
        printExpression(expression);
        print("\n", .{});
    }
}

fn printStatement(stmt: Statement) void {
    switch (stmt) {
        .Assign => |assignment| {
            printAssignment(assignment);
        },
        else => {},
    }
}

pub fn printProgram(prog: Program) void {
    for (prog.statements) |stmt| {
        printStatement(stmt);
    }
}

