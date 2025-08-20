// Written in the D programming language.

/*
   Copyright: Copyright The D Language Foundation 2000-2013.

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format/internal/write.d)
 */
module std2.format.internal.write;

//import std.format : FormatException, formatValue, NoOpSink;
//import std.format : NoOpSink;
import std2.format.noopsink;
import core.exception : AssertError;
import core.simd; // cannot be selective, because float4 might not be defined
import std.algorithm.comparison : among, min;
import std.algorithm.searching : all, canFind;
import std.array : appender;
import std.conv : text, to;
import std.exception : assertThrown, collectExceptionMsg, enforce;
//import std.format : formattedWrite;
import std2.format.exception : FormatException, enforceFmt;
import std2.format.internal.floats : printFloat, isFloatSpec;
//import std2.format.internal.write : hasToString, HasToStringResult;
import std2.format.spec : FormatSpec, singleSpec;
//import std2.format.write : formattedWrite, formatValue;
import std.math.exponential : log2;
import std.math.hardware; // cannot be selective, because FloatingPointControl might not be defined
import std.math.operations : nextUp;
import std.math.traits : isInfinity;
import std.meta : AliasSeq;
import std.range : iota, isInputRange, repeat;
import std.range.interfaces : InputRange, inputRangeObject;
import std.range.interfaces : inputRangeObject;
import std.range.primitives : ElementType, isInputRange, isOutputRange, back, empty, front, hasLength, walkLength, isForwardRange, isInfinite, popFront, put;
import std.system : endian, Endian;
import std.traits;
import std.typecons : Nullable;
import std.uni : isGraphical, graphemeStride;
import std.utf : decode, UTFException;

package(std2.format):

/*
    `bool`s are formatted as `"true"` or `"false"` with `%s` and as `1` or
    `0` with integral-specific format specs.
 */
void formatValueImpl(Writer, T)(auto ref Writer w, const(T) obj, scope const ref FormatSpec f)
if (is(BooleanTypeOf!T) && !is(T == enum))
{
    BooleanTypeOf!T val = obj;

    if (f.spec == 's')
        writeAligned(w, val ? "true" : "false", f);
    else
        formatValueImpl(w, cast(byte) val, f);
}

/*
    `null` literal is formatted as `"null"`
 */
void formatValueImpl(Writer, T)(auto ref Writer w, const(T) obj, scope const ref FormatSpec f)
if (is(immutable T == immutable typeof(null)) && !is(T == enum))
{
    const spec = f.spec;
    enforceFmt(spec == 's', "null literal cannot match %" ~ spec);

    writeAligned(w, "null", f);
}

/*
    Integrals are formatted like $(REF printf, core, stdc, stdio).
 */
void formatValueImpl(Writer, T)(auto ref Writer w, const(T) obj, scope const ref FormatSpec f)
if (is(IntegralTypeOf!T) && !is(T == enum))
{
    alias U = IntegralTypeOf!T;
    U val = obj;    // Extracting alias this may be impure/system/may-throw

    if (f.spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto raw = (ref val) @trusted {
            return (cast(const char*) &val)[0 .. val.sizeof];
        }(val);
        if (needToSwapEndianess(f))
            foreach_reverse (c; raw)
                put(w, c);
        else
            foreach (c; raw)
                put(w, c);
        return;
    }

    static if (isSigned!U)
    {
        const negative = val < 0 && f.spec != 'x' && f.spec != 'X' && f.spec != 'b' && f.spec != 'o' && f.spec != 'u';
        ulong arg = negative ? -cast(ulong) val : val;
    }
    else
    {
        const negative = false;
        ulong arg = val;
    }
    arg &= Unsigned!U.max;

    formatValueImplUlong!(Writer)(w, arg, negative, f);
}

// Helper function for `formatValueImpl` that avoids template bloat
private void formatValueImplUlong(Writer)(auto ref Writer w, ulong arg, in bool negative,
                                                scope const ref FormatSpec f)
{
    immutable uint base = baseOfSpec(f.spec);

    const bool zero = arg == 0;
    char[64] digits = void;
    size_t pos = digits.length - 1;
    do
    {
        /* `cast(char)` is needed because value range propagation (VRP) cannot
         * analyze `base` because it’s computed in a separate function
         * (`baseOfSpec`). */
        digits[pos--] = cast(char) ('0' + arg % base);
        if (base > 10 && digits[pos + 1] > '9')
            digits[pos + 1] += ((f.spec == 'x' || f.spec == 'a') ? 'a' : 'A') - '0' - 10;
        arg /= base;
    } while (arg > 0);

    char[3] prefix = void;
    size_t left = 2;
    size_t right = 2;

    // add sign
    if (f.spec != 'x' && f.spec != 'X' && f.spec != 'b' && f.spec != 'o' && f.spec != 'u')
    {
        if (negative)
            prefix[right++] = '-';
        else if (f.flPlus)
            prefix[right++] = '+';
        else if (f.flSpace)
            prefix[right++] = ' ';
    }

    // not a floating point like spec
    if (f.spec == 'x' || f.spec == 'X' || f.spec == 'b' || f.spec == 'o' || f.spec == 'u'
        || f.spec == 'd' || f.spec == 's')
    {
        if (f.flHash && (base == 16) && !zero)
        {
            prefix[--left] = f.spec;
            prefix[--left] = '0';
        }
        if (f.flHash && (base == 8) && !zero
            && (digits.length - (pos + 1) >= f.precision || f.precision == f.UNSPECIFIED))
            prefix[--left] = '0';

        writeAligned(w, prefix[left .. right], digits[pos + 1 .. $], "", f, true);
        return;
    }

    FormatSpec fs = f;
    if (f.precision == f.UNSPECIFIED)
        fs.precision = cast(typeof(fs.precision)) (digits.length - pos - 2);

    // %f like output
    if (f.spec == 'f' || f.spec == 'F'
        || ((f.spec == 'g' || f.spec == 'G') && (fs.precision >= digits.length - pos - 2)))
    {
        if (f.precision == f.UNSPECIFIED)
            fs.precision = 0;

        writeAligned(w, prefix[left .. right], digits[pos + 1 .. $], ".", "", fs,
                     (f.spec == 'g' || f.spec == 'G') ? PrecisionType.allDigits : PrecisionType.fractionalDigits);

        return;
    }

    // at least one digit for %g
    if ((f.spec == 'g' || f.spec == 'G') && fs.precision == 0)
        fs.precision = 1;

    // rounding
    size_t digit_end = pos + fs.precision + ((f.spec == 'g' || f.spec == 'G') ? 1 : 2);
    if (digit_end <= digits.length)
    {
        RoundingClass rt = RoundingClass.ZERO;
        if (digit_end < digits.length)
        {
            auto tie = (f.spec == 'a' || f.spec == 'A') ? '8' : '5';
            if (digits[digit_end] >= tie)
            {
                rt = RoundingClass.UPPER;
                if (digits[digit_end] == tie && digits[digit_end + 1 .. $].all!(a => a == '0'))
                    rt = RoundingClass.FIVE;
            }
            else
            {
                rt = RoundingClass.LOWER;
                if (digits[digit_end .. $].all!(a => a == '0'))
                    rt = RoundingClass.ZERO;
            }
        }

        if (round(digits, pos + 1, digit_end, rt, negative,
                  f.spec == 'a' ? 'f' : (f.spec == 'A' ? 'F' : '9')))
        {
            pos--;
            digit_end--;
        }
    }

    // convert to scientific notation
    char[1] int_digit = void;
    int_digit[0] = digits[pos + 1];
    digits[pos + 1] = '.';

    char[4] suffix = void;

    if (f.spec == 'e' || f.spec == 'E' || f.spec == 'g' || f.spec == 'G')
    {
        suffix[0] = (f.spec == 'e' || f.spec == 'g') ? 'e' : 'E';
        suffix[1] = '+';
        suffix[2] = cast(char) ('0' + (digits.length - pos - 2) / 10);
        suffix[3] = cast(char) ('0' + (digits.length - pos - 2) % 10);
    }
    else
    {
        if (right == 3)
            prefix[0] = prefix[2];
        prefix[1] = '0';
        prefix[2] = f.spec == 'a' ? 'x' : 'X';

        left = right == 3 ? 0 : 1;
        right = 3;

        suffix[0] = f.spec == 'a' ? 'p' : 'P';
        suffix[1] = '+';
        suffix[2] = cast(char) ('0' + ((digits.length - pos - 2) * 4) / 10);
        suffix[3] = cast(char) ('0' + ((digits.length - pos - 2) * 4) % 10);
    }

    // remove trailing zeros
    if ((f.spec == 'g' || f.spec == 'G') && !f.flHash)
    {
        digit_end = min(digit_end, digits.length);
        while (digit_end > pos + 1 &&
               (digits[digit_end - 1] == '0' || digits[digit_end - 1] == '.'))
            digit_end--;
    }

    writeAligned(w, prefix[left .. right], int_digit[0 .. $],
                 digits[pos + 1 .. min(digit_end, $)],
                 suffix[0 .. $], fs,
                 (f.spec == 'g' || f.spec == 'G') ? PrecisionType.allDigits : PrecisionType.fractionalDigits);
}

