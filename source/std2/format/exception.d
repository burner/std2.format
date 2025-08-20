module std2.format.exception;

import std.exception : enforce;

/**
Signals an issue encountered while formatting.
 */
class FormatException : Exception
{
    /// Generic constructor.
    @safe @nogc pure nothrow
    this()
    {
        super("format error");
    }

    /**
       Creates a new instance of `FormatException`.

       Params:
           msg = message of the exception
           fn = file name of the file where the exception was created (optional)
           ln = line number of the file where the exception was created (optional)
           next = for internal use, should always be null (optional)
     */
    @safe @nogc pure nothrow
    this(string msg, string fn = __FILE__, size_t ln = __LINE__, Throwable next = null)
    {
        super(msg, fn, ln, next);
    }
}

package alias enforceFmt = enforce!FormatException;

