/**
 * Read a CSV file with libcsv and print each row.
 *
 * Field and record callbacks are C function pointers (no Vala target), so
 * instance methods are wrapped as static functions and the object is passed
 * as the userdata pointer.
 */

errordomain Err { FILE }

uint8[] read_data(string filename) throws Error {
    if (!FileUtils.test (filename, FileTest.IS_REGULAR))
        throw new Err.FILE ("Database %s does not exist or is directory\n", filename);
    uint8[] content;
    FileUtils.get_data (filename, out content);
    return content;
}

class CSV : Object {
    public string delim { get; }

    public CSV (string delim) {
        Object (delim: delim);
    }

    public string[,] from_text (string text) {
        string[] rows = text.split("\n");
        var result = new string[rows.length, rows[0].split(this.delim).length];
        for (int row = 0; row < result.length[0]; row++) {
            string[] line = rows[row].split(",");
            for (int col = 0; col < result.length[1]; col++)
                result[row,col] = line[col];
        }
        return result;
    }

    public string to_text (string[,] data) {
        var text = new StringBuilder ();
        for (int row = 0; row < data.length[0]; row++) {
            for (int col = 0; col < data.length[1]; col++)
                text.append (data[row,col] + this.delim);
            text.erase (text.len - 1, 1);
            text.append ("\r\n");
        };
        return text.str;
    }
}

int main (string[] args) {
    try {
        var csv = new CSV(",");
        string text = csv.to_text({
            {"Name","Age","City","Notes"},
            {"Alice","30","New York","Engineer"},
            {"Bob","25","Los Angeles","Designer"},
            {"Charlie","35","Chicago","Manager"},
            {"Diana","28","Houston","Contains, comma"},
            {"Eve","32","Phoenix","""Has "quotes""""},
        });
        const string FILE_NAME = "sample.csv";
        FileUtils.set_contents (FILE_NAME, text);
        csv.from_text ((string) read_data(FILE_NAME));
        return 0;
    } catch (Error e) {
        critical("failed while %s: %s\n", args[0], e.message);
        return 1;
    }
}
