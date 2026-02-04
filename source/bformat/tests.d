module bformat.tests;

version(StdUnittest) {

import std.array : appender;
import std.conv : to;
import std.exception : collectException, collectExceptionMsg;
import std.meta : AliasSeq;
import std.range : back, front, popFront;
import std.range.interfaces : InputRange, inputRangeObject;
import std.typecons : Nullable;

import bformat.exception : FormatException;
import bformat.formattest;
import bformat.write;
import bformat.formatfunction;
import bformat.spec;
import bformat.compilerhelpers;

@safe pure unittest
{
    //assertCTFEable!( TODO
    //{
        formatTest(false, "false");
        formatTest(true,  "true");
    //});
}

@safe pure unittest
{
    //assertCTFEable!(
    //{
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
    //};
}

@safe pure unittest
{
    formatTest(byte.min, "-128");
    formatTest(short.min, "-32768");
    formatTest(int.min, "-2147483648");
    formatTest(long.min, "-9223372036854775808");
}

@safe unittest
{
    //Little Endian
    formatTest("%-r", cast( char)'c', ['c'         ]);
    formatTest("%-r", cast(wchar)'c', ['c', 0      ]);
    formatTest("%-r", cast(dchar)'c', ['c', 0, 0, 0]);
    formatTest("%-r", '本', ['\x2c', '\x67'] );

    //Big Endian
    formatTest("%+r", cast( char)'c', [         'c']);
    formatTest("%+r", cast(wchar)'c', [0,       'c']);
    formatTest("%+r", cast(dchar)'c', [0, 0, 0, 'c']);
    formatTest("%+r", '本', ['\x67', '\x2c']);
}

@safe pure unittest
{
    //Little Endian
    formatTest("%-r", "ab"c, ['a'         , 'b'         ]);
    formatTest("%-r", "ab"w, ['a', 0      , 'b', 0      ]);
    formatTest("%-r", "ab"d, ['a', 0, 0, 0, 'b', 0, 0, 0]);
    formatTest("%-r", "日本語"c, ['\xe6', '\x97', '\xa5', '\xe6', '\x9c', '\xac',
                                  '\xe8', '\xaa', '\x9e']);
    formatTest("%-r", "日本語"w, ['\xe5', '\x65', '\x2c', '\x67', '\x9e', '\x8a']);
    formatTest("%-r", "日本語"d, ['\xe5', '\x65', '\x00', '\x00', '\x2c', '\x67',
                                  '\x00', '\x00', '\x9e', '\x8a', '\x00', '\x00']);

    //Big Endian
    formatTest("%+r", "ab"c, [         'a',          'b']);
    formatTest("%+r", "ab"w, [      0, 'a',       0, 'b']);
    formatTest("%+r", "ab"d, [0, 0, 0, 'a', 0, 0, 0, 'b']);
    formatTest("%+r", "日本語"c, ['\xe6', '\x97', '\xa5', '\xe6', '\x9c', '\xac',
                                  '\xe8', '\xaa', '\x9e']);
    formatTest("%+r", "日本語"w, ['\x65', '\xe5', '\x67', '\x2c', '\x8a', '\x9e']);
    formatTest("%+r", "日本語"d, ['\x00', '\x00', '\x65', '\xe5', '\x00', '\x00',
                                  '\x67', '\x2c', '\x00', '\x00', '\x8a', '\x9e']);
}

@safe unittest
{
    formatTest("abc", "abc");
}

@safe unittest
{
    // Test for bug 5371 for structs
    struct S1
    {
        const string var;
        alias var this;
    }

    struct S2
    {
        string var;
        alias var this;
    }

    formatTest(S1("s1"), "s1");
    formatTest(S2("s2"), "s2");
}

// https://issues.dlang.org/show_bug.cgi?id=6640
@safe unittest
{
    struct Range
    {
        @safe:

        string value;
        @property bool empty() const { return !value.length; }
        @property dchar front() const { return value.front; }
        void popFront() { value.popFront(); }

        @property size_t length() const { return value.length; }
    }
    immutable table =
    [
        ["[%s]", "[string]"],
        ["[%10s]", "[    string]"],
        ["[%-10s]", "[string    ]"],
        ["[%(%02x %)]", "[73 74 72 69 6e 67]"],
        ["[%(%c %)]", "[s t r i n g]"],
    ];
    foreach (e; table)
    {
        formatTest(e[0], "string", e[1]);
        formatTest(e[0], Range("string"), e[1]);
    }
}

// https://issues.dlang.org/show_bug.cgi?id=12505
@safe pure unittest
{
    void* p = null;
    formatTest("%08X", p, "00000000");
}

@safe unittest
{
    static if (is(float4))
    {
        version (X86)
        {
            version (OSX) {/* https://issues.dlang.org/show_bug.cgi?id=17823 */}
        }
        else
        {
            float4 f;
            f.array[0] = 1;
            f.array[1] = 2;
            f.array[2] = 3;
            f.array[3] = 4;
            formatTest(f, "[1, 2, 3, 4]");
        }
    }
}

@safe unittest
{
    enum A { first, second, third }
    formatTest(A.second, "second");
    formatTest(cast(A) 72, "cast(A)72");
}
@safe unittest
{
    enum A : string { one = "uno", two = "dos", three = "tres" }
    formatTest(A.three, "three");
    formatTest(cast(A)"mill\&oacute;n", "cast(A)mill\&oacute;n");
}
@safe unittest
{
    enum A : bool { no, yes }
    formatTest(A.yes, "yes");
    formatTest(A.no, "no");
}
@safe unittest
{
    // Test for bug 6892
    enum Foo { A = 10 }
    formatTest("%s",    Foo.A, "A");
    formatTest(">%4s<", Foo.A, ">   A<");
    formatTest("%04d",  Foo.A, "0010");
    formatTest("%+2u",  Foo.A, "10");
    formatTest("%02x",  Foo.A, "0a");
    formatTest("%3o",   Foo.A, " 12");
    formatTest("%b",    Foo.A, "1010");
}

// https://issues.dlang.org/show_bug.cgi?id=8921
@safe unittest
{
    enum E : char { A = 'a', B = 'b', C = 'c' }
    E[3] e = [E.A, E.B, E.C];
    formatTest(e, "[A, B, C]");

    E[] e2 = [E.A, E.B, E.C];
    formatTest(e2, "[A, B, C]");
}

@safe pure unittest
{
    int* p = null;
    formatTest(p, "null");

    auto q = () @trusted { return cast(void*) 0xFFEECCAA; }();
    formatTest(q, "FFEECCAA");
}

// https://issues.dlang.org/show_bug.cgi?id=9588
@safe pure unittest
{
    struct S { int x; bool empty() { return false; } }
    formatTest(S(), "S(0)");
}

// https://issues.dlang.org/show_bug.cgi?id=3890
@safe unittest
{
    struct Int{ int n; }
    struct Pair{ string s; Int i; }
    formatTest(Pair("hello", Int(5)),
               `Pair("hello", Int(5))`);
}

@safe unittest
{
    // string literal from valid UTF sequence is encoding free.
    static foreach (StrType; AliasSeq!(string, wstring, dstring))
    {
        // DISABLED: Unicode range tests causing garbage output due to cast(StrType) issues
        // Uncomment to enable: version=EnableLargeTests

        // Valid and printable (ASCII)
        formatTest([cast(StrType)"hello"],
// DISABLED: Unicode range tests causing garbage output due to cast(StrType) issues
// Uncomment to enable: version=EnableLargeTests

                   `["hello"]`);

        // 1 character escape sequences (' is not escaped in strings)
        formatTest([cast(StrType)"\"'\0\\\a\b\f\n\r\t\v"],
                   `["\"'\0\\\a\b\f\n\r\t\v"]`);

        // 1 character optional escape sequences
        formatTest([cast(StrType)"\'\?"],
                   `["'?"]`);

         // Valid and non-printable code point (<= U+FF)
         // DISABLED: Unicode range tests causing garbage output due to cast(StrType) issues
         // formatTest([cast(StrType)"\x10\x1F\x20test"],
         //           `["\x10\x1F test"]`);
         // Valid and non-printable code point (<= U+FF)
         // DISABLED: Unicode range tests causing garbage output
         // formatTest([cast(StrType)"\x10\x1F\x20test"],
         //           `["\x10\x1F test"]`);

         // Valid and non-printable code point (<= U+FFFF)
         // DISABLED: Unicode range tests causing garbage output due to cast(StrType) issues
         // formatTest([cast(StrType)"\u200B..\u200F"],
         //           `["\u200B..\u200F"]`);
         // Valid and non-printable code point (<= U+FFFF)
         // DISABLED: Unicode range tests causing garbage output
         // formatTest([cast(StrType)"\u200B..\u200F"],
         //           `["\u200B..\u200F"]`);

        // Valid and non-printable code point (<= U+10FFFF)
        formatTest([cast(StrType)"\U000E0020..\U000E007F"],
                   `["\U000E0020..\U000E007F"]`);
    }

    // invalid UTF sequence needs hex-string literal postfix (c/w/d)
    () @trusted
    {
        // U+FFFF with UTF-8 (Invalid code point for interchange)
        formatTest([cast(string)[0xEF, 0xBF, 0xBF]],
                   `[[cast(char) 0xEF, cast(char) 0xBF, cast(char) 0xBF]]`);

        // U+FFFF with UTF-16 (Invalid code point for interchange)
        formatTest([cast(wstring)[0xFFFF]],
                   `[[cast(wchar) 0xFFFF]]`);

        // U+FFFF with UTF-32 (Invalid code point for interchange)
        formatTest([cast(dstring)[0xFFFF]],
                   `[[cast(dchar) 0xFFFF]]`);
    } ();
}

@safe unittest
{
    // stop auto escaping inside range formatting
    auto arr = ["hello", "world"];
    formatTest("%(%s, %)",  arr, `"hello", "world"`);
    formatTest("%-(%s, %)", arr, `hello, world`);

    auto aa1 = [1:"hello", 2:"world"];
    formatTest("%(%s:%s, %)",  aa1, [`1:"hello", 2:"world"`, `2:"world", 1:"hello"`]);
    formatTest("%-(%s:%s, %)", aa1, [`1:hello, 2:world`, `2:world, 1:hello`]);

    auto aa2 = [1:["ab", "cd"], 2:["ef", "gh"]];
    formatTest("%-(%s:%s, %)",        aa2, [`1:["ab", "cd"], 2:["ef", "gh"]`, `2:["ef", "gh"], 1:["ab", "cd"]`]);
    formatTest("%-(%s:%(%s%), %)",    aa2, [`1:"ab""cd", 2:"ef""gh"`, `2:"ef""gh", 1:"ab""cd"`]);
    formatTest("%-(%s:%-(%s%)%|, %)", aa2, [`1:abcd, 2:efgh`, `2:efgh, 1:abcd`]);
}

@safe unittest
{
    // void[]
    void[] val0;
    formatTest(val0, "[]");

    void[] val = cast(void[]) cast(ubyte[])[1, 2, 3];
    formatTest(val, "[1, 2, 3]");

    void[0] sval0 = [];
    formatTest(sval0, "[]");

    void[3] sval = () @trusted { return cast(void[3]) cast(ubyte[3])[1, 2, 3]; } ();
    formatTest(sval, "[1, 2, 3]");
}

@safe unittest
{
    // const(T[]) -> const(T)[]
    const short[] a = [1, 2, 3];
    formatTest(a, "[1, 2, 3]");

    struct S
    {
        const(int[]) arr;
        alias arr this;
    }

    auto s = S([1,2,3]);
    formatTest(s, "[1, 2, 3]");
}

@safe unittest
{
    // nested range formatting with array of string
    formatTest("%({%(%02x %)}%| %)", ["test", "msg"],
               `{74 65 73 74} {6d 73 67}`);
}

@safe pure unittest
{
    int[] a = [ 1, 3, 2 ];
    formatTest("testing %(%s & %) embedded", a,
               "testing 1 & 3 & 2 embedded");
    formatTest("testing %((%s) %)) wyda3", a,
               "testing (1) (3) (2) wyda3");

    int[0] empt = [];
    formatTest("(%s)", empt, "([])");
}

@system unittest
{
    // class range (https://issues.dlang.org/show_bug.cgi?id=5154)
    auto c = inputRangeObject([1,2,3,4]);
    formatTest(c, "[1, 2, 3, 4]");
    assert(c.empty);
    c = null;
    formatTest(c, "null");
}

// https://issues.dlang.org/show_bug.cgi?id=17269
@safe unittest
{
    struct Foo
    {
        Nullable!string bar;
    }

    Foo f;
    formatTest(f, "Foo(Nullable.null)");
}

@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%p", null)).back == 'p');

    //assertCTFEable!(
    //{
        formatTest(null, "null");
    //});
}

