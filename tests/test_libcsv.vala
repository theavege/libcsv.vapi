/**
 * TAP tests for the libcsv Vala bindings against Robert Gamble's C library.
 */

using Csv;

class Counts {
    public int fields;
    public int records;
    public string[] cells;
    public int last_record_c;

    public Counts () {
        this.fields = 0;
        this.records = 0;
        this.cells = {};
        this.last_record_c = 0;
    }
}

class NullFields {
    public int nulls;
    public int nonempty;

    public NullFields () {
        this.nulls = 0;
        this.nonempty = 0;
    }
}

int tests_run = 0;
int tests_passed = 0;

void expect (string name, bool ok) {
    tests_run++;
    if (ok) {
        tests_passed++;
        stdout.printf ("ok %d - %s\n", tests_run, name);
    } else {
        stdout.printf ("not ok %d - %s\n", tests_run, name);
    }
}

static string field_text (void* field, size_t len) {
    if (field == null)
        return "";
    var buf = new uint8[len + 1];
    if (len > 0)
        Memory.copy (buf, field, len);
    buf[len] = 0;
    return (string) buf;
}

static void count_field (void* field, size_t len, void* data) {
    unowned Counts c = (Counts) data;
    c.fields++;
    c.cells += field_text (field, len);
}

static void count_record (int ch, void* data) {
    unowned Counts c = (Counts) data;
    c.records++;
    c.last_record_c = ch;
}

static void count_null_field (void* field, size_t len, void* data) {
    unowned NullFields n = (NullFields) data;
    if (field == null) {
        n.nulls++;
    } else {
        n.nonempty++;
    }
    if (len == 0 && field != null) {
        /* quoted empty field: pointer is non-null, length is 0 */
    }
}

static void noop_record (int ch, void* data) {
}

bool parse_counts (ref Parser parser, string csv, Counts counts) {
    size_t n = csv.length;
    if (parser.parse (csv, n, count_field, count_record, counts) != n)
        return false;
    return parser.fini (count_field, count_record, counts) == Status.SUCCESS;
}

bool parse_nulls (ref Parser parser, string csv, NullFields nfields) {
    size_t n = csv.length;
    if (parser.parse (csv, n, count_null_field, noop_record, nfields) != n)
        return false;
    return parser.fini (count_null_field, noop_record, nfields) == Status.SUCCESS;
}

void test_version_constants () {
    expect ("CSV_MAJOR is 3", MAJOR == 3);
    expect ("CSV_MINOR is non-negative", MINOR >= 0);
    expect ("CSV_RELEASE is non-negative", RELEASE >= 0);
}

void test_character_constants () {
    expect ("TAB", TAB == 0x09);
    expect ("SPACE", SPACE == 0x20);
    expect ("CR", CR == 0x0d);
    expect ("LF", LF == 0x0a);
    expect ("COMMA", COMMA == 0x2c);
    expect ("QUOTE", QUOTE == 0x22);
}

void test_strerror () {
    expect ("strerror SUCCESS", Csv.strerror (Status.SUCCESS).length > 0);
    expect ("strerror EPARSE", Csv.strerror (Status.EPARSE).length > 0);
    expect ("strerror ENOMEM", Csv.strerror (Status.ENOMEM).length > 0);
}

void test_parser_init () {
    var parser = Parser (Options.NONE);
    expect ("init default delim is comma", parser.get_delim () == COMMA);
    expect ("init default quote is quote", parser.get_quote () == QUOTE);
    expect ("init error is SUCCESS", parser.error () == Status.SUCCESS);
    expect ("init opts NONE", parser.get_opts () == 0);
}

void test_parser_init_method () {
    Parser parser = {};
    expect ("csv_init returns 0", parser.init (Options.APPEND_NULL | Options.STRICT) == 0);
    expect ("opts include APPEND_NULL", (parser.get_opts () & Options.APPEND_NULL) != 0);
    expect ("opts include STRICT", (parser.get_opts () & Options.STRICT) != 0);
    parser.free ();
}

void test_parse_simple () {
    var parser = Parser (Options.APPEND_NULL);
    var counts = new Counts ();
    expect ("simple parse succeeds",
            parse_counts (ref parser, "name,age\nAlice,30\n", counts));
    expect ("simple field count", counts.fields == 4);
    expect ("simple record count", counts.records == 2);
    expect ("simple first cell", counts.cells[0] == "name");
    expect ("simple last cell", counts.cells[3] == "30");
}

void test_quoted_comma_and_quote () {
    var parser = Parser (Options.APPEND_NULL);
    var counts = new Counts ();
    string csv = "\"Contains, comma\",\"Has \"\"quotes\"\"\"\n";
    expect ("quoted parse succeeds",
            parse_counts (ref parser, csv, counts));
    expect ("quoted field count", counts.fields == 2);
    expect ("quoted comma preserved", counts.cells[0] == "Contains, comma");
    expect ("doubled quotes become one", counts.cells[1] == "Has \"quotes\"");
}

void test_custom_delim () {
    var parser = Parser (Options.APPEND_NULL);
    parser.set_delim ('|');
    expect ("custom delim stored", parser.get_delim () == '|');
    var counts = new Counts ();
    expect ("pipe parse succeeds",
            parse_counts (ref parser, "a|b|c\n", counts));
    expect ("pipe field count", counts.fields == 3);
    expect ("pipe middle cell", counts.cells[1] == "b");
}

