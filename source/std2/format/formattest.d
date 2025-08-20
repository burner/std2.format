module std2.format.formattest;

version (StdUnittest)
private void formatTest(T)(T val, string expected, size_t ln = __LINE__, string fn = __FILE__)
{
    //formatTest(val, [expected], ln, fn);
}

version (StdUnittest)
private void formatTest(T)(string fmt, T val, string expected, size_t ln = __LINE__, string fn = __FILE__) @safe
{
    //formatTest(fmt, val, [expected], ln, fn);
}

version (StdUnittest)
private void formatTest(T)(T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__)
{

    //FormatSpec f;
    //auto w = appender!string();
    //formatValue(w, val, f);
    //enforce!AssertError(expected.canFind(w.data),
    //    text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
private void formatTest(T)(string fmt, T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__) @safe
{
    //auto w = appender!string();
    //formattedWrite(w, fmt, val);
    //enforce!AssertError(expected.canFind(w.data),
    //    text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}
