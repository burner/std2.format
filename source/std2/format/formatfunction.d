module std2.format.formatfunction;

import core.exception : RangeError;

import std.traits : isSomeChar, isSomeString;
import std.array : appender;
import std.conv : text;
import std.range.primitives;
import std.utf : encode;

import std2.format.internal.write;
import std2.format.exception;
import std2.format.spec;
import std2.format.internal.checkformatexception;

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

/// ditto
typeof(fmt) format(alias fmt, Args...)(Args args)
if (isSomeString!(typeof(fmt)))
{
    import std.array : appender;
    import std.range.primitives : ElementEncodingType;
    import std.traits : Unqual;

    alias e = checkFormatException!(fmt, Args);
    alias Char = char;

    static assert(!e, e);
    auto w = appender!(string);

    // no need to traverse the string twice during compile time
    if (!__ctfe)
    {
        enum len = guessLength(fmt);
        w.reserve(len);
    }
    else
    {
        w.reserve(fmt.length);
    }

    formattedWrite(w, fmt, args);
    return w.data;
}

// called during compilation to guess the length of the
// result of format
private size_t guessLength(string fmtString) pure @safe
{
    import std.array : appender;

    size_t len;
    auto output = appender!(string)();
    auto spec = FormatSpec(fmtString);
    while (spec.writeUpToNextSpec(output))
    {
        // take a guess
        if (spec.width == 0 && (spec.precision == spec.UNSPECIFIED || spec.precision == spec.DYNAMIC))
        {
            switch (spec.spec)
            {
                case 'c':
                    ++len;
                    break;
                case 'd':
                case 'x':
                case 'X':
                    len += 3;
                    break;
                case 'b':
                    len += 8;
                    break;
                case 'f':
                case 'F':
                    len += 10;
                    break;
                case 's':
                case 'e':
                case 'E':
                case 'g':
                case 'G':
                    len += 12;
                    break;
                default: break;
            }

            continue;
        }

        if ((spec.spec == 'e' || spec.spec == 'E' || spec.spec == 'g' ||
             spec.spec == 'G' || spec.spec == 'f' || spec.spec == 'F') &&
            spec.precision != spec.UNSPECIFIED && spec.precision != spec.DYNAMIC &&
            spec.width == 0
        )
        {
            len += spec.precision + 5;
            continue;
        }

        if (spec.width == spec.precision)
            len += spec.width;
        else if (spec.width > 0 && spec.width != spec.DYNAMIC &&
                 (spec.precision == spec.UNSPECIFIED || spec.width > spec.precision))
        {
            len += spec.width;
        }
        else if (spec.precision != spec.UNSPECIFIED && spec.precision > spec.width)
            len += spec.precision;
    }
    len += output.data.length;
    return len;
}

@safe pure
unittest
{
    assert(guessLength("%c") == 1);
    assert(guessLength("%d") == 3);
    assert(guessLength("%x") == 3);
    assert(guessLength("%b") == 8);
    assert(guessLength("%f") == 10);
    assert(guessLength("%s") == 12);
    assert(guessLength("%02d") == 2);
    assert(guessLength("%02d") == 2);
    assert(guessLength("%4.4d") == 4);
    assert(guessLength("%2.4f") == 4);
    assert(guessLength("%02d:%02d:%02d") == 8);
    assert(guessLength("%0.2f") == 7);
    assert(guessLength("%0*d") == 0);
}

/**
Converts its arguments according to a format string into a buffer.
The buffer has to be large enough to hold the formatted string.

The second version of `sformat` takes the format string as a template
argument. In this case, it is checked for consistency at
compile-time.

Params:
    buf = the buffer where the formatted string should go
    fmt = a $(MREF_ALTTEXT format string, std2.format)
    args = a variadic list of arguments to be formatted
    Char = character type of `fmt`
    Args = a variadic list of types of the arguments

Returns:
    A slice of `buf` containing the formatted string.

Throws:
    A $(REF_ALTTEXT RangeError, RangeError, core, exception) if `buf`
    isn't large enough to hold the formatted string
    and a $(LREF FormatException) if formatting did not succeed.

Note:
    In theory this function should be `@nogc`. But with the current
    implementation there are some cases where allocations occur:

    $(UL
    $(LI An exception is thrown.)
    $(LI A custom `toString` function of a compound type allocates.))
 */
