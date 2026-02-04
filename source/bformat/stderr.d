module bformat.stderr;

import std.range.primitives;
import std.array : appender;
import bformat.formatfunction;
import bformat.formatfunction2;
import bformat.buffered_stderr;

/**
Writes a string to standard error.

The function uses a 4096-byte page-aligned buffer for optimal kernel I/O
performance and automatically flushes buffer after writing. No newline is
appended to the output.

Params:
    fmt = The string to write to standard error.

See_Also:
    $(LREF stdErrln) for a variant that appends a newline,
    $(LREF stdErrf) for formatted output,
    $(LREF format) for formatting to a string.
*/
void stdErr(string fmt) {
	BufferedStderrRange oRng;
	oRng.put(fmt);
	oRng.flush();
}

/**
Writes a string to standard error followed by a newline.

The function uses a 4096-byte page-aligned buffer for optimal kernel I/O
performance, appends a newline after the string, and automatically flushes
the buffer after writing.

Params:
    fmt = The string to write to standard error.

See_Also:
    $(LREF stdErr) for a variant without a newline,
    $(LREF stdErrfln) for formatted output with a newline.
*/
void stdErrln(string fmt) {
	BufferedStderrRange oRng;
	oRng.put(fmt);
	oRng.put("\n");
	oRng.flush();
}

/**
Writes formatted output to standard error using format specifiers.

The function uses a 4096-byte page-aligned buffer for optimal kernel I/O
performance and automatically flushes the buffer after writing. No newline is
appended to the output. All format specifiers supported by this package can
be used (see package documentation for details on format strings and specifiers).

Params:
    fmt = A $(I format string) containing format specifiers.
    args = A variadic list of arguments to be formatted according to $(D fmt).

Throws:
    A $(LREF FormatException) if formatting did not succeed.

See_Also:
    $(LREF stdErrfln) for a variant that appends a newline,
    $(LREF stdErr) for simple string output,
    $(LREF format) for formatting to a string.

Example:
---
stdErrf("%s %d", "Error:", 42); // Writes: "Error: 42"
stdErrf("%.2f", 3.14159);      // Writes: "3.14"
stdErrf("%5s", "hi");           // Writes: "   hi"
---
*/
void stdErrf(Args...)(string fmt, Args args) {
	BufferedStderrRange oRng;
	formattedWrite(oRng, fmt, args);
	oRng.flush();
}

/**
Writes formatted output to standard error followed by a newline.

The function uses a 4096-byte page-aligned buffer for optimal kernel I/O
performance, appends a newline after the formatted output, and automatically
flushes the buffer. All format specifiers supported by this package can be
used (see package documentation for details on format strings and specifiers).

Params:
    fmt = A $(I format string) containing format specifiers.
    args = A variadic list of arguments to be formatted according to $(D fmt).

Throws:
    A $(LREF FormatException) if formatting did not succeed.

See_Also:
    $(LREF stdErrf) for a variant without a newline,
    $(LREF stdErrln) for simple string output with a newline,
    $(LREF format) for formatting to a string.

Example:
---
stdErrfln("%s %d", "Code:", 500); // Writes: "Code: 500\n"
stdErrfln("%.1f", 2.5);          // Writes: "2.5\n"
stdErrfln("%6s", "ok");            // Writes: "    ok\n"
---
*/
void stdErrfln(Args...)(string fmt, Args args) {
	BufferedStderrRange oRng;
	formattedWrite(oRng, fmt, args);
	oRng.put("\n");
	oRng.flush();
}

version (Posix)
{
	import std.array : appender;
	import std.exception : enforce;
	import std.stdio : stderr;
	import core.stdc.errno : errno, EINTR;
	import core.sys.posix.unistd : pipe, dup, dup2, close, read, STDERR_FILENO;

	private string captureStderr(void delegate() action)
	{
		int[2] fds;
		enforce(pipe(fds) == 0, "pipe failed");
		scope(exit) close(fds[0]);

		const saved = dup(STDERR_FILENO);
		enforce(saved != -1, "dup failed");
		enforce(dup2(fds[1], STDERR_FILENO) != -1, "dup2 failed");
		close(fds[1]);

		action();
		stderr.flush();

		enforce(dup2(saved, STDERR_FILENO) != -1, "restore failed");
		close(saved);

		auto sink = appender!string();
		ubyte[256] buffer;

		while (true)
		{
			auto count = read(fds[0], buffer.ptr, buffer.length);
			if (count == 0)
				break;
			if (count > 0)
			{
				assert(count <= buffer.length, "Buffer overflow in stdErr");
				sink.put(cast(const(char)[]) buffer[0 .. count]);
				continue;
			}
			if (errno == EINTR)
			{
				errno = 0;
				continue;
			}
			enforce(false, "read failed");
		}
		return sink.data;
	}

	enum string block16 = "0123456789ABCDEF";
	enum string sixtyFourChars = block16 ~ block16 ~ block16 ~ block16;
	enum string overSixtyFour = sixtyFourChars ~ "XYZ";

	unittest
	{
		assert(captureStderr({ stdErr("hello"); }) == "hello");
	}

	unittest
	{
		assert(captureStderr({ stdErr(""); }) == "");
	}

	unittest
	{
		assert(captureStderr({ stdErr("line1\nline2"); }) == "line1\nline2");
	}

	unittest
	{
		assert(captureStderr({ stdErr(sixtyFourChars); }) == sixtyFourChars);
	}

	unittest
	{
		assert(captureStderr({ stdErr(overSixtyFour); }) == overSixtyFour);
	}

	unittest
	{
		assert(captureStderr({ stdErrln("alpha"); }) == "alpha\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrln(""); }) == "\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrln("beta\n"); }) == "beta\n\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrln(sixtyFourChars); }) == sixtyFourChars ~ "\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrln(overSixtyFour); }) == overSixtyFour ~ "\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrf("%s", "items"); }) == "items");
	}

	unittest
	{
		assert(captureStderr({ stdErrf("%d", -42); }) == "-42");
	}

	unittest
	{
		assert(captureStderr({ stdErrf("%.2f", 3.14159); }) == "3.14");
	}

	unittest
	{
		assert(captureStderr({ stdErrf("%5s", "hi"); }) == "   hi");
	}

	unittest
	{
		assert(captureStderr({ stdErrf("%s %d %x", "count", 255, 255); }) == "count 255 ff");
	}

	unittest
	{
		assert(captureStderr({ stdErrfln("%s", "done"); }) == "done\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrfln("%d", 123); }) == "123\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrfln("%.1f", 2.5); }) == "2.5\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrfln("%6s", "ok"); }) == "    ok\n");
	}

	unittest
	{
		assert(captureStderr({ stdErrfln("%s %d %X", "hex", 16, 255); }) == "hex 16 FF\n");
	}
 }