void test_custom_quote () {
    var parser = Parser (Options.APPEND_NULL);
    parser.set_quote ('\'');
    expect ("custom quote stored", parser.get_quote () == '\'');
    var counts = new Counts ();
    expect ("custom quote parse succeeds",
            parse_counts (ref parser, "'a,b',c\n", counts));
    expect ("custom quote fields", counts.fields == 2);
    expect ("custom quote contents", counts.cells[0] == "a,b");
}

void test_empty_is_null () {
    var parser = Parser (Options.EMPTY_IS_NULL | Options.APPEND_NULL);
    var n = new NullFields ();
    expect ("empty-is-null parse succeeds",
            parse_nulls (ref parser, "a,,b\n", n));
    expect ("empty unquoted field is null", n.nulls == 1);
    expect ("non-empty fields stay non-null", n.nonempty == 2);
}

void test_strict_parse_error () {
    var parser = Parser (Options.STRICT | Options.STRICT_FINI);
    string csv = "\"unterminated";
    size_t n = csv.length;
    size_t consumed = parser.parse (csv, n, null, null, null);
    int fini = parser.fini (null, null, null);
    expect ("strict unclosed quote fails", consumed == n && fini != 0);
    expect ("error is EPARSE", parser.error () == Status.EPARSE);
    expect ("EPARSE strerror is useful", Csv.strerror ((int) parser.error ()).length > 0);
}

void test_write_quotes_field () {
    string src = "a,b";
    size_t need = Csv.write (null, 0, src, src.length);
    expect ("write reports size for a,b", need == 5); /* "a,b" */
    var dest = new uint8[need];
    size_t wrote = Csv.write (dest, dest.length, src, src.length);
    expect ("write fills dest", wrote == need);
    expect ("write leading quote", dest[0] == '"');
    expect ("write trailing quote", dest[need - 1] == '"');
}

void test_write2_custom_quote () {
    string src = "x";
    var dest = new uint8[8];
    size_t wrote = Csv.write2 (dest, dest.length, src, src.length, '\'');
    expect ("write2 size", wrote == 3);
    expect ("write2 uses custom quote", dest[0] == '\'' && dest[2] == '\'');
}

void test_fwrite_roundtrip () {
    string path = Path.build_filename (Environment.get_tmp_dir (), "libcsv-vapi-roundtrip.csv");
    var out_file = FileStream.open (path, "wb");
    expect ("fopen write", out_file != null);
    if (out_file == null) {
        return;
    }
    string[] row = {"Alice", "Contains, comma", "Has \"quotes\""};
    for (int i = 0; i < row.length; i++) {
        if (i > 0) {
            out_file.putc (',');
        }
        expect ("fwrite field", Csv.fwrite (out_file, row[i], row[i].length) == 0);
    }
    out_file.putc ('\n');
    out_file = null;

    var parser = Parser (Options.APPEND_NULL);
    var counts = new Counts ();
    var in_file = FileStream.open (path, "rb");
    expect ("fopen read", in_file != null);
    if (in_file != null) {
        uint8 buf[256];
        size_t n;
        bool ok = true;
        while ((n = in_file.read (buf)) > 0) {
            if (parser.parse (buf, n, count_field, count_record, counts) != n) {
                ok = false;
                break;
            }
        }
        ok = ok && parser.fini (count_field, count_record, counts) == Status.SUCCESS;
        expect ("fwrite roundtrip parse", ok);
        expect ("roundtrip field count", counts.fields == 3);
        expect ("roundtrip comma field", counts.cells[1] == "Contains, comma");
        expect ("roundtrip quote field", counts.cells[2] == "Has \"quotes\"");
    }

    FileUtils.unlink (path);
}

void test_set_opts_and_blk () {
    var parser = Parser ();
    expect ("set_opts returns 0", parser.set_opts (Options.APPEND_NULL) == 0);
    expect ("get_opts sees APPEND_NULL", (parser.get_opts () & Options.APPEND_NULL) != 0);
    parser.set_blk_size (256);
    expect ("buffer starts empty", parser.get_buffer_size () == 0);
}

void test_space_and_term_func () {
    var parser = Parser (Options.APPEND_NULL);
    parser.set_space_func ((c) => {
        return (int) (c == ' ' || c == '\t');
    });
    parser.set_term_func ((c) => {
        return (int) (c == '\n');
    });
    var counts = new Counts ();
    expect ("custom space/term parse",
            parse_counts (ref parser, " a , b \n", counts));
    expect ("leading space skipped in unquoted field", counts.cells[0] == "a");
}

void test_fini_record_c () {
    var parser = Parser (Options.APPEND_NULL);
    var counts = new Counts ();
    /* no trailing newline: csv_fini reports the last row with c == -1 */
    expect ("fini parse without newline",
            parse_counts (ref parser, "x,y", counts));
    expect ("fini emits a record", counts.records == 1);
    expect ("fini record terminator is -1", counts.last_record_c == -1);
}

public int main (string[] args) {
    stdout.printf ("1..65\n");
    stdout.printf ("# libcsv %d.%d.%d Vala bindings\n", MAJOR, MINOR, RELEASE);

    test_version_constants ();
    test_character_constants ();
    test_strerror ();
    test_parser_init ();
    test_parser_init_method ();
    test_parse_simple ();
    test_quoted_comma_and_quote ();
    test_custom_delim ();
    test_custom_quote ();
    test_empty_is_null ();
    test_strict_parse_error ();
    test_write_quotes_field ();
    test_write2_custom_quote ();
    test_fwrite_roundtrip ();
    test_set_opts_and_blk ();
    test_space_and_term_func ();
    test_fini_record_c ();

    stdout.printf ("# Tests run: %d, passed: %d\n", tests_run, tests_passed);
    return tests_passed == tests_run ? 0 : 1;
}
