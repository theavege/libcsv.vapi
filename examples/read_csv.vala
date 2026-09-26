/**
 * Read a CSV file with libcsv and print each row.
 *
 * Field and record callbacks are C function pointers (no Vala target), so
 * instance methods are wrapped as static functions and the object is passed
 * as the userdata pointer.
 */

errordomain Err { USAGE, FILE, PARSER }

public class CSVReader : Object {
    private string[] current_row;
    private int rows;

    public CSVReader () {
        this.current_row = {};
        this.rows = 0;
    }

    private static string field_to_string (void* field, size_t len) {
        if (field == null)
            return "";
        var buf = new uint8[len + 1];
        if (len > 0)
            Memory.copy (buf, field, len);
        buf[len] = 0;
        return (string) buf;
    }

    private static void on_field (void* field, size_t len, void* data) {
        unowned CSVReader self = (CSVReader) data;
        self.current_row += field_to_string (field, len);
    }

    private static void on_record (int c, void* data) {
        unowned var self = (CSVReader) data;
        self.rows++;

        stdout.printf ("Row %d:", self.rows);
        foreach (unowned string cell in self.current_row)
            stdout.printf (" \"%s\"", cell);

        stdout.printf ("\n");

        self.current_row = {};
        // ''c'' is CR/LF (or a custom terminator), or -1 from csv_fini.
        if (c < 0) {
            return;
        }
    }

    public void parse_file (string filename) throws Error {
        var parser = Csv.Parser (Csv.Options.APPEND_NULL);
        parser.set_delim (Csv.COMMA);
        parser.set_quote (Csv.QUOTE);

        var file = FileStream.open (filename, "rb");
        if (file == null)
            throw new Err.FILE("Failed to open %s\n", filename);

        uint8 buf[4096]; size_t n;
        while ((n = file.read (buf)) > 0)
            if (parser.parse (buf, n, on_field, on_record, this) != n)
                throw new Err.PARSER("Parse error: %s\n", Csv.strerror ((int) parser.error ()));

        if (parser.fini (on_field, on_record, this) != Csv.Status.SUCCESS)
            throw new Err.PARSER("Finalize error: %s\n", Csv.strerror ((int) parser.error ()));

        message ("Parsed %d records from %s\n", this.rows, filename);
    }
}

int main (string[] args) {
    try {
        if (args.length < 2)
            throw new Err.USAGE ("Usage: %s <csv_file>\n", args[0]);
        new CSVReader ()
            .parse_file (args[1]);
        return 0;
    } catch (Error e) {
        critical("failed while %s: %s\n", args[0], e.message);
        return 1;
    }
}
