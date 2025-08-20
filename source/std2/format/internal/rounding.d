module std2.format.internal.rounding;

import std.math.hardware;

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
