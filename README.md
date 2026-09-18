# libcsv.vapi

Vala bindings for the libcsv library by Robert Gamble.

## Overview

This project provides Vala language bindings for [libcsv](http://libcsv.sourceforge.net/), a C library for parsing and writing CSV files. The bindings allow Vala developers to easily work with CSV data in their applications.

## Features

- Full coverage of libcsv parsing and writing functions
- Type-safe Vala API with proper error handling
- Support for custom parsing options (whitespace handling, quote relaxation, etc.)
- Support for custom writing options (quoting, escaping)
- Callback-based parsing for efficient memory usage
- Line and field number tracking during parsing

## Requirements

- Vala compiler (`valac`)
- GLib 2.0
- libcsv library (optional, for linking)
- Meson build system (for building examples and tests)

## Installation

### Installing the VAPI file

To use the bindings in your Vala project, copy the `libcsv.vapi` file to your project directory or install it system-wide:

```bash
# System-wide installation
sudo cp libcsv.vapi /usr/share/vala/vapi/

# Or to a custom location
cp libcsv.vapi /path/to/your/project/
```

### Using with Meson

If you're using Meson as your build system, include this project as a submodule:

```meson
libcsv_vapi_dir = subdir('libcsv-vapi')
```

Then compile your Vala code with:

```meson
executable('myapp',
  'main.vala',
  vala_args: ['--vapidir', libcsv_vapi_dir],
  dependencies: glib_dep
)
```

### Building Examples and Tests

```bash
# Configure the build
meson setup builddir

# Build everything
ninja -C builddir

# Run tests
ninja -C builddir test

# Install (optional)
sudo ninja -C builddir install
```

## Usage

### Reading a CSV File

```vala
using LibCSV;

public class CSVReader : GLib.Object {
    private string[] current_row;

    public CSVReader () {
        current_row = {};
    }

    private void on_field (void* field, size_t field_size, void* user_data) {
        string field_str = ((string)field).substring (0, (int)field_size);
        current_row += field_str;
    }

    private void on_record (void* user_data) {
        stdout.printf ("Row: %s\n", string.joinv (", ", current_row));
        current_row = {};
    }

    public bool parse_file (string filename) {
        var parser = LibCSV.Parser ();
        var options = ParseOptions.SKIP_INITIAL_WHITESPACE | ParseOptions.SKIP_EMPTY_LINES;

        if (LibCSV.Parser.init (&parser, options) != Error.SUCCESS) {
            stderr.printf ("Failed to initialize parser: %s\n", LibCSV.get_error (&parser));
            return false;
        }

        var file = FileStream.open (filename, "r");
        if (file == null) {
            LibCSV.Parser.free (&parser);
            return false;
        }

        FieldCallback field_cb = on_field;
        RecordCallback record_cb = on_record;

        var result = LibCSV.parse_file (&parser, file, field_cb, record_cb, this);
        LibCSV.finalize (&parser, field_cb, record_cb, this);
        LibCSV.Parser.free (&parser);
        file.close ();

        return result >= 0;
    }
}
```

### Writing a CSV File

```vala
using LibCSV;

var file = FileStream.open ("output.csv", "w");
if (file != null) {
    string[] fields = {"Name", "Age", "City"};
    var options = WriteOptions.QUOTE_NON_NUMERIC;

    LibCSV.write (file, fields, fields.length,
                  options, ',', '"', '\\');
    file.putc ('\n');

    string[] data = {"Alice", "30", "New York"};
    LibCSV.write (file, data, data.length,
                  options, ',', '"', '\\');
    file.putc ('\n');

    file.close ();
}
```

### Parse Options

- `ParseOptions.NONE` - Default behavior
- `ParseOptions.SKIP_INITIAL_WHITESPACE` - Skip whitespace at start of fields
- `ParseOptions.SKIP_TRAILING_WHITESPACE` - Skip whitespace at end of fields
- `ParseOptions.SKIP_EMPTY_LINES` - Skip empty lines
- `ParseOptions.RELAXED_QUOTES` - Allow unquoted fields with quotes
- `ParseOptions.RELAXED_ESCAPES` - Allow unrecognized escape sequences

### Write Options

- `WriteOptions.NONE` - Default behavior
- `WriteOptions.QUOTE_ALL` - Quote all fields
- `WriteOptions.QUOTE_NON_NUMERIC` - Quote non-numeric fields
- `WriteOptions.ESCAPE_ALL` - Escape special characters

## API Reference

### Core Types

#### `LibCSV.Error`
Error codes returned by libcsv functions:
- `SUCCESS` - Operation completed successfully
- `MEMORY_ERROR` - Memory allocation failed
- `PARSE_ERROR` - CSV parsing error
- `WRITE_ERROR` - Write operation failed
- `FILE_ERROR` - File operation error

#### `LibCSV.Parser`
Opaque structure representing a CSV parser.

**Methods:**
- `init (Parser* parser, ParseOptions options)` - Initialize parser
- `free (Parser* parser)` - Free parser resources

#### `LibCSV.ParseOptions` (Flags)
Options controlling parser behavior.

#### `LibCSV.WriteOptions` (Flags)
Options controlling writer behavior.

### Functions

#### Parsing
- `parse (Parser* parser, void* data, size_t data_size, FieldCallback field_cb, RecordCallback? record_cb, void* user_data)` - Parse CSV from buffer
- `parse_file (Parser* parser, FILE* stream, FieldCallback field_cb, RecordCallback? record_cb, void* user_data)` - Parse CSV from file
- `finalize (Parser* parser, FieldCallback field_cb, RecordCallback? record_cb, void* user_data)` - Finalize parsing

#### Writing
- `write (FILE* stream, string[] fields, size_t num_fields, WriteOptions options, char delimiter, char quote, char escape)` - Write CSV row
- `write_field (FILE* stream, void* field, size_t field_size, WriteOptions options, char delimiter, char quote, char escape)` - Write single field

#### Status
- `get_error (Parser* parser)` - Get error message
- `eof (Parser* parser)` - Check if end-of-file reached
- `get_line (Parser* parser)` - Get current line number
- `get_field (Parser* parser)` - Get current field number

### Callbacks

#### `FieldCallback`
```vala
public delegate void FieldCallback (void* field, size_t field_size, void* user_data);
```
Called for each field parsed. The field data may contain null bytes.

#### `RecordCallback`
```vala
public delegate void RecordCallback (void* user_data);
```
Called when a complete record (row) has been parsed.

## Examples

The `examples/` directory contains complete working examples:

- `read_csv.vala` - Read and display a CSV file
- `write_csv.vala` - Create a CSV file with proper quoting

Build and run examples:

```bash
# Build
ninja -C builddir

# Run read example
./builddir/read_csv_example test.csv

# Run write example
./builddir/write_csv_example output.csv
```

## Running Tests

```bash
# Run the test suite
ninja -C builddir test

# Or run directly
./builddir/test_libcsv
```

Tests use TAP (Test Anything Protocol) format for compatibility with CI systems.

## Generating Documentation

If `vapigen` is available, you can generate GIR meta

```bash
vapigen --pkg glib-2.0 --gir LibCSV-1.0.gir libcsv.vapi
```

This creates a GObject Introspection repository that can be used by other languages.

## License

This project is licensed under the LGPL-2.1 license, compatible with libcsv.

## Contributing

Contributions are welcome! Please ensure that:

1. All code follows Vala coding conventions
2. New features include appropriate documentation
3. Changes pass existing tests
4. New functionality includes test coverage

## Links

- [libcsv Homepage](http://libcsv.sourceforge.net/)
- [Vala Documentation](https://wiki.gnome.org/Projects/Vala)
- [Meson Build System](https://mesonbuild.com/)