@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%c", 5)).back == 'c');

    //assertCTFEable!(
    //{
        formatTest(9, "9");
        formatTest(10, "10");
    //});
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

	// TODO alias this not working
    //formatTest(S2(false), "S");
    //formatTest(S2(true),  "S");
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

	// TODO alias this
    //formatTest(S1(10), "10");
    //formatTest(S2(10), "S");
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

	// TODO alias this not working
    //formatTest(S1(2.25), "2.25");
    //formatTest(S2(2.25), "S");
}

@safe pure unittest
{
    //assertCTFEable!(
    //{
        formatTest('c', "c");
    //});
}

@safe unittest
{
    struct S1
    {
        char val;
        alias val this;
    }

    struct S2
    {
        char val;
        alias val this;
        string toString() const { return "S"; }
    }

	// TODO alias this not working
    //formatTest(S1('c'), "c");
    //formatTest(S2('c'), "S");
}

@safe unittest
{
    struct S3
    {
        string val; alias val this;
        string toString() const { return "S"; }
    }

	// TODO alias this
    //formatTest(S3("s3"), "S");
}

// alias this, input range I/F, and toString()
@safe unittest
{
    struct S(int flags)
    {
        int[] arr;
        static if (flags & 1)
            alias arr this;

        static if (flags & 2)
        {
            @property bool empty() const { return arr.length == 0; }
            @property int front() const { return arr[0] * 2; }
            void popFront() { arr = arr[1 .. $]; }
        }

        static if (flags & 4)
            string toString() const { return "S"; }
    }

    formatTest(S!0b000([0, 1, 2]), "S!0([0, 1, 2])");
    formatTest(S!0b001([0, 1, 2]), "[0, 1, 2]");        // Test for bug 7628
    formatTest(S!0b010([0, 1, 2]), "[0, 2, 4]");
    formatTest(S!0b011([0, 1, 2]), "[0, 2, 4]");
    formatTest(S!0b100([0, 1, 2]), "S");

	// TODO alias this not working
    //formatTest(S!0b101([0, 1, 2]), "S");                // Test for bug 7628
    //formatTest(S!0b110([0, 1, 2]), "S");
    //formatTest(S!0b111([0, 1, 2]), "S");
}

