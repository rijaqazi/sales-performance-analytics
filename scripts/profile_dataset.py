"""Read-only Phase 1 profiling. Run with Python, pandas, and openpyxl installed.

Usage: python scripts/profile_dataset.py (from the project root).
The original workbook is never edited. No business cleaning is performed here.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import pandas as pd
from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/raw/online_retail_II.xlsx'
REPORTS = ROOT / 'reports'

def main():
    digest = hashlib.file_digest(SOURCE.open('rb'), 'sha256').hexdigest()
    book = load_workbook(SOURCE, read_only=True, data_only=False)
    sheets = []
    frames = []
    for ws in book:
        print(f'Reading {ws.title}', flush=True)
        iterator = ws.iter_rows()
        headers = [c.value for c in next(iterator)]
        values = []
        types = {h: Counter() for h in headers}
        formats = Counter()
        formula_count = 0
        for cells in iterator:
            row = [c.value for c in cells]
            if all(v is None for v in row):
                continue
            values.append(row)
            for h, c in zip(headers, cells):
                types[h][type(c.value).__name__] += 1
                formula_count += c.data_type == 'f'
                if h == 'InvoiceDate' and c.value is not None:
                    formats[c.number_format] += 1
        frame = pd.DataFrame(values, columns=headers)
        del values
        sheets.append({'name': ws.title, 'rows': len(frame), 'headers': headers,
                       'cell_python_types': types, 'invoice_date_formats': formats,
                       'formula_cells': formula_count,
                       'extra_exact_duplicate_rows': int(frame.duplicated().sum()),
                       'min_date': str(frame.InvoiceDate.min()),
                       'max_date': str(frame.InvoiceDate.max())})
        frames.append(frame)
        print(f'Profiled {len(frame):,} rows', flush=True)
    book.close()
    df = pd.concat(frames, ignore_index=True)
    del frames
    expected = ['Invoice','StockCode','Description','Quantity','InvoiceDate','Price','Customer ID','Country']
    assert df.columns.tolist() == expected, 'Unexpected headers: review before continuing'
    date = pd.to_datetime(df.InvoiceDate, errors='coerce')
    inv = df.Invoice.astype('string')
    stock = df.StockCode.astype('string')
    cancel = inv.str.upper().str.startswith('C', na=False)
    numeric = {}
    for c in ['Quantity','Price']:
        v = pd.to_numeric(df[c], errors='coerce')
        numeric[c] = {'min': float(v.min()), 'max': float(v.max()),
                      'zero_rows': int(v.eq(0).sum()), 'negative_rows': int(v.lt(0).sum()),
                      'non_numeric_nonblank_rows': int((v.isna() & df[c].notna()).sum()),
                      'non_integer_rows': int((v.notna() & v.mod(1).ne(0)).sum())}
    month = df.groupby(date.dt.to_period('M')).size()
    duplicates = int(df.duplicated().sum())
    within = sum(s['extra_exact_duplicate_rows'] for s in sheets)
    consistency = df.assign(InvoiceKey=inv).groupby('InvoiceKey', dropna=False).agg(
        customers=('Customer ID', lambda s: s.nunique(dropna=False)),
        countries=('Country', lambda s: s.nunique(dropna=False)),
        timestamps=('InvoiceDate', 'nunique'))
    descriptions = df.groupby('StockCode').Description.nunique()
    specials = stock[~stock.str.fullmatch(r'\d{5}[A-Za-z]*', na=False)].value_counts()
    result = {
        'source_file': SOURCE.name, 'bytes': SOURCE.stat().st_size, 'sha256': digest,
        'sheets': sheets, 'total_rows': len(df), 'column_count': len(df.columns),
        'missing': {c: int(df[c].isna().sum()) for c in df},
        'whitespace_only': {c: int(df[c].map(lambda v: isinstance(v,str) and not v.strip()).sum()) for c in df},
        'max_text_lengths': {c: int(df[c].dropna().astype(str).str.len().max()) for c in df},
        'numeric': numeric, 'invalid_dates': int(date.isna().sum()),
        'min_date': str(date.min()), 'max_date': str(date.max()),
        'extra_exact_duplicate_rows': duplicates,
        'rows_in_duplicate_groups': int(df.duplicated(keep=False).sum()),
        'distinct_duplicate_groups': int(df[df.duplicated(keep=False)].drop_duplicates().shape[0]),
        'cross_sheet_duplicate_excess': duplicates-within,
        'distinct_invoice_ids': int(inv.nunique()),
        'distinct_nonmissing_customers': int(df['Customer ID'].nunique()),
        'distinct_stock_codes': int(stock.nunique()), 'distinct_countries': int(df.Country.nunique()),
        'c_prefixed_rows': int(cancel.sum()),
        'c_prefixed_nonnegative_quantity_rows': int((cancel & df.Quantity.ge(0)).sum()),
        'negative_quantity_without_c_prefix_rows': int((~cancel & df.Quantity.lt(0)).sum()),
        'invoice_ids_with_multiple_customers_including_missing': int(consistency.customers.gt(1).sum()),
        'invoice_ids_with_multiple_countries': int(consistency.countries.gt(1).sum()),
        'invoice_ids_with_multiple_timestamps': int(consistency.timestamps.gt(1).sum()),
        'stock_codes_with_multiple_nonmissing_descriptions': int(descriptions.gt(1).sum()),
        'unusual_stock_code_rows_by_code': {str(k):int(v) for k,v in specials.items()},
        'monthly_row_counts': {str(k):int(v) for k,v in month.items()},
    }
    assert len(df) == sum(s['rows'] for s in sheets)
    assert len(df) == sum(result['monthly_row_counts'].values()) + result['invalid_dates']
    REPORTS.mkdir(exist_ok=True)
    (REPORTS/'dataset_profile.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['sheets','monthly_row_counts']},indent=2), flush=True)

if __name__ == '__main__':
    main()
