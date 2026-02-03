module bformat.stdout;

import std.range.primitives;
import std.array : appender;
import bformat.formatfunction;
import bformat.formatfunction2;
import bformat.buffered_stdout;

void stdOut(string fmt) {
	BufferedStdoutRange oRng;
	oRng.put(fmt);
	oRng.flush();
}

void stdOutln(string fmt) {
	BufferedStdoutRange oRng;
	oRng.put(fmt);
	oRng.put("\n");
	oRng.flush();
}

void stdOutf(Args...)(string fmt, Args args) {
	BufferedStdoutRange oRng;
	formattedWrite(oRng, fmt, args);
	oRng.flush();
}

void stdOutfln(Args...)(string fmt, Args args) {
	BufferedStdoutRange oRng;
	formattedWrite(oRng, fmt, args);
	oRng.put("\n");
	oRng.flush();
}

version (Posix)
{
	import std.array : appender;
	import std.exception : enforce;
	import std.stdio : stdout;
	import core.stdc.errno : errno, EINTR;
	import core.sys.posix.unistd : pipe, dup, dup2, close, read, STDOUT_FILENO;

	private string captureStdout(void delegate() action)
	{
		int[2] fds;
		enforce(pipe(fds) == 0, "pipe failed");
		scope(exit) close(fds[0]);

		const saved = dup(STDOUT_FILENO);
		enforce(saved != -1, "dup failed");
		enforce(dup2(fds[1], STDOUT_FILENO) != -1, "dup2 failed");
		close(fds[1]);

		action();
		stdout.flush();

		enforce(dup2(saved, STDOUT_FILENO) != -1, "restore failed");
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
		assert(captureStdout({ stdOut("hello"); }) == "hello");
	}

	unittest
	{
		assert(captureStdout({ stdOut(""); }) == "");
	}

	unittest
	{
		assert(captureStdout({ stdOut("line1\nline2"); }) == "line1\nline2");
	}

	unittest
	{
		assert(captureStdout({ stdOut(sixtyFourChars); }) == sixtyFourChars);
	}

	unittest
	{
		assert(captureStdout({ stdOut(overSixtyFour); }) == overSixtyFour);
	}

	unittest
	{
		assert(captureStdout({ stdOutln("alpha"); }) == "alpha\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutln(""); }) == "\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutln("beta\n"); }) == "beta\n\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutln(sixtyFourChars); }) == sixtyFourChars ~ "\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutln(overSixtyFour); }) == overSixtyFour ~ "\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutf("%s", "items"); }) == "items");
	}

	unittest
	{
		assert(captureStdout({ stdOutf("%d", -42); }) == "-42");
	}

	unittest
	{
		assert(captureStdout({ stdOutf("%.2f", 3.14159); }) == "3.14");
	}

	unittest
	{
		assert(captureStdout({ stdOutf("%5s", "hi"); }) == "   hi");
	}

	unittest
	{
		assert(captureStdout({ stdOutf("%s %d %x", "count", 255, 255); }) == "count 255 ff");
	}

	unittest
	{
		assert(captureStdout({ stdOutfln("%s", "done"); }) == "done\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutfln("%d", 123); }) == "123\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutfln("%.1f", 2.5); }) == "2.5\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutfln("%6s", "ok"); }) == "    ok\n");
	}

	unittest
	{
		assert(captureStdout({ stdOutfln("%s %d %X", "hex", 16, 255); }) == "hex 16 FF\n");
	}
}