private uint baseOfSpec(in char spec) @safe pure
{
    typeof(return) base =
        spec == 'x' || spec == 'X' || spec == 'a' || spec == 'A' ? 16 :
        spec == 'o' ? 8 :
        spec == 'b' ? 2 :
        spec == 's' || spec == 'd' || spec == 'u'
        || spec == 'e' || spec == 'E' || spec == 'f' || spec == 'F'
        || spec == 'g' || spec == 'G' ? 10 :
        0;

    enforceFmt(base > 0,
        "incompatible format character for integral argument: %" ~ spec);

    return base;
}

/*
    Floating-point values are formatted like $(REF printf, core, stdc, stdio)
 */
void formatValueImpl(Writer, T)(auto ref Writer w, const(T) obj,
                                      scope const ref FormatSpec f)
if (is(FloatingPointTypeOf!T) && !is(T == enum))
{
    FloatingPointTypeOf!T val = obj;
    const char spec = f.spec;

    if (spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto raw = (ref val) @trusted {
            return (cast(const char*) &val)[0 .. val.sizeof];
        }(val);

        if (needToSwapEndianess(f))
        {
            foreach_reverse (c; raw)
                put(w, c);
        }
        else
        {
            foreach (c; raw)
                put(w, c);
        }
        return;
    }

    FormatSpec fs = f; // fs is copy for change its values.
    fs.spec = spec == 's' ? 'g' : spec;
    enforceFmt(isFloatSpec(fs.spec), "incompatible format character for floating point argument: %" ~ spec);

    static if (is(T == float) || is(T == double)
               || (is(T == real) && (T.mant_dig == double.mant_dig || T.mant_dig == 64)))
    {
        alias tval = val;
    }
    else
    {
        // reals that are not supported by printFloat are cast to double.
        double tval = val;

        // Numbers greater than double.max are converted to double.max:
        if (val > double.max && !isInfinity(val))
            tval = double.max;
        if (val < -double.max && !isInfinity(val))
            tval = -double.max;

        // Numbers between the smallest representable double subnormal and 0.0
        // are converted to the smallest representable double subnormal:
        enum doubleLowest = nextUp(0.0);
        if (val > 0 && val < doubleLowest)
            tval = doubleLowest;
        if (val < 0 && val > -doubleLowest)
            tval = -doubleLowest;
    }

    printFloat(w, tval, fs);
}

/*
    Formatting a `creal` is deprecated but still kept around for a while.
 */
deprecated("Use of complex types is deprecated. Use std.complex")
void formatValueImpl(Writer, T)(auto ref Writer w, const(T) obj, scope const ref FormatSpec f)
if (is(immutable T : immutable creal) && !is(T == enum))
{
    immutable creal val = obj;

    formatValueImpl(w, val.re, f);
    if (val.im >= 0)
    {
        put(w, '+');
    }
    formatValueImpl(w, val.im, f);
    put(w, 'i');
}

/*
    Formatting an `ireal` is deprecated but still kept around for a while.
 */
deprecated("Use of imaginary types is deprecated. Use std.complex")
void formatValueImpl(Writer, T)(auto ref Writer w, const(T) obj, scope const ref FormatSpec f)
if (is(immutable T : immutable ireal) && !is(T == enum))
{
    immutable ireal val = obj;

    formatValueImpl(w, val.im, f);
    put(w, 'i');
}

/*
    Individual characters are formatted as Unicode characters with `%s`
    and as integers with integral-specific format specs
 */
void formatValueImpl(Writer, T)(auto ref Writer w, const(T) obj, scope const ref FormatSpec f)
if (is(CharTypeOf!T) && !is(T == enum))
{
    CharTypeOf!T[1] val = obj;

    if (f.spec == 's' || f.spec == 'c')
        writeAligned(w, val[], f);
    else
    {
        alias U = AliasSeq!(ubyte, ushort, uint)[CharTypeOf!T.sizeof/2];
        formatValueImpl(w, cast(U) val[0], f);
    }
}

/*
    Strings are formatted like $(REF printf, core, stdc, stdio)
 */
void formatValueImpl(Writer, T)(auto ref Writer w, scope const(T) obj,
    scope const ref FormatSpec f)
if (is(StringTypeOf!T) && !is(StaticArrayTypeOf!T) && !is(T == enum))
{
    Unqual!(const(StringTypeOf!T)) val = obj;  // for `alias this`, see bug5371
    formatRange(w, val, f);
}

/*
    Static-size arrays are formatted as dynamic arrays.
 */
void formatValueImpl(Writer, T)(auto ref Writer w, auto ref T obj,
    scope const ref FormatSpec f)
if (is(StaticArrayTypeOf!T) && !is(T == enum))
{
    formatValueImpl(w, obj[], f);
}

/*
    Dynamic arrays are formatted as input ranges.
 */
void formatValueImpl(Writer, T)(auto ref Writer w, T obj, scope const ref FormatSpec f)
if (is(DynamicArrayTypeOf!T) && !is(StringTypeOf!T) && !is(T == enum))
{
    static if (is(immutable(ArrayTypeOf!T) == immutable(void[])))
    {
        formatValueImpl(w, cast(const ubyte[]) obj, f);
    }
    else static if (!isInputRange!T)
    {
        alias U = Unqual!(ArrayTypeOf!T);
        static assert(isInputRange!U, U.stringof ~ " must be an InputRange");
        U val = obj;
        formatValueImpl(w, val, f);
    }
    else
    {
        formatRange(w, obj, f);
    }
}

