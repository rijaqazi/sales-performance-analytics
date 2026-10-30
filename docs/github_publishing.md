# GitHub publishing guide

The local portfolio is complete. No GitHub repository has been created or published by this workflow. Open the **sales-performance-analytics** folder itself in VS Code; do not initialize or publish an unrelated parent workspace.

1. Review the final README, screenshots, SQL, and findings. Keep passwords, tokens, and private connection information out of source control. The model includes development instance `TELESTE\RIJA_101`, not a password; readers must substitute their own instance. Review local path/instance identifiers before public sharing and update instructions if replacing them with examples.
2. Keep raw data and database backup files out of the repository. The project .gitignore already excludes these. Provide the official download link and attribution instead.
3. In VS Code, open this project folder. Use **Source Control → Initialize Repository** if it is not already in a repository. Check the repository root before initializing.
4. Review the files shown in Source Control, stage the intended files, and make a commit such as `Complete sales analytics portfolio project` only once that description is accurate.
5. Create an empty GitHub repository named `sales-performance-analytics`. Use VS Code's publish flow or follow GitHub's connection instructions for an existing repository. Choose public visibility when ready to showcase the work.
6. Open the repository in your browser. Check links, screenshots, source credit, and reproducibility instructions.
7. Add a short description and topics such as `sql-server`, `power-bi`, `data-analysis`, and `portfolio`.

Include `SalesAnalytics.pbip` and both its Report and SemanticModel folders. A PBIP file alone is only a pointer. Include all three real dashboard screenshots. Confirm the staged file list contains no original XLSX, staging CSV, `.pbi` directory, `cache.abf`, or database backup. The clone deliberately excludes the populated local model cache; a reader must download the source, build SQL, authenticate, and refresh the report.

After publishing, check the README images, findings, SQL, source attribution, and setup links in GitHub. When possible, verify a fresh clone in a separate folder. Pin the verified repository on your profile. Suggested description: `Retail sales analysis with SQL Server, a verified Power BI star model, and evidence-based customer insights.`

Dataset attribution: Chen, D. (2012). Online Retail II [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5CG6D. CC BY 4.0: https://creativecommons.org/licenses/by/4.0/.

The dataset license does not automatically license your own code. Choose a code license when publishing. Do not label the historical project as production deployment or claim business improvements that were not measured.
