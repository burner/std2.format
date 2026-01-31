module bformat.checkformatexception;

import bformat.write;
import bformat.noopsink;
import bformat.exception;
import bformat.formatfunction2;

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

