module std2.format.formattest2;

version(StdUnittest) {

import std.array : appender;
import std.exception : assertThrown, collectExceptionMsg;
import std.typecons : Nullable;
import std.range : back, repeat, iota, isOutputRange;
import std.math : log2;

import std2.format.formatfunction;
import std2.format.exception;
import std2.format.compilerhelpers;
import std2.format.spec;
import std2.format.internal.write;

@safe pure unittest
{
    string t1 = format("[%6s] [%6s] [%-6s]", true, false, true);
    assert(t1 == "[  true] [ false] [true  ]");

    string t2 = format("[%3s] [%-2s]", true, false);
    assert(t2 == "[true] [false]");
}

// https://issues.dlang.org/show_bug.cgi?id=20534
@safe pure unittest
{
    assert(format("%r",false) == "\0");
}

@safe pure unittest
{
    assert(format("%07s",true) == "   true");
}

@safe pure unittest
{
    assert(format("%=8s",true)    == "  true  ");
    assert(format("%=9s",false)   == "  false  ");
    assert(format("%=9s",true)    == "   true  ");
    assert(format("%-=9s",true)   == "  true   ");
    assert(format("%=10s",false)  == "   false  ");
    assert(format("%-=10s",false) == "  false   ");
}

@safe pure unittest
{
    string t = format("[%6s] [%-6s]", null, null);
    assert(t == "[  null] [null  ]");
}

// https://issues.dlang.org/show_bug.cgi?id=18838
@safe pure unittest
{
    assert("%12,d".format(0) == "           0");
}

// https://issues.dlang.org/show_bug.cgi?id=20064
@safe unittest
{
    assert(format( "%03,d",  1234) ==              "1,234");
    assert(format( "%04,d",  1234) ==              "1,234");
    assert(format( "%05,d",  1234) ==              "1,234");
    assert(format( "%06,d",  1234) ==             "01,234");
    assert(format( "%07,d",  1234) ==            "001,234");
    assert(format( "%08,d",  1234) ==          "0,001,234");
    assert(format( "%09,d",  1234) ==          "0,001,234");
    assert(format("%010,d",  1234) ==         "00,001,234");
    assert(format("%011,d",  1234) ==        "000,001,234");
    assert(format("%012,d",  1234) ==      "0,000,001,234");
    assert(format("%013,d",  1234) ==      "0,000,001,234");
    assert(format("%014,d",  1234) ==     "00,000,001,234");
    assert(format("%015,d",  1234) ==    "000,000,001,234");
    assert(format("%016,d",  1234) ==  "0,000,000,001,234");
    assert(format("%017,d",  1234) ==  "0,000,000,001,234");

    assert(format( "%03,d", -1234) ==             "-1,234");
    assert(format( "%04,d", -1234) ==             "-1,234");
    assert(format( "%05,d", -1234) ==             "-1,234");
    assert(format( "%06,d", -1234) ==             "-1,234");
    assert(format( "%07,d", -1234) ==            "-01,234");
    assert(format( "%08,d", -1234) ==           "-001,234");
    assert(format( "%09,d", -1234) ==         "-0,001,234");
    assert(format("%010,d", -1234) ==         "-0,001,234");
    assert(format("%011,d", -1234) ==        "-00,001,234");
    assert(format("%012,d", -1234) ==       "-000,001,234");
    assert(format("%013,d", -1234) ==     "-0,000,001,234");
    assert(format("%014,d", -1234) ==     "-0,000,001,234");
    assert(format("%015,d", -1234) ==    "-00,000,001,234");
    assert(format("%016,d", -1234) ==   "-000,000,001,234");
    assert(format("%017,d", -1234) == "-0,000,000,001,234");
}

@safe pure unittest
{
    string t1 = format("[%6s] [%-6s]", 123, 123);
    assert(t1 == "[   123] [123   ]");

    string t2 = format("[%6s] [%-6s]", -123, -123);
    assert(t2 == "[  -123] [-123  ]");
}

// https://issues.dlang.org/show_bug.cgi?id=21777
@safe pure unittest
{
    assert(format!"%20.5,d"(cast(short) 120) == "              00,120");
    assert(format!"%20.5,o"(cast(short) 120) == "              00,170");
    assert(format!"%20.5,x"(cast(short) 120) == "              00,078");
    assert(format!"%20.5,2d"(cast(short) 120) == "             0,01,20");
    assert(format!"%20.5,2o"(cast(short) 120) == "             0,01,70");
    assert(format!"%20.5,4d"(cast(short) 120) == "              0,0120");
    assert(format!"%20.5,4o"(cast(short) 120) == "              0,0170");
    assert(format!"%20.5,4x"(cast(short) 120) == "              0,0078");
    assert(format!"%20.5,2x"(3000) == "             0,0b,b8");
    assert(format!"%20.5,4d"(3000) == "              0,3000");
    assert(format!"%20.5,4o"(3000) == "              0,5670");
    assert(format!"%20.5,4x"(3000) == "              0,0bb8");
    assert(format!"%20.5,d"(-400) == "             -00,400");
    assert(format!"%20.30d"(-400) == "-000000000000000000000000000400");
    assert(format!"%20.5,4d"(0) == "              0,0000");
    assert(format!"%0#.8,2s"(12345) == "00,01,23,45");
    assert(format!"%0#.9,3x"(55) == "0x000,000,037");
}

// https://issues.dlang.org/show_bug.cgi?id=21814
@safe pure unittest
{
    assert(format("%,0d",1000) == "1000");
}

// https://issues.dlang.org/show_bug.cgi?id=21817
@safe pure unittest
{
    assert(format!"%u"(-5) == "4294967291");
}

// https://issues.dlang.org/show_bug.cgi?id=21820
@safe pure unittest
{
    assert(format!"%#.0o"(0) == "0");
}

@safe pure unittest
{
    assert(format!"%e"(10000) == "1.0000e+04");
    assert(format!"%.2e"(10000) == "1.00e+04");
    assert(format!"%.10e"(10000) == "1.0000000000e+04");

    assert(format!"%e"(9999) == "9.999e+03");
    assert(format!"%.2e"(9999) == "1.00e+04");
    assert(format!"%.10e"(9999) == "9.9990000000e+03");

    assert(format!"%f"(10000) == "10000");
    assert(format!"%.2f"(10000) == "10000.00");

    assert(format!"%g"(10000) == "10000");
    assert(format!"%.2g"(10000) == "1e+04");
    assert(format!"%.10g"(10000) == "10000");

    assert(format!"%#g"(10000) == "10000.");
    assert(format!"%#.2g"(10000) == "1.0e+04");
    assert(format!"%#.10g"(10000) == "10000.00000");

    assert(format!"%g"(9999) == "9999");
    assert(format!"%.2g"(9999) == "1e+04");
    assert(format!"%.10g"(9999) == "9999");

    assert(format!"%a"(0x10000) == "0x1.0000p+16");
    assert(format!"%.2a"(0x10000) == "0x1.00p+16");
    assert(format!"%.10a"(0x10000) == "0x1.0000000000p+16");

    assert(format!"%a"(0xffff) == "0xf.fffp+12");
    assert(format!"%.2a"(0xffff) == "0x1.00p+16");
    assert(format!"%.10a"(0xffff) == "0xf.fff0000000p+12");
}

@safe pure unittest
{
    assert(format!"%.3e"(ulong.max) == "1.845e+19");
    assert(format!"%.3f"(ulong.max) == "18446744073709551615.000");
    assert(format!"%.3g"(ulong.max) == "1.84e+19");
    assert(format!"%.3a"(ulong.max) == "0x1.000p+64");

    assert(format!"%.3e"(long.min) == "-9.223e+18");
    assert(format!"%.3f"(long.min) == "-9223372036854775808.000");
    assert(format!"%.3g"(long.min) == "-9.22e+18");
    assert(format!"%.3a"(long.min) == "-0x8.000p+60");

    assert(format!"%e"(0) == "0e+00");
    assert(format!"%f"(0) == "0");
    assert(format!"%g"(0) == "0");
    assert(format!"%a"(0) == "0x0p+00");
}

@safe pure unittest
{
    assert(format!"%.0g"(1500) == "2e+03");
}

// https://issues.dlang.org/show_bug.cgi?id=21900#
@safe pure unittest
{
    assert(format!"%.1a"(472) == "0x1.ep+08");
}

@safe unittest
{
    assert(format("%.1f", 1337.7) == "1337.7");
    assert(format("%,3.2f", 1331.982) == "1,331.98");
    assert(format("%,3.0f", 1303.1982) == "1,303");
    assert(format("%#,3.4f", 1303.1982) == "1,303.1982");
    assert(format("%#,3.0f", 1303.1982) == "1,303.");
}

// https://issues.dlang.org/show_bug.cgi?id=19939
@safe unittest
{
    assert(format("^%13,3.2f$",          1.00) == "^         1.00$");
    assert(format("^%13,3.2f$",         10.00) == "^        10.00$");
    assert(format("^%13,3.2f$",        100.00) == "^       100.00$");
    assert(format("^%13,3.2f$",      1_000.00) == "^     1,000.00$");
    assert(format("^%13,3.2f$",     10_000.00) == "^    10,000.00$");
    assert(format("^%13,3.2f$",    100_000.00) == "^   100,000.00$");
    assert(format("^%13,3.2f$",  1_000_000.00) == "^ 1,000,000.00$");
    assert(format("^%13,3.2f$", 10_000_000.00) == "^10,000,000.00$");
}

// https://issues.dlang.org/show_bug.cgi?id=20069
@safe unittest
{
    assert(format("%012,f",   -1234.0) ==    "-1,234.000000");
    assert(format("%013,f",   -1234.0) ==    "-1,234.000000");
    assert(format("%014,f",   -1234.0) ==   "-01,234.000000");
    assert(format("%011,f",    1234.0) ==     "1,234.000000");
    assert(format("%012,f",    1234.0) ==     "1,234.000000");
    assert(format("%013,f",    1234.0) ==    "01,234.000000");
    assert(format("%014,f",    1234.0) ==   "001,234.000000");
    assert(format("%015,f",    1234.0) == "0,001,234.000000");
    assert(format("%016,f",    1234.0) == "0,001,234.000000");

    assert(format( "%08,.2f", -1234.0) ==        "-1,234.00");
    assert(format( "%09,.2f", -1234.0) ==        "-1,234.00");
    assert(format("%010,.2f", -1234.0) ==       "-01,234.00");
    assert(format("%011,.2f", -1234.0) ==      "-001,234.00");
    assert(format("%012,.2f", -1234.0) ==    "-0,001,234.00");
    assert(format("%013,.2f", -1234.0) ==    "-0,001,234.00");
    assert(format("%014,.2f", -1234.0) ==   "-00,001,234.00");
    assert(format( "%08,.2f",  1234.0) ==         "1,234.00");
    assert(format( "%09,.2f",  1234.0) ==        "01,234.00");
    assert(format("%010,.2f",  1234.0) ==       "001,234.00");
    assert(format("%011,.2f",  1234.0) ==     "0,001,234.00");
    assert(format("%012,.2f",  1234.0) ==     "0,001,234.00");
    assert(format("%013,.2f",  1234.0) ==    "00,001,234.00");
    assert(format("%014,.2f",  1234.0) ==   "000,001,234.00");
    assert(format("%015,.2f",  1234.0) == "0,000,001,234.00");
    assert(format("%016,.2f",  1234.0) == "0,000,001,234.00");
}

@safe unittest
{
    // std.math's FloatingPointControl isn't available on all target platforms
    static if (is(FloatingPointControl))
    {
        assert(FloatingPointControl.rounding == FloatingPointControl.roundToNearest);
    }

    // https://issues.dlang.org/show_bug.cgi?id=20320
    real a = 0.16;
    real b = 0.016;
    assert(format("%.1f", a) == "0.2");
    assert(format("%.2f", b) == "0.02");

    double a1 = 0.16;
    double b1 = 0.016;
    assert(format("%.1f", a1) == "0.2");
    assert(format("%.2f", b1) == "0.02");

    // https://issues.dlang.org/show_bug.cgi?id=9889
    assert(format("%.1f", 0.09) == "0.1");
    assert(format("%.1f", -0.09) == "-0.1");
    assert(format("%.1f", 0.095) == "0.1");
    assert(format("%.1f", -0.095) == "-0.1");
    assert(format("%.1f", 0.094) == "0.1");
    assert(format("%.1f", -0.094) == "-0.1");
}

@safe unittest
{
    double a = 123.456;
    double b = -123.456;
    double c = 123.0;

    assert(format("%10.4f",a)  == "  123.4560");
    assert(format("%-10.4f",a) == "123.4560  ");
    assert(format("%+10.4f",a) == " +123.4560");
    assert(format("% 10.4f",a) == "  123.4560");
    assert(format("%010.4f",a) == "00123.4560");
    assert(format("%#10.4f",a) == "  123.4560");

    assert(format("%10.4f",b)  == " -123.4560");
    assert(format("%-10.4f",b) == "-123.4560 ");
    assert(format("%+10.4f",b) == " -123.4560");
    assert(format("% 10.4f",b) == " -123.4560");
    assert(format("%010.4f",b) == "-0123.4560");
    assert(format("%#10.4f",b) == " -123.4560");

    assert(format("%10.0f",c)  == "       123");
    assert(format("%-10.0f",c) == "123       ");
    assert(format("%+10.0f",c) == "      +123");
    assert(format("% 10.0f",c) == "       123");
    assert(format("%010.0f",c) == "0000000123");
    assert(format("%#10.0f",c) == "      123.");

    assert(format("%+010.4f",a) == "+0123.4560");
    assert(format("% 010.4f",a) == " 0123.4560");
    assert(format("% +010.4f",a) == "+0123.4560");
}

@safe unittest
{
    string t1 = format("[%6s] [%-6s]", 12.3, 12.3);
    assert(t1 == "[  12.3] [12.3  ]");

    string t2 = format("[%6s] [%-6s]", -12.3, -12.3);
    assert(t2 == "[ -12.3] [-12.3 ]");
}

// https://issues.dlang.org/show_bug.cgi?id=20396
/+
@safe unittest
{
	string a = format!"%a"(nextUp(0.0f));
	string a2 = format("%a", nextUp(0.0f));
	assert(a == a2, a ~ "\n" ~ a2);
    assert(a == "0x0.000002p-126", a);
	string b = format!"%a"(nextUp(0.0));
    assert(b == "0x0.0000000000001p-1022", b);
}
+/

// https://issues.dlang.org/show_bug.cgi?id=20371
@safe unittest
{
    assert(format!"%.1000a"(1.0).length == 1007);
    assert(format!"%.600f"(0.1).length == 602);
    assert(format!"%.600e"(0.1L).length == 606);
}

@safe unittest
{
    // std.math's FloatingPointControl isn't available on all target platforms
    static if (is(FloatingPointControl))
    {
        FloatingPointControl fpctrl;

        fpctrl.rounding = FloatingPointControl.roundUp;
        assert(format!"%.0e"(3.5) == "4e+00");
        assert(format!"%.0e"(4.5) == "5e+00");
        assert(format!"%.0e"(-3.5) == "-3e+00");
        assert(format!"%.0e"(-4.5) == "-4e+00");

        fpctrl.rounding = FloatingPointControl.roundDown;
        assert(format!"%.0e"(3.5) == "3e+00");
        assert(format!"%.0e"(4.5) == "4e+00");
        assert(format!"%.0e"(-3.5) == "-4e+00");
        assert(format!"%.0e"(-4.5) == "-5e+00");

        fpctrl.rounding = FloatingPointControl.roundToZero;
        assert(format!"%.0e"(3.5) == "3e+00");
        assert(format!"%.0e"(4.5) == "4e+00");
        assert(format!"%.0e"(-3.5) == "-3e+00");
        assert(format!"%.0e"(-4.5) == "-4e+00");

        fpctrl.rounding = FloatingPointControl.roundToNearest;
        assert(format!"%.0e"(3.5) == "4e+00");
        assert(format!"%.0e"(4.5) == "4e+00");
        assert(format!"%.0e"(-3.5) == "-4e+00");
        assert(format!"%.0e"(-4.5) == "-4e+00");
    }
}

@safe pure unittest
{
    static assert(format("%e",1.0) == "1.000000e+00");
    static assert(format("%e",-1.234e156) == "-1.234000e+156");
    static assert(format("%a",1.0) == "0x1p+0");
    static assert(format("%a",-1.234e156) == "-0x1.7024c96ca3ce4p+518");
    static assert(format("%f",1.0) == "1.000000");
    static assert(format("%f",-1.234e156) ==
                  "-123399999999999990477495546305353609103201879173427886566531" ~
                  "0740685826234179310516880117527217443004051984432279880308552" ~
                  "009640198043032289366552939010719744.000000");
    static assert(format("%g",1.0) == "1");
    static assert(format("%g",-1.234e156) == "-1.234e+156");

    static assert(format("%e",1.0f) == "1.000000e+00");
    static assert(format("%e",-1.234e23f) == "-1.234000e+23");
    static assert(format("%a",1.0f) == "0x1p+0");
    static assert(format("%a",-1.234e23f) == "-0x1.a2187p+76");
    static assert(format("%f",1.0f) == "1.000000");
    static assert(format("%f",-1.234e23f) == "-123399998884238311030784.000000");
    static assert(format("%g",1.0f) == "1");
    static assert(format("%g",-1.234e23f) == "-1.234e+23");
}

// https://issues.dlang.org/show_bug.cgi?id=21641
@safe unittest
{
    float a = -999999.8125;
    assert(format("%#.5g",a) == "-1.0000e+06");
    assert(format("%#.6g",a) == "-1.00000e+06");
}

// https://issues.dlang.org/show_bug.cgi?id=8424
@safe pure unittest
{
    static assert(format("%s", 0.6f) == "0.6");
    static assert(format("%s", 0.6) == "0.6");
    static assert(format("%s", 0.6L) == "0.6");
}

// https://issues.dlang.org/show_bug.cgi?id=9297
@safe pure unittest
{
    static if (real.mant_dig == 64) // 80 bit reals
    {
        assert(format("%.25f", 1.6180339887_4989484820_4586834365L) == "1.6180339887498948482072100");
    }
}

/+ TODO why is this
// https://issues.dlang.org/show_bug.cgi?id=21853
@safe pure unittest
{
    static if (real.mant_dig == 64) // 80 bit reals
    {
        // log2 is broken for x87-reals on some computers in CTFE
        // the following test excludes these computers from the test
        // (https://issues.dlang.org/show_bug.cgi?id=21757)
        enum test = cast(int) log2(3.05e2312L);
        static if (test == 7681)
            static assert(format!"%e"(real.max) == "1.189731e+4932");
    }
}
+/

// https://issues.dlang.org/show_bug.cgi?id=21842
@safe pure unittest
{
    assert(format!"%-+05,g"(1.0) == "+1   ");
}

// https://issues.dlang.org/show_bug.cgi?id=20536
@safe pure unittest
{
    real r = .00000095367431640625L;
    assert(format("%a", r) == "0x1p-20");
}

// https://issues.dlang.org/show_bug.cgi?id=21840
@safe pure unittest
{
    assert(format!"% 0,e"(0.0) == " 0.000000e+00");
}

// https://issues.dlang.org/show_bug.cgi?id=21841
@safe pure unittest
{
    assert(format!"%0.0,e"(0.0) == "0e+00");
}

// https://issues.dlang.org/show_bug.cgi?id=21836
@safe pure unittest
{
    assert(format!"%-5,1g"(0.0) == "0    ");
}

// https://issues.dlang.org/show_bug.cgi?id=21838
@safe pure unittest
{
    assert(format!"%#,a"(0.0) == "0x0.p+0");
}

@safe pure unittest
{
    string t1 = format("[%6s] [%-6s]", 'A', 'A');
    assert(t1 == "[     A] [A     ]");
    string t2 = format("[%6s] [%-6s]", '本', '本');
    assert(t2 == "[     本] [本     ]");
}


@safe pure unittest
{
    assert(collectExceptionMsg(format("%d", "hi")).back == 'd');
}

@safe pure unittest
{
    string t1 = format("[%6s] [%-6s]", "AB", "AB");
    assert(t1 == "[    AB] [AB    ]");
    string t2 = format("[%6s] [%-6s]", "本Ä", "本Ä");
    assert(t2 == "[    本Ä] [本Ä    ]");
}

// Test for https://issues.dlang.org/show_bug.cgi?id=8310
@safe unittest
{
    FormatSpec f;
    auto w = appender!string();

    char[2] two = ['a', 'b'];
    formatValue(w, two, f);

    char[2] getTwo() { return two; }
    formatValue(w, getTwo(), f);
}

// https://issues.dlang.org/show_bug.cgi?id=18205
@safe pure unittest
{
    assert("|%8s|".format("abc")       == "|     abc|");
    assert("|%8s|".format("αβγ")       == "|     αβγ|");
    assert("|%8s|".format("   ")       == "|        |");
    assert("|%8s|".format("été"d)      == "|     été|");
    assert("|%8s|".format("été 2018"w) == "|été 2018|");

    assert("%2s".format("e\u0301"w) == " e\u0301");
    assert("%2s".format("a\u0310\u0337"d) == " a\u0310\u0337");
}

// https://issues.dlang.org/show_bug.cgi?id=20848
@safe unittest
{
    class C
    {
        immutable(void)[] data;
    }

    Nullable!C c;
}


@safe pure unittest
{
    auto value = 1.repeat;

    // This should fail to compile — so we assert that it *doesn't* compile
    static assert(!__traits(compiles, format!"%s"(value)),
        "Test failed: formatting an infinite range should not compile.");
}

// https://issues.dlang.org/show_bug.cgi?id=21875
@safe unittest
{
    auto aa = [ 1 : "x", 2 : "y", 3 : "z" ];

    assertThrown!FormatException(format("%(%)", aa));
    assertThrown!FormatException(format("%(%s%)", aa));
    assertThrown!FormatException(format("%(%s%s%s%)", aa));
}

@safe unittest
{
    auto aa = [ 1 : "x", 2 : "y", 3 : "z" ];

    assertThrown!FormatException(format("%(%3$s%s%)", aa));
    assertThrown!FormatException(format("%(%s%3$s%)", aa));
    assertThrown!FormatException(format("%(%1$s%1$s%)", aa));
    assertThrown!FormatException(format("%(%2$s%2$s%)", aa));
    assertThrown!FormatException(format("%(%s%1$s%)", aa));
}

// https://issues.dlang.org/show_bug.cgi?id=21808
@safe unittest
{
    auto spelled = [ 1 : "one" ];
    assert(format("%-(%2$s (%1$s)%|, %)", spelled) == "one (1)");

    spelled[2] = "two";
    auto result = format("%-(%2$s (%1$s)%|, %)", spelled);
    assert(result == "one (1), two (2)" || result == "two (2), one (1)");
}

@safe unittest
{
    static struct A
    {
        void toString(Writer)(ref Writer w)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct B
    {
        void toString(scope void delegate(scope const(char)[]) sink, scope FormatSpec fmt) {}
    }
    static struct C
    {
        void toString(scope void delegate(scope const(char)[]) sink, string fmt) {}
    }
    static struct D
    {
        void toString(scope void delegate(scope const(char)[]) sink) {}
    }
    static struct E
    {
        string toString() {return "";}
    }
    static struct F
    {
        void toString(Writer)(ref Writer w, scope const ref FormatSpec fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct G
    {
        string toString() {return "";}
        void toString(Writer)(ref Writer w)
        if (isOutputRange!(Writer, string)) {}
    }
    static struct H
    {
        string toString() {return "";}
        void toString(Writer)(ref Writer w, scope const ref FormatSpec fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct I
    {
        void toString(Writer)(ref Writer w)
        if (isOutputRange!(Writer, string)) {}
        void toString(Writer)(ref Writer w, scope const ref FormatSpec fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct J
    {
        string toString() {return "";}
        void toString(Writer)(ref Writer w, scope ref FormatSpec fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct K
    {
        void toString(Writer)(Writer w, scope const ref FormatSpec fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct L
    {
        void toString(Writer)(ref Writer w, scope const FormatSpec fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct M
    {
        void toString(scope void delegate(in char[]) sink, in FormatSpec fmt) {}
    }
    static struct N
    {
        void toString(scope void delegate(in char[]) sink, string fmt) {}
    }
    static struct O
    {
        void toString(scope void delegate(in char[]) sink) {}
    }

    with(HasToStringResult)
    {
        static assert(hasToString!(A) == customPutWriter);
        static assert(hasToString!(B) == constCharSinkFormatSpec);
        static assert(hasToString!(C) == constCharSinkFormatString);
        static assert(hasToString!(D) == constCharSink);
        static assert(hasToString!(E) == hasSomeToString);
        static assert(hasToString!(F) == customPutWriterFormatSpec);
        static assert(hasToString!(G) == customPutWriter);
        static assert(hasToString!(H) == customPutWriterFormatSpec);
        static assert(hasToString!(I) == customPutWriterFormatSpec);
        static assert(hasToString!(J) == hasSomeToString
            || hasToString!(J) == constCharSinkFormatSpec); // depends on -preview=rvaluerefparam
        static assert(hasToString!(K) == constCharSinkFormatSpec);
        static assert(hasToString!(L) == customPutWriterFormatSpec);
        static if (hasPreviewIn)
        {
            static assert(hasToString!(M) == inCharSinkFormatSpec);
            static assert(hasToString!(N) == inCharSinkFormatString);
            static assert(hasToString!(O) == inCharSink);
        }
    }
}

// const toString methods
@safe unittest
{
    static struct A
    {
        void toString(Writer)(ref Writer w) const
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct B
    {
        void toString(scope void delegate(scope const(char)[]) sink, scope FormatSpec fmt) const {}
    }
    static struct C
    {
        void toString(scope void delegate(scope const(char)[]) sink, string fmt) const {}
    }
    static struct D
    {
        void toString(scope void delegate(scope const(char)[]) sink) const {}
    }
    static struct E
    {
        string toString() const {return "";}
    }
    static struct F
    {
        void toString(Writer)(ref Writer w, scope const ref FormatSpec fmt) const
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct G
    {
        string toString() const {return "";}
        void toString(Writer)(ref Writer w) const
        if (isOutputRange!(Writer, string)) {}
    }
    static struct H
    {
        string toString() const {return "";}
        void toString(Writer)(ref Writer w, scope const ref FormatSpec fmt) const
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct I
    {
        void toString(Writer)(ref Writer w) const
        if (isOutputRange!(Writer, string)) {}
        void toString(Writer)(ref Writer w, scope const ref FormatSpec fmt) const
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct J
    {
        string toString() const {return "";}
        void toString(Writer)(ref Writer w, scope ref FormatSpec fmt) const
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct K
    {
        void toString(Writer)(Writer w, scope const ref FormatSpec fmt) const
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct L
    {
        void toString(Writer)(ref Writer w, scope const FormatSpec fmt) const
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct M
    {
        void toString(scope void delegate(in char[]) sink, in FormatSpec fmt) const {}
    }
    static struct N
    {
        void toString(scope void delegate(in char[]) sink, string fmt) const {}
    }
    static struct O
    {
        void toString(scope void delegate(in char[]) sink) const {}
    }

    with(HasToStringResult)
    {
        static assert(hasToString!(A) == customPutWriter);
        static assert(hasToString!(B) == constCharSinkFormatSpec);
        static assert(hasToString!(C) == constCharSinkFormatString);
        static assert(hasToString!(D) == constCharSink);
        static assert(hasToString!(E) == hasSomeToString);
        static assert(hasToString!(F) == customPutWriterFormatSpec);
        static assert(hasToString!(G) == customPutWriter);
        static assert(hasToString!(H) == customPutWriterFormatSpec);
        static assert(hasToString!(I) == customPutWriterFormatSpec);
        static assert(hasToString!(J) == hasSomeToString
            || hasToString!(J) == constCharSinkFormatSpec); // depends on -preview=rvaluerefparam
        static assert(hasToString!(K) == constCharSinkFormatSpec);
        static assert(hasToString!(L) == HasToStringResult.customPutWriterFormatSpec);
        static if (hasPreviewIn)
        {
            static assert(hasToString!(M) == inCharSinkFormatSpec);
            static assert(hasToString!(N) == inCharSinkFormatString);
            static assert(hasToString!(O) == inCharSink);
        }

        // https://issues.dlang.org/show_bug.cgi?id=22873
        static assert(hasToString!(inout(A)) == customPutWriter);
        static assert(hasToString!(inout(B)) == constCharSinkFormatSpec);
        static assert(hasToString!(inout(C)) == constCharSinkFormatString);
        static assert(hasToString!(inout(D)) == constCharSink);
        static assert(hasToString!(inout(E)) == hasSomeToString);
        static assert(hasToString!(inout(F)) == customPutWriterFormatSpec);
        static assert(hasToString!(inout(G)) == customPutWriter);
        static assert(hasToString!(inout(H)) == customPutWriterFormatSpec);
        static assert(hasToString!(inout(I)) == customPutWriterFormatSpec);
        static assert(hasToString!(inout(J)) == hasSomeToString
            || hasToString!(inout(J)) == constCharSinkFormatSpec); // depends on -preview=rvaluerefparam
        static assert(hasToString!(inout(K)) == constCharSinkFormatSpec);
        static assert(hasToString!(inout(L)) == customPutWriterFormatSpec);
        static if (hasPreviewIn)
        {
            static assert(hasToString!(inout(M)) == inCharSinkFormatSpec);
            static assert(hasToString!(inout(N)) == inCharSinkFormatString);
            static assert(hasToString!(inout(O)) == inCharSink);
        }
    }
}

@system unittest
{
    static interface IF1 { }
    class CIF1 : IF1 { }
    static struct SF1 { }
    static union UF1 { }
    static class CF1 { }

    static interface IF2 { string toString(); }
    static class CIF2 : IF2 { override string toString() { return ""; } }
    static struct SF2 { string toString() { return ""; } }
    static union UF2 { string toString() { return ""; } }
    static class CF2 { override string toString() { return ""; } }

    static interface IK1 { void toString(scope void delegate(scope const(char)[]) sink,
                           FormatSpec) const; }
    static class CIK1 : IK1 { override void toString(scope void delegate(scope const(char)[]) sink,
                              FormatSpec) const { sink("CIK1"); } }
    static struct KS1 { void toString(scope void delegate(scope const(char)[]) sink,
                        FormatSpec) const { sink("KS1"); } }

    static union KU1 { void toString(scope void delegate(scope const(char)[]) sink,
                       FormatSpec) const { sink("KU1"); } }

    static class KC1 { void toString(scope void delegate(scope const(char)[]) sink,
                       FormatSpec) const { sink("KC1"); } }

    IF1 cif1 = new CIF1;
    assertThrown!FormatException(format("%f", cif1));
    assertThrown!FormatException(format("%f", SF1()));
    assertThrown!FormatException(format("%f", UF1()));
    assertThrown!FormatException(format("%f", new CF1()));

    IF2 cif2 = new CIF2;
    assertThrown!FormatException(format("%f", cif2));
    assertThrown!FormatException(format("%f", SF2()));
    assertThrown!FormatException(format("%f", UF2()));
    assertThrown!FormatException(format("%f", new CF2()));

    IK1 cik1 = new CIK1;
    assert(format("%f", cik1) == "CIK1");
    assert(format("%f", KS1()) == "KS1");
    assert(format("%f", KU1()) == "KU1");
    assert(format("%f", new KC1()) == "KC1");
}

// outside the unittest block, otherwise the FQN of the
// class contains the line number of the unittest
version (StdUnittest)
{
    private class C {}
}

// https://issues.dlang.org/show_bug.cgi?id=7879
@safe unittest
{
    const(C) c;
    auto s = format("%s", c);
    assert(s == "null");

    immutable(C) c2 = new C();
    s = format("%s", c2);
    assert(s == "immutable(std2.format.formattest2.C)", s);

    const(C) c3 = new C();
    s = format("%s", c3);
    assert(s == "const(std2.format.formattest2.C)", s);

    shared(C) c4 = new C();
    s = format("%s", c4);
    assert(s == "shared(std2.format.formattest2.C)", s);
}

// https://issues.dlang.org/show_bug.cgi?id=7879
@safe unittest
{
    class F
    {
        override string toString() const @safe
        {
            return "Foo";
        }
    }

    const(F) c;
    auto s = format("%s", c);
    assert(s == "null");

    const(F) c2 = new F();
    s = format("%s", c2);
    assert(s == "Foo", s);
}

	/+ TODO
// https://issues.dlang.org/show_bug.cgi?id=9117
@safe unittest
{
    static struct Frop {}

    static struct Foo
    {
        int n = 0;
        alias n this;
        T opCast(T) ()
        if (is(T == Frop))
        {
            return Frop();
        }
        string toString()
        {
            return "Foo";
        }
    }

    static struct Bar
    {
        Foo foo;
        alias foo this;
        string toString()
        {
            return "Bar";
        }
    }

    const(char)[] result;
    void put(scope const char[] s) { result ~= s; }

    Foo foo;
    formattedWrite(&put, "%s", foo);    // OK
    assert(result == "Foo", result);

    result = null;

    Bar bar;
    formattedWrite(&put, "%s", bar);    // NG
    assert(result == "Bar", result);

    result = null;

    int i = 9;
    formattedWrite(&put, "%s", 9);
    assert(result == "9", result);
}
	+/

@safe unittest
{
    // https://issues.dlang.org/show_bug.cgi?id=7230
    static struct Bug7230
    {
        string s = "hello";
        union {
            string a;
            int b;
            double c;
        }
        long x = 10;
    }

    Bug7230 bug;
    bug.b = 123;

    FormatSpec f;
    auto w = appender!(char[])();
    formatValue(w, bug, f);
    assert(w.data == `Bug7230("hello", #{overlap a, b, c}, 10)`);
}

@safe unittest
{
    static struct S{ @disable this(this); }
    S s;

    FormatSpec f;
    auto w = appender!string();
    formatValue(w, s, f);
    assert(w.data == "S()");
}

@safe unittest
{
    //struct Foo { @disable string toString(); }
    //Foo foo;

    interface Bar { @disable string toString(); }
    Bar bar;

    auto w = appender!(char[])();
    FormatSpec f;

    // NOTE: structs cant be tested : the assertion is correct so compilation
    // continues and fails when trying to link the unimplemented toString.
    //static assert(!__traits(compiles, formatValue(w, foo, f)));
    static assert(!__traits(compiles, formatValue(w, bar, f)));
}


// https://issues.dlang.org/show_bug.cgi?id=21722
@safe unittest
{
    struct Bar
    {
        void toString (scope void delegate (scope const(char)[]) sink, string fmt)
        {
            sink("Hello");
        }
    }

    Bar b;
    auto result = () @trusted { return format("%b", b); } ();
    assert(result == "Hello");

    static if (hasPreviewIn)
    {
        struct Foo
        {
            void toString(scope void delegate(in char[]) sink, in FormatSpec fmt)
            {
                sink("Hello");
            }
        }

        Foo f;
        assert(format("%b", f) == "Hello");

        struct Foo2
        {
            void toString(scope void delegate(in char[]) sink, string fmt)
            {
                sink("Hello");
            }
        }

        Foo2 f2;
        assert(format("%b", f2) == "Hello");
    }
}

	/+
@safe unittest
{
    // Bug #17269. Behavior similar to `struct A { Nullable!string B; }`
    struct StringAliasThis
    {
        @property string value() const { assert(0); }
        alias value this;
        string toString() { return "helloworld"; }
        private string _value;
    }
    struct TestContainer
    {
        StringAliasThis testVar;
    }

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatElement(w, TestContainer(), spec);

    assert(w.data == "TestContainer(helloworld)", w.data);
}
+/

// https://issues.dlang.org/show_bug.cgi?id=19003
@safe unittest
{
    struct S
    {
        int i;

        @disable this();

        invariant { assert(this.i); }

        this(int i) @safe in { assert(i); } do { this.i = i; }

        string toString() { return "S"; }
    }

    S s = S(1);

    format!"%s"(s);
}

@safe pure unittest
{
    enum A { one, two, three }

    string t1 = format("[%6s] [%-6s]", A.one, A.one);
    assert(t1 == "[   one] [one   ]");
    string t2 = format("[%10s] [%-10s]", cast(A) 10, cast(A) 10);
    assert(t2 == "[ cast(A)" ~ "10] [cast(A)" ~ "10 ]"); // due to bug in style checker
}

@safe pure unittest
{
    int* p;

    string t1 = format("[%6s] [%-6s]", p, p);
    assert(t1 == "[  null] [null  ]");
}

// https://issues.dlang.org/show_bug.cgi?id=11782
@safe pure unittest
{
    auto a = iota(0, 10);
    auto b = iota(0, 10);
    auto p = () @trusted { auto result = &a; return result; }();

    assert(format("%s",p) != format("%s",b));
}

// https://issues.dlang.org/show_bug.cgi?id=9336
@system pure unittest
{
    shared int i;
    format("%s", &i);
}

// https://issues.dlang.org/show_bug.cgi?id=11778
@safe pure unittest
{
    int* p = null;
    assertThrown!FormatException(format("%d", p));
    assertThrown!FormatException(format("%04d", () @trusted { return p + 2; } ()));
}

@safe unittest
{
    void func() @system { __gshared int x; ++x; throw new Exception("msg"); }
    version (linux)
    {
        FormatSpec f;
        auto w = appender!string();
        formatValue(w, &func, f);
        assert(w.data.length >= 15 && w.data[0 .. 15] == "void delegate()");
    }
}

@safe pure unittest
{
    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatElement(w, "Hello World", spec);

    assert(w.data == "\"Hello World\"");
}

@safe unittest
{
    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatElement(w, "H", spec);

    assert(w.data == "\"H\"", w.data);
}

// https://issues.dlang.org/show_bug.cgi?id=15888
@safe pure unittest
{
    ushort[] a = [0xFF_FE, 0x42];
    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatElement(w, cast(wchar[]) a, spec);
    assert(w.data == `[cast(wchar) 0xFFFE, cast(wchar) 0x42]`);

    uint[] b = [0x0F_FF_FF_FF, 0x42];
    w = appender!string();
    spec = singleSpec("%s");
    formatElement(w, cast(dchar[]) b, spec);
    assert(w.data == `[cast(dchar) 0xFFFFFFF, cast(dchar) 0x42]`);
}

@safe unittest
{
    assert(format("%,d", 1000) == "1,000");
    assert(format("%,f", 1234567.891011) == "1,234,567.891011");
    assert(format("%,?d", '?', 1000) == "1?000");
    assert(format("%,1d", 1000) == "1,0,0,0", format("%,1d", 1000));
    assert(format("%,*d", 4, -12345) == "-1,2345");
    assert(format("%,*?d", 4, '_', -12345) == "-1_2345");
    assert(format("%,6?d", '_', -12345678) == "-12_345678");
    assert(format("%12,3.3f", 1234.5678) == "   1,234.568", "'" ~
           format("%12,3.3f", 1234.5678) ~ "'");
}

@safe unittest
{
    char[10] c;
    size_t left = 5;
    size_t right = 8;

    c[4 .. 8] = "x.99";
    assert(round(c, left, right, RoundingClass.UPPER, false) == true);
    assert(c[4 .. 8] == "1.00");

    c[4 .. 8] = "x.99";
    assert(round(c, left, right, RoundingClass.FIVE, false) == true);
    assert(c[4 .. 8] == "1.00");

    c[4 .. 8] = "x.99";
    assert(round(c, left, right, RoundingClass.LOWER, false) == false);
    assert(c[4 .. 8] == "x.99");

    c[4 .. 8] = "x.99";
    assert(round(c, left, right, RoundingClass.ZERO, false) == false);
    assert(c[4 .. 8] == "x.99");

    static if (is(FloatingPointControl))
    {
        FloatingPointControl fpctrl;

        fpctrl.rounding = FloatingPointControl.roundUp;

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.UPPER, false) == true);
        assert(c[4 .. 8] == "1.00");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.FIVE, false) == true);
        assert(c[4 .. 8] == "1.00");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.LOWER, false) == true);
        assert(c[4 .. 8] == "1.00");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.ZERO, false) == false);
        assert(c[4 .. 8] == "x.99");

        fpctrl.rounding = FloatingPointControl.roundDown;

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.UPPER, false) == false);
        assert(c[4 .. 8] == "x.99");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.FIVE, false) == false);
        assert(c[4 .. 8] == "x.99");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.LOWER, false) == false);
        assert(c[4 .. 8] == "x.99");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.ZERO, false) == false);
        assert(c[4 .. 8] == "x.99");

        fpctrl.rounding = FloatingPointControl.roundToZero;

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.UPPER, false) == false);
        assert(c[4 .. 8] == "x.99");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.FIVE, false) == false);
        assert(c[4 .. 8] == "x.99");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.LOWER, false) == false);
        assert(c[4 .. 8] == "x.99");

        c[4 .. 8] = "x.99";
        assert(round(c, left, right, RoundingClass.ZERO, false) == false);
        assert(c[4 .. 8] == "x.99");
    }
}