// input range formatting
private void formatRange(Writer, T)(ref Writer w, ref T val, scope const ref FormatSpec f)
if (isInputRange!T)
{
    // in this mode, we just want to do a representative print to discover
    // if the format spec is valid
    enum formatTestMode = is(Writer == NoOpSink);

    static if (!formatTestMode && isInfinite!T)
    {
        static assert(!isInfinite!T, "Cannot format an infinite range. " ~
            "Convert it to a finite range first using `std.range.take` or `std.range.takeExactly`.");
    }

    // Formatting character ranges like string
    if (f.spec == 's')
    {
        alias E = ElementType!T;

        static if (!is(E == enum) && is(CharTypeOf!E))
        {
            static if (is(StringTypeOf!T))
                writeAligned(w, val[0 .. f.precision < $ ? f.precision : $], f);
            else
            {
                if (!f.flDash)
                {
                    static if (hasLength!T)
                    {
                        // right align
                        auto len = val.length;
                    }
                    else static if (isForwardRange!T && !isInfinite!T)
                    {
                        auto len = walkLength(val.save);
                    }
                    else
                    {
                        enforceFmt(f.width == 0, "Cannot right-align a range without length");
                        size_t len = 0;
                    }
                    if (f.precision != f.UNSPECIFIED && len > f.precision)
                        len = f.precision;

                    if (f.width > len)
                        foreach (i ; 0 .. f.width - len)
                            put(w, ' ');
                    if (f.precision == f.UNSPECIFIED)
                        put(w, val);
                    else
                    {
                        size_t printed = 0;
                        for (; !val.empty && printed < f.precision; val.popFront(), ++printed)
                            put(w, val.front);
                    }
                }
                else
                {
                    size_t printed = void;

                    // left align
                    if (f.precision == f.UNSPECIFIED)
                    {
                        static if (hasLength!T)
                        {
                            printed = val.length;
                            put(w, val);
                        }
                        else
                        {
                            printed = 0;
                            for (; !val.empty; val.popFront(), ++printed)
                            {
                                put(w, val.front);
                                static if (formatTestMode) break; // one is enough to test
                            }
                        }
                    }
                    else
                    {
                        printed = 0;
                        for (; !val.empty && printed < f.precision; val.popFront(), ++printed)
                            put(w, val.front);
                    }

                    if (f.width > printed)
                        foreach (i ; 0 .. f.width - printed)
                            put(w, ' ');
                }
            }
        }
        else
        {
            put(w, f.seqBefore);
            if (!val.empty)
            {
                formatElement(w, val.front, f);
                val.popFront();
                for (size_t i; !val.empty; val.popFront(), ++i)
                {
                    put(w, f.seqSeparator);
                    formatElement(w, val.front, f);
                    static if (formatTestMode) break; // one is enough to test
                }
            }
            static if (!isInfinite!T) put(w, f.seqAfter);
        }
    }
    else if (f.spec == 'r')
    {
        static if (is(DynamicArrayTypeOf!T))
        {
            alias ARR = DynamicArrayTypeOf!T;
            scope a = cast(ARR) val;
            foreach (e ; a)
            {
                formatValue(w, e, f);
                static if (formatTestMode) break; // one is enough to test
            }
        }
        else
        {
            for (size_t i; !val.empty; val.popFront(), ++i)
            {
                formatValue(w, val.front, f);
                static if (formatTestMode) break; // one is enough to test
            }
        }
    }
    else if (f.spec == '(')
    {
        if (val.empty)
            return;
        // Nested specifier is to be used
        for (;;)
        {
            FormatSpec fmt = FormatSpec(f.nested);
            w: while (true)
            {
                immutable r = fmt.writeUpToNextSpec(w);
                // There was no format specifier, so break
                if (!r)
                    break;
                if (f.flDash)
                    formatValue(w, val.front, fmt);
                else
                    formatElement(w, val.front, fmt);
                // Check if there will be a format specifier farther on in the
                // string. If so, continue the loop, otherwise break. This
                // prevents extra copies of the `sep` from showing up.
                foreach (size_t i; 0 .. fmt.trailing.length)
                    if (fmt.trailing[i] == '%')
                        continue w;
                break w;
            }
            static if (formatTestMode)
            {
                break; // one is enough to test
            }
            else
            {
                if (f.sep !is null)
                {
                    put(w, fmt.trailing);
                    val.popFront();
                    if (val.empty)
                        break;
                    put(w, f.sep);
                }
                else
                {
                    val.popFront();
                    if (val.empty)
                        break;
                    put(w, fmt.trailing);
                }
            }
        }
    }
    else
        throw new FormatException(text("Incorrect format specifier for range: %", f.spec));
}
	

// character formatting with ecaping
void formatChar(Writer)(ref Writer w, in dchar c, in char quote)
{
    string fmt;
    if (isGraphical(c))
    {
        if (c == quote || c == '\\')
            put(w, '\\');
        put(w, c);
        return;
    }
    else if (c <= 0xFF)
    {
        if (c < 0x20)
        {
            foreach (i, k; "\n\r\t\a\b\f\v\0")
            {
                if (c == k)
                {
                    put(w, '\\');
                    put(w, "nrtabfv0"[i]);
                    return;
                }
            }
        }
        fmt = "\\x%02X";
    }
    else if (c <= 0xFFFF)
        fmt = "\\u%04X";
    else
        fmt = "\\U%08X";

    formattedWrite(w, fmt, cast(uint) c);
}

/*
    Associative arrays are formatted by using `':'` and $(D ", ") as
    separators, and enclosed by `'['` and `']'`.
 */
void formatValueImpl(Writer, T)(auto ref Writer w, T obj, scope const ref FormatSpec f)
if (is(AssocArrayTypeOf!T) && !is(T == enum))
{
    AssocArrayTypeOf!T val = obj;
    const spec = f.spec;

    enforceFmt(spec == 's' || spec == '(',
        "incompatible format character for associative array argument: %" ~ spec);

    enum string defSpec = "%s" ~ f.keySeparator ~ "%s" ~ f.seqSeparator;
    auto fmtSpec = spec == '(' ? f.nested : defSpec;

    auto key_first = true;

    // testing correct nested format spec
    auto noop = NoOpSink();
    auto test = FormatSpec(fmtSpec);
    enforceFmt(test.writeUpToNextSpec(noop),
        "nested format string for associative array contains no format specifier");
    enforceFmt(test.indexStart <= 2,
        "positional parameter in nested format string for associative array may only be 1 or 2");
    if (test.indexStart == 2)
        key_first = false;

    enforceFmt(test.writeUpToNextSpec(noop),
        "nested format string for associative array contains only one format specifier");
    enforceFmt(test.indexStart <= 2,
        "positional parameter in nested format string for associative array may only be 1 or 2");
    enforceFmt(test.indexStart == 0 || ((test.indexStart == 2) == key_first),
        "wrong combination of positional parameters in nested format string");

    enforceFmt(!test.writeUpToNextSpec(noop),
        "nested format string for associative array contains more than two format specifiers");

    size_t i = 0;
    immutable end = val.length;

    if (spec == 's')
        put(w, f.seqBefore);
    foreach (k, ref v; val)
    {
        auto fmt = FormatSpec(fmtSpec);

        foreach (pos; 1 .. 3)
        {
            fmt.writeUpToNextSpec(w);

            if (key_first == (pos == 1))
            {
                if (f.flDash)
                    formatValue(w, k, fmt);
                else
                    formatElement(w, k, fmt);
            }
            else
            {
                if (f.flDash)
                    formatValue(w, v, fmt);
                else
                    formatElement(w, v, fmt);
            }
        }

        if (f.sep !is null)
        {
            fmt.writeUpToNextSpec(w);
            if (++i != end)
                put(w, f.sep);
        }
        else
        {
            if (++i != end)
                fmt.writeUpToNextSpec(w);
        }
    }
    if (spec == 's')
        put(w, f.seqAfter);
}

