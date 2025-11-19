# vim-SearchAndReplace

Global search and replace in Vim has always been a bit of a hassle. While powerful, the native methods often feel clunky or require too many keystrokes for simple, interactive renaming across a project.

I decided to fix this problem with a simple and quick solution: **vim-SearchAndReplace**.

## Installation

Requires Vim 9.0+.

**Pathogen:**
```bash
git clone https://github.com/arp/vim-SearchAndReplace.git ~/.vim/bundle/vim-SearchAndReplace
```

**vim-plug:**
```vim
Plug 'arp/vim-SearchAndReplace'
```

**Native Vim Packages:**
```bash
git clone https://github.com/arp/vim-SearchAndReplace.git ~/.vim/pack/plugins/start/vim-SearchAndReplace
```

## Usage

The plugin exposes a single, intuitive command `:SR`.

```vim
:SR {search_term} {replace_term} [file_pattern]
```

### Examples

**Basic usage (recursive search in current directory):**
```vim
:SR foo bar
```

**Specify a file pattern:**
```vim
:SR foo bar src/**/*.js
```

**Multiple file patterns:**
```vim
:SR foo bar src/*.js test/*.js
```

**Handling spaces (use quotes):**
```vim
:SR "foo bar" "baz qux"
```

**Handling single quotes (use double quotes or double single quotes):**
```vim
:SR "'foo' + 'bar'" '''bar'' + ''foo'''
```

**Handling double quotes (use single quotes or backslash):**
```vim
:SR '"foo" + "bar"' "\"foos\" + \"bars\""
```

### Interactive Controls

When a match is found, you are prompted with the following options:

- **y**: Replace this match
- **n**: Skip this match
- **a**: Replace all remaining matches automatically
- **q**: Quit (preserves changes made so far)
- **u**: Undo the last replacement
- **c**: Cancel (undo **all** changes made in this session and quit)

## Contributing

Pull requests and issues are welcome! If you find a bug or have a feature request, please open an issue.

## License

MIT

Copyright (c) 2025 Artur Pyrogovskyi (@arp)