@safe unittest
{
    char[10] c;
    size_t left = 5;
    size_t right = 8;

    c[4 .. 8] = "x8.5";
    assert(round(c, left, right, RoundingClass.UPPER, true) == false);
    assert(c[4 .. 8] == "x8.6");

    c[4 .. 8] = "x8.5";
    assert(round(c, left, right, RoundingClass.FIVE, true) == false);
    assert(c[4 .. 8] == "x8.6");

    c[4 .. 8] = "x8.4";
    assert(round(c, left, right, RoundingClass.FIVE, true) == false);
    assert(c[4 .. 8] == "x8.4");

    c[4 .. 8] = "x8.5";
    assert(round(c, left, right, RoundingClass.LOWER, true) == false);
    assert(c[4 .. 8] == "x8.5");

    c[4 .. 8] = "x8.5";
    assert(round(c, left, right, RoundingClass.ZERO, true) == false);
    assert(c[4 .. 8] == "x8.5");

    static if (is(FloatingPointControl))
    {
        FloatingPointControl fpctrl;

        fpctrl.rounding = FloatingPointControl.roundUp;

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.UPPER, true) == false);
        assert(c[4 .. 8] == "x8.5");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.FIVE, true) == false);
        assert(c[4 .. 8] == "x8.5");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.LOWER, true) == false);
        assert(c[4 .. 8] == "x8.5");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.ZERO, true) == false);
        assert(c[4 .. 8] == "x8.5");

        fpctrl.rounding = FloatingPointControl.roundDown;

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.UPPER, true) == false);
        assert(c[4 .. 8] == "x8.6");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.FIVE, true) == false);
        assert(c[4 .. 8] == "x8.6");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.LOWER, true) == false);
        assert(c[4 .. 8] == "x8.6");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.ZERO, true) == false);
        assert(c[4 .. 8] == "x8.5");

        fpctrl.rounding = FloatingPointControl.roundToZero;

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.UPPER, true) == false);
        assert(c[4 .. 8] == "x8.5");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.FIVE, true) == false);
        assert(c[4 .. 8] == "x8.5");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.LOWER, true) == false);
        assert(c[4 .. 8] == "x8.5");

        c[4 .. 8] = "x8.5";
        assert(round(c, left, right, RoundingClass.ZERO, true) == false);
        assert(c[4 .. 8] == "x8.5");
    }
}