enum HasToStringResult
{
    none,
    hasSomeToString,
    inCharSink,
    inCharSinkFormatString,
    inCharSinkFormatSpec,
    constCharSink,
    constCharSinkFormatString,
    constCharSinkFormatSpec,
    customPutWriter,
    customPutWriterFormatSpec,
}

private alias DScannerBug895 = int[256];
private immutable bool hasPreviewIn = ((in DScannerBug895 a) { return __traits(isRef, a); })(DScannerBug895.init);

template hasToString(T, Char)
{
    static if (isPointer!T)
    {
        // X* does not have toString, even if X is aggregate type has toString.
        enum hasToString = HasToStringResult.none;
    }
    else static if (is(typeof(
        (T val) {
            const FormatSpec f;
            static struct S
            {
                @disable this(this);
                void put(scope Char s){}
            }
            S s;
            val.toString(s, f);
        })))
    {
        enum hasToString = HasToStringResult.customPutWriterFormatSpec;
    }
    else static if (is(typeof(
        (T val) {
            static struct S
            {
                @disable this(this);
                void put(scope Char s){}
            }
            S s;
            val.toString(s);
        })))
    {
        enum hasToString = HasToStringResult.customPutWriter;
    }
    else static if (is(typeof((T val) { FormatSpec f; val.toString((scope const(char)[] s){}, f); })))
    {
        enum hasToString = HasToStringResult.constCharSinkFormatSpec;
    }
    else static if (is(typeof((T val) { val.toString((scope const(char)[] s){}, "%s"); })))
    {
        enum hasToString = HasToStringResult.constCharSinkFormatString;
    }
    else static if (is(typeof((T val) { val.toString((scope const(char)[] s){}); })))
    {
        enum hasToString = HasToStringResult.constCharSink;
    }

    else static if (hasPreviewIn &&
                    is(typeof((T val) { FormatSpec f; val.toString((in char[] s){}, f); })))
    {
        enum hasToString = HasToStringResult.inCharSinkFormatSpec;
    }
    else static if (hasPreviewIn &&
                    is(typeof((T val) { val.toString((in char[] s){}, "%s"); })))
    {
        enum hasToString = HasToStringResult.inCharSinkFormatString;
    }
    else static if (hasPreviewIn &&
                    is(typeof((T val) { val.toString((in char[] s){}); })))
    {
        enum hasToString = HasToStringResult.inCharSink;
    }

    else static if (is(ReturnType!((T val) { return val.toString(); }) S) && isSomeString!S)
    {
        enum hasToString = HasToStringResult.hasSomeToString;
    }
    else
    {
        enum hasToString = HasToStringResult.none;
    }
}

@safe pure unittest 
{
    struct S2
    {
        bool val;
        alias val this;
        string toString() const { return "S"; }
    }

	static assert(hasToString!(S2, char));
}

// object formatting with toString
private void formatObject(Writer, T)(ref Writer w, ref T val, scope const ref FormatSpec f)
{
    enum overload = hasToString!(T, char);

    enum noop = is(Writer == NoOpSink);

    static if (overload == HasToStringResult.customPutWriterFormatSpec)
    {
        static if (!noop) val.toString(w, f);
    }
    else static if (overload == HasToStringResult.customPutWriter)
    {
        static if (!noop) val.toString(w);
    }
    else static if (overload == HasToStringResult.constCharSinkFormatSpec)
    {
        static if (!noop) val.toString((scope const(char)[] s) { put(w, s); }, f);
    }
    else static if (overload == HasToStringResult.constCharSinkFormatString)
    {
        static if (!noop) val.toString((scope const(char)[] s) { put(w, s); }, f.getCurFmtStr());
    }
    else static if (overload == HasToStringResult.constCharSink)
    {
        static if (!noop) val.toString((scope const(char)[] s) { put(w, s); });
    }
    else static if (overload == HasToStringResult.inCharSinkFormatSpec)
    {
        static if (!noop) val.toString((in char[] s) { put(w, s); }, f);
    }
    else static if (overload == HasToStringResult.inCharSinkFormatString)
    {
        static if (!noop) val.toString((in char[] s) { put(w, s); }, f.getCurFmtStr());
    }
    else static if (overload == HasToStringResult.inCharSink)
    {
        static if (!noop) val.toString((in char[] s) { put(w, s); });
    }
    else static if (overload == HasToStringResult.hasSomeToString)
    {
        static if (!noop) put(w, val.toString());
    }
    else
    {
        static assert(0, "No way found to format " ~ T.stringof ~ " as string");
    }
}

/*
    Aggregates
 */
void formatValueImpl(Writer, T)(auto ref Writer w, T val, scope const ref FormatSpec f)
if (is(T == class) && !is(T == enum))
{
    enforceValidFormatSpec!(T)(f);

    // TODO: remove this check once `@disable override` deprecation cycle is finished
    static if (__traits(hasMember, T, "toString") && isSomeFunction!(val.toString))
        static assert(!__traits(isDisabled, T.toString), T.stringof ~
            " cannot be formatted because its `toString` is marked with `@disable`");

    if (val is null)
        put(w, "null");
    else
    {
        enum overload = hasToString!(T, char);
        with(HasToStringResult)
        static if ((is(T == immutable) || is(T == const) || is(T == shared)) && overload == none)
        {
            // Remove this when Object gets const toString
            // https://issues.dlang.org/show_bug.cgi?id=7879
            static if (is(T == immutable))
                put(w, "immutable(");
            else static if (is(T == const))
                put(w, "const(");
            else static if (is(T == shared))
                put(w, "shared(");

            put(w, typeid(Unqual!T).name);
            put(w, ')');
        }
        else static if (overload.among(constCharSink, constCharSinkFormatString, constCharSinkFormatSpec) ||
                       (!isInputRange!T && !is(BuiltinTypeOf!T)))
        {
            formatObject!(Writer, T)(w, val, f);
        }
        else
        {
            static if (!is(__traits(parent, T.toString) == Object)) // not inherited Object.toString
            {
                formatObject(w, val, f);
            }
            else static if (isInputRange!T)
            {
                formatRange(w, val, f);
            }
            else static if (is(BuiltinTypeOf!T X))
            {
                X x = val;
                formatValueImpl(w, x, f);
            }
            else
            {
                formatObject(w, val, f);
            }
        }
    }
}

