[CCode (cheader_filename = "csv.h", cprefix = "CSV_", lower_case_cprefix = "csv_")]
namespace Csv {
	[CCode (cname = "CSV_MAJOR")]
	public const int MAJOR;
	[CCode (cname = "CSV_MINOR")]
	public const int MINOR;
	[CCode (cname = "CSV_RELEASE")]
	public const int RELEASE;

	/**
	 * Codes returned by {@link Parser.error}. {@link Parser.init} returns 0
	 * on success and -1 if the parser pointer is null; {@link Parser.fini}
	 * returns 0 on success and non-zero on failure — call {@link Parser.error}
	 * afterward for the specific status.
	 */
	[CCode (cname = "int", cprefix = "CSV_", has_type_id = false)]
	public enum Status {
		SUCCESS,
		EPARSE,
		ENOMEM,
		ETOOBIG,
		EINVALID
	}

	/**
	 * Parser option flags, combined with bitwise OR and passed to
	 * {@link Parser.init} / {@link Parser.set_opts}.
	 */
	[Flags]
	[CCode (cname = "unsigned char", cprefix = "CSV_", has_type_id = false)]
	public enum Options {
		[CCode (cname = "0")]
		NONE = 0,
		STRICT = 1 << 0,
		REPALL_NL = 1 << 1,
		STRICT_FINI = 1 << 2,
		APPEND_NULL = 1 << 3,
		EMPTY_IS_NULL = 1 << 4
	}

	[CCode (cname = "CSV_TAB")]
	public const uchar TAB;
	[CCode (cname = "CSV_SPACE")]
	public const uchar SPACE;
	[CCode (cname = "CSV_CR")]
	public const uchar CR;
	[CCode (cname = "CSV_LF")]
	public const uchar LF;
	[CCode (cname = "CSV_COMMA")]
	public const uchar COMMA;
	[CCode (cname = "CSV_QUOTE")]
	public const uchar QUOTE;

	/**
	 * Called when a field is complete.
	 *
	 * @param field pointer to field bytes, or null when {@link Options.EMPTY_IS_NULL}
	 *              applies to an empty unquoted field
	 * @param len   field length in bytes (the extra NUL from {@link Options.APPEND_NULL}
	 *              is not included)
	 * @param data  user pointer passed to {@link Parser.parse}
	 */
	[CCode (has_target = false)]
	public delegate void FieldCb (void* field, size_t len, void* data);

	/**
	 * Called when a record (row) is complete.
	 *
	 * @param c    terminator that ended the row ({@link CR}, {@link LF}, or the
	 *             custom terminator), or -1 when invoked from {@link Parser.fini}
	 * @param data user pointer passed to {@link Parser.parse}
	 */
	[CCode (has_target = false)]
	public delegate void RecordCb (int c, void* data);

	[CCode (has_target = false)]
	public delegate int CharTest (uchar c);

	[CCode (has_target = false)]
	public delegate void* ReallocFunc (void* ptr, size_t size);

	[CCode (has_target = false)]
	public delegate void FreeFunc (void* ptr);

	/**
	 * libcsv parser object. Stack-allocated; {@link free} (and the Vala destroy
	 * function) releases the internal entry buffer. {@link free} is idempotent.
	 */
	[CCode (cname = "struct csv_parser", destroy_function = "csv_free", has_type_id = false, default_value = "{ }")]
	public struct Parser {
		[CCode (cname = "csv_init")]
		public Parser (Options options = Options.NONE);

		[CCode (cname = "csv_init")]
		public int init (Options options = Options.NONE);

		/**
		 * Parse ''len'' bytes at ''s''. Returns the number of bytes consumed.
		 * A short return (less than ''len'') means an error; call {@link error}.
		 */
		[CCode (cname = "csv_parse")]
		public size_t parse (void* s, size_t len, FieldCb? cb1, RecordCb? cb2, void* data = null);

		/**
		 * Flush a partial final field/row. Returns 0 on success, non-zero on
		 * failure. With {@link Options.STRICT_FINI}, an unclosed quote makes
		 * {@link error} return {@link Status.EPARSE}.
		 */
		[CCode (cname = "csv_fini")]
		public int fini (FieldCb? cb1, RecordCb? cb2, void* data = null);

		[CCode (cname = "csv_free")]
		public void free ();

		[CCode (cname = "csv_error")]
		public Status error ();

		[CCode (cname = "csv_get_opts")]
		public Options get_opts ();
		[CCode (cname = "csv_set_opts")]
		public int set_opts (Options options);

		[CCode (cname = "csv_get_delim")]
		public uchar get_delim ();
		[CCode (cname = "csv_set_delim")]
		public void set_delim (uchar delim);

		[CCode (cname = "csv_get_quote")]
		public uchar get_quote ();
		[CCode (cname = "csv_set_quote")]
		public void set_quote (uchar quote);

		[CCode (cname = "csv_set_space_func")]
		public void set_space_func (CharTest? f);
		[CCode (cname = "csv_set_term_func")]
		public void set_term_func (CharTest? f);

		[CCode (cname = "csv_set_realloc_func")]
		public void set_realloc_func (ReallocFunc? f);
		[CCode (cname = "csv_set_free_func")]
		public void set_free_func (FreeFunc? f);

		[CCode (cname = "csv_set_blk_size")]
		public void set_blk_size (size_t size);

		[CCode (cname = "csv_get_buffer_size")]
		public size_t get_buffer_size ();
	}

	/**
	 * Quote a single field into ''dest''. Always surrounds the field with
	 * {@link QUOTE} and doubles internal quotes. Returns the number of bytes
	 * that would be written (even if ''dest'' is null or too small).
	 */
	public size_t write (void* dest, size_t dest_size, void* src, size_t src_size);

	/**
	 * Quote a single field to a stream. Returns 0 on success, or a negative
	 * value (EOF) on write error. Does not write a delimiter or newline.
	 */
	public int fwrite (GLib.FileStream fp, void* src, size_t src_size);

	public size_t write2 (void* dest, size_t dest_size, void* src, size_t src_size, uchar quote);
	public int fwrite2 (GLib.FileStream fp, void* src, size_t src_size, uchar quote);

	public unowned string strerror (int error);
}