@safe unittest
{
    char[10] c;
    size_t left = 5;
    size_t right = 8;

    c[4 .. 8] = "x8.9";
    assert(round(c, left, right, RoundingClass.UPPER, true, 'f') == false);
    assert(c[4 .. 8] == "x8.a");

    c[4 .. 8] = "x8.9";
    assert(round(c, left, right, RoundingClass.UPPER, true, 'F') == false);
    assert(c[4 .. 8] == "x8.A");

    c[4 .. 8] = "x8.f";
    assert(round(c, left, right, RoundingClass.UPPER, true, 'f') == false);
    assert(c[4 .. 8] == "x9.0");
}

// https://issues.dlang.org/show_bug.cgi?id=17381
@safe pure unittest
{
    static assert(!__traits(compiles, format!"%s"(1.5, 2)));
    static assert(!__traits(compiles, format!"%f"(1.5, 2)));
    static assert(!__traits(compiles, format!"%s"(1.5L, 2)));
    static assert(!__traits(compiles, format!"%f"(1.5L, 2)));
}

/// The format string can be checked at compile-time:
@safe pure unittest
{
    auto s = format!"%s is %s"("Pi", 3.14);
    assert(s == "Pi is 3.14");

    // This line doesn't compile, because 3.14 cannot be formatted with %d:
    // s = format!"%s is %d"("Pi", 3.14);
}

