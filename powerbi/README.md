# Power BI report project

Open **SalesAnalytics.pbip** in Power BI Desktop. Keep the Report and SemanticModel folders together. The model imports five tables from the local SalesAnalyticsDB SQL database and uses four single-direction dimension relationships.

Status: **Phase 4 complete.** The SQL refresh succeeded, all 16 DAX checks passed, year/country slicers were verified against SQL, and all three pages were visually reviewed and captured. The populated model was saved in Power BI Desktop. See `../reports/phase_4_verification.md`.

- `measures.dax`: 18 individual measure definitions.
- `validate_measures.dax`: executable DAX query with 16 SQL-backed controls, including case-distinct product display and complete top-ten coverage.
- `sales-analytics-theme.json`: reusable professional palette.
- `SalesAnalytics.Report/`: three pages in supported PBIR JSON format.
- `SalesAnalytics.SemanticModel/`: TMSL model, imports, relationships, formatting, and measures.

Full setup and step-by-step visual instructions: `../docs/07_powerbi_dashboard_guide.md`.

No credentials are embedded. Machine-local caches/settings under `.pbi` are excluded from Git. The source connection currently points to the user's local instance; change it to your own SQL instance when reproducing the project.

ProductLabel preserves case-distinct SQL product identities in Power BI visuals by adding a variant suffix only where case-insensitive labels would collide. See the build guide for the transformation and limitations. Regenerating definitions is optional; use a fresh clone without a model cache, not a populated open report.
