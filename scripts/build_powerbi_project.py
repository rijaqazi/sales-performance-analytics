"""Author supported PBIP/PBIR and TMSL files; refresh/verify in Power BI Desktop.
Requires a native blank project scaffold saved at work/pbi-seed in this workspace.
Does not embed SQL credentials or claim that opening/refresh succeeded.
"""
from pathlib import Path
import json
import shutil

ROOT=Path(__file__).resolve().parents[1]
SEED=ROOT.parents[1]/'work/pbi-seed'
OUT=ROOT/'powerbi'
REPORT=OUT/'SalesAnalytics.Report'
MODEL=OUT/'SalesAnalytics.SemanticModel'

def write(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(obj,indent=2,ensure_ascii=False),encoding='utf-8')

def lit(value):
    if isinstance(value,bool): value='true' if value else 'false'
    elif isinstance(value,(int,float)): value=str(value)+'D'
    else: value="'"+str(value).replace("'","''")+"'"
    return {'expr':{'Literal':{'Value':value}}}

def color(value): return {'solid':{'color':lit(value)}}

def field(table,name,measure=False):
    return {('Measure' if measure else 'Column'):{'Expression':{'SourceRef':{'Entity':table}},'Property':name}}

def projection(table,name,measure=False):
    labels={'ProductLabel':'SKU','ProductDescription':'Product','StockCode':'SKU','YearMonth':'Month','CalendarYear':'Year','LineStatus':'Transaction status','Signed Source Value':'Signed value (GBP)'}
    return {'field':field(table,name,measure),'queryRef':table+'.'+name,'nativeQueryRef':name,'displayName':labels.get(name,name),'active':True}

def visual(page,name,kind,x,y,w,h,title,roles=None,sort=None,objects=None):
    v={'visualType':kind,
       'visualContainerObjects':{
           'title':[{'properties':{'show':lit(True),'text':lit(title),'fontSize':lit(12),'bold':lit(True),'fontColor':color('#17324D')}}],
           'subTitle':[{'properties':{'show':lit(False)}}],
           'background':[{'properties':{'show':lit(True),'color':color('#FFFFFF'),'transparency':lit(0)}}],
           'border':[{'properties':{'show':lit(True),'color':color('#E2E8F0'),'radius':lit(8)}}],
           'padding':[{'properties':{'top':lit(12),'bottom':lit(12),'left':lit(14),'right':lit(14)}}]
       }}
    if roles: v['query']={'queryState':{role:{'projections':[projection(*p) for p in fields]} for role,fields in roles.items()}}
    if sort:
        v['query']['sortDefinition']={'sort':[{'field':field(*sort[0]),'direction':sort[1]}],'isDefaultSort':False}
    if kind=='tableEx':
        v['objects']={'grid':[{'properties':{'rowPadding':lit(2)}}],
            'values':[{'properties':{'fontSize':lit(10)}}],
            'columnHeaders':[{'properties':{'fontSize':lit(10)}}],
            'total':[{'properties':{'totals':lit(False)}}]}
    if objects: v.setdefault('objects',{}).update(objects)
    write(REPORT/f'definition/pages/{page}/visuals/{name}/visual.json',{
        '$schema':'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.4.0/schema.json',
        'name':name,'position':{'x':x,'y':y,'z':0,'width':w,'height':h,'tabOrder':y*10+x},'visual':v})

def text(page,name,x,y,w,h,value,size=14,ink='#64748B'):
    visual(page,name,'textbox',x,y,w,h,'',objects={'general':[{'properties':{'paragraphs':[
        {'textRuns':[{'value':value,'textStyle':{'fontFamily':'Segoe UI','fontSize':str(size)+'pt','color':ink}}]}]}}]})
    path=REPORT/f'definition/pages/{page}/visuals/{name}/visual.json'
    o=json.loads(path.read_text(encoding='utf-8'))
    o['visual']['visualContainerObjects']['title']=[{'properties':{'show':lit(False)}}]
    o['visual']['visualContainerObjects']['background']=[{'properties':{'show':lit(False)}}]
    o['visual']['visualContainerObjects']['border']=[{'properties':{'show':lit(False)}}]
    o['visual']['visualContainerObjects']['padding']=[{'properties':{'top':lit(0),'bottom':lit(0),'left':lit(0),'right':lit(0)}}]
    write(path,o)