void formatValueImpl(Writer, T)(auto ref Writer w, T val, scope const ref FormatSpec f)
if (is(T == interface) && !is(BuiltinTypeOf!T) && !is(T == enum))
{
    enforceValidFormatSpec!(T, char)(f);
    if (val is null)
        put(w, "null");
    else
    {
        static if (__traits(hasMember, T, "toString") && isSomeFunction!(val.toString))
            static assert(!__traits(isDisabled, T.toString), T.stringof ~
                " cannot be formatted because its `toString` is marked with `@disable`");

        static if (hasToString!(T, char) != HasToStringResult.none)
        {
            formatObject(w, val, f);
        }
        else static if (isInputRange!T)
        {
            formatRange(w, val, f);
        }
        else
        {
            version (Windows)
            {
                static if (is(T : IUnknown))
                {
                    formatValueImpl(w, *cast(void**)&val, f);
                }
                else
                {
                    formatValueImpl(w, cast(Object) val, f);
                }
            }
            else
            {
                formatValueImpl(w, cast(Object) val, f);
            }
        }
    }
}

// Maybe T is noncopyable struct, so receive it by 'auto ref'.
void formatValueImpl(Writer, T)(auto ref Writer w, auto ref T val,
    scope const ref FormatSpec f)
if ((is(T == struct) || is(T == union)) && !is(BuiltinTypeOf!T) && !is(T == enum))
{
    static if (__traits(hasMember, T, "toString") && isSomeFunction!(val.toString))
        static assert(!__traits(isDisabled, T.toString), T.stringof ~
            " cannot be formatted because its `toString` is marked with `@disable`");

    enforceValidFormatSpec!(T)(f);
    static if (hasToString!(T, char))
    {
        formatObject(w, val, f);
    }
    else static if (isInputRange!T)
    {
        formatRange(w, val, f);
    }
    else static if (is(T == struct))
    {
        enum left = T.stringof~"(";
        enum separator = ", ";
        enum right = ")";

        put(w, left);
        static foreach (i; 0 .. T.tupleof.length)
        {{
            static if (__traits(identifier, val.tupleof[i]) == "this")
            {
                // ignore hidden context pointer
            }
            else static if (0 < i && T.tupleof[i-1].offsetof == T.tupleof[i].offsetof)
            {
                static if (i == T.tupleof.length - 1 || T.tupleof[i].offsetof != T.tupleof[i+1].offsetof)
                {
                    enum el = separator ~ __traits(identifier, T.tupleof[i]) ~ "}";
                    put(w, el);
                }
                else
                {
                    enum el = separator ~ __traits(identifier, T.tupleof[i]);
                    put(w, el);
                }
            }
            else static if (i+1 < T.tupleof.length && T.tupleof[i].offsetof == T.tupleof[i+1].offsetof)
            {
                enum el = (i > 0 ? separator : "") ~ "#{overlap " ~ __traits(identifier, T.tupleof[i]);
                put(w, el);
            }
            else
            {
                static if (i > 0)
                    put(w, separator);
                formatElement(w, val.tupleof[i], f);
            }
        }}
        put(w, right);
    }
    else
    {
        put(w, T.stringof);
    }
}

void enforceValidFormatSpec(T)(scope const ref FormatSpec f)
{
    enum overload = hasToString!(T, char);
    static if (
            overload != HasToStringResult.constCharSinkFormatSpec &&
            overload != HasToStringResult.constCharSinkFormatString &&
            overload != HasToStringResult.inCharSinkFormatSpec &&
            overload != HasToStringResult.inCharSinkFormatString &&
            overload != HasToStringResult.customPutWriterFormatSpec &&
            !isInputRange!T)
    {
        enforceFmt(f.spec == 's',
            "Expected '%s' format specifier for type '" ~ T.stringof ~ "'");
    }
}

/*
    `enum`s are formatted like their base value
 */
void formatValueImpl(Writer, T)(auto ref Writer w, T val, scope const ref FormatSpec f)
if (is(T == enum))
{
    if (f.spec != 's')
        return formatValueImpl(w, cast(OriginalType!T) val, f);

    foreach (immutable member; __traits(allMembers, T))
        if (val == __traits(getMember, T, member))
            return formatValueImpl(w, member, f);

    auto w2 = appender!string();

    // val is not a member of T, output cast(T) rawValue instead.
    enum prefix = "cast(" ~ T.stringof ~ ")";
    put(w2, prefix);
    static assert(!is(OriginalType!T == T), "OriginalType!" ~ T.stringof ~
                  "must not be equal to " ~ T.stringof);

    FormatSpec f2 = f;
    f2.width = 0;
    formatValueImpl(w2, cast(OriginalType!T) val, f2);
    writeAligned(w, w2.data, f);
}

/*
    Pointers are formatted as hex integers.
 */
void formatValueImpl(Writer, T)(auto ref Writer w, scope const(T) val, scope const ref FormatSpec f)
if (isPointer!T && !is(T == enum))
{
    static if (is(typeof({ shared const void* p = val; })))
        alias SharedOf(T) = shared(T);
    else
        alias SharedOf(T) = T;

    const SharedOf!(void*) p = val;
    const pnum = () @trusted { return cast(ulong) p; }();

    if (f.spec == 's')
    {
        if (p is null)
        {
            writeAligned(w, "null", f);
            return;
        }
        FormatSpec fs = f; // fs is copy for change its values.
        fs.spec = 'X';
        formatValueImpl(w, pnum, fs);
    }
    else
    {
        enforceFmt(f.spec == 'X' || f.spec == 'x',
            "Expected one of %s, %x or %X for pointer type.");
        formatValueImpl(w, pnum, f);
    }
}

/*
    SIMD vectors are formatted as arrays.
 */
void formatValueImpl(Writer, V)(auto ref Writer w, const(V) val, scope const ref FormatSpec f)
if (isSIMDVector!V)
{
    formatValueImpl(w, val.array, f);
}

/*
    Delegates are formatted by `ReturnType delegate(Parameters) FunctionAttributes`

    Known bug: Because of issue https://issues.dlang.org/show_bug.cgi?id=18269
               the FunctionAttributes might be wrong.
 */
void formatValueImpl(Writer, T)(auto ref Writer w, scope const(T), scope const ref FormatSpec f)
if (isDelegate!T)
{
    formatValueImpl(w, T.stringof, f);
}

// string elements are formatted like UTF-8 string literals.
void formatElement(Writer, T)(auto ref Writer w, T val, scope const ref FormatSpec f)
if (is(StringTypeOf!T) && !is(T == enum))
{
    StringTypeOf!T str = val;   // https://issues.dlang.org/show_bug.cgi?id=8015

    if (f.spec == 's')
    {
        try
        {
            // ignore other specifications and quote
            for (size_t i = 0; i < str.length; )
            {
                auto c = decode(str, i);
                // \uFFFE and \uFFFF are considered valid by isValidDchar,
                // so need checking for interchange.
                if (c == 0xFFFE || c == 0xFFFF)
                    goto LinvalidSeq;
            }
            put(w, '\"');
            for (size_t i = 0; i < str.length; )
            {
                auto c = decode(str, i);
                formatChar(w, c, '"');
            }
            put(w, '\"');
            return;
        }
        catch (UTFException)
        {
        }

        // If val contains invalid UTF sequence, formatted like HexString literal
    LinvalidSeq:
        static if (is(typeof(str[0]) : const(char)))
        {
            enum type = "";
            alias IntArr = const(ubyte)[];
        }
        else static if (is(typeof(str[0]) : const(wchar)))
        {
            enum type = "w";
            alias IntArr = const(ushort)[];
        }
        else static if (is(typeof(str[0]) : const(dchar)))
        {
            enum type = "d";
            alias IntArr = const(uint)[];
        }
        formattedWrite(w, "[%(cast(" ~ type ~ "char) 0x%X%|, %)]", cast(IntArr) str);
    }
    else
        formatValue(w, str, f);
}

