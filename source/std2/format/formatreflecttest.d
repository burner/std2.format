module std2.format.formatreflecttest;

import core.exception : AssertError;
import std.exception : enforce;
import std.algorithm.searching : canFind;
import std.array : appender;
import std.math.operations : isClose;
import std.traits : FloatingPointTypeOf;

import std2.format.internal.write;

private void formatReflectTest(T)(ref T val, string fmt, string formatted, string fn = __FILE__, size_t ln = __LINE__)
{
    formatReflectTest(val, fmt, [formatted], fn, ln);
}

private void formatReflectTest(T)(ref T val, string fmt, string[] formatted, string fn = __FILE__, size_t ln = __LINE__)
{
    auto w = appender!string();
    formattedWrite(w, fmt, val);

    auto input = w.data;
    enforce!AssertError(formatted.canFind(input), input, fn, ln);

    //T val2;
    //formattedRead(input, fmt, val2);

    //static if (is(FloatingPointTypeOf!T))
    //    enforce!AssertError(isClose(val, val2), input, fn, ln);
    //else
    //    enforce!AssertError(val == val2, input, fn, ln);
}

@safe unittest
{
    void booleanTest()
    {
        auto b = true;
        formatReflectTest(b, "%s", `true`);
        formatReflectTest(b, "%b", `1`);
        formatReflectTest(b, "%o", `1`);
        formatReflectTest(b, "%d", `1`);
        formatReflectTest(b, "%u", `1`);
        formatReflectTest(b, "%x", `1`);
    }

    void integerTest()
    {
        auto n = 127;
        formatReflectTest(n, "%s", `127`);
        formatReflectTest(n, "%b", `1111111`);
        formatReflectTest(n, "%o", `177`);
        formatReflectTest(n, "%d", `127`);
        formatReflectTest(n, "%u", `127`);
        formatReflectTest(n, "%x", `7f`);
    }

    void floatingTest()
    {
        auto f = 3.14;
        formatReflectTest(f, "%s", `3.14`);
        formatReflectTest(f, "%e", `3.140000e+00`);
        formatReflectTest(f, "%f", `3.140000`);
        formatReflectTest(f, "%g", `3.14`);
    }

    void charTest()
    {
        auto c = 'a';
        formatReflectTest(c, "%s", `a`);
        formatReflectTest(c, "%c", `a`);
        formatReflectTest(c, "%b", `1100001`);
        formatReflectTest(c, "%o", `141`);
        formatReflectTest(c, "%d", `97`);
        formatReflectTest(c, "%u", `97`);
        formatReflectTest(c, "%x", `61`);
    }

    void strTest()
    {
        auto s = "hello";
        formatReflectTest(s, "%s",              `hello`);
        formatReflectTest(s, "%(%c,%)",         `h,e,l,l,o`);
        formatReflectTest(s, "%(%s,%)",         `'h','e','l','l','o'`);
        formatReflectTest(s, "[%(<%c>%| $ %)]", `[<h> $ <e> $ <l> $ <l> $ <o>]`);
    }

    void daTest()
    {
        auto a = [1,2,3,4];
        formatReflectTest(a, "%s",              `[1, 2, 3, 4]`);
        formatReflectTest(a, "[%(%s; %)]",      `[1; 2; 3; 4]`);
        formatReflectTest(a, "[%(<%s>%| $ %)]", `[<1> $ <2> $ <3> $ <4>]`);
    }

    void saTest()
    {
        int[4] sa = [1,2,3,4];
        formatReflectTest(sa, "%s",              `[1, 2, 3, 4]`);
        formatReflectTest(sa, "[%(%s; %)]",      `[1; 2; 3; 4]`);
        formatReflectTest(sa, "[%(<%s>%| $ %)]", `[<1> $ <2> $ <3> $ <4>]`);
    }

    void aaTest()
    {
        auto aa = [1:"hello", 2:"world"];
        formatReflectTest(aa, "%s",                    [`[1:"hello", 2:"world"]`, `[2:"world", 1:"hello"]`]);
        formatReflectTest(aa, "[%(%s->%s, %)]",        [`[1->"hello", 2->"world"]`, `[2->"world", 1->"hello"]`]);
        formatReflectTest(aa, "{%([%s=%(%c%)]%|; %)}", [`{[1=hello]; [2=world]}`, `{[2=world]; [1=hello]}`]);
    }

    //import std.exception : assertCTFEable;

    //assertCTFEable!(
    {
        booleanTest();
        integerTest();
        floatingTest();
        charTest();
        strTest();
        daTest();
        saTest();
        aaTest();
    }
		//);
}
