"""Validate saved SQL aggregates with Decimal arithmetic and write a readable report.
This script never connects to SQL Server and does not generate underlying data.
"""
from pathlib import Path
from decimal import Decimal
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]

def main():
    path = ROOT/'reports/sql_analysis_results.json'
    r = json.loads(path.read_text(encoding='utf-8'), parse_float=Decimal)
    k, c, rf = r['KPIs'], r['CustomerBehavior'], r['RFMDefinition']
    gross = k['GrossMerchandiseSalesGBP']
    checks = {
        'Monthly gross equals total': sum(x['GrossSalesGBP'] for x in r['MonthlyTrends']) == gross,
        'Yearly gross equals total': sum(x['GrossSalesGBP'] for x in r['YearlyTrends']) == gross,
        'Country gross equals total': sum(x['GrossSalesGBP'] for x in r['CountryPerformance']) == gross,
        'Country net equals total': sum(x['NetMerchandiseValueGBP'] for x in r['CountryPerformance']) == k['NetMerchandiseTransactionValueGBP'],
        'Known plus anonymous equals gross': c['KnownCustomerGrossSalesGBP']+c['AnonymousGrossSalesGBP'] == gross,
        'Customer bands reconcile counts': sum(x['Customers'] for x in r['PurchaseFrequency']) == k['KnownPurchasingCustomers'],
        'Customer bands reconcile value': sum(x['GrossPurchasesGBP'] for x in r['PurchaseFrequency']) == c['KnownCustomerGrossSalesGBP'],
        'RFM segments reconcile counts': sum(x['Customers'] for x in r['RFMSegments']) == rf['IncludedCustomers'],
        'RFM segments reconcile value': sum(x['GrossPurchasesGBP'] for x in r['RFMSegments']) == rf['IncludedGrossPurchasesGBP'],
        'Gross minus cancellations equals net': gross-k['CancellationValueGBP'] == k['NetMerchandiseTransactionValueGBP'],
        'AOV agrees within displayed precision': abs(gross/k['PurchaseOrders']-k['AverageOrderValueGBP']) <= Decimal('0.00005'),
        'Monthly order counts reconcile': sum(x['PurchaseOrders'] for x in r['MonthlyTrends']) == k['PurchaseOrders'],
        'Profit and margin are unavailable': k['ProfitGBP'] is None and k['ProfitMarginPct'] is None,
        'SQL reconciliations pass': r['Validation']['OrderValueDifferenceGBP']==0 and r['Validation']['MonthlyValueDifferenceGBP']==0 and r['Validation']['InvalidRFMScores']==0,
        'Top products are ranked descending': len(r['TopProducts'])==10 and all(a['GrossSalesGBP']>=b['GrossSalesGBP'] for a,b in zip(r['TopProducts'],r['TopProducts'][1:])),
    }
    assert all(checks.values()), checks
    money = lambda n: f'{n:,.2f}'
    lines = [
        '# Phase 3: verified SQL analysis', '',
        'Executed in SQL Server through the connected SSMS session on 31 October 2026. '
        'The actual result is saved in `sql_analysis_results.json`. No permanent tables were changed.', '',
        f"Source coverage: **{r['SourceFirstDate']} to {r['SourceLastDate']}**. Currency: GBP. "
        'Repeated-line candidates remain included, and merchandise includes the documented provisional code-pattern rule.', '',
        '## KPI results', '', '| Metric | Verified value |', '| --- | ---: |',
        f"| Gross merchandise sales | £{money(gross)} |",
        f"| Merchandise cancellation value | £{money(k['CancellationValueGBP'])} |",
        f"| Net merchandise transaction value | £{money(k['NetMerchandiseTransactionValueGBP'])} |",
        f"| Eligible purchase orders | {k['PurchaseOrders']:,} |",
        f"| Average order value | £{money(k['AverageOrderValueGBP'])} |",
        f"| Known purchasing customers | {k['KnownPurchasingCustomers']:,} |",
        f"| Repeat known purchasers | {c['RepeatPurchasers']:,} ({c['RepeatPurchaserPct']:.2f}%) |",
        '| Profit / profit margin | Unavailable: costs absent |', '',
        'Net merchandise transaction value excludes separate discounts, shipping, fees, vouchers, and unresolved lines. '
        'It is not audited accounting revenue. Category analysis is unavailable because the source has no merchandise-category hierarchy.', '',
        '## Comparable-period growth', '',
    ]
    y = r['ComparablePeriodYoY']
    lines += [f"**{y['CurrentPeriodStart']}–{y['CurrentPeriodEnd']}** gross sales: £{money(y['CurrentGBP'])}. "
              f"Matching prior period **{y['PriorPeriodStart']}–{y['PriorPeriodEnd']}**: £{money(y['PriorGBP'])}. "
              f"Growth: **{y['GrowthPct']:.2f}%**.", '',
              'Monthly YoY is unavailable where comparable complete-source months are absent. December 2011 is partial.', '',
              '## Top ten products by gross merchandise sales', '',
              '| Rank | Stock code | Product display description | Gross sales (GBP) |',
              '| ---: | --- | --- | ---: |']
    for p in r['TopProducts']:
        name = (p['ProductDescription'] or '(description missing)').replace('|','/')
        lines.append(f"| {p['RevenueRank']} | {p['StockCode']} | {name} | {money(p['GrossSalesGBP'])} |")
    lines += ['', '## Leading country labels', '',
              '| Country | Gross merchandise sales (GBP) | Eligible orders |', '| --- | ---: | ---: |']
    for g in r['CountryPerformance'][:5]:
        lines.append(f"| {g['Country']} | {money(g['GrossSalesGBP'])} | {g['PurchaseOrders']:,} |")
    lines += ['', 'All source country labels are in the JSON. These are customer-country comparisons, not verified delivery regions.', '',
              '## RFM customer segments', '',
              f"Window: **{rf['WindowStart']} inclusive to {rf['WindowEndExclusive']} exclusive**. "
              f"Snapshot: **{rf['SnapshotDate']}**. Known customers included: **{rf['IncludedCustomers']:,}**.", '',
              '| Segment | Customers | Window gross purchases (GBP) |', '| --- | ---: | ---: |']
    for s in r['RFMSegments']:
        lines.append(f"| {s['Segment']} | {s['Customers']:,} | {money(s['GrossPurchasesGBP'])} |")
    lines += ['', 'Segments are exploratory, analyst-defined labels, not validated churn or profitability predictions. '
              'Scores keep ties together; groups are not guaranteed equal size. Anonymous customers and customers '
              'without a purchase in this window are excluded. Scoring details are in `docs/06_sql_analysis_guide.md`.', '',
              '## Validation', '',
              'All SQL order/month/RFM reconciliations passed. No eligible purchase invoice spans calendar dates or months in this snapshot. '
              'This validates the first-purchase-date convention for monthly order counts.', '',
              f"Repeated eligible sale-line candidates contribute **£{money(r['Validation']['RepeatedSaleLineValueGBP'])}** "
              'to gross sales. This is a sensitivity amount, not proof of overstatement.', '',
              f'All {len(checks)} saved-result checks passed using independent Decimal arithmetic:', '']
    lines += [f'- {name}.' for name in checks]
    lines += ['', '## Next phase', '',
              'Build the Power BI semantic model, DAX measures, visuals, and reconciliation against these SQL controls. '
              'No Power BI report or screenshots are claimed complete.', '']
    (ROOT/'reports/phase_3_sql_analysis.md').write_text('\n'.join(lines), encoding='utf-8')
    manifest = {'verification_date':'2026-10-31','sql_file':'sql/20_sales_analysis.sql',
                'sql_sha256':hashlib.sha256((ROOT/'sql/20_sales_analysis.sql').read_bytes()).hexdigest(),
                'results_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'sql_execution':'Executed and verified via connected SSMS session',
                'saved_result_checks':checks}
    (ROOT/'reports/phase_3_verification.json').write_text(json.dumps(manifest,indent=2), encoding='utf-8')
    print(f'PASS: {len(checks)} result reconciliations. Wrote Phase 3 report and verification manifest.')

if __name__ == '__main__':
    main()
