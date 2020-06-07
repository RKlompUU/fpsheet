# FPSheet
## A Spreadsheet program with Haskell as the scripting language

The prototype was written in C, it can be tried out in the c-prototype branch.
I am currently rewriting the tool in Haskell, which I am doing in this master branch.

![Alt text](imgs/example.png?raw=true "Example")

FPSheet is a spreadsheet program, where the scripting language for computing cell's values from formulas runs Haskell internally.
This arguably provides a more uniform experience than what is provided by the scripting languages of standard spreadsheet programs. Note: this README currently assumes some familiarity from the reader with ghc's ghci tool.

Currently the tool starts a ghci session in the background. When a cell is defined or edited, a unique variable is defined or redefined inside this ghci session. For example, if cell abd124 is edited to: "45", FPSheet sends the following to the ghci session: "let abd124 = 45". Similarly, if cell a4 is edited to: "a5 * 10", FPSheet sends the following to the ghci session: "let a4 = a5 * 10".

Interestingly, since Haskell is lazily evaluated, and since Haskell regards function values as first class citizens, any custom function can be defined inside a cell. Any other cell can then apply this function simply by referring to the cell.

### Installation

Run: `stack install`

### Usage

Run: `stack exec FPSheet-exe`

The program has vim-like modes:
- normal mode for moving around
- edit mode for editing the definition of a cell

While in normal mode, press:
- `:q` to exit.
- `:w <filename>` to write the sheet to disk
- `:r <filename>` to read a sheet from disk
- `:i <filename>` to import an .xlsx file (imports from cell values)
- `:I <filename>` to import an .xlsx file (imports from cell formulas if set, falls back to cell values for cells that do not have a formula definition set)
- `:<column><row>` to jump to `column,row` (e.g. `a10`, `azzz4050`, etc.)
- `<ESCAPE>` to interrupt the ghci backend (useful for when you accidentally defined a cell that cannot finish evaluation)

### TODOs

- Copy pasting cells (properly handling loose and stuck cell references)
- Exporting to excell savefiles
- Undo & redo
- Many many more vital features (aka: TODO: write these out)