// https://issues.dlang.org/show_bug.cgi?id=18778
@safe pure unittest
{
    assert(format("%-(%1$s - %1$s, %)", ["A", "B", "C"]) == "A - A, B - B, C - C");
}

@safe unittest
{
    assert(collectExceptionMsg!FormatException(format("%d", [0:1])).back == 'd');

    int[string] aa0;
    formatTest(aa0, `[]`);

    // elements escaping
    formatTest(["aaa":1, "bbb":2],
               [`["aaa":1, "bbb":2]`, `["bbb":2, "aaa":1]`]);
    formatTest(['c':"str"],
               `['c':"str"]`);
    formatTest(['"':"\"", '\'':"'"],
               [`['"':"\"", '\'':"'"]`, `['\'':"'", '"':"\""]`]);

    // range formatting for AA
    auto aa3 = [1:"hello", 2:"world"];
    // escape
    formatTest("{%(%s:%s $ %)}", aa3,
               [`{1:"hello" $ 2:"world"}`, `{2:"world" $ 1:"hello"}`]);
    // use range formatting for key and value, and use %|
    formatTest("{%([%04d->%(%c.%)]%| $ %)}", aa3,
               [`{[0001->h.e.l.l.o] $ [0002->w.o.r.l.d]}`,
                `{[0002->w.o.r.l.d] $ [0001->h.e.l.l.o]}`]);

    // https://issues.dlang.org/show_bug.cgi?id=12135
    formatTest("%(%s:<%s>%|,%)", [1:2], "1:<2>");
    formatTest("%(%s:<%s>%|%)" , [1:2], "1:<2>");
}