@safe pure unittest
{
    string s;
    static assert(!__traits(compiles, {s = format!"%l"();}));     // missing arg
    static assert(!__traits(compiles, {s = format!""(404);}));    // surplus arg
    static assert(!__traits(compiles, {s = format!"%d"(4.03);})); // incompatible arg
}

// https://issues.dlang.org/show_bug.cgi?id=20288
@safe unittest
{
    string s = format("%,.2f", double.nan);
    assert(s == "nan", s);

    s = format("%,.2F", double.nan);
    assert(s == "NAN", s);

    s = format("%,.2f", -double.nan);
    assert(s == "-nan", s);

    s = format("%,.2F", -double.nan);
    assert(s == "-NAN", s);

    string g = format("^%13s$", "nan");
    string h = "^          nan$";
    assert(g == h, "\ngot:" ~ g ~ "\nexp:" ~ h);
    string a = format("^%13,3.2f$", double.nan);
    string b = format("^%13,3.2F$", double.nan);
    string c = format("^%13,3.2f$", -double.nan);
    string d = format("^%13,3.2F$", -double.nan);
    assert(a == "^          nan$", "\ngot:'"~ a ~ "'\nexp:'^          nan$'");
    assert(b == "^          NAN$", "\ngot:'"~ b ~ "'\nexp:'^          NAN$'");
    assert(c == "^         -nan$", "\ngot:'"~ c ~ "'\nexp:'^         -nan$'");
    assert(d == "^         -NAN$", "\ngot:'"~ d ~ "'\nexp:'^         -NAN$'");

    a = format("^%-13,3.2f$", double.nan);
    b = format("^%-13,3.2F$", double.nan);
    c = format("^%-13,3.2f$", -double.nan);
    d = format("^%-13,3.2F$", -double.nan);
    assert(a == "^nan          $", "\ngot:'"~ a ~ "'\nexp:'^nan          $'");
    assert(b == "^NAN          $", "\ngot:'"~ b ~ "'\nexp:'^NAN          $'");
    assert(c == "^-nan         $", "\ngot:'"~ c ~ "'\nexp:'^-nan         $'");
    assert(d == "^-NAN         $", "\ngot:'"~ d ~ "'\nexp:'^-NAN         $'");

    a = format("^%+13,3.2f$", double.nan);
    b = format("^%+13,3.2F$", double.nan);
    c = format("^%+13,3.2f$", -double.nan);
    d = format("^%+13,3.2F$", -double.nan);
    assert(a == "^         +nan$", "\ngot:'"~ a ~ "'\nexp:'^         +nan$'");
    assert(b == "^         +NAN$", "\ngot:'"~ b ~ "'\nexp:'^         +NAN$'");
    assert(c == "^         -nan$", "\ngot:'"~ c ~ "'\nexp:'^         -nan$'");
    assert(d == "^         -NAN$", "\ngot:'"~ d ~ "'\nexp:'^         -NAN$'");

    a = format("^%-+13,3.2f$", double.nan);
    b = format("^%-+13,3.2F$", double.nan);
    c = format("^%-+13,3.2f$", -double.nan);
    d = format("^%-+13,3.2F$", -double.nan);
    assert(a == "^+nan         $", "\ngot:'"~ a ~ "'\nexp:'^+nan         $'");
    assert(b == "^+NAN         $", "\ngot:'"~ b ~ "'\nexp:'^+NAN         $'");
    assert(c == "^-nan         $", "\ngot:'"~ c ~ "'\nexp:'^-nan         $'");
    assert(d == "^-NAN         $", "\ngot:'"~ d ~ "'\nexp:'^-NAN         $'");

    a = format("^%- 13,3.2f$", double.nan);
    b = format("^%- 13,3.2F$", double.nan);
    c = format("^%- 13,3.2f$", -double.nan);
    d = format("^%- 13,3.2F$", -double.nan);
    assert(a == "^ nan         $", "\ngot:'"~ a ~ "'\nexp:'^ nan         $'");
    assert(b == "^ NAN         $", "\ngot:'"~ b ~ "'\nexp:'^ NAN         $'");
    assert(c == "^-nan         $", "\ngot:'"~ c ~ "'\nexp:'^-nan         $'");
    assert(d == "^-NAN         $", "\ngot:'"~ d ~ "'\nexp:'^-NAN         $'");
}

