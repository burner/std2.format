module bformat.print;

import std.range.primitives;
import std.array : appender;
import bformat.formatfunction;
import bformat.formatfunction2;
import bformat.buffered_stdout;

void print(string fmt) {
	BufferedStdoutRange oRng;
	oRng.put(fmt);
	oRng.flush();
}

void println(string fmt) {
	BufferedStdoutRange oRng;
	oRng.put(fmt);
	oRng.put("\n");
	oRng.flush();
}

void printf(Args...)(string fmt, Args args) {
	BufferedStdoutRange oRng;
	formattedWrite(oRng, fmt, args);
	oRng.flush();
}

void printfln(Args...)(string fmt, Args args) {
	BufferedStdoutRange oRng;
	formattedWrite(oRng, fmt, args);
	oRng.put("\n");
	oRng.flush();
}

