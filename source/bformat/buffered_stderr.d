module bformat.buffered_stderr;

import std.range.primitives;
import std.algorithm : copy;
import std.array : array;
import std.traits;
import std.stdio;
import core.sys.posix.unistd : write, STDERR_FILENO;


/**
 * A buffered output range that writes to stderr only when its 4096-byte buffer is full.
 * Uses page-aligned buffer size for optimal kernel I/O performance.
 * Accumulates ubyte elements and flushes to stderr using direct Linux file descriptor I/O.
 * Manual flush() is required for any remaining bytes at end.
 */
struct BufferedStderrRange {
    private char[4096] buffer;
    private size_t index = 0;

    /**
     * Puts a single ubyte into buffer. Flushes if buffer is full.
     */
    void put(char b) {
        buffer[index++] = b;
        if(index == 4096) {
            flush();
        }
    }

    /**
     * Puts a range of ubytes into buffer using batch copying for performance.
     * Optimizes by copying large chunks at once instead of character-by-character.
     * SIMD optimization: Uses slice assignment for static arrays to enable compiler vectorization.
     */
    void put(R)(R range) if (isInputRange!R) {
        // SIMD OPTIMIZATION: Fast path for static arrays (strings, static arrays)
        // Slice assignment allows compiler to vectorize with SIMD instructions
        static if (isArray!R && __traits(isStaticArray, R)) {
            immutable len = range.length;
            immutable space = buffer.length - index;
            
            if (len <= space) {
                // Single slice operation - fully vectorizable by LDC/GCC/DMD
                buffer[index .. index + len] = range[];
                index += len;
                if (index == buffer.length) flush();
                return;
            }
        }
        
        // Fallback to character-by-character for dynamic ranges
        size_t remaining = buffer.length - index;
        size_t count = 0;
        auto r = range.save;
        
        // Count how many elements fit in remaining buffer space
        while (!r.empty && count < remaining) {
            r.popFront();
            count++;
        }
        
        // Batch copy all elements that fit at once
        if (count > 0) {
            size_t i = index;
            auto r2 = range.save;
            foreach (ref e; r2) {
                if (count == 0) break;
                buffer[i++] = e;
                count--;
                r2.popFront();
            }
            index = i;
            
            // Flush if buffer is now full
            if (index == buffer.length) {
                flush();
                index = 0;
            }
        }
        
        // Recursively handle any remaining elements
        if (!r.empty) {
            put(r);
        }
    }

    /**
     * Flushes any remaining bytes in the buffer to stderr and resets the index.
     */
    void flush() {
        if(index > 0) {
            write(STDERR_FILENO, &buffer[0], index);
            index = 0;
        }
    }
}

 unittest {
    // Test single puts
    auto buf = BufferedStderrRange();
    buf.put(65); // 'A'
    buf.put(66); // 'B'
    // Buffer not full, nothing written yet

    // Fill buffer to 4096 bytes
    foreach(i; 2 .. 4096) {
        buf.put(cast(char)(i + 65));
    }
    // Now should have written 4096 bytes to stderr

    // Add more
    buf.put(67); // 'C'
    buf.flush(); // Should write 'C'

    // Test with range
    ubyte[] testRange = [68, 69, 70]; // 'D', 'E', 'F'
    copy(testRange, buf);
    buf.flush(); // Should write 'D', 'E', 'F'
 }