///
@safe pure unittest
{
    assert(format("Here are %d %s.", 3, "apples") == "Here are 3 apples.");

    assert("Increase: %7.2f %%".format(17.4285) == "Increase:   17.43 %");
}

@safe pure unittest
{
    import std.exception : assertThrown;

    //assertCTFEable!(
    {
        assert(format("foo") == "foo");
        assert(format("foo%%") == "foo%");
        assert(format("foo%s", 'C') == "fooC");
        assert(format("%s foo", "bar") == "bar foo");
        assert(format("%s foo %s", "bar", "abc") == "bar foo abc");
        assert(format("foo %d", -123) == "foo -123");
        assert(format("foo %d", 123) == "foo 123");

        assertThrown!FormatException(format("foo %s"));
        assertThrown!FormatException(format("foo %s", 123, 456));

        assert(format("hel%slo%s%s%s", "world", -138, 'c', true) == "helworldlo-138ctrue");
    }
	//);

    assert(is(typeof(format("happy")) == string));
}

// https://issues.dlang.org/show_bug.cgi?id=16661
@safe pure unittest
{
    assert(format("%.2f", 0.4) == "0.40");
    assert("%02d".format(1) == "01");
}

@safe unittest
{
    int i;
    string s;

    s = format("hello world! %s %s %s%s%s", true, 57, 1_000_000_000, 'x', " foo");
    assert(s == "hello world! true 57 1000000000x foo");

    s = format("%s %A %s", 1.67, -1.28, float.nan);
    assert(s == "1.67 -0X1.47AE147AE147BP+0 nan", s);

    s = format("%x %X", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1234af AFAFAFAF");

    s = format("%b %o", 0x1234AF, 0xAFAFAFAF);
    assert(s == "100100011010010101111 25753727657");

    s = format("%d %s", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1193135 2947526575");
}

@safe unittest
{
    import std.conv : octal;

    string s;
    int i;

    s = format("%#06.*f", 2, 12.345);
    assert(s == "012.35");

    s = format("%#0*.*f", 6, 2, 12.345);
    assert(s == "012.35");

    s = format("%7.4g:", 12.678);
    assert(s == "  12.68:");

    s = format("%7.4g:", 12.678L);
    assert(s == "  12.68:");

	// TODO
    // s = format("%04f|%05d|%#05x|%#5x", -4.0, -10, 1, 1);
	// string exp = "-4.000000|-0010|0x001|  0x1";
    // assert(s == exp, "\n" ~ s ~ "\n" ~ exp);

    i = -10;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "-10|-10|-10|-10|-10.0000");

    i = -5;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "-5| -5|-05|-5|-5.0000");

    i = 0;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "0|  0|000|0|0.0000");

    i = 5;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "5|  5|005|5|5.0000");

    i = 10;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "10| 10|010|10|10.0000");

    s = format("%.0d", 0);
    assert(s == "0");

    s = format("%.g", .34);
    assert(s == "0.3");

    s = format("%.0g", .34);
    assert(s == "0.3");

    s = format("%.2g", .34);
    assert(s == "0.34");

    s = format("%0.0008f", 1e-08);
    assert(s == "0.00000001");

    s = format("%0.0008f", 1e-05);
    assert(s == "0.00001000");

    s = "helloworld";
    string r;
    r = format("%.2s", s[0 .. 5]);
    assert(r == "he");
    r = format("%.20s", s[0 .. 5]);
    assert(r == "hello");
    r = format("%8s", s[0 .. 5]);
    assert(r == "   hello");

    byte[] arrbyte = new byte[4];
    arrbyte[0] = 100;
    arrbyte[1] = -99;
    arrbyte[3] = 0;
    r = format("%s", arrbyte);
    assert(r == "[100, -99, 0, 0]");

    ubyte[] arrubyte = new ubyte[4];
    arrubyte[0] = 100;
    arrubyte[1] = 200;
    arrubyte[3] = 0;
    r = format("%s", arrubyte);
    assert(r == "[100, 200, 0, 0]");

    short[] arrshort = new short[4];
    arrshort[0] = 100;
    arrshort[1] = -999;
    arrshort[3] = 0;
    r = format("%s", arrshort);
    assert(r == "[100, -999, 0, 0]");

    ushort[] arrushort = new ushort[4];
    arrushort[0] = 100;
    arrushort[1] = 20_000;
    arrushort[3] = 0;
    r = format("%s", arrushort);
    assert(r == "[100, 20000, 0, 0]");

    int[] arrint = new int[4];
    arrint[0] = 100;
    arrint[1] = -999;
    arrint[3] = 0;
    r = format("%s", arrint);
    assert(r == "[100, -999, 0, 0]");

    long[] arrlong = new long[4];
    arrlong[0] = 100;
    arrlong[1] = -999;
    arrlong[3] = 0;
    r = format("%s", arrlong);
    assert(r == "[100, -999, 0, 0]");

    ulong[] arrulong = new ulong[4];
    arrulong[0] = 100;
    arrulong[1] = 999;
    arrulong[3] = 0;
    r = format("%s", arrulong);
    assert(r == "[100, 999, 0, 0]");

    string[] arr2 = new string[4];
    arr2[0] = "hello";
    arr2[1] = "world";
    arr2[3] = "foo";
    r = format("%s", arr2);
    assert(r == `["hello", "world", "", "foo"]`);

    r = format("%.8d", 7);
    assert(r == "00000007");
    r = format("%.8x", 10);
    assert(r == "0000000a");

    r = format("%-3d", 7);
    assert(r == "7  ");

    r = format("%-1*d", 4, 3);
    assert(r == "3   ");

    r = format("%*d", -3, 7);
    assert(r == "7  ");

    r = format("%.*d", -3, 7);
    assert(r == "7");

    r = format("%-1.*f", 2, 3.1415);
    assert(r == "3.14");

    r = format("abc"c);
    assert(r == "abc");

    // Empty static character arrays work as well
    const char[0] cempty;
    assert(format("test%spath", cempty) == "testpath");
    const wchar[0] wempty;
    assert(format("test%spath", wempty) == "testpath");
    const dchar[0] dempty;
    assert(format("test%spath", dempty) == "testpath");

    void* p = () @trusted { return cast(void*) 0xDEADBEEF; } ();
    r = format("%s", p);
    assert(r == "DEADBEEF");

    r = format("%#x", 0xabcd);
    assert(r == "0xabcd");
    r = format("%#X", 0xABCD);
    assert(r == "0XABCD");

    r = format("%#o", octal!12345);
    assert(r == "012345");
    r = format("%o", 9);
    assert(r == "11");
    r = format("%#o", 0);   // https://issues.dlang.org/show_bug.cgi?id=15663
    assert(r == "0");

    r = format("%+d", 123);
    assert(r == "+123");
    r = format("%+d", -123);
    assert(r == "-123");
    r = format("% d", 123);
    assert(r == " 123");
    r = format("% d", -123);
    assert(r == "-123");

    r = format("%%");
    assert(r == "%");

    r = format("%d", true);
    assert(r == "1");
    r = format("%d", false);
    assert(r == "0");

    r = format("%d", 'a');
    assert(r == "97");
    wchar wc = 'a';
    r = format("%d", wc);
    assert(r == "97");
    dchar dc = 'a';
    r = format("%d", dc);
    assert(r == "97");

    byte b = byte.max;
    r = format("%x", b);
    assert(r == "7f");
    r = format("%x", ++b);
    assert(r == "80");
    r = format("%x", ++b);
    assert(r == "81");

    short sh = short.max;
    r = format("%x", sh);
    assert(r == "7fff");
    r = format("%x", ++sh);
    assert(r == "8000");
    r = format("%x", ++sh);
    assert(r == "8001");

    i = int.max;
    r = format("%x", i);
    assert(r == "7fffffff");
    r = format("%x", ++i);
    assert(r == "80000000");
    r = format("%x", ++i);
    assert(r == "80000001");

    r = format("%x", 10);
    assert(r == "a");
    r = format("%X", 10);
    assert(r == "A");
    r = format("%x", 15);
    assert(r == "f");
    r = format("%X", 15);
    assert(r == "F");

    Object c = null;
    r = () @trusted { return format("%s", c); } ();
    assert(r == "null");

    enum TestEnum
    {
        Value1, Value2
    }
    r = format("%s", TestEnum.Value2);
    assert(r == "Value2");

    immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    r = () @trusted { return format("%s", aa.values); } ();
    assert(r == `["hello", "betty"]` || r == `["betty", "hello"]`);
    r = format("%s", aa);
    assert(r == `[3:"hello", 4:"betty"]` || r == `[4:"betty", 3:"hello"]`);

    static const dchar[] ds = ['a','b'];
    for (int j = 0; j < ds.length; ++j)
    {
        r = format(" %d", ds[j]);
        if (j == 0)
            assert(r == " 97");
        else
            assert(r == " 98");
    }

    r = format(">%14d<, %s", 15, [1,2,3]);
    assert(r == ">            15<, [1, 2, 3]");

    assert(format("%8s", "bar") == "     bar");
    assert(format("%8s", "b\u00e9ll\u00f4") == "   b\u00e9ll\u00f4");
}

