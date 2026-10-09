void test_parse () {
    try {
        var rows = Csv.parse_string ("name,age\r\n\"Doe, Jane\",30\r\n\"say \"\"hi\"\"\",7");
        assert (rows.length == 3);
        assert (rows[0][0] == "name");
        assert (rows[1][0] == "Doe, Jane");
        assert (rows[2][0] == "say \"hi\"");
        assert (rows[2][1] == "7");
    } catch (Csv.ParseError e) {
        Test.fail_printf (e.message);
    }
}

void test_chunked () {
    var rows = new GenericArray<string> ();
    var r = new Csv.Reader ();
    r.row_read.connect ((f) => rows.add (string.joinv ("|", (string[]) f.data)));
    try {
        r.feed_string ("a,b\n\"x");
        r.feed_string ("y\",é\nlast,row");
        r.finish ();
    } catch (Csv.ParseError e) {
        Test.fail_printf (e.message);
    }
    assert (rows.length == 3);
    assert (rows[1] == "xy|é");
    assert (rows[2] == "last|row");
}

void test_strict_error () {
    try {
        Csv.parse_string ("a,\"b\"c\n", Csv.Options.STRICT);
        Test.fail_printf ("expected error");
    } catch (Csv.ParseError e) {
        assert (e is Csv.ParseError.SYNTAX);
    }
}

void test_write () {
    assert (Csv.quote_field ("say \"hi\"") == "\"say \"\"hi\"\"\"");
    assert (Csv.format_row ({ "a", null, "b,c" }) == "\"a\",,\"b,c\"");
    var mem = new MemoryOutputStream.resizable ();
    var w = new Csv.Writer (mem);
    try {
        w.write_row ({ "x", "y" });
        mem.close ();
    } catch (Error e) {
        Test.fail_printf (e.message);
    }
    assert ((string) mem.steal_data () == "\"x\",\"y\"\r\n");
}

void test_empty_null () {
    try {
        var rows = Csv.parse_string ("a,,b\n", Csv.Options.EMPTY_IS_NULL);
        assert (rows[0][1] == null);
    } catch (Csv.ParseError e) {
        Test.fail_printf (e.message);
    }
}

void main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/csv/parse", test_parse);
    Test.add_func ("/csv/chunked", test_chunked);
    Test.add_func ("/csv/strict", test_strict_error);
    Test.add_func ("/csv/write", test_write);
    Test.add_func ("/csv/empty-null", test_empty_null);
    Test.run ();
}
