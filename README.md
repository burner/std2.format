## std2.format

This is an attempt to improve std.format compile time performance by only
supporting `string`s no `wstring` no `dstring`.

See the below code importing `std2.format`.
Some floating point things and (class|struct).toString fail.

```d
import std2.format;

void main() {
    string s = format("Hello %s %s", "World", 1337);
    assert(s == "Hello World 1337");
}
```