def card(page,name,x,y,w,h,measure,title):
    is_percent=measure.endswith('Rate') or measure.endswith('Share')
    is_money=not is_percent and ('Sales' in measure or 'Value' in measure)
    visual(page,name,'card',x,y,w,h,title,{'Values':[('FactSalesLine',measure,True)]},objects={
        'labels':[{'properties':{'fontSize':lit(24 if is_money else 28),'color':color('#12324A'),'labelDisplayUnits':lit(1),'labelPrecision':lit(2 if is_money or is_percent else 0)}}],
        'categoryLabels':[{'properties':{'show':lit(False)}}]})

def page_header(page,title,subtitle,slicers=True):
    write(REPORT/f'definition/pages/{page}/page.json',{
        '$schema':'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json',
        'name':page,'displayName':title,'displayOption':'FitToPage','height':900,'width':1600,
        'objects':{'background':[{'properties':{'color':color('#F3F6FA'),'transparency':lit(0)}}]}})
    text(page,'heading',22,12,970,56,title,26,'#12324A')
    text(page,'subtitle',24,68,970,43,subtitle,11)
    if slicers:
        visual(page,'year_slicer','slicer',1016,18,200,88,'YEAR',{'Values':[('DimDate','CalendarYear',False)]},objects={'data':[{'properties':{'mode':lit('Dropdown')}}],'header':[{'properties':{'show':lit(False)}}]})
        visual(page,'country_slicer','slicer',1232,18,336,88,'COUNTRY',{'Values':[('DimCountry','Country',False)]},objects={'data':[{'properties':{'mode':lit('Dropdown')}}],'header':[{'properties':{'show':lit(False)}}]})

