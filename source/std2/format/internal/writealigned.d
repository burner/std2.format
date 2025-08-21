module std2.format.internal.writealigned;

import std2.format.spec;
import std2.format.internal.getwidth;

import std.range.primitives : put;
import std.traits : isSomeString;
import std.array : appender;

void writeAligned(Writer)(auto ref Writer w, string s, scope const ref FormatSpec f)
{
    FormatSpec fs = f;
    fs.flZero = false;
    writeAligned(w, "", "", s, fs);
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

enum PrecisionType
{
    none,
    integer,
    fractionalDigits,
    allDigits,
}

void writeAligned(Writer)(auto ref Writer w,
    string prefix, string grouped, string suffix, scope const ref FormatSpec f,
    bool integer_precision = false)
{
    writeAligned(w, prefix, grouped, "", suffix, f,
                 integer_precision ? PrecisionType.integer : PrecisionType.none);
}

void writeAligned(Writer)(auto ref Writer w,
    string prefix, string grouped, string fracts, string suffix, scope const ref FormatSpec f,
    PrecisionType p = PrecisionType.none)
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