// Character elements are formatted like UTF-8 character literals.
void formatElement(Writer, T)(auto ref Writer w, T val, scope const ref FormatSpec f)
if (is(CharTypeOf!T) && !is(T == enum))
{
    if (f.spec == 's')
    {
        put(w, '\'');
        formatChar(w, val, '\'');
        put(w, '\'');
    }
    else
        formatValue(w, val, f);
}

// Maybe T is noncopyable struct, so receive it by 'auto ref'.
void formatElement(Writer, T)(auto ref Writer w, auto ref T val, scope const ref FormatSpec f)
if (!is(StringTypeOf!T) && !is(CharTypeOf!T) || is(T == enum))
{
    formatValue(w, val, f);
}


// Fix for https://issues.dlang.org/show_bug.cgi?id=1591
int getNthInt(string kind, A...)(uint index, A args)
{
    return getNth!(kind, isIntegral, int)(index, args);
}

T getNth(string kind, alias Condition, T, A...)(uint index, A args)
{
    switch (index)
    {
        foreach (n, _; A)
        {
            case n:
                static if (Condition!(typeof(args[n])))
                {
                    return to!T(args[n]);
                }
                else
                {
                    throw new FormatException(
                        text(kind, " expected, not ", typeof(args[n]).stringof,
                            " for argument #", index + 1));
                }
        }
        default:
            throw new FormatException(text("Missing ", kind, " argument"));
    }
}

private bool needToSwapEndianess(scope const ref FormatSpec f) @safe pure
{
    return endian == Endian.littleEndian && f.flPlus
        || endian == Endian.bigEndian && f.flDash;
}

void writeAligned(Writer, T)(auto ref Writer w, T s, scope const ref FormatSpec f)
if (isSomeString!T)
{
    FormatSpec fs = f;
    fs.flZero = false;
    writeAligned(w, "", "", s, fs);
}

enum PrecisionType
{
    none,
    integer,
    fractionalDigits,
    allDigits,
}

void writeAligned(Writer, T1, T2, T3)(auto ref Writer w,
    T1 prefix, T2 grouped, T3 suffix, scope const ref FormatSpec f,
    bool integer_precision = false)
if (isSomeString!T1 && isSomeString!T2 && isSomeString!T3)
{
    writeAligned(w, prefix, grouped, "", suffix, f,
                 integer_precision ? PrecisionType.integer : PrecisionType.none);
}

void writeAligned(Writer, T1, T2, T3, T4)(auto ref Writer w,
    T1 prefix, T2 grouped, T3 fracts, T4 suffix, scope const ref FormatSpec f,
    PrecisionType p = PrecisionType.none)
if (isSomeString!T1 && isSomeString!T2 && isSomeString!T3 && isSomeString!T4)
{
    // writes: left padding, prefix, leading zeros, grouped, fracts, suffix, right padding

    if (p == PrecisionType.integer && f.precision == f.UNSPECIFIED)
        p = PrecisionType.none;

    long prefixWidth;
    long groupedWidth = grouped.length; // TODO: does not take graphemes into account
    long fractsWidth = fracts.length; // TODO: does not take graphemes into account
    long suffixWidth;

    // TODO: remove this workaround which hides https://issues.dlang.org/show_bug.cgi?id=21815
    if (f.width > 0)
    {
        prefixWidth = getWidth(prefix);
        suffixWidth = getWidth(suffix);
    }

    auto doGrouping = f.flSeparator && groupedWidth > 0
                      && f.separators > 0 && f.separators != f.UNSPECIFIED;
    // front = number of symbols left of the leftmost separator
    long front = doGrouping ? (groupedWidth - 1) % f.separators + 1 : 0;
    // sepCount = number of separators to be inserted
    long sepCount = doGrouping ? (groupedWidth - 1) / f.separators : 0;

    long trailingZeros = 0;
    if (p == PrecisionType.fractionalDigits)
        trailingZeros = f.precision - (fractsWidth - 1);
    if (p == PrecisionType.allDigits && f.flHash)
    {
        if (grouped != "0")
            trailingZeros = f.precision - (fractsWidth - 1) - groupedWidth;
        else
        {
            trailingZeros = f.precision - fractsWidth;
            foreach (i;0 .. fracts.length)
                if (fracts[i] != '0' && fracts[i] != '.')
                {
                    trailingZeros = f.precision - (fracts.length - i);
                    break;
                }
        }
    }

    auto nodot = fracts == "." && trailingZeros == 0 && !f.flHash;

    if (nodot) fractsWidth = 0;

    long width = prefixWidth + sepCount + groupedWidth + fractsWidth + trailingZeros + suffixWidth;
    long delta = f.width - width;

    // with integers, precision is considered the minimum number of digits;
    // if digits are missing, we have to recalculate everything
    long pregrouped = 0;
    if (p == PrecisionType.integer && groupedWidth < f.precision)
    {
        pregrouped = f.precision - groupedWidth;
        delta -= pregrouped;
        if (doGrouping)
        {
            front = ((front - 1) + pregrouped) % f.separators + 1;
            delta -= (f.precision - 1) / f.separators - sepCount;
        }
    }

    // left padding
    if ((!f.flZero || p == PrecisionType.integer) && delta > 0)
    {
        if (f.flEqual)
        {
            foreach (i ; 0 .. delta / 2 + ((delta % 2 == 1 && !f.flDash) ? 1 : 0))
                put(w, ' ');
        }
        else if (!f.flDash)
        {
            foreach (i ; 0 .. delta)
                put(w, ' ');
        }
    }

    // prefix
    put(w, prefix);

    // leading grouped zeros
    if (f.flZero && p != PrecisionType.integer && !f.flDash && delta > 0)
    {
        if (doGrouping)
        {
            // front2 and sepCount2 are the same as above for the leading zeros
            long front2 = (delta + front - 1) % (f.separators + 1) + 1;
            long sepCount2 = (delta + front - 1) / (f.separators + 1);
            delta -= sepCount2;

            // according to POSIX: if the first symbol is a separator,
            // an additional zero is put left of it, even if that means, that
            // the total width is one more then specified
            if (front2 > f.separators) { front2 = 1; }

            foreach (i ; 0 .. delta)
            {
                if (front2 == 0)
                {
                    put(w, f.separatorChar);
                    front2 = f.separators;
                }
                front2--;

                put(w, '0');
            }

            // separator between zeros and grouped
            if (front == f.separators)
                put(w, f.separatorChar);
        }
        else
            foreach (i ; 0 .. delta)
                put(w, '0');
    }

    // grouped content
    if (doGrouping)
    {
        // TODO: this does not take graphemes into account
        foreach (i;0 .. pregrouped + grouped.length)
        {
            if (front == 0)
            {
                put(w, f.separatorChar);
                front = f.separators;
            }
            front--;

            put(w, i < pregrouped ? '0' : grouped[cast(size_t) (i - pregrouped)]);
        }
    }
    else
    {
        foreach (i;0 .. pregrouped)
            put(w, '0');
        put(w, grouped);
    }

    // fracts
    if (!nodot)
        put(w, fracts);

    // trailing zeros
    foreach (i ; 0 .. trailingZeros)
        put(w, '0');

    // suffix
    put(w, suffix);

    // right padding
    if (delta > 0)
    {
        if (f.flEqual)
        {
            foreach (i ; 0 .. delta / 2 + ((delta % 2 == 1 && f.flDash) ? 1 : 0))
                put(w, ' ');
        }
        else if (f.flDash)
        {
            foreach (i ; 0 .. delta)
                put(w, ' ');
        }
    }
}

