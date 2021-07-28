# Parsing

What approach should be taken?

Keys? In tokenizer or inside parser? Should we even split those phases?

## Using ABNF

1. Program is just a bunch of expression
2. Parse is like this: list of expressions
3. Get stream of headers, keys
4. Building final data structure
    * Push everything intDo nicer structure, with support of some stack?
    * Build everyting in the same time, as parsing. Keeping stack of nodes
## Tasks

+ [ ] Fix parser to not reach for lexer directly, but to be able to lazily reach for next tokens or even combine both phases
+ [ ] Impl data and time
+ [ ] Add proper test cases 

## Project structure

- `src` - main source directory
    - `ini.zig` - main datastructure and code parsing main API
    - `lexer.zig` - low level, byte-by-byte lexer
    - `parser.zig` - tokenization and parsing into proper `Config` struct

