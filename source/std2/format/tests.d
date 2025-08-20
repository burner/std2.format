module std2.format.tests;

import std2.format.formattest;

__EOF__

@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%p", null)).back == 'p');

    assertCTFEable!(
    {
        formatTest(null, "null");
    });
}

@safe pure unittest
{
    assertCTFEable!(
    {
        formatTest(false, "false");
        formatTest(true,  "true");
    });
}

@safe unittest
{
    struct S1
    {
        bool val;
        alias val this;
    }

    struct S2
    {
        bool val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(false), "false");
    formatTest(S1(true),  "true");
    formatTest(S2(false), "S");
    formatTest(S2(true),  "S");
}

@safe pure unittest
{
    assertCTFEable!(
    {
        formatTest(byte.min, "-128");
        formatTest(byte.max, "127");
        formatTest(short.min, "-32768");
        formatTest(short.max, "32767");
        formatTest(int.min, "-2147483648");
        formatTest(int.max, "2147483647");
        formatTest(long.min, "-9223372036854775808");
        formatTest(long.max, "9223372036854775807");

        formatTest(ubyte.min, "0");
        formatTest(ubyte.max, "255");
        formatTest(ushort.min, "0");
        formatTest(ushort.max, "65535");
        formatTest(uint.min, "0");
        formatTest(uint.max, "4294967295");
        formatTest(ulong.min, "0");
        formatTest(ulong.max, "18446744073709551615");
    });
}

@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%c", 5)).back == 'c');

    assertCTFEable!(
    {
        formatTest(9, "9");
        formatTest(10, "10");
    });
}

@safe unittest
{
    struct S1
    {
        long val;
        alias val this;
    }

    struct S2
    {
        long val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(10), "10");
    formatTest(S2(10), "S");
}

@safe pure unittest
{
    formatTest(byte.min, "-128");
    formatTest(short.min, "-32768");
    formatTest(int.min, "-2147483648");
    formatTest(long.min, "-9223372036854775808");
}


@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%d", 5.1)).back == 'd');

    static foreach (T; AliasSeq!(float, double, real))
    {
        formatTest(to!(          T)(5.5), "5.5");
        formatTest(to!(    const T)(5.5), "5.5");
        formatTest(to!(immutable T)(5.5), "5.5");

        formatTest(T.nan, "nan");
    }
}

@safe unittest
{
    formatTest(2.25, "2.25");

    struct S1
    {
        double val;
        alias val this;
    }
    struct S2
    {
        double val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(2.25), "2.25");
    formatTest(S2(2.25), "S");
}
