# libcsv.vapi

Vala bindings for [Robert Gamble's libcsv](https://github.com/rgamble/libcsv),
a small C library for parsing and writing CSV data.

## Requirements

- Vala (`valac`)
- libcsv (`csv.h` and `-lcsv`; Debian/Ubuntu: `libcsv-dev`)

## Install the bindings

```bash
sudo install -m644 src/libcsv.vapi /usr/share/vala/vapi/
```

## Use in your project

```meson
cc = meson.get_compiler('c')
libcsv_dep = cc.find_library('csv', required: true)

executable('app', 'main.vala',
  dependencies: [dependency('glib-2.0'), libcsv_dep],
  vala_args: ['--vapidir', meson.current_source_dir() / 'path/to/src', '--pkg', 'libcsv'],
)
```

Compile with `--fatal-warnings` (Meson does this for this repo).

## Parse

Initialize a `Csv.Parser`, feed it chunks with `parse`, then `fini`. Field and
record callbacks are C function pointers (`has_target = false`): use static
methods and pass `this` as userdata.

```vala
using Csv;

class RowPrinter {
    string[] row;

    static void on_field (void* field, size_t len, void* data) {
        unowned var self = (RowPrinter) data;
        if (field == null) {
            self.row += "";
            return;
        }
        var buf = new uint8[len + 1];
        if (len > 0) {
            Memory.copy (buf, field, len);
        }
        buf[len] = 0;
        self.row += (string) buf;
    }

    static void on_record (int c, void* data) {
        unowned var self = (RowPrinter) data;
        stdout.printf ("%s\n", string.joinv (",", self.row));
        self.row = {};
    }

    public void parse_buffer (string csv) {
        var parser = Parser (Options.APPEND_NULL);
        size_t n = csv.length;
        if (parser.parse (csv, n, on_field, on_record, this) != n) {
            stderr.printf ("%s\n", Csv.strerror ((int) parser.error ()));
            return;
        }
        parser.fini (on_field, on_record, this);
    }
}
```

`parse` returns the number of bytes consumed. If that is less than `len`, call
`parser.error()` / `Csv.strerror()`.

`on_record`'s `int c` is the byte that ended the row (`Csv.CR`, `Csv.LF`, or a
custom terminator), or `-1` when `fini` completes a row without a newline.

### Parser options (`Csv.Options`)

| Flag | Meaning |
| --- | --- |
| `STRICT` | Reject malformed CSV |
| `REPALL_NL` | Report unquoted CR/LF inside fields |
| `STRICT_FINI` | `fini` fails if the last field is an unclosed quote |
| `APPEND_NULL` | NUL-terminate field buffers (not counted in `len`) |
| `EMPTY_IS_NULL` | Empty *unquoted* fields are passed as `field == null` |

Use `set_delim` / `set_quote` for TSV or a custom quote character.
`set_space_func` / `set_term_func` override what counts as whitespace and as a
row terminator.

## Write

`csv_write` / `csv_fwrite` encode **one field**. They always wrap the field in
quotes and double internal quotes. You write commas and newlines yourself.

```vala
using Csv;

void write_row (FileStream fp, string[] fields) {
    for (int i = 0; i < fields.length; i++) {
        if (i > 0) {
            fp.putc (',');
        }
        if (Csv.fwrite (fp, fields[i], fields[i].length) != 0) {
            error ("write failed");
        }
    }
    fp.putc ('\n');
}
```

`csv_write (null, 0, src, src_size)` returns the quoted size so you can
allocate a buffer. `write2` / `fwrite2` take a custom quote byte.

## API map

| Vala | C |
| --- | --- |
| `Csv.Parser (options)` / `parser.init (options)` | `csv_init` |
| `parser.parse (s, len, cb1, cb2, data)` | `csv_parse` |
| `parser.fini (cb1, cb2, data)` | `csv_fini` |
| `parser.free ()` | `csv_free` (also the struct destroy function) |
| `parser.error ()` | `csv_error` |
| `Csv.strerror (err)` | `csv_strerror` |
| `Csv.write` / `Csv.fwrite` | `csv_write` / `csv_fwrite` |
| `Csv.write2` / `Csv.fwrite2` | `csv_write2` / `csv_fwrite2` |
| `get_opts` / `set_opts` | `csv_get_opts` / `csv_set_opts` |
| `get_delim` / `set_delim` | `csv_get_delim` / `csv_set_delim` |
| `get_quote` / `set_quote` | `csv_get_quote` / `csv_set_quote` |
| `set_space_func` / `set_term_func` | `csv_set_space_func` / `csv_set_term_func` |
| `set_realloc_func` / `set_free_func` | `csv_set_realloc_func` / `csv_set_free_func` |
| `set_blk_size` / `get_buffer_size` | `csv_set_blk_size` / `csv_get_buffer_size` |

Error codes (`Csv.Status`): `SUCCESS`, `EPARSE`, `ENOMEM`, `ETOOBIG`, `EINVALID`.

Character constants: `TAB`, `SPACE`, `CR`, `LF`, `COMMA`, `QUOTE`.

## Examples

```bash
vala --fatal-warnings --vapidir src --pkg libcsv -X -lcsv examples/simple.vala
```

## Tests

```bash
vala --fatal-warnings --vapidir src --pkg libcsv -X -lcsv tests/test_libcsv.vala
```

Tests speak TAP.

## License

LGPL-2.1, same family as libcsv.

## Links

- [libcsv](https://github.com/rgamble/libcsv)
- [Vala](https://vala.dev/)
