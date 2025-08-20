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

///
@safe unittest
{
    // Easiest way is to use `%s` everywhere:
    assert(format("I got %s %s for %s euros.", 30, "eggs", 5.27) == "I got 30 eggs for 5.27 euros.");

    // Other format characters provide more control:
    assert(format("I got %b %(%X%) for %f euros.", 30, "eggs", 5.27) == "I got 11110 65676773 for 5.270000 euros.");
}

/// Compound specifiers allow formatting arrays and other compound types:
@safe unittest
{
/*
The trailing end of the sub-format string following the specifier for
each item is interpreted as the array delimiter, and is therefore
omitted following the last array item:
 */
    assert(format("My items are %(%s %).", [1,2,3]) == "My items are 1 2 3.");
    assert(format("My items are %(%s, %).", [1,2,3]) == "My items are 1, 2, 3.");

/*
The "%|" delimiter specifier may be used to indicate where the
delimiter begins, so that the portion of the format string prior to
it will be retained in the last array element:
 */
    assert(format("My items are %(-%s-%|, %).", [1,2,3]) == "My items are -1-, -2-, -3-.");

/*
These compound format specifiers may be nested in the case of a
nested array argument:
 */
    auto mat = [[1, 2, 3],
                [4, 5, 6],
                [7, 8, 9]];

    assert(format("%(%(%d %) - %)", mat), "1 2 3 - 4 5 6 - 7 8 9");
    assert(format("[%(%(%d %) - %)]", mat), "[1 2 3 - 4 5 6 - 7 8 9]");
    assert(format("[%([%(%d %)]%| - %)]", mat), "[1 2 3] - [4 5 6] - [7 8 9]");

/*
Strings and characters are escaped automatically inside compound
format specifiers. To avoid this behavior, use "%-(" instead of "%(":
 */
    assert(format("My friends are %s.", ["John", "Nancy"]) == `My friends are ["John", "Nancy"].`);
    assert(format("My friends are %(%s, %).", ["John", "Nancy"]) == `My friends are "John", "Nancy".`);
    assert(format("My friends are %-(%s, %).", ["John", "Nancy"]) == `My friends are John, Nancy.`);
}

/// Using parameters:
@safe unittest
{
    // Flags can be used to influence to outcome:
    assert(format("%g != %+#g", 3.14, 3.14) == "3.14 != +3.14000");

    // Width and precision help to arrange the formatted result:
    assert(format(">%10.2f<", 1234.56789) == ">   1234.57<");

    // Numbers can be grouped:
    assert(format("%,4d", int.max) == "21,4748,3647");

    // It's possible to specify the position of an argument:
    assert(format("%3$s %1$s", 3, 17, 5) == "5 3");
}

/// Providing parameters as arguments:
@safe unittest
{
    // Width as argument
    assert(format(">%*s<", 10, "abc") == ">       abc<");

    // Precision as argument
    assert(format(">%.*f<", 5, 123.2) == ">123.20000<");

    // Grouping as argument
    assert(format("%,*d", 1, int.max) == "2,1,4,7,4,8,3,6,4,7");

    // Grouping separator as argument
    assert(format("%,3?d", '_', int.max) == "2_147_483_647");

    // All at once
    assert(format("%*.*,*?d", 20, 15, 6, '/', int.max) == "   000/002147/483647");
}

///
@safe unittest
{
    import std.exception : assertThrown;

    assertThrown!FormatException(format("%d", "foo"));
}

