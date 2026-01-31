module bformat.formattest;

import bformat.write;
import bformat.spec;

import std.algorithm.searching : canFind;
import std.conv : text;
import std.array : appender;
import std.exception : enforce;

import core.exception : AssertError;

version (StdUnittest)
void formatTest(T)(T val, string expected, size_t ln = __LINE__, string fn = __FILE__)
{
    formatTest(val, [expected], ln, fn);
}

version (StdUnittest)
void formatTest(T)(string fmt, T val, string expected, size_t ln = __LINE__, string fn = __FILE__) @safe
{
    formatTest(fmt, val, [expected], ln, fn);
}

version (StdUnittest)
void formatTest(T)(T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__)
{

    FormatSpec f;
    auto w = appender!string();
    formatValue(w, val, f);
    enforce!AssertError(expected.canFind(w.data),
        text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
void formatTest(T)(string fmt, T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__) @safe
{
    auto w = appender!string();
    formattedWrite(w, fmt, val);
    enforce!AssertError(expected.canFind(w.data),
        text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}
