module std2.format.formatfunction;

import std.traits : isSomeChar;
import std.array : appender;
import std.conv : text;

import std2.format.internal.write;
import std2.format.exception;

/**
Converts its arguments according to a format string into a string.

The second version of `format` takes the format string as template
argument. In this case, it is checked for consistency at
compile-time and produces slightly faster code, because the length of
the output buffer can be estimated in advance.

Params:
    fmt = a $(MREF_ALTTEXT format string, std,format)
    args = a variadic list of arguments to be formatted
    Args = a variadic list of types of the arguments

Returns:
    The formatted string.

Throws:
    A $(LREF FormatException) if formatting did not succeed.

See_Also:
    $(LREF sformat) for a variant, that tries to avoid garbage collection.
 */
string format(Args...)(in string fmt, Args args)
{
    auto w = appender!(string);
    auto n = formattedWrite(w, fmt, args);
    version (all)
    {
        // In the future, this check will be removed to increase consistency
        // with formattedWrite
        enforceFmt(n == args.length, text("Orphan format arguments: args[", n, "..", args.length, "]"));
    }
    return w.data;
}

///
@safe pure unittest
{
    assert(format("Here are %d %s.", 3, "apples") == "Here are 3 apples.");

    assert("Increase: %7.2f %%".format(17.4285) == "Increase:   17.43 %");
}

