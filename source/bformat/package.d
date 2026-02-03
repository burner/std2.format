/**
This package provides string formatting functionality using
`printf` style format strings.

$(BOOKTABLE ,
$(TR $(TH Submodule) $(TH Function Name) $(TH Description))
$(TR
    $(TD $(I package))
    $(TD $(LREF format))
    $(TD Converts its arguments according to a format string into a string.)
)
$(TR
    $(TD $(I package))
    $(TD $(LREF sformat))
    $(TD Converts its arguments according to a format string into a buffer.)
)
$(TR
    $(TD $(I package))
    $(TD $(LREF FormatException))
    $(TD Signals a problem while formatting.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D write), std, format, write))
    $(TD $(REF_ALTTEXT $(D formattedWrite), formattedWrite, std, format, write))
    $(TD Converts its arguments according to a format string and writes
         the result to an output range.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D write), std, format, write))
    $(TD $(REF_ALTTEXT $(D formatValue), formatValue, std, format, write))
    $(TD Formats a value of any type according to a format specifier and
         writes the result to an output range.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D read), std, format, read))
    $(TD $(REF_ALTTEXT $(D formattedRead), formattedRead, std, format, read))
    $(TD Reads an input range according to a format string and stores the read
         values into its arguments.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D read), std, format, read))
    $(TD $(REF_ALTTEXT $(D unformatValue), unformatValue, std, format, read))
    $(TD Reads a value from the given input range and converts it according to
         a format specifier.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D spec), std, format, spec))
    $(TD $(REF_ALTTEXT $(D FormatSpec), FormatSpec, std, format, spec))
    $(TD A general handler for format strings.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D spec), std, format, spec))
    $(TD $(REF_ALTTEXT $(D singleSpec), singleSpec, std, format, spec))
    $(TD Helper function that returns a `FormatSpec` for a single format specifier.)
))

Limitation: This package does not support localization, but
    adheres to the rounding mode of the floating point unit, if
    available.

$(H3 $(LNAME2 format-strings, Format Strings))

The functions contained in this package use $(I format strings). A
format string describes the layout of another string for reading or
writing purposes. A format string is composed of normal text
interspersed with $(I format specifiers). A format specifier starts
with a percentage sign $(B '%'), optionally followed by one or more
$(I parameters) and ends with a $(I format indicator). A format
indicator may be a simple $(I format character) or a $(I compound
indicator).

$(I Format strings) are composed according to the following grammar:

$(PRE
$(I FormatString):
    $(I FormatStringItem) $(I FormatString)
$(I FormatStringItem):
    $(I Character)
    $(I FormatSpecifier)
$(I FormatSpecifier):
    $(B '%') $(I Parameters) $(I FormatIndicator)

$(I FormatIndicator):
    $(I FormatCharacter)
    $(I CompoundIndicator)
$(I FormatCharacter):
    $(I see remark below)
$(I CompoundIndicator):
    $(B '$(LPAREN)') $(I FormatString) $(B '%$(RPAREN)')
    $(B '$(LPAREN)') $(I FormatString) $(B '%|') $(I Delimiter) $(B '%$(RPAREN)')
$(I Delimiter)
    $(I empty)
    $(I Character) $(I Delimiter)

$(I Parameters):
    $(I Position) $(I Flags) $(I Width) $(I Precision) $(I Separator)
$(I Position):
    $(I empty)
    $(I Integer) $(B '$')
    $(I Integer) $(B ':') $(I Integer) $(B '$')
    $(I Integer) $(B ':') $(B '$')
$(I Flags):
    $(I empty)
    $(I Flag) $(I Flags)
$(I Flag):
    $(B '-')|$(B '+')|$(B '&nbsp;')|$(B '0')|$(B '#')|$(B '=')
$(I Width):
    $(I OptionalPositionalInteger)
$(I Precision):
    $(I empty)
    $(B '.') $(I OptionalPositionalInteger)
$(I Separator):
    $(I empty)
    $(B ',') $(I OptionalInteger)
    $(B ',') $(I OptionalInteger) $(B '?')
$(I OptionalInteger):
    $(I empty)
    $(I Integer)
    $(B '*')
$(I OptionalPositionalInteger):
    $(I OptionalInteger)
    $(B '*') $(I Integer) $(B '$')

$(I Character)
    $(B '%%')
    $(I AnyCharacterExceptPercent)
$(I Integer):
    $(I NonZeroDigit) $(I Digits)
$(I Digits):
    $(I empty)
    $(I Digit) $(I Digits)
$(I NonZeroDigit):
    $(B '1')|$(B '2')|$(B '3')|$(B '4')|$(B '5')|$(B '6')|$(B '7')|$(B '8')|$(B '9')
$(I Digit):
    $(B '0')|$(B '1')|$(B '2')|$(B '3')|$(B '4')|$(B '5')|$(B '6')|$(B '7')|$(B '8')|$(B '9')
)

Note: $(I FormatCharacter) is unspecified. It can be any character
that has no other purpose in this grammar, but it is
recommended to assign (lower- and uppercase) letters.

Note: The $(I Parameters) of a $(I CompoundIndicator) are currently
limited to a $(B '-') flag.

$(H4 $(LNAME2 format-indicator, Format Indicator))

The $(I format indicator) can either be a single character or an
expression surrounded by $(B '%$(LPAREN)') and $(B '%$(RPAREN)'). It specifies the
basic manner in which a value will be formatted and is the minimum
requirement to format a value.

The following characters can be used as $(I format characters):

$(BOOKTABLE ,
   $(TR $(TH FormatCharacter) $(TH Semantics))
   $(TR $(TD $(B 's'))
        $(TD To be formatted in a human readable format.
             Can be used with all types.))
   $(TR $(TD $(B 'c'))
        $(TD To be formatted as a character.))
   $(TR $(TD $(B 'd'))
        $(TD To be formatted as a signed decimal integer.))
   $(TR $(TD $(B 'u'))
        $(TD To be formatted as a decimal image of the underlying bit representation.))
   $(TR $(TD $(B 'b'))
        $(TD To be formatted as a binary image of the underlying bit representation.))
   $(TR $(TD $(B 'o'))
        $(TD To be formatted as an octal image of the underlying bit representation.))
   $(TR $(TD $(B 'x') / $(B 'X'))
        $(TD To be formatted as a hexadecimal image of the underlying bit representation.))
   $(TR $(TD $(B 'e') / $(B 'E'))
        $(TD To be formatted as a real number in decimal scientific notation.))
   $(TR $(TD $(B 'f') / $(B 'F'))
        $(TD To be formatted as a real number in decimal natural notation.))
   $(TR $(TD $(B 'g') / $(B 'G'))
        $(TD To be formatted as a real number in decimal short notation.
             Depending on the number, a scientific notation or
             a natural notation is used.))
   $(TR $(TD $(B 'a') / $(B 'A'))
        $(TD To be formatted as a real number in hexadecimal scientific notation.))
   $(TR $(TD $(B 'r'))
        $(TD To be formatted as raw bytes.
             The output may not be printable and depends on endianness.))
)

The $(I compound indicator) can be used to describe compound types
like arrays or structs in more detail. A compound type is enclosed
within $(B '%$(LPAREN)') and $(B '%$(RPAREN)'). The enclosed sub-format string is
applied to individual elements. The trailing portion of the
sub-format string following the specifier for the element is
interpreted as the delimiter, and is therefore omitted following the
last element. The $(B '%|') specifier may be used to explicitly
indicate the start of the delimiter, so that the preceding portion of
the string will be included following the last element.

The $(I format string) inside of the $(I compound indicator) should
contain exactly one $(I format specifier) (two in case of associative
arrays), which specifies the formatting mode of the elements of the
compound type. This $(I format specifier) can be a $(I compound
indicator) itself.

Note: Inside a $(I compound indicator), strings and characters are
escaped automatically. To avoid this behavior, use `"%-$(LPAREN)"`
instead of `"%$(LPAREN)"`.

$(H4 $(LNAME2 flags, Flags))

There are several flags that affect the outcome of the formatting.

$(BOOKTABLE ,
   $(TR $(TH Flag) $(TH Semantics))
   $(TR $(TD $(B '-'))
        $(TD When the formatted result is shorter than the value
             given by the width parameter, the output is left
             justified. Without the $(B '-') flag, the output remains
             right justified.

             There are two exceptions where the $(B '-') flag has a
             different meaning: (1) with $(B 'r') it denotes to use little
             endian and (2) in case of a compound indicator it means that
             no special handling of the members is applied.))
   $(TR $(TD $(B '='))
        $(TD When the formatted result is shorter than the value
             given by the width parameter, the output is centered.
             If the central position is not possible it is moved slightly
             to the right. In this case, if $(B '-') flag is present in
             addition to the $(B '=') flag, it is moved slightly to the left.))
   $(TR $(TD $(B '+')&nbsp;/&nbsp;$(B '&nbsp;'))
        $(TD Applies to numerical values. By default, positive numbers are not
             formatted to include the `+` sign. With one of these two flags present,
             positive numbers are preceded by a plus sign or a space.
             When both flags are present, a plus sign is used.

             In case of $(B 'r'), a big endian format is used.))
   $(TR $(TD $(B '0'))
        $(TD Is applied to numerical values that are printed right justified.
             If the zero flag is present, the space left to the number is
             filled with zeros instead of spaces.))
   $(TR $(TD $(B '#'))
        $(TD Denotes that an alternative output must be used. This depends on the type
             to be formatted and the $(I format character) used. See the
             sections below for more information.))
)

$(H4 $(LNAME2 width-precision-separator, Width, Precision and Separator))

The $(I width) parameter specifies the minimum width of the result.

The meaning of $(I precision) depends on the format indicator. For
integers it denotes the minimum number of digits printed, for
real numbers it denotes the number of fractional digits and for
strings and compound types it denotes the maximum number of elements
that are included in the output.

A $(I separator) is used for formatting numbers. If it is specified,
the output is divided into chunks of three digits, separated by a $(B
','). The number of digits in a chunk can be given explicitly by
providing a number or a $(B '*') after the $(B ',').

In all three cases the number of digits can be replaced by a $(B
'*'). In this scenario, the next argument is used as the number of
digits. If the argument is a negative number, the $(I precision) and
$(I separator) parameters are considered unspecified. For $(I width),
the absolute value is used and the $(B '-') flag is set.

The $(I separator) can also be followed by a $(B '?'). In that case,
an additional argument is used to specify the symbol that should be
used to separate the chunks.

$(H4 $(LNAME2 position, Position))

By default, the arguments are processed in the provided order. With
the $(I position) parameter it is possible to address arguments
directly. It is also possible to denote a series of arguments with
two numbers separated by $(B ':'), that are all processed in the same
way. The second number can be omitted. In that case the series ends
with the last argument.

It's also possible to use positional arguments for $(I width), $(I
precision) and $(I separator) by adding a number and a $(B
'$(DOLLAR)') after the $(B '*').

$(H4 $(LNAME2 types, Types))

This section describes the result of combining types with format
characters. It is organized in 2 subsections: a list of general
information regarding the formatting of types in the presence of
format characters and a table that contains details for every
available combination of type and format character.

When formatting types, the following rules apply:

$(UL
  $(LI If the format character is upper case, the resulting string will
       be formatted using upper case letters.)
  $(LI The default precision for floating point numbers is 6 digits.)
  $(LI Rounding of floating point numbers adheres to the rounding mode
       of the floating point unit, if available.)
  $(LI The floating point values `NaN` and `Infinity` are formatted as
       `nan` and `inf`, possibly preceded by $(B '+') or $(B '-') sign.)
  $(LI Formatting reals is only supported for 64 bit reals and 80 bit reals.
       All other reals are cast to double before they are formatted. This will
       cause the result to be `inf` for very large numbers.)
  $(LI Characters and strings formatted with the $(B 's') format character
       inside of compound types are surrounded by single and double quotes
       and unprintable characters are escaped. To avoid this, a $(B '-')
       flag can be specified for the compound specifier
       $(LPAREN)e.g. `"%-$(LPAREN)%s%$(RPAREN)"` instead of `"%$(LPAREN)%s%$(RPAREN)"` $(RPAREN).)
  $(LI Structs, unions, classes and interfaces are formatted by calling a
       `toString` method if available.
       See $(MREF_ALTTEXT $(D module bformat.write), std, format, write) for more
       details.)
  $(LI Only part of these combinations can be used for reading. See
       $(MREF_ALTTEXT $(D module bformat.read), std, format, read) for more
       detailed information.)
)

This table contains descriptions for every possible combination of
type and format character:

$(BOOKTABLE ,
   $(TR $(THMINWIDTH Type) $(THMINWIDTH Format Character) $(TH Formatted as...))
   $(TR $(MULTIROW_CELL 1, `null`)
        $(TD $(B 's'))
            $(TD `null`)
   )
   $(TR $(MULTIROW_CELL 3, `bool`)
        $(TD $(B 's'))
            $(TD `false` or `true`)
   )
   $(TR $(TD $(B 'b'), $(B 'd'), $(B 'o'), $(B 'u'), $(B 'x'), $(B 'X'))
            $(TD As the integrals 0 or 1 with the same format character.

            $(I Please note, that $(B 'o') and $(B 'x') with $(B '#') flag
            might produce unexpected results due to special handling of
            the value 0.))
   )
   $(TR $(TD $(B 'r'))
            $(TD `\0` or `\1`)
   )
   $(TR $(MULTIROW_CELL 4, $(I Integral))
        $(TD $(B 's'), $(B 'd'))
            $(TD A signed decimal number. The $(B '#') flag is ignored.)
   )
   $(TR $(TD $(B 'b'), $(B 'o'), $(B 'u'), $(B 'x'), $(B 'X'))
            $(TD An unsigned binary, decimal, octal or hexadecimal number.

                 In case of $(B 'o') and $(B 'x'), the $(B '#') flag
                 denotes that the number must be preceded by `0` and `0x`, with
                 the exception of the value 0, where this does not apply. For
                 $(B 'b') and $(B 'u') the $(B '#') flag has no effect.)
   )
   $(TR $(TD $(B 'e'), $(B 'E'), $(B 'f'), $(B 'F'), $(B 'g'), $(B 'G'), $(B 'a'), $(B 'A'))
            $(TD As a floating point value with the same specifier.

                 Default precision is large enough to add all digits
                 of the integral value.

                 In case of $(B 'a') and $(B 'A'), the integral digit can be
                 any hexadecimal digit.
               )
   )
   $(TR $(TD $(B 'r'))
            $(TD Characters taken directly from the binary representation.)
   )
   $(TR $(MULTIROW_CELL 5, $(I Floating Point))
        $(TD $(B 'e'), $(B 'E'))
            $(TD Scientific notation: Exactly one integral digit followed by a dot
                 and fractional digits, followed by the exponent.
                 The exponent is formatted as $(B 'e') followed by
                 a $(B '+') or $(B '-') sign, followed by at least
                 two digits.

                 When there are no fractional digits and the $(B '#') flag
                 is $(I not) present, the dot is omitted.)
   )
   $(TR $(TD $(B 'f'), $(B 'F'))
            $(TD Natural notation: Integral digits followed by a dot and
                 fractional digits.

                 When there are no fractional digits and the $(B '#') flag
                 is $(I not) present, the dot is omitted.

                 $(I Please note: the difference between $(B 'f') and $(B 'F')
                 is only visible for `NaN` and `Infinity`.))
   )
   $(TR $(TD $(B 's'), $(B 'g'), $(B 'G'))
            $(TD Short notation: If the absolute value is larger than `10 ^^ precision`
                 or smaller than `0.0001`, the scientific notation is used.
                 If not, the natural notation is applied.

                 In both cases $(I precision) denotes the count of all digits, including
                 the integral digits. Trailing zeros (including a trailing dot) are removed.

                 If $(B '#') flag is present, trailing zeros are not removed.)
   )
   $(TR $(TD $(B 'a'), $(B 'A'))
            $(TD Hexadecimal scientific notation: `0x` followed by `1`
                 (or `0` in case of value zero or denormalized number)
                 followed by a dot, fractional digits in hexadecimal
                 notation and an exponent. The exponent is build by `p`,
                 followed by a sign and the exponent in $(I decimal) notation.

                 When there are no fractional digits and the $(B '#') flag
                 is $(I not) present, the dot is omitted.)
   )
   $(TR $(TD $(B 'r'))
            $(TD Characters taken directly from the binary representation.)
   )
   $(TR $(MULTIROW_CELL 3, $(I Character))
        $(TD $(B 's'), $(B 'c'))
            $(TD As the character.

                 Inside of a compound indicator $(B 's') is treated differently: The
                 character is surrounded by single quotes and non printable
                 characters are escaped. This can be avoided by preceding
                 the compound indicator with a $(B '-') flag
                 $(LPAREN)e.g. `"%-$(LPAREN)%s%$(RPAREN)"`$(RPAREN).)
   )
   $(TR $(TD $(B 'b'), $(B 'd'), $(B 'o'), $(B 'u'), $(B 'x'), $(B 'X'))
            $(TD As the integral that represents the character.)
   )
   $(TR $(TD $(B 'r'))
            $(TD Characters taken directly from the binary representation.)
   )
   $(TR $(MULTIROW_CELL 3, $(I String))
        $(TD $(B 's'))
            $(TD The sequence of characters that form the string.

                 Inside of a compound indicator the string is surrounded by double quotes
                 and non printable characters are escaped. This can be avoided
                 by preceding the compound indicator with a $(B '-') flag
                 $(LPAREN)e.g. `"%-$(LPAREN)%s%$(RPAREN)"`$(RPAREN).)
   )
   $(TR $(TD $(B 'r'))
            $(TD The sequence of characters, each formatted with $(B 'r').)
   )
   $(TR $(TD compound)
            $(TD As an array of characters.)
   )
   $(TR $(MULTIROW_CELL 3, $(I Array))
        $(TD $(B 's'))
            $(TD When the elements are characters, the array is formatted as
                 a string. In all other cases the array is surrounded by square brackets
                 and the elements are separated by a comma and a space. If the elements
                 are strings, they are surrounded by double quotes and non
                 printable characters are escaped.)
   )
   $(TR $(TD $(B 'r'))
            $(TD The sequence of the elements, each formatted with $(B 'r').)
   )
   $(TR $(TD compound)
            $(TD The sequence of the elements, each formatted according to the specifications
                 given inside of the compound specifier.)
   )
   $(TR $(MULTIROW_CELL 2, $(I Associative Array))
        $(TD $(B 's'))
            $(TD As a sequence of the elements in unpredictable order. The output is
                 surrounded by square brackets. The elements are separated by a
                 comma and a space. The elements are formatted as `key:value`.)
   )
   $(TR $(TD compound)
            $(TD As a sequence of the elements in unpredictable order. Each element
                 is formatted according to the specifications given inside of the
                 compound specifier. The first specifier is used for formatting
                 the key and the second specifier is used for formatting the value.
                 The order can be changed with positional arguments. For example
                 `"%(%2$s (%1$s), %)"` will write the value, followed by the key in
                 parenthesis.)
   )
   $(TR $(MULTIROW_CELL 2, $(I Enum))
        $(TD $(B 's'))
            $(TD The name of the value. If the name is not available, the base value
                 is used, preceeded by a cast.)
   )
   $(TR $(TD All, but $(B 's'))
            $(TD Enums can be formatted with all format characters that can be used
                 with the base value. In that case they are formatted like the base value.)
   )
   $(TR $(MULTIROW_CELL 3, $(I Input Range))
        $(TD $(B 's'))
            $(TD When the elements of the range are characters, they are written like a string.
                 In all other cases, the elements are enclosed by square brackets and separated
                 by a comma and a space.)
   )
   $(TR $(TD $(B 'r'))
            $(TD The sequence of the elements, each formatted with $(B 'r').)
   )
   $(TR $(TD compound)
            $(TD The sequence of the elements, each formatted according to the specifications
                 given inside of the compound specifier.)
   )
   $(TR $(MULTIROW_CELL 1, $(I Struct))
        $(TD $(B 's'))
            $(TD When the struct has neither an applicable `toString`
                 nor is an input range, it is formatted as follows:
                 `StructType(field1, field2, ...)`.)
   )
   $(TR $(MULTIROW_CELL 1, $(I Class))
        $(TD $(B 's'))
            $(TD When the class has neither an applicable `toString`
                 nor is an input range, it is formatted as the
                 fully qualified name of the class.)
   )
   $(TR $(MULTIROW_CELL 1, $(I Union))
        $(TD $(B 's'))
            $(TD When the union has neither an applicable `toString`
                 nor is an input range, it is formatted as its base name.)
   )
   $(TR $(MULTIROW_CELL 2, $(I Pointer))
        $(TD $(B 's'))
            $(TD A null pointer is formatted as 'null'. All other pointers are
                 formatted as hexadecimal numbers with the format character $(B 'X').)
   )
   $(TR $(TD $(B 'x'), $(B 'X'))
            $(TD Formatted as a hexadecimal number.)
   )
   $(TR $(MULTIROW_CELL 3, $(I SIMD vector))
        $(TD $(B 's'))
            $(TD The array is surrounded by square brackets
                 and the elements are separated by a comma and a space.)
   )
   $(TR $(TD $(B 'r'))
            $(TD The sequence of the elements, each formatted with $(B 'r').)
   )
   $(TR $(TD compound)
            $(TD The sequence of the elements, each formatted according to the specifications
                 given inside of the compound specifier.)
   )
   $(TR $(MULTIROW_CELL 1, $(I Delegate))
        $(TD $(B 's'), $(B 'r'), compound)
            $(TD As the `.stringof` of this delegate treated as a string.

                 $(I Please note: The implementation is currently buggy
                 and its use is discouraged.))
   )
)

Copyright: Copyright The D Language Foundation 2000-2021.

Macros:
SUBREF = $(REF_ALTTEXT $2, $2, std, format, $1)$(NBSP)
MULTIROW_CELL = <td rowspan="$1">$+</td>
THMINWIDTH = <th scope="col" width="20%">$0</th>

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
Andrei Alexandrescu), and Kenji Hara

Source: $(PHOBOSSRC bformat/package.d)
 */
module bformat;

public import bformat.write;
public import bformat.formatfunction;
public import bformat.formatfunction2;
public import bformat.spec;
public import bformat.stdout;