@safe unittest
{
    //import std.exception : assertCTFEable;

    //assertCTFEable!(
    {
        auto tmp = format("%,d", 1000);
        assert(tmp == "1,000", "'" ~ tmp ~ "'");

        tmp = format("%,?d", 'z', 1234567);
        assert(tmp == "1z234z567", "'" ~ tmp ~ "'");

        tmp = format("%10,?d", 'z', 1234567);
        assert(tmp == " 1z234z567", "'" ~ tmp ~ "'");

        tmp = format("%11,2?d", 'z', 1234567);
        assert(tmp == " 1z23z45z67", "'" ~ tmp ~ "'");

        tmp = format("%11,*?d", 2, 'z', 1234567);
        assert(tmp == " 1z23z45z67", "'" ~ tmp ~ "'");

        tmp = format("%11,*d", 2, 1234567);
        assert(tmp == " 1,23,45,67", "'" ~ tmp ~ "'");

        tmp = format("%11,2d", 1234567);
        assert(tmp == " 1,23,45,67", "'" ~ tmp ~ "'");
    }
	//);
}

@safe unittest
{
    auto tmp = format("%,f", 1000.0);
    assert(tmp == "1,000.000000", "'" ~ tmp ~ "'");

    tmp = format("%,f", 1234567.891011);
    assert(tmp == "1,234,567.891011", "'" ~ tmp ~ "'");

    tmp = format("%,f", -1234567.891011);
    assert(tmp == "-1,234,567.891011", "'" ~ tmp ~ "'");

    tmp = format("%,2f", 1234567.891011);
    assert(tmp == "1,23,45,67.891011", "'" ~ tmp ~ "'");

    tmp = format("%18,f", 1234567.891011);
    assert(tmp == "  1,234,567.891011", "'" ~ tmp ~ "'");

    tmp = format("%18,?f", '.', 1234567.891011);
    assert(tmp == "  1.234.567.891011", "'" ~ tmp ~ "'");

    tmp = format("%,?.3f", 'ä', 1234567.891011);
    assert(tmp == "1ä234ä567.891", "'" ~ tmp ~ "'");

    tmp = format("%,*?.3f", 1, 'ä', 1234567.891011);
    assert(tmp == "1ä2ä3ä4ä5ä6ä7.891", "'" ~ tmp ~ "'");

    tmp = format("%,4?.3f", '_', 1234567.891011);
    assert(tmp == "123_4567.891", "'" ~ tmp ~ "'");

    tmp = format("%12,3.3f", 1234.5678);
    assert(tmp == "   1,234.568", "'" ~ tmp ~ "'");

    tmp = format("%,e", 3.141592653589793238462);
    assert(tmp == "3.141593e+00", "'" ~ tmp ~ "'");

    tmp = format("%15,e", 3.141592653589793238462);
    assert(tmp == "   3.141593e+00", "'" ~ tmp ~ "'");

    tmp = format("%15,e", -3.141592653589793238462);
    assert(tmp == "  -3.141593e+00", "'" ~ tmp ~ "'");

    tmp = format("%.4,*e", 2, 3.141592653589793238462);
    assert(tmp == "3.1416e+00", "'" ~ tmp ~ "'");

    tmp = format("%13.4,*e", 2, 3.141592653589793238462);
    assert(tmp == "   3.1416e+00", "'" ~ tmp ~ "'");

    tmp = format("%,.0f", 3.14);
    assert(tmp == "3", "'" ~ tmp ~ "'");

    tmp = format("%3,g", 1_000_000.123456);
    assert(tmp == "1e+06", "'" ~ tmp ~ "'");

    tmp = format("%19,?f", '.', -1234567.891011);
    assert(tmp == "  -1.234.567.891011", "'" ~ tmp ~ "'");
}