@safe pure unittest
{
    auto w = appender!string();
    auto spec = singleSpec("%s");
    writeAligned(w, "a本Ä", spec);
    assert(w.data == "a本Ä", w.data);
}

@safe pure unittest
{
    auto w = appender!string();
    auto spec = singleSpec("%10s");
    writeAligned(w, "a本Ä", spec);
    assert(w.data == "       a本Ä", "|" ~ w.data ~ "|");
}

@safe pure unittest
{
    auto w = appender!string();
    auto spec = singleSpec("%-10s");
    writeAligned(w, "a本Ä", spec);
    assert(w.data == "a本Ä       ", w.data);
}

@safe pure unittest
{
    auto w = appender!string();
    auto spec = singleSpec("%s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pregroupingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%20s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "      pregroupingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%-20s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pregroupingsuf      ", w.data);

    w = appender!string();
    spec = singleSpec("%020s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pre000000groupingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%-020s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pregroupingsuf      ", w.data);

    w = appender!string();
    spec = singleSpec("%20,1s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "preg,r,o,u,p,i,n,gsuf", w.data);

    w = appender!string();
    spec = singleSpec("%20,2s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "   pregr,ou,pi,ngsuf", w.data);

    w = appender!string();
    spec = singleSpec("%20,3s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "    pregr,oup,ingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%20,10s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "      pregroupingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%020,1s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "preg,r,o,u,p,i,n,gsuf", w.data);

    w = appender!string();
    spec = singleSpec("%020,2s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pre00,gr,ou,pi,ngsuf", w.data);

    w = appender!string();
    spec = singleSpec("%020,3s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pre00,0gr,oup,ingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%020,10s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pre000,00groupingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%021,3s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pre000,0gr,oup,ingsuf", w.data);

    // According to https://github.com/dlang/phobos/pull/7112 this
    // is defined by POSIX standard:
    w = appender!string();
    spec = singleSpec("%022,3s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pre0,000,0gr,oup,ingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%023,3s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pre0,000,0gr,oup,ingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%,3s");
    writeAligned(w, "pre", "grouping", "suf", spec);
    assert(w.data == "pregr,oup,ingsuf", w.data);
}

@safe pure unittest
{
    auto w = appender!string();
    auto spec = singleSpec("%.10s");
    writeAligned(w, "pre", "grouping", "suf", spec, true);
    assert(w.data == "pre00groupingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%.10,3s");
    writeAligned(w, "pre", "grouping", "suf", spec, true);
    assert(w.data == "pre0,0gr,oup,ingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%25.10,3s");
    writeAligned(w, "pre", "grouping", "suf", spec, true);
    assert(w.data == "      pre0,0gr,oup,ingsuf", w.data);

    // precision has precedence over zero flag
    w = appender!string();
    spec = singleSpec("%025.12,3s");
    writeAligned(w, "pre", "grouping", "suf", spec, true);
    assert(w.data == "    pre000,0gr,oup,ingsuf", w.data);

    w = appender!string();
    spec = singleSpec("%025.13,3s");
    writeAligned(w, "pre", "grouping", "suf", spec, true);
    assert(w.data == "  pre0,000,0gr,oup,ingsuf", w.data);
}

private long getWidth(T)(T s)
{
    // check for non-ascii character
    if (s.all!(a => a <= 0x7F)) return s.length;

    //TODO: optimize this
    long width = 0;
    for (size_t i; i < s.length; i += graphemeStride(s, i))
        ++width;
    return width;
}

enum RoundingClass { ZERO, LOWER, FIVE, UPPER }
enum RoundingMode { up, down, toZero, toNearestTiesToEven, toNearestTiesAwayFromZero }

bool round(T)(ref T sequence, size_t left, size_t right, RoundingClass type, bool negative, char max = '9')
in (left >= 0) // should be left > 0, but if you know ahead, that there's no carry, left == 0 is fine
in (left < sequence.length)
in (right >= 0)
in (right <= sequence.length)
in (right >= left)
in (max == '9' || max == 'f' || max == 'F')
{
    auto mode = RoundingMode.toNearestTiesToEven;

    if (!__ctfe)
    {
        // std.math's FloatingPointControl isn't available on all target platforms
        static if (is(FloatingPointControl))
        {
            switch (FloatingPointControl.rounding)
            {
            case FloatingPointControl.roundUp:
                mode = RoundingMode.up;
                break;
            case FloatingPointControl.roundDown:
                mode = RoundingMode.down;
                break;
            case FloatingPointControl.roundToZero:
                mode = RoundingMode.toZero;
                break;
            case FloatingPointControl.roundToNearest:
                mode = RoundingMode.toNearestTiesToEven;
                break;
            default: assert(false, "Unknown floating point rounding mode");
            }
        }
    }

    bool roundUp = false;
    if (mode == RoundingMode.up)
        roundUp = type != RoundingClass.ZERO && !negative;
    else if (mode == RoundingMode.down)
        roundUp = type != RoundingClass.ZERO && negative;
    else if (mode == RoundingMode.toZero)
        roundUp = false;
    else
    {
        roundUp = type == RoundingClass.UPPER;

        if (type == RoundingClass.FIVE)
        {
            // IEEE754 allows for two different ways of implementing roundToNearest:

            if (mode == RoundingMode.toNearestTiesAwayFromZero)
                roundUp = true;
            else
            {
                // Round to nearest, ties to even
                auto last = sequence[right - 1];
                if (last == '.') last = sequence[right - 2];
                roundUp = (last <= '9' && last % 2 != 0) || (last > '9' && last % 2 == 0);
            }
        }
    }

    if (!roundUp) return false;

    foreach_reverse (i;left .. right)
    {
        if (sequence[i] == '.') continue;
        if (sequence[i] == max)
            sequence[i] = '0';
        else
        {
            if (max != '9' && sequence[i] == '9')
                sequence[i] = max == 'f' ? 'a' : 'A';
            else
                sequence[i]++;
            return false;
        }
    }

    sequence[left - 1] = '1';
    return true;
}


/**
Formats a value of any type according to a format specifier and
writes the result to an output range.

More details about how types are formatted, and how the format
specifier influences the outcome, can be found in the definition of a
$(MREF_ALTTEXT format string, std2.format).

Params:
    w = an $(REF_ALTTEXT output range, isOutputRange, std, range, primitives) where
        the formatted value is written to
    val = the value to write
    f = a $(REF_ALTTEXT FormatSpec, FormatSpec, std, format, spec) defining the
        format specifier
    Writer = the type of the output range `w`
    T = the type of value `val`
    Char = the character type used for `f`

Throws:
    A $(LREF FormatException) if formatting did not succeed.

Note:
    In theory this function should be `@nogc`. But with the current
    implementation there are some cases where allocations occur.
    See $(REF_ALTTEXT $(D sformat), sformat, std, format) for more details.

See_Also:
    $(LREF formattedWrite) which formats several values at once.
 */
void formatValue(Writer, T)(auto ref Writer w, auto ref T val, scope const ref FormatSpec f)
{
    enforceFmt(f.width != f.DYNAMIC && f.precision != f.DYNAMIC
               && f.separators != f.DYNAMIC && !f.dynamicSeparatorChar,
               "Dynamic argument not allowed for `formatValue`");

    formatValueImpl(w, val, f);
}

///
@safe pure unittest
{
    auto writer = appender!string();
    auto spec = singleSpec("%08b");
    writer.formatValue(42, spec);
    assert(writer.data == "00101010");

    spec = singleSpec("%2s");
    writer.formatValue('=', spec);
    assert(writer.data == "00101010 =");

    spec = singleSpec("%+14.6e");
    writer.formatValue(42.0, spec);
    assert(writer.data == "00101010 = +4.200000e+01");
}

/**
Converts its arguments according to a format string and writes
the result to an output range.

The second version of `formattedWrite` takes the format string as a
template argument. In this case, it is checked for consistency at
compile-time.

Params:
    w = an $(REF_ALTTEXT output range, isOutputRange, std, range, primitives),
        where the formatted result is written to
    fmt = a $(MREF_ALTTEXT format string, std2.format)
    args = a variadic list of arguments to be formatted
    Writer = the type of the writer `w`
    Char = character type of `fmt`
    Args = a variadic list of types of the arguments

Returns:
    The index of the last argument that was formatted. If no positional
    arguments are used, this is the number of arguments that where formatted.

Throws:
    A $(REF_ALTTEXT FormatException, FormatException, std, format)
    if formatting did not succeed.

Note:
    In theory this function should be `@nogc`. But with the current
    implementation there are some cases where allocations occur.
    See $(REF_ALTTEXT $(D sformat), sformat, std, format) for more details.
 */
uint formattedWrite(Writer, Args...)(auto ref Writer w, const string fmt, Args args)
{
    auto spec = FormatSpec(fmt);

    // Are we already done with formats? Then just dump each parameter in turn
    uint currentArg = 0;
    while (spec.writeUpToNextSpec(w))
    {
        if (currentArg == Args.length && !spec.indexStart)
        {
            // leftover spec?
            enforceFmt(fmt.length == 0,
                text("Orphan format specifier: %", spec.spec));
            break;
        }

        if (spec.width == spec.DYNAMIC)
        {
            auto width = getNthInt!"integer width"(currentArg, args);
            if (width < 0)
            {
                spec.flDash = true;
                width = -width;
            }
            spec.width = width;
            ++currentArg;
        }
        else if (spec.width < 0)
        {
            // means: get width as a positional parameter
            auto index = cast(uint) -spec.width;
            assert(index > 0, "The index must be greater than zero");
            auto width = getNthInt!"integer width"(index - 1, args);
            if (currentArg < index) currentArg = index;
            if (width < 0)
            {
                spec.flDash = true;
                width = -width;
            }
            spec.width = width;
        }

        if (spec.precision == spec.DYNAMIC)
        {
            auto precision = getNthInt!"integer precision"(currentArg, args);
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.UNSPECIFIED;
            ++currentArg;
        }
        else if (spec.precision < 0)
        {
            // means: get precision as a positional parameter
            auto index = cast(uint) -spec.precision;
            assert(index > 0, "The precision must be greater than zero");
            auto precision = getNthInt!"integer precision"(index- 1, args);
            if (currentArg < index) currentArg = index;
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.UNSPECIFIED;
        }

        if (spec.separators == spec.DYNAMIC)
        {
            auto separators = getNthInt!"separator digit width"(currentArg, args);
            spec.separators = separators;
            ++currentArg;
        }

        if (spec.dynamicSeparatorChar)
        {
            auto separatorChar =
                getNth!("separator character", isSomeChar, dchar)(currentArg, args);
            spec.separatorChar = separatorChar;
            spec.dynamicSeparatorChar = false;
            ++currentArg;
        }

        if (currentArg == Args.length && !spec.indexStart)
        {
            // leftover spec?
            enforceFmt(fmt.length == 0,
                text("Orphan format specifier: %", spec.spec));
            break;
        }

        // Format an argument
        // This switch uses a static foreach to generate a jump table.
        // Currently `spec.indexStart` use the special value '0' to signal
        // we should use the current argument. An enhancement would be to
        // always store the index.
        size_t index = currentArg;
        if (spec.indexStart != 0)
            index = spec.indexStart - 1;
        else
            ++currentArg;
    SWITCH: switch (index)
        {
            foreach (i, Tunused; Args)
            {
            case i:
                formatValue(w, args[i], spec);
                if (currentArg < spec.indexEnd)
                    currentArg = spec.indexEnd;
                // A little know feature of format is to format a range
                // of arguments, e.g. `%1:3$` will format the first 3
                // arguments. Since they have to be consecutive we can
                // just use explicit fallthrough to cover that case.
                if (i + 1 < spec.indexEnd)
                {
                    // You cannot goto case if the next case is the default
                    static if (i + 1 < Args.length)
                        goto case;
                    else
                        goto default;
                }
                else
                    break SWITCH;
            }
        default:
            if (spec.indexEnd == spec.indexEnd.max)
                break;
            else if (spec.indexEnd == spec.indexStart)
                throw new FormatException(
                    text("Positional specifier %", spec.indexStart, '$', spec.spec,
                    " index exceeds ", Args.length));
            else
                throw new FormatException(
                    text("Positional specifier %", spec.indexStart, ":", spec.indexEnd, '$', spec.spec,
                    " index exceeds ", Args.length));
        }
    }
    return currentArg;
}

///
@safe pure unittest
{
    auto writer1 = appender!string();
    formattedWrite(writer1, "%s is the ultimate %s.", 42, "answer");
    assert(writer1[] == "42 is the ultimate answer.");

    auto writer2 = appender!string();
    formattedWrite(writer2, "Increase: %7.2f %%", 17.4285);
    assert(writer2[] == "Increase:   17.43 %");
}

/// ditto
uint formattedWrite(alias fmt, Writer, Args...)(auto ref Writer w, Args args)
if (isSomeString!(typeof(fmt)))
{
    //alias e = checkFormatException!(fmt, Args);
    //static assert(!e, e);
    return .formattedWrite(w, fmt, args);
}

/// The format string can be checked at compile-time:
@safe pure unittest
{
    auto writer = appender!string();
    writer.formattedWrite!"%d is the ultimate %s."(42, "answer");
    assert(writer[] == "42 is the ultimate answer.");

    // This line doesn't compile, because 3.14 cannot be formatted with %d:
    // writer.formattedWrite!"%d is the ultimate %s."(3.14, "answer");
}
