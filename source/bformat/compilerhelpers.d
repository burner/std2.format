module bformat.compilerhelpers;

import std.traits;
import std.range : ElementType;

struct FloatingPointBitpattern(T)
if (isFloatingPoint!T)
{
    static if (T.mant_dig <= 64)
    {
        ulong mantissa;
    }
    else
    {
        ulong mantissa_lsb;
        ulong mantissa_msb;
    }

    int exponent;
    bool negative;
}


FloatingPointBitpattern!T extractBitpattern(T)(const(T) value) @trusted
if (isFloatingPoint!T)
{
    import std.math.traits : floatTraits, RealFormat;

    T val = value;
    FloatingPointBitpattern!T ret;

    alias F = floatTraits!T;
    static if (F.realFormat == RealFormat.ieeeExtended)
    {
        if (__ctfe)
        {
            import core.math : fabs, ldexp;
            import std.math.rounding : floor;
            import std.math.traits : isInfinity, isNaN, signbit;
            import std.math.exponential : log2;

            if (isNaN(val) || isInfinity(val))
                ret.exponent = 32767;
            else if (fabs(val) < real.min_normal)
                ret.exponent = 0;
            else if (fabs(val) >= nextUp(real.max / 2))
                ret.exponent = 32766;
            else
                ret.exponent = cast(int) (val.fabs.log2.floor() + 16383);

            if (ret.exponent == 32767)
            {
                // NaN or infinity
                ret.mantissa = isNaN(val) ? ((1L << 63) - 1) : 0;
            }
            else
            {
                auto delta = 16382 + 64 // bias + bits of ulong
                             - (ret.exponent == 0 ? 1 : ret.exponent); // -1 in case of subnormals
                val = ldexp(val, delta); // val *= 2^^delta

                ulong tmp = cast(ulong) fabs(val);
                if (ret.exponent != 32767 && ret.exponent > 0 && tmp <= ulong.max / 2)
                {
                    // correction, due to log2(val) being rounded up:
                    ret.exponent--;
                    val *= 2;
                    tmp = cast(ulong) fabs(val);
                }

                ret.mantissa = tmp & long.max;
            }

            ret.negative = (signbit(val) == 1);
        }
        else
        {
            ushort* vs = cast(ushort*) &val;
            ret.mantissa = (cast(ulong*) vs)[0] & long.max;
            ret.exponent = vs[4] & short.max;
            ret.negative = (vs[4] >> 15) & 1;
        }
    }
    else
    {
        static if (F.realFormat == RealFormat.ieeeSingle)
        {
            ulong ival = *cast(uint*) &val;
        }
        else static if (F.realFormat == RealFormat.ieeeDouble)
        {
            ulong ival = *cast(ulong*) &val;
        }
        else
        {
            static assert(false, "Floating point type `" ~ F.realFormat ~ "` not supported.");
        }

        import std.math.exponential : log2;
        enum log2_max_exp = cast(int) log2(T(T.max_exp));

        ret.mantissa = ival & ((1L << (T.mant_dig - 1)) - 1);
        ret.exponent = (ival >> (T.mant_dig - 1)) & ((1L << (log2_max_exp + 1)) - 1);
        ret.negative = (ival >> (T.mant_dig + log2_max_exp)) & 1;
    }

    // add leading 1 for normalized values and correct exponent for denormalied values
    if (ret.exponent != 0 && ret.exponent != 2 * T.max_exp - 1)
        ret.mantissa |= 1L << (T.mant_dig - 1);
    else if (ret.exponent == 0)
        ret.exponent = 1;

    ret.exponent -= T.max_exp - 1;

    return ret;
}

void assertCTFEable(alias dg)()
{
    static assert({ cast(void) dg(); return true; }());
    cast(void) dg();
}