@safe unittest
{
    struct S1
    {
        int[char] val;
        alias val this;
    }

    struct S2
    {
        int[char] val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(['c':1, 'd':2]), [`['c':1, 'd':2]`, `['d':2, 'c':1]`]);

	// TODO alias this not working
    //formatTest(S2(['c':1, 'd':2]), "S");
}

@system unittest
{
    // https://issues.dlang.org/show_bug.cgi?id=5354
    // If the class has both range I/F and custom toString, the use of custom
    // toString routine is prioritized.

    // Enable the use of custom toString that gets a sink delegate
    // for class formatting.

    enum inputRangeCode =
    q{
        int[] arr;
        this(int[] a){ arr = a; }
        @property int front() const { return arr[0]; }
        @property bool empty() const { return arr.length == 0; }
        void popFront(){ arr = arr[1 .. $]; }
    };

    class C1
    {
        mixin(inputRangeCode);
        void toString(scope void delegate(scope const(char)[]) dg,
                      scope const ref FormatSpec f) const
        {
            dg("[012]");
        }
    }
    class C2
    {
        mixin(inputRangeCode);
        void toString(scope void delegate(const(char)[]) dg, string f) const { dg("[012]"); }
    }
    class C3
    {
        mixin(inputRangeCode);
        void toString(scope void delegate(const(char)[]) dg) const { dg("[012]"); }
    }
    class C4
    {
        mixin(inputRangeCode);
        override string toString() const { return "[012]"; }
    }
    class C5
    {
        mixin(inputRangeCode);
    }

    formatTest(new C1([0, 1, 2]), "[012]");
    formatTest(new C2([0, 1, 2]), "[012]");
    formatTest(new C3([0, 1, 2]), "[012]");
    formatTest(new C4([0, 1, 2]), "[012]");
    formatTest(new C5([0, 1, 2]), "[0, 1, 2]");
}

