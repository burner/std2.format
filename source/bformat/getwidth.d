module bformat.getwidth;

import std.algorithm.searching : all;
import std.uni : graphemeStride;

long getWidth(T)(T s)
{
    // check for non-ascii character
    if (s.all!(a => a <= 0x7F)) return s.length;

    //TODO: optimize this
    long width = 0;
    for (size_t i; i < s.length; i += graphemeStride(s, i))
        ++width;
    return width;
}
