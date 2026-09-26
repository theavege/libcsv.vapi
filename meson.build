project('libcsv-vapi', ['c', 'vala'],
  version: '0.1.0',
  license: 'LGPL-2.1-or-later',
  meson_version: '>= 0.60.0',
  default_options: [
    'c_std=c11',
    'warning_level=2',
  ],
)

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')

cc = meson.get_compiler('c')
if not cc.has_header('csv.h')
  error('csv.h not found — install libcsv-dev / libcsv-devel, or build Robert Gamble\'s libcsv')
endif

csv_lib = cc.find_library('csv', required: true)
libcsv_dep = declare_dependency(dependencies: csv_lib)

add_project_arguments('--fatal-warnings', language: 'vala')

vapi_dir = meson.current_source_dir() / 'src'
vala_args = [
  '--vapidir', vapi_dir,
  '--pkg', 'libcsv',
]

install_data(
  'src/libcsv.vapi',
  install_dir: get_option('datadir') / 'vala' / 'vapi',
)

if get_option('examples')
  executable('read-csv',
    'examples/read_csv.vala',
    dependencies: [glib_dep, gobject_dep, libcsv_dep],
    vala_args: vala_args,
    install: false,
  )

  executable('write-csv',
    'examples/write_csv.vala',
    dependencies: [glib_dep, gobject_dep, libcsv_dep],
    vala_args: vala_args,
    install: false,
  )
endif

test_exe = executable('test-libcsv',
  'tests/test_libcsv.vala',
  dependencies: [glib_dep, gobject_dep, libcsv_dep],
  vala_args: vala_args,
  install: false,
)

test('libcsv', test_exe, protocol: 'tap')