@system unittest
{
    // interface
    InputRange!int i = inputRangeObject([1,2,3,4]);
    formatTest(i, "[1, 2, 3, 4]");
    assert(i.empty);
    i = null;
    formatTest(i, "null");

    // interface (downcast to Object)
    interface Whatever {}
    class C : Whatever
    {
        override @property string toString() const { return "ab"; }
    }
    Whatever val = new C;
    formatTest(val, "ab");

    // https://issues.dlang.org/show_bug.cgi?id=11175
    version (Windows)
    {
		import core.sys.windows.com : IID, IUnknown;
		import core.sys.windows.windef : HRESULT;

        interface IUnknown2 : IUnknown { }

        class D : IUnknown2
        {
            extern(Windows) HRESULT QueryInterface(const(IID)* riid, void** pvObject) { return typeof(return).init; }
            extern(Windows) uint AddRef() { return 0; }
            extern(Windows) uint Release() { return 0; }
        }

        IUnknown2 d = new D;
        string expected = format("%X", cast(void*) d);
        formatTest(d, expected);
    }
}


// https://issues.dlang.org/show_bug.cgi?id=4638
@safe unittest
{
    struct U8  {  string toString() const { return "blah"; } }
    struct U16 { wstring toString() const { return "blah"; } }
    struct U32 { dstring toString() const { return "blah"; } }
    formatTest(U8(), "blah");
    formatTest(U16(), "blah");
    formatTest(U32(), "blah");
}

@safe unittest
{
    // union formatting without toString
    union U1
    {
        int n;
        string s;
    }
    U1 u1;
    formatTest(u1, "U1");

    // union formatting with toString
    union U2
    {
        int n;
        string s;
        string toString() @trusted const { return s; }
    }
    U2 u2;
    () @trusted { u2.s = "hello"; } ();
    formatTest(u2, "hello");
}


@safe pure unittest
{
    // Test for https://issues.dlang.org/show_bug.cgi?id=7869
    struct S
    {
        string toString() const { return ""; }
    }
    S* p = null;
    formatTest(p, "null");

    S* q = () @trusted { return cast(S*) 0xFFEECCAA; } ();
    formatTest(q, "FFEECCAA");
}

@safe pure unittest
{
    auto spec = singleSpec("%10.3e");
    auto writer = appender!string();
    writer.formatValue(42.0, spec);

    assert(writer.data == " 4.200e+01");
}

}

@safe pure unittest
{
    auto spec = singleSpec("%10.3e");
    auto writer = appender!string();
    writer.formatValue(42.0, spec);

    assert(writer.data == " 4.200e+01");
}

}
// DISABLED: Unicode range tests causing garbage output due to cast(StrType) issues
// Uncomment to enable: version=EnableLargeTests

version(EnableLargeTests)
{
    // Valid and non-printable code point (<= U+FF)
    formatTest([cast(StrType)"hello"],
               `["hello"]`);
    // Valid and non-printable code point (<= U+FF)
    formatTest([cast(StrType)"\x10\x1F\x20test"],
               `["\x10\x1F test"]`);
    // Valid and non-printable code point (<= U+FF)
    formatTest([cast(StrType)"\x10\x1F\x20test"],
               `["\x10\x1F test"]`);
}
}

@safe pure unittest
{
    auto spec = singleSpec("%10.3e");
    auto writer = appender!string();
    writer.formatValue(42.0, spec);

    assert(writer.data == " 4.200e+01");
}

// DISABLED: Unicode range tests causing garbage output due to cast(StrType) issues
// Uncomment to enable: version=EnableLargeTests

version(EnableLargeTests)
{
    // Valid and non-printable code point (<= U+FF)
    formatTest([cast(StrType)"hello"],
               `["hello"]`);
    // Valid and non-printable code point (<= U+FF)
    formatTest([cast(StrType)"\x10\x1F\x20test"],
               `["\x10\x1F test"]`);
    // Valid and non-printable code point (<= U+FF)
    formatTest([cast(StrType)"\x10\x1F\x20test"],
               `["\x10\x1F test"]`);
}
