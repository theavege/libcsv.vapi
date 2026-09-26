/**
 * Write CSV rows with libcsv. csv_fwrite quotes a single field; delimiters
 * and record separators are the caller's responsibility.
 */

errordomain Err { WRITE }

public class CSVWriter : Object {
    public void write_file (string filename) throws Error {
        var file = FileStream.open (filename, "wb");
        if (file == null)
            throw new Err.WRITE ("Failed to open %s for writing\n", filename);

        int rows = 0;
        this.write_row (file, {"Name", "Age", "City", "Notes"});
        rows++;
        this.write_row (file, {"Alice", "30", "New York", "Engineer"});
        rows++;
        this.write_row (file, {"Bob", "25", "Los Angeles", "Designer"});
        rows++;
        this.write_row (file, {"Charlie", "35", "Chicago", "Manager"});
        rows++;
        this.write_row (file, {"Diana", "28", "Houston", "Contains, comma"});
        rows++;
        this.write_row (file, {"Eve", "32", "Phoenix", "Has \"quotes\""});
        rows++;

        message ("Wrote %d rows to %s\n", rows, filename);
    }

    private static void write_row (FileStream file, string[] fields) throws Error {
        for (int i = 0; i < fields.length; i++) {
            if (i > 0 && file.putc (',') == FileStream.EOF)
                throw new Err.WRITE ("Failed to write delimiter\n");
            unowned string field = fields[i];
            if (Csv.fwrite (file, field, field.length) != 0)
                throw new Err.WRITE ("Failed to write field\n");
        }
        if (file.putc ('\n') == FileStream.EOF)
            throw new Err.WRITE ("Failed to write newline\n");
    }
}

public int main (string[] args) {
    try {
        string output_file = args.length > 1 ? args[1] : "output.csv";
        new CSVWriter ()
            .write_file (output_file);
        return 0;
    } catch (Error e) {
        critical("failed while %s: %s\n", args[0], e.message);
        return 1;
    }
}
