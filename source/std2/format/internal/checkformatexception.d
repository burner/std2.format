module std2.format.internal.checkformatexception;

import std2.format.internal.write;
import std2.format.noopsink;
import std2.format.exception;

// Used to check format strings are compatible with argument types
enum checkFormatException(alias fmt, Args...) =
{
    import std.conv : text;

    try
    {
        auto n = .formattedWrite(NoOpSink(), fmt, Args.init);

        enforceFmt(n == Args.length, text("Orphan format arguments: args[", n, "..", Args.length, "]"));
    }
    catch (Exception e)
        return e.msg;
    return null;
}();

