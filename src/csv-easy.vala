/*
 * csv-easy.vala — idiomatic, pointer-free Vala API on top of libcsv.vapi
 *
 * Compile together with the VAPI:
 *   valac --pkg gio-2.0 libcsv.vapi csv-easy.vala your-app.vala -X -lcsv
 */

namespace Csv {

    /** A parsed row. Fields are null only when {@link Options.EMPTY_IS_NULL} is set. */
    public delegate void RowFunc (GLib.GenericArray<string?> fields);

    public errordomain ParseError {
        /** Malformed input in strict mode (or an unclosed quote with STRICT_FINI). */
        SYNTAX,
        NO_MEMORY,
        TOO_BIG,
        INVALID,
        /** A field was not valid UTF-8 (only raised when validate_utf8 is true). */
        ENCODING
    }

    private ParseError make_error (Status status, string? detail = null) {
        string msg = detail ?? strerror (status);
        switch (status) {
        case Status.EPARSE:  return new ParseError.SYNTAX (msg);
        case Status.ENOMEM:  return new ParseError.NO_MEMORY (msg);
        case Status.ETOOBIG: return new ParseError.TOO_BIG (msg);
        default:             return new ParseError.INVALID (msg);
        }
    }

    /**
     * Incremental CSV reader. Feed it chunks of bytes; complete rows are
     * delivered through the {@link row_read} signal.
     */
    public class Reader : GLib.Object {
        private Parser parser;
        private GLib.GenericArray<string?> current = new GLib.GenericArray<string?> ();
        private ParseError? pending = null;

        /** Emitted once per completed record. */
        public signal void row_read (GLib.GenericArray<string?> fields);

        /** Reject fields that are not valid UTF-8 (Vala strings assume UTF-8). */
        public bool validate_utf8 { get; set; default = true; }

        public Options options {
            get { return parser.get_opts (); }
            set { parser.set_opts (value); }
        }

        public uchar delimiter {
            get { return parser.get_delim (); }
            set { parser.set_delim (value); }
        }

        public uchar quote {
            get { return parser.get_quote (); }
            set { parser.set_quote (value); }
        }

        public Reader (Options options = Options.NONE, uchar delimiter = COMMA, uchar quote = QUOTE) {
            parser = Parser (options);
            parser.set_delim (delimiter);
            parser.set_quote (quote);
        }

        /** Push a chunk of data. Chunks may split fields, rows, even UTF-8 sequences. */
        public void feed (uint8[] data) throws ParseError {
            size_t used = parser.parse (data, on_field, on_record, this);
            check ((size_t) data.length, used);
        }

        public void feed_string (string text) throws ParseError {
            feed (text.data);
        }

        /** Flush the final row when the input has no trailing newline. */
        public void finish () throws ParseError {
            int rc = parser.fini (on_field, on_record, this);
            check (0, 0, rc != 0);
        }

        /** Read everything from a stream, in chunks. */
        public void read_stream (GLib.InputStream input, GLib.Cancellable? cancellable = null) throws GLib.Error {
            var buf = new uint8[64 * 1024];
            ssize_t n;
            while ((n = input.read (buf, cancellable)) > 0) {
                feed (buf[0:n]);
            }
            finish ();
        }

        private void check (size_t wanted, size_t used, bool fini_failed = false) throws ParseError {
            if (pending != null) {
                var e = (owned) pending;
                pending = null;
                throw e;
            }
            if (used < wanted || fini_failed) {
                throw make_error (parser.error ());
            }
        }

        // libcsv callbacks: the only place a pointer shows up, and it is private.
        private static void on_field (void* field, size_t len, void* data) {
            unowned Reader self = (Reader) data;
            if (self.pending != null) {
                return;
            }
            if (field == null) {
                self.current.add (null);
                return;
            }
            var bytes = new uint8[len + 1];
            GLib.Memory.copy (bytes, field, len);
            string s = (string) (owned) bytes;
            if (self.validate_utf8 && !s.validate ()) {
                self.pending = new ParseError.ENCODING ("Field %u is not valid UTF-8", self.current.length);
                return;
            }
            self.current.add ((owned) s);
        }

        private static void on_record (int c, void* data) {
            unowned Reader self = (Reader) data;
            var row = self.current;
            self.current = new GLib.GenericArray<string?> ();
            if (self.pending == null) {
                self.row_read (row);
            }
        }
    }

    /** Parse a whole string into rows. */
    public GLib.GenericArray<GLib.GenericArray<string?>> parse_string (string text, Options options = Options.NONE, uchar delimiter = COMMA) throws ParseError {
        var rows = new GLib.GenericArray<GLib.GenericArray<string?>> ();
        var reader = new Reader (options, delimiter);
        reader.row_read.connect ((r) => rows.add (r));
        reader.feed_string (text);
        reader.finish ();
        return rows;
    }

    /** Parse a file into rows. Throws GLib.IOError / GLib.FileError / ParseError. */
    public GLib.GenericArray<GLib.GenericArray<string?>> parse_file (string path, Options options = Options.NONE, uchar delimiter = COMMA) throws GLib.Error {
        var rows = new GLib.GenericArray<GLib.GenericArray<string?>> ();
        var reader = new Reader (options, delimiter);
        reader.row_read.connect ((r) => rows.add (r));
        reader.read_stream (GLib.File.new_for_path (path).read ());
        return rows;
    }

    /** Parse a string and call ''func'' for each row, without holding them all in memory. */
    public void parse_each (string text, RowFunc func, Options options = Options.NONE, uchar delimiter = COMMA) throws ParseError {
        var reader = new Reader (options, delimiter);
        reader.row_read.connect ((r) => func (r));
        reader.feed_string (text);
        reader.finish ();
    }

    /** Quote one field (internal quotes doubled). Null and empty fields yield an empty string. */
    public string quote_field (string? field, uchar quote = QUOTE) {
        uint8[] src = field != null ? field.data : new uint8[0];
        size_t needed = write2 (null, src, quote);
        var buf = new uint8[needed + 1];
        write2 (buf[0:needed], src, quote);
        buf[needed] = 0;
        return (string) buf;
    }

    /** Format one row as a CSV line (no trailing newline). */
    public string format_row (string?[] fields, uchar delimiter = COMMA, uchar quote = QUOTE) {
        var sb = new GLib.StringBuilder ();
        for (int i = 0; i < fields.length; i++) {
            if (i > 0) {
                sb.append_c ((char) delimiter);
            }
            sb.append (quote_field (fields[i], quote));
        }
        return sb.str;
    }

    /** Writes rows to any GLib.OutputStream. */
    public class Writer : GLib.Object {
        private GLib.OutputStream output;

        public uchar delimiter { get; set; default = COMMA; }
        public uchar quote { get; set; default = QUOTE; }
        public string newline { get; set; default = "\r\n"; }

        public Writer (GLib.OutputStream output) {
            this.output = output;
        }

        public void write_row (string?[] fields, GLib.Cancellable? cancellable = null) throws GLib.Error {
            string line = format_row (fields, delimiter, quote) + newline;
            output.write_all (line.data, null, cancellable);
        }
    }
}
