## bformat

This is an attempt to improve std.format compile time performance by only
supporting `string`s no `wstring` no `dstring`.

See the below code importing `bformat`.

```d
import bformat;

void main() {
    string s = format("Hello %s %s", "World", 1337);
    assert(s == "Hello World 1337");
}

```

Note the import statement at the top of the example. 
This is all that should be required to use the faster compiling bformat.

### Limitation

#### alias this toString()
Currently, alias this and toString implementations conflict. PR's welcome

#### Some floating point tests fail
I don't know why. PR's welcome