def build():
    if (MODEL/'.pbi/cache.abf').exists():
        raise RuntimeError('Use a fresh project clone without a native cache for regeneration. Do not overwrite a populated open project; preserve it first.')
    OUT.mkdir(parents=True,exist_ok=True)
    # Copy only report resources, never the native model cache or local credentials.
    if (SEED/'Seed.Report/StaticResources').exists():
        shutil.copytree(SEED/'Seed.Report/StaticResources',REPORT/'StaticResources',dirs_exist_ok=True)
    base_report=SEED/'Seed.Report/definition/report.json'
    if not base_report.exists(): base_report=REPORT/'definition/report.json'
    report=json.loads(base_report.read_text(encoding='utf-8-sig'))
    report['themeCollection']['customTheme']={'name':'SalesAnalyticsTheme','type':'RegisteredResources','reportVersionAtImport':{'visual':'2.14.0','report':'3.4.0','page':'2.3.1'}}
    report['resourcePackages']=[r for r in report.get('resourcePackages',[]) if r.get('name')!='RegisteredResources']
    report['resourcePackages'].append({'name':'RegisteredResources','type':'RegisteredResources','items':[{'name':'SalesAnalyticsTheme','path':'SalesAnalyticsTheme.json','type':'CustomTheme'}]})
    theme={'name':'SalesAnalyticsTheme','dataColors':['#087F8C','#17324D','#38A99B','#E8AA42','#7086A0','#B85B63'],
           'background':'#F3F6FA','foreground':'#17324D','tableAccent':'#087F8C',
           'textClasses':{'title':{'fontFace':'Segoe UI Semibold','fontSize':12,'color':'#17324D'},
                          'label':{'fontFace':'Segoe UI','fontSize':11,'color':'#475569'},
                          'callout':{'fontFace':'Segoe UI Semibold','fontSize':28,'color':'#17324D'}}}
    write(REPORT/'StaticResources/RegisteredResources/SalesAnalyticsTheme.json',theme)
    write(OUT/'sales-analytics-theme.json',theme)
    write(REPORT/'definition/report.json',report)
    version_source=SEED/'Seed.Report/definition/version.json'
    if not version_source.exists(): version_source=REPORT/'definition/version.json'
    write(REPORT/'definition/version.json',json.loads(version_source.read_text()))
    write(REPORT/'definition.pbir',{'version':'4.0','datasetReference':{'byPath':{'path':'../SalesAnalytics.SemanticModel'}}})
    write(OUT/'SalesAnalytics.pbip',{'version':'1.0','artifacts':[{'report':{'path':'SalesAnalytics.Report'}}],'settings':{'enableAutoRecovery':True}})
    write(MODEL/'definition.pbism',{'version':'1.0','settings':{}})

    schemas={
        'DimDate': [('DateKey','int64'),('CalendarDate','dateTime'),('CalendarYear','int64'),('MonthNumber','int64'),('YearMonth','string'),('MonthStart','dateTime'),('IsCompleteSourceMonth','boolean')],
        'DimProduct':[('ProductKey','int64'),('StockCode','string'),('ProductDescription','string'),('ProductLabel','string')],
        'DimCustomer':[('CustomerKey','int64'),('CustomerID','string'),('IsUnknown','boolean')],
        'DimCountry':[('CountryKey','int64'),('Country','string')],
        'FactSalesLine':[('SalesLineKey','int64'),('SourceSheet','string'),('SourceRowNumber','int64'),('DateKey','int64'),('ProductKey','int64'),('CustomerKey','int64'),('CountryKey','int64'),('InvoiceNumber','string'),('InvoiceDate','dateTime'),('Quantity','int64'),('UnitPrice','decimal'),('SignedLineValueGBP','decimal'),('IsCancellation','boolean'),('CodeType','string'),('ClassificationBasis','string'),('LineStatus','string'),('IsRepeatedLine','boolean')]
    }
    tables=[]
    for name,columns in schemas.items():
        cols=[]
        for col,typ in columns:
            c={'name':col,'dataType':typ,'sourceColumn':col,'summarizeBy':'none'}
            if col.endswith('Key') or col in ['SourceSheet','SourceRowNumber']:
                c['isHidden']=True
            if typ=='dateTime': c['formatString']='dd MMM yyyy'
            if typ=='decimal': c['formatString']='£#,0.00;(£#,0.00);£0.00'
            if name=='DimDate' and col=='CalendarDate': c['isKey']=True
            cols.append(c)
        table={'name':name,'columns':cols,'partitions':[{'name':name,'mode':'import','source':{'type':'m','expression':[
            'let', '    Source = Sql.Database("TELESTE\\RIJA_101", "SalesAnalyticsDB"),',
            f'    Data = Source{{[Schema="dbo",Item="{name}"]}}[Data]', 'in', '    Data']}}]}
        if name=='DimProduct':
            table['partitions'][0]['source']['expression']=[
                'let', '    Source = Sql.Database("TELESTE\\RIJA_101", "SalesAnalyticsDB"),',
                '    Data = Source{[Schema="dbo",Item="DimProduct"]}[Data],',
                '    Keyed = Table.AddColumn(Data, "FoldedCode", each Text.Upper([StockCode], "en-US"), type text),',
                '    Counts = Table.Group(Keyed, {"FoldedCode"}, {{"VariantCount", each Table.RowCount(_), Int64.Type}}),',
                '    Joined = Table.NestedJoin(Keyed, {"FoldedCode"}, Counts, {"FoldedCode"}, "Counts", JoinKind.LeftOuter),',
                '    Expanded = Table.ExpandTableColumn(Joined, "Counts", {"VariantCount"}),',
                '    Labeled = Table.AddColumn(Expanded, "ProductLabel", each if [VariantCount] > 1 then [StockCode] & " [variant " & Text.From([ProductKey]) & "]" else [StockCode], type text),',
                '    Result = Table.RemoveColumns(Labeled, {"FoldedCode", "VariantCount"})', 'in', '    Result']
        if name=='DimDate': table['dataCategory']='Time'
        tables.append(table)

    measures={
        'Gross Sales':('CALCULATE(SUM(FactSalesLine[SignedLineValueGBP]), KEEPFILTERS(FactSalesLine[LineStatus] = "MerchandiseSale"))','money','Sales'),
        'Cancellation Value':('-CALCULATE(SUM(FactSalesLine[SignedLineValueGBP]), KEEPFILTERS(FactSalesLine[LineStatus] = "MerchandiseCancellation"))','money','Sales'),
        'Net Merchandise Value':('[Gross Sales] - [Cancellation Value]','money','Sales'),
        'Purchase Orders':('CALCULATE(DISTINCTCOUNT(FactSalesLine[InvoiceNumber]), KEEPFILTERS(FactSalesLine[LineStatus] = "MerchandiseSale"))','integer','Orders'),
        'Average Order Value':('DIVIDE([Gross Sales], [Purchase Orders])','money','Orders'),
        'Known Customers':('CALCULATE(DISTINCTCOUNT(FactSalesLine[CustomerKey]), KEEPFILTERS(FactSalesLine[LineStatus] = "MerchandiseSale"), KEEPFILTERS(DimCustomer[IsUnknown] = FALSE()))','integer','Customers'),
        'Repeat Purchasers':('COUNTROWS(FILTER(CALCULATETABLE(VALUES(DimCustomer[CustomerKey]), KEEPFILTERS(DimCustomer[IsUnknown] = FALSE())), [Purchase Orders] >= 2))','integer','Customers'),
        'Repeat Purchaser Rate':('DIVIDE([Repeat Purchasers], [Known Customers])','percent','Customers'),
        'Anonymous Sales':('CALCULATE([Gross Sales], KEEPFILTERS(DimCustomer[IsUnknown] = TRUE()))','money','Customers'),
        'Anonymous Sales Share':('DIVIDE([Anonymous Sales], [Gross Sales])','percent','Customers'),
        'Cancellation Value Rate':('DIVIDE([Cancellation Value], [Gross Sales])','percent','Sales'),
        'Source Lines':('COUNTROWS(FactSalesLine)','integer','Data quality'),
        'Signed Source Value':('SUM(FactSalesLine[SignedLineValueGBP])','money','Data quality'),
        'Review Lines':('CALCULATE(COUNTROWS(FactSalesLine), KEEPFILTERS(FactSalesLine[LineStatus] = "ReviewCode"))','integer','Data quality'),
        'Repeated Sale Value':('CALCULATE([Gross Sales], KEEPFILTERS(FactSalesLine[IsRepeatedLine] = TRUE()))','money','Data quality'),
        'Top 10 Product Sales':('VAR TopProducts = TOPN(10, ALLSELECTED(DimProduct), [Gross Sales], DESC, DimProduct[StockCode], ASC) RETURN IF(CONTAINS(TopProducts, DimProduct[ProductKey], SELECTEDVALUE(DimProduct[ProductKey])), [Gross Sales])','money','Ranking'),
        'Top 10 Country Sales':('VAR TopCountries = TOPN(10, ALLSELECTED(DimCountry), [Gross Sales], DESC, DimCountry[Country], ASC) RETURN IF(CONTAINS(TopCountries, DimCountry[CountryKey], SELECTEDVALUE(DimCountry[CountryKey])), [Gross Sales])','money','Ranking'),
        'Comparable YoY Growth':('''VAR CurrentDates = CALCULATETABLE(VALUES(DimDate[CalendarDate]), KEEPFILTERS(DimDate[IsCompleteSourceMonth] = TRUE()))
VAR MatchedDates = FILTER(CurrentDates, VAR PriorDate = EDATE(DimDate[CalendarDate], -12) RETURN CALCULATE(COUNTROWS(DimDate), REMOVEFILTERS(DimDate), DimDate[CalendarDate] = PriorDate, DimDate[IsCompleteSourceMonth] = TRUE()) > 0)
VAR PriorDates = SELECTCOLUMNS(MatchedDates, "PriorDate", EDATE(DimDate[CalendarDate], -12))
VAR CurrentValue = CALCULATE([Gross Sales], REMOVEFILTERS(DimDate), TREATAS(MatchedDates, DimDate[CalendarDate]))
VAR PriorValue = CALCULATE([Gross Sales], REMOVEFILTERS(DimDate), TREATAS(PriorDates, DimDate[CalendarDate]))
RETURN DIVIDE(CurrentValue - PriorValue, PriorValue)''','percent','Time intelligence')
    }
    formats={'money':'£#,0.00;(£#,0.00);£0.00','integer':'#,0','percent':'0.00%;-0.00%;0.00%'}
    tables[-1]['measures']=[{'name':name,'expression':expr.splitlines(),'formatString':formats[fmt],'displayFolder':folder} for name,(expr,fmt,folder) in measures.items()]
    relationships=[{'name':'Fact_'+d,'fromTable':'FactSalesLine','fromColumn':key,'toTable':d,'toColumn':key,
                    'fromCardinality':'many','toCardinality':'one','crossFilteringBehavior':'oneDirection','isActive':True}
                   for d,key in [('DimDate','DateKey'),('DimProduct','ProductKey'),('DimCustomer','CustomerKey'),('DimCountry','CountryKey')]]
    write(MODEL/'model.bim',{'name':'SalesAnalytics','compatibilityLevel':1606,'model':{
        'culture':'en-GB','defaultPowerBIDataSourceVersion':'powerBI_V3','sourceQueryCulture':'en-GB',
        'tables':tables,'relationships':relationships,
        'annotations':[{'name':'__PBI_TimeIntelligenceEnabled','value':'0'}]}})
    (OUT/'measures.dax').write_text('\n\n'.join(f'// {folder}\n{name} =\n{expr}' for name,(expr,fmt,folder) in measures.items())+'\n',encoding='utf-8')

    p='overview'
    page_header(p,'Sales Performance Overview','GBP | Dec 2009–Dec 2011 | Merchandise scope; December 2011 is partial')
    for i,(measure,title) in enumerate([('Gross Sales','GROSS MERCHANDISE SALES'),('Net Merchandise Value','NET MERCHANDISE VALUE'),('Purchase Orders','PURCHASE ORDERS'),('Average Order Value','AVERAGE ORDER VALUE'),('Known Customers','KNOWN CUSTOMERS')]):
        card(p,'kpi_'+str(i),32+i*310,128,296,116,measure,title)
    visual(p,'monthly_sales','lineChart',32,268,918,300,'Monthly gross merchandise sales',{'Category':[('DimDate','YearMonth',False)],'Y':[('FactSalesLine','Gross Sales',True)]},(('DimDate','YearMonth',False),'Ascending'))
    visual(p,'country_sales','clusteredBarChart',974,268,594,300,'Top 10 customer-country labels',{'Category':[('DimCountry','Country',False)],'Y':[('FactSalesLine','Top 10 Country Sales',True)]},(('FactSalesLine','Top 10 Country Sales',True),'Descending'))
    visual(p,'product_table','tableEx',32,592,918,274,'Top 10 products by gross sales',{'Values':[('DimProduct','ProductLabel',False),('DimProduct','ProductDescription',False),('FactSalesLine','Top 10 Product Sales',True)]},(('FactSalesLine','Top 10 Product Sales',True),'Descending'))
    card(p,'repeat_rate',974,592,285,130,'Repeat Purchaser Rate','REPEAT KNOWN PURCHASERS')
    card(p,'cancel_rate',1283,592,285,130,'Cancellation Value Rate','CANCELLATION VALUE / SALES')
    text(p,'scope_note',974,746,594,120,'Scope: eligible merchandise lines. Separate discounts, shipping, fees and unresolved lines are excluded. Costs and original product categories are unavailable.',12)

    p='products_markets'
    page_header(p,'Products and Markets','Explore product concentration and customer-country performance | GBP')
    card(p,'gross',32,128,368,116,'Gross Sales','GROSS MERCHANDISE SALES')
    card(p,'orders',424,128,368,116,'Purchase Orders','PURCHASE ORDERS')
    card(p,'aov',816,128,368,116,'Average Order Value','AVERAGE ORDER VALUE')
    card(p,'cancellations',1208,128,360,116,'Cancellation Value','MERCHANDISE CANCELLATIONS')
    visual(p,'top_product_bars','clusteredBarChart',32,268,744,310,'Top 10 product codes',{'Category':[('DimProduct','ProductLabel',False)],'Y':[('FactSalesLine','Top 10 Product Sales',True)]},(('FactSalesLine','Top 10 Product Sales',True),'Descending'))
    visual(p,'top_countries','clusteredBarChart',800,268,768,310,'Top 10 customer-country labels',{'Category':[('DimCountry','Country',False)],'Y':[('FactSalesLine','Top 10 Country Sales',True)]},(('FactSalesLine','Top 10 Country Sales',True),'Descending'))
    visual(p,'monthly_comparison','tableEx',32,602,1536,264,'Monthly performance — YoY uses complete comparable months',{'Values':[('DimDate','YearMonth',False),('FactSalesLine','Gross Sales',True),('FactSalesLine','Cancellation Value',True),('FactSalesLine','Net Merchandise Value',True),('FactSalesLine','Comparable YoY Growth',True)]},(('DimDate','YearMonth',False),'Ascending'))

    p='customers_quality'
    page_header(p,'Customers and Data Quality','Known-customer behavior respects filters | Anonymous purchases remain in sales')
    for i,(measure,title) in enumerate([('Known Customers','KNOWN PURCHASING CUSTOMERS'),('Repeat Purchasers','REPEAT PURCHASERS'),('Repeat Purchaser Rate','REPEAT PURCHASER SHARE'),('Anonymous Sales','ANONYMOUS CUSTOMER SALES'),('Anonymous Sales Share','ANONYMOUS SALES SHARE')]):
        card(p,'customer_kpi_'+str(i),32+i*310,128,296,116,measure,title)
    visual(p,'monthly_customers','lineChart',32,268,918,300,'Known purchasing customers by month',{'Category':[('DimDate','YearMonth',False)],'Y':[('FactSalesLine','Known Customers',True)]},(('DimDate','YearMonth',False),'Ascending'))
    visual(p,'purpose_breakdown','tableEx',974,268,594,300,'Transaction status reconciliation — not product categories',{'Values':[('FactSalesLine','LineStatus',False),('FactSalesLine','Source Lines',True),('FactSalesLine','Signed Source Value',True)]},(('FactSalesLine','Source Lines',True),'Descending'))
    card(p,'review',32,592,440,130,'Review Lines','UNRESOLVED CODE LINES')
    card(p,'repeats',496,592,454,130,'Repeated Sale Value','RETAINED REPEATED SALE VALUE')
    text(p,'quality_note',974,592,594,255,'Repeated lines are retained as candidates for review, not automatically deleted. The unknown customer member is excluded from customer counts. RFM is a separate fixed-window SQL analysis: 10 Dec 2010–9 Dec 2011; see the SQL report. No profit or merchandise-category conclusions are inferred.',13)
    text(p,'source_credit',32,752,918,100,'Source: UCI Online Retail II — Chen (2012), CC BY 4.0. Historical portfolio analysis. Figures follow documented eligibility and worksheet-overlap rules.',12)

    pages=['overview','products_markets','customers_quality']
    write(REPORT/'definition/pages/pages.json',{'$schema':'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json','pageOrder':pages,'activePageName':'overview'})
    print(f'Prepared project with {len(tables)} SQL import tables, {len(relationships)} relationships, {len(measures)} measures and {len(pages)} pages. Native refresh and visual verification pending.')

if __name__=='__main__': build()
