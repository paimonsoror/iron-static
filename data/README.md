# data/

Balance and content tables as CSV. The importer (`tools\import_data.ps1`, M1-02) turns them into `src/data_gen/*.tres`. Never hand-edit `src/data_gen/`.

Every CSV table must have:

- A header row as the first line.
- A first column `id` holding a snake_case id taken from the GDD (`docs/design/`); ids are never invented here.
- UTF-8 encoding without BOM, LF line endings.
- No currency or cost values outside `BigNum` string form where the GDD requires it.
- Cross-table references by GDD id only.
