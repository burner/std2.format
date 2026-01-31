module bformat.buffered_stdout;

import std.range.primitives;
import std.algorithm : copy;
import std.array : array;
import std.stdio;
import core.sys.posix.unistd : write, STDOUT_FILENO;


/**
 * A buffered output range that writes to stdout only when its 64-byte buffer is full.
 * Accumulates ubyte elements and flushes to stdout using direct Linux file descriptor I/O.
 * Manual flush() is required for any remaining bytes at the end.
 */
struct BufferedStdoutRange {
    private ubyte[64] buffer;
    private size_t index = 0;

    /**
     * Puts a single ubyte into the buffer. Flushes if buffer is full.
     */
    void put(ubyte b) {
        buffer[index++] = b;
        if(index == 64) {
            flush();
        }
    }

    /**
     * Puts a range of ubytes into the buffer, handling each element.
     */
    void put(R)(R range) if (isInputRange!R && is(ElementType!R : ubyte)) {
        foreach(e; range) {
            put(e);
        }
    }

    /**
     * Flushes any remaining bytes in the buffer to stdout and resets the index.
     */
    void flush() {
        if(index > 0) {
            write(STDOUT_FILENO, &buffer[0], index);
            index = 0;
        }
    }
}

unittest {
    // Test single puts
    auto buf = BufferedStdoutRange();
    buf.put(65); // 'A'
    buf.put(66); // 'B'
    // Buffer not full, nothing written yet

    // Fill buffer to 64 bytes
    foreach(i; 2 .. 64) {
        buf.put(cast(ubyte)(i + 65));
    }
    // Now should have written 64 bytes to stdout

    // Add more
    buf.put(67); // 'C'
    buf.flush(); // Should write the 'C'

    // Test with range
    ubyte[] testRange = [68, 69, 70]; // 'D', 'E', 'F'
    copy(testRange, buf);
    buf.flush(); // Should write 'D', 'E', 'F'
}