// Test for multiple indexes
@safe unittest
{
    auto tmp = format("%2:5$s", 1, 2, 3, 4, 5);
    assert(tmp == "2345", tmp);
}

// https://issues.dlang.org/show_bug.cgi?id=18047
@safe unittest
{
    auto cmp = "     123,456";
    assert(cmp.length == 12, format("%d", cmp.length));
    auto tmp = format("%12,d", 123456);
    assert(tmp.length == 12, format("%d", tmp.length));

    assert(tmp == cmp, "'" ~ tmp ~ "'");
}

// https://issues.dlang.org/show_bug.cgi?id=17459
@safe unittest
{
    auto cmp = "100";
    auto tmp  = format("%0d", 100);
    assert(tmp == cmp, tmp);

    cmp = "0100";
    tmp  = format("%04d", 100);
    assert(tmp == cmp, tmp);

    cmp = "0,000,000,100";
    tmp  = format("%012,3d", 100);
    assert(tmp == cmp, tmp);

    cmp = "0,000,001,000";
    tmp = format("%012,3d", 1_000);
    assert(tmp == cmp, tmp);

    cmp = "0,000,100,000";
    tmp = format("%012,3d", 100_000);
    assert(tmp == cmp, tmp);

    cmp = "0,001,000,000";
    tmp = format("%012,3d", 1_000_000);
    assert(tmp == cmp, tmp);

    cmp = "0,100,000,000";
    tmp = format("%012,3d", 100_000_000);
    assert(tmp == cmp, tmp);
}

// https://issues.dlang.org/show_bug.cgi?id=17459
@safe unittest
{
    auto cmp = "100,000";
    auto tmp  = format("%06,d", 100_000);
    assert(tmp == cmp, tmp);

    cmp = "100,000";
    tmp  = format("%07,d", 100_000);
    assert(tmp == cmp, tmp);

    cmp = "0,100,000";
    tmp  = format("%08,d", 100_000);
    assert(tmp == cmp, tmp);
}

}
