module std2.format.noopsink;

// Like NullSink, but toString() isn't even called at all. Used to test the format string.
package struct NoOpSink
{
    void put(E)(scope const E) pure @safe @nogc nothrow {}
}