char[] sformat(Args...)(return scope char[] buf, string fmt, Args args)
{
    static struct Sink
    {
        char[] buf;
        size_t i;
        void put(char c)
        {
            if (buf.length <= i)
                throw new RangeError(__FILE__, __LINE__);

            buf[i] = c;
            i += 1;
        }
        void put(dchar c)
        {
            char[4] enc;
            auto n = encode(enc, c);

            if (buf.length < i + n)
                throw new RangeError(__FILE__, __LINE__);

            buf[i .. i + n] = enc[0 .. n];
            i += n;
        }
        void put(scope const(char)[] s)
        {
            if (buf.length < i + s.length)
                throw new RangeError(__FILE__, __LINE__);

            buf[i .. i + s.length] = s[];
            i += s.length;
        }
        void put(scope const(wchar)[] s)
        {
            for (; !s.empty; s.popFront())
                put(s.front);
        }
        void put(scope const(dchar)[] s)
        {
            for (; !s.empty; s.popFront())
                put(s.front);
        }
    }
    auto sink = Sink(buf);
    auto n = formattedWrite(sink, fmt, args);
    version (all)
    {
        // In the future, this check will be removed to increase consistency
        // with formattedWrite
        import std.conv : text;
        enforceFmt(
            n == args.length,
            text("Orphan format arguments: args[", n, " .. ", args.length, "]")
        );
    }
    return buf[0 .. sink.i];
}

/// ditto
char[] sformat(alias fmt, Args...)(char[] buf, Args args)
if (isSomeString!(typeof(fmt)))
{
    alias e = checkFormatException!(fmt, Args);
    static assert(!e, e);
    return .sformat(buf, fmt, args);
}

///
@safe pure unittest
{
    char[20] buf;
    assert(sformat(buf[], "Here are %d %s.", 3, "apples") == "Here are 3 apples.");

    assert(buf[].sformat("Increase: %7.2f %%", 17.4285) == "Increase:   17.43 %");
}

/// The format string can be checked at compile-time:
@safe pure unittest
{
    char[20] buf;

    assert(sformat!"Here are %d %s."(buf[], 3, "apples") == "Here are 3 apples.");

    // This line doesn't compile, because 3.14 cannot be formatted with %d:
    // writeln(sformat!"Here are %d %s."(buf[], 3.14, "apples"));
}

// checking, what is implicitly and explicitly stated in the public unittest
@safe unittest
{
    import std.exception : assertThrown;

    char[20] buf;
    assertThrown!FormatException(sformat(buf[], "Here are %d %s.", 3.14, "apples"));
    assert(!__traits(compiles, sformat!"Here are %d %s."(buf[], 3.14, "apples")));
}

@safe unittest
{
    import core.exception : RangeError;
    //import std.exception : assertCTFEable, assertThrown;
    import std.exception : assertThrown;

    //assertCTFEable!(
    {
        char[10] buf;

        assert(sformat(buf[], "foo") == "foo");
        assert(sformat(buf[], "foo%%") == "foo%");
        assert(sformat(buf[], "foo%s", 'C') == "fooC");
        assert(sformat(buf[], "%s foo", "bar") == "bar foo");
        () @trusted {
            assertThrown!RangeError(sformat(buf[], "%s foo %s", "bar", "abc"));
        } ();
        assert(sformat(buf[], "foo %d", -123) == "foo -123");
        assert(sformat(buf[], "foo %d", 123) == "foo 123");

        assertThrown!FormatException(sformat(buf[], "foo %s"));
        assertThrown!FormatException(sformat(buf[], "foo %s", 123, 456));

        assert(sformat(buf[], "%s %s %s", "c"c, "w"w, "d"d) == "c w d");
    }
		//);
}

@safe unittest // ensure that sformat avoids the GC
{
    import core.memory : GC;

    const a = ["foo", "bar"];
    const u = () @trusted { return GC.stats().usedSize; } ();
    char[20] buf;
    sformat(buf, "%d", 123);
    sformat(buf, "%s", a);
    sformat(buf, "%s", 'c');
    const v = () @trusted { return GC.stats().usedSize; } ();
    assert(u == v);
}

@safe unittest // https://issues.dlang.org/show_bug.cgi?id=23488
{
    static struct R
    {
        string s = "Ü";
        bool empty() { return s.length == 0; }
        char front() { return s[0]; }
        void popFront() { s = s[1 .. $]; }
    }
    char[2] buf;
    assert(sformat(buf, "%s", R()) == "Ü");
}