real nextUp(real x) @trusted pure nothrow @nogc
{
    import std.math.traits : floatTraits, RealFormat, MANTISSA_MSB, MANTISSA_LSB;

    alias F = floatTraits!(real);
    static if (F.realFormat != RealFormat.ieeeDouble)
    {
        if (__ctfe)
        {
            if (x == -real.infinity)
                return -real.max;
            if (!(x < real.infinity)) // Infinity or NaN.
                return x;
            real delta;
            // Start with a decent estimate of delta.
            if (x <= 0x1.ffffffffffffep+1023 && x >= -double.max)
            {
                const double d = cast(double) x;
                delta = (cast(real) nextUp(d) - cast(real) d) * 0x1p-11L;
                while (x + (delta * 0x1p-100L) > x)
                    delta *= 0x1p-100L;
            }
            else
            {
                delta = 0x1p960L;
                while (!(x + delta > x) && delta < real.max * 0x1p-100L)
                    delta *= 0x1p100L;
            }
            if (x + delta > x)
            {
                while (x + (delta / 2) > x)
                    delta /= 2;
            }
            else
            {
                do { delta += delta; } while (!(x + delta > x));
            }
            if (x < 0 && x + delta == 0)
                return -0.0L;
            return x + delta;
        }
    }
    static if (F.realFormat == RealFormat.ieeeDouble)
    {
        return nextUp(cast(double) x);
    }
    else static if (F.realFormat == RealFormat.ieeeQuadruple)
    {
        ushort e = F.EXPMASK & (cast(ushort *)&x)[F.EXPPOS_SHORT];
        if (e == F.EXPMASK)
        {
            // NaN or Infinity
            if (x == -real.infinity) return -real.max;
            return x; // +Inf and NaN are unchanged.
        }

        auto ps = cast(ulong *)&x;
        if (ps[MANTISSA_MSB] & 0x8000_0000_0000_0000)
        {
            // Negative number
            if (ps[MANTISSA_LSB] == 0 && ps[MANTISSA_MSB] == 0x8000_0000_0000_0000)
            {
                // it was negative zero, change to smallest subnormal
                ps[MANTISSA_LSB] = 1;
                ps[MANTISSA_MSB] = 0;
                return x;
            }
            if (ps[MANTISSA_LSB] == 0) --ps[MANTISSA_MSB];
            --ps[MANTISSA_LSB];
        }
        else
        {
            // Positive number
            ++ps[MANTISSA_LSB];
            if (ps[MANTISSA_LSB] == 0) ++ps[MANTISSA_MSB];
        }
        return x;
    }
    else static if (F.realFormat == RealFormat.ieeeExtended ||
                    F.realFormat == RealFormat.ieeeExtended53)
    {
        // For 80-bit reals, the "implied bit" is a nuisance...
        ushort *pe = cast(ushort *)&x;
        ulong  *ps = cast(ulong  *)&x;
        // EPSILON is 1 for 64-bit, and 2048 for 53-bit precision reals.
        enum ulong EPSILON = 2UL ^^ (64 - real.mant_dig);

        if ((pe[F.EXPPOS_SHORT] & F.EXPMASK) == F.EXPMASK)
        {
            // First, deal with NANs and infinity
            if (x == -real.infinity) return -real.max;
            return x; // +Inf and NaN are unchanged.
        }
        if (pe[F.EXPPOS_SHORT] & 0x8000)
        {
            // Negative number -- need to decrease the significand
            *ps -= EPSILON;
            // Need to mask with 0x7FFF... so subnormals are treated correctly.
            if ((*ps & 0x7FFF_FFFF_FFFF_FFFF) == 0x7FFF_FFFF_FFFF_FFFF)
            {
                if (pe[F.EXPPOS_SHORT] == 0x8000)   // it was negative zero
                {
                    *ps = 1;
                    pe[F.EXPPOS_SHORT] = 0; // smallest subnormal.
                    return x;
                }

                --pe[F.EXPPOS_SHORT];

                if (pe[F.EXPPOS_SHORT] == 0x8000)
                    return x; // it's become a subnormal, implied bit stays low.

                *ps = 0xFFFF_FFFF_FFFF_FFFF; // set the implied bit
                return x;
            }
            return x;
        }
        else
        {
            // Positive number -- need to increase the significand.
            // Works automatically for positive zero.
            *ps += EPSILON;
            if ((*ps & 0x7FFF_FFFF_FFFF_FFFF) == 0)
            {
                // change in exponent
                ++pe[F.EXPPOS_SHORT];
                *ps = 0x8000_0000_0000_0000; // set the high bit
            }
        }
        return x;
    }
    else // static if (F.realFormat == RealFormat.ibmExtended)
    {
        assert(0, "nextUp not implemented");
    }
}

void assertCTFEable(alias dg)()
{
    static assert({ cast(void) dg(); return true; }());
    cast(void) dg();
}

package template WideElementType(T)
{
    alias E = ElementType!T;
    static if (isSomeChar!E)
        alias WideElementType = dchar;
    else
        alias WideElementType = E;
}
