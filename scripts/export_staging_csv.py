"""Export original rows for SQL Server CSV import; do not clean or deduplicate.

Run from any directory with Python 3.11+ and openpyxl installed.
Source worksheet and Excel row number uniquely identify every exported line.
"""
from pathlib import Path
from datetime import datetime
from decimal import Decimal
import csv
import hashlib
import json
from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/raw/online_retail_II.xlsx'
TARGET = ROOT / 'data/processed/retail_staging.csv'
EXPECTED_HASH = 'bcbe73b35f5b7babf197fb0cb983a11f5d9ff929078d4aa53d171b1f2df2e980'

def serialize(value):
    if value is None:
        return ''
    if isinstance(value, datetime):
        return value.isoformat(timespec='seconds')
    if isinstance(value, float):
        return format(Decimal(str(value)), 'f')
    return str(value)

def main():
    with SOURCE.open('rb') as f:
        source_hash = hashlib.file_digest(f, 'sha256').hexdigest()
    if source_hash != EXPECTED_HASH:
        raise ValueError('Source changed: profile it before exporting.')
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    temporary = TARGET.with_suffix('.csv.tmp')
    book = load_workbook(SOURCE, read_only=True, data_only=False)
    expected = ['Invoice','StockCode','Description','Quantity','InvoiceDate','Price','Customer ID','Country']
    counts = {}
    canonical_rows = 0
    max_price_scale = 0
    with temporary.open('w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, lineterminator='\n')
        writer.writerow(['SourceSheet','SourceRowNumber','InvoiceRaw','StockCodeRaw',
                         'DescriptionRaw','QuantityRaw','InvoiceDateRaw','UnitPriceRaw',
                         'CustomerIDRaw','CountryRaw'])
        for ws in book:
            rows = ws.iter_rows(values_only=True)
            assert list(next(rows)) == expected, f'Unexpected headers in {ws.title}'
            count = 0
            for row_number, row in enumerate(rows, start=2):
                if all(v is None for v in row):
                    continue
                assert len(row) == 8 and isinstance(row[4], datetime)
                price = Decimal(str(row[5]))
                max_price_scale = max(max_price_scale, max(0, -price.as_tuple().exponent))
                assert price == price.quantize(Decimal('0.0001')), 'Price requires more than 4 decimal places'
                writer.writerow([ws.title, row_number] + [serialize(v) for v in row])
                if ((ws.title == 'Year 2009-2010' and row[4] < datetime(2010,12,1))
                    or (ws.title == 'Year 2010-2011' and row[4] >= datetime(2010,12,1))):
                    canonical_rows += 1
                count += 1
            counts[ws.title] = count
            print(f'Exported {ws.title}: {count:,} rows', flush=True)
    book.close()
    assert counts == {'Year 2009-2010':525461, 'Year 2010-2011':541910}
    temporary.replace(TARGET)
    # Independently parse the CSV with the same CSV grammar, not newline counting.
    with TARGET.open(encoding='utf-8', newline='') as f:
        reader = csv.reader(f)
        assert len(next(reader)) == 10
        parsed = 0
        for row in reader:
            assert len(row) == 10
            assert int(row[1]) >= 2
            datetime.fromisoformat(row[6])
            Decimal(row[7])
            assert row[8] == '' or row[8].isdigit()
            parsed += 1
    assert parsed == sum(counts.values())
    with TARGET.open('rb') as f:
        output_hash = hashlib.file_digest(f, 'sha256').hexdigest()
    manifest = {'source_sha256':source_hash, 'csv_sha256':output_hash,
                'csv_path':'data/processed/retail_staging.csv', 'encoding':'UTF-8 without BOM',
                'delimiter':',', 'quote':'"', 'line_terminator':'LF', 'header_rows':1,
                'rows':parsed, 'rows_by_sheet':counts, 'max_observed_price_decimal_places':max_price_scale,
                'canonical_rows_under_date_partition':canonical_rows,
                'excluded_overlap_rows_under_date_partition':parsed-canonical_rows,
                'csv_roundtrip_validation':'passed: 10 fields, row counts, dates, prices, customer ID formatting'}
    (ROOT/'reports/import_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(manifest, indent=2), flush=True)

if __name__ == '__main__':
    main()
