USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetCommonReport]
	@FromDate [datetime],
	@ToDate [datetime],
	@ReportID [int],
	@strSeqNos [nvarchar](max) = NULL,
	@Select [nvarchar](max) = null,
	@SelectAlias [nvarchar](max) = null,
	@strCCJoin [nvarchar](max) = null,
	@strCCWhere [nvarchar](max) = null,
	@OptionsXML [nvarchar](max) = null,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;      
  DECLARE @SQL NVARCHAR(MAX),@DateFilter nvarchar(max)
  
 DECLARE @From FLOAT,@To FLOAT  
  
 SET @From=CONVERT(FLOAT,@FromDate)  
 SET @To=CONVERT(FLOAT,@ToDate)  

IF (@ReportID=150)
BEGIN
if @OptionsXML='ModifiedDate'
	set @DateFilter=' AND ACC.ModifiedDate>='+Convert(nvarchar,@From) +' and ACC.ModifiedDate<=' +convert(nvarchar,@To+1)
else
	set @DateFilter=' AND ACC.DocDate>='+Convert(nvarchar,@From) +' and ACC.DocDate<=' +convert(nvarchar,@To)

	SET @SQL=' SELECT row_number() over (order by ACC.DocDate) SLNO, CONVERT(DATETIME,ACC.DocDate) Year ,
ACC.VoucherNo VoucherNo, CONVERT(DATETIME,ACC.DocDate) DocDate,
CONVERT(DATETIME,ACC.ModifiedDate) ModifiedDate,
T1.DocumentAbbr DocumentAbbr, ACC.ModifiedBy CreatedBy,0.00 OldAmount,
sum(ACC.StockValue) NewAmount, 0.00 OldQuantity, sum(ACC.QUANTITY) NewQuantity,--0.00 OldRate, UnitPrice,
ACC.HistoryStatus,ACC.DOCID ,  '''' DebitAccountOldvalue,  dacc.AccountCode DebitAccountnewvalue,
'''' CreditAccountOldvalue,  cacc.AccountCode CreditAccountnewvalue, acc.docseqno 
,  '''' DebitAccountNameOldvalue,  dacc.AccountName DebitAccountNamenewvalue,
'''' CreditAccountNameOldvalue,  cacc.AccountName CreditAccountNamenewvalue
,	'''' OldProductCode,  p.ProductCode NewProductCode , 
'''' OldProductName,  p.ProductName NewProductName'+@Select+'
FROM INV_DocDetails_History ACC with(nolock) '+@strCCJoin+'
inner join ADM_DocumentTypes T1 with(nolock) on acc.costcenterid=t1.costcenterid
LEFT JOIN INV_PRODUCT P with(nolock) ON ACC.PRODUCTID=P.PRODUCTID
left join ACC_Accounts dacc with(nolock) on acc.DebitAccount=dacc.accountid
left join ACC_Accounts Cacc with(nolock) on acc.CreditAccount=cacc.accountid
WHERE ACC.CostCenterID=ACC.CostCenterID   '+@strSeqNos+@strCCWhere+@DateFilter+'
group by acc.docdate,acc.voucherno, acc.ModifiedDate,T1.DocumentAbbr, ACC.ModifiedBy,
ACC.HistoryStatus ,  ACC.DOCID ,  acc.docseqno, dacc.AccountCode,cacc.AccountCode,dacc.AccountName,cacc.AccountName
,p.productcode, p.productname'+@SelectAlias+'
union all
SELECT row_number() over (order by ACC.DocDate) SLNO,  CONVERT(DATETIME,ACC.DocDate) Year ,
ACC.VoucherNo VoucherNo, CONVERT(DATETIME,ACC.DocDate) DocDate,
CONVERT(DATETIME,ACC.ModifiedDate) ModifiedDate,
T1.DocumentAbbr DocumentAbbr, ACC.ModifiedBy CreatedBy,0.00 OldAmount,
sum(ACC.Amount) NewAmount,  0.00 OldQty, 0.00 NewQuantity,
ACC.HistoryStatus,ACC.DOCID , '''' DebitAccountOldvalue,  dacc.AccountCode DebitAccountnewvalue,
'''' CreditAccountOldvalue,  cacc.AccountCode CreditAccountnewvalue ,  acc.docseqno 
	,  '''' DebitAccountNameOldvalue,  dacc.AccountName DebitAccountNamenewvalue,
'''' CreditAccountNameOldvalue,  cacc.AccountName CreditAccountNamenewvalue 
,'''' OldProductCode,  ''''  NewProductCode , 
'''' OldProductName,  ''''  NewProductName'+@Select+'
FROM ACC_DocDetails_History ACC with(nolock) '+replace(@strCCJoin,'.InvDocDetailsID','.AccDocDetailsID')+'
inner join ADM_DocumentTypes T1 with(nolock) on acc.costcenterid=t1.costcenterid
left join ACC_Accounts dacc with(nolock) on acc.DebitAccount=dacc.accountid
left join ACC_Accounts Cacc with(nolock) on acc.CreditAccount=cacc.accountid
WHERE ACC.CostCenterID=ACC.CostCenterID   '+@strSeqNos+replace(@strCCWhere,'.InvDocDetailsID','.AccDocDetailsID')+@DateFilter+'
group by acc.docdate,acc.voucherno, acc.ModifiedDate,T1.DocumentAbbr, ACC.ModifiedBy,
ACC.HistoryStatus ,  ACC.DOCID  ,  acc.docseqno, dacc.AccountCode,cacc.AccountCode,dacc.AccountName,cacc.AccountName'+@SelectAlias+'
--	order by acc.docdate,acc.voucherno'
 	print (@SQL) 
	EXEC (@SQL)   
END
ELSE IF (@ReportID=207)
BEGIN
	SET @SQL='
select *
,convert(xml,PreXML).value(''/XML[1]/@StartDate'',''datetime'') StartDate
,convert(xml,PreXML).value(''/XML[1]/@EndDate'',''datetime'') EndDate
,convert(xml,PreXML).value(''/XML[1]/@Months'',''int'') [Mns]
from
(
select D.AccDocDetailsID,convert(datetime,D.DocDate) DocDate,D.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber
,DA.AccountName DrMainAccName,CA.AccountName CrMainAccName
,D.Amount TotalAmount,D.CommonNarration,D.LineNarration
,D.DocumentType,D.[Description] PreXML'+@Select+'
FROM ACC_DocDetails D with(nolock) 
join ACC_Accounts DA with(nolock) on D.DebitAccount=DA.AccountID
join ACC_Accounts CA with(nolock) on D.CreditAccount=CA.AccountID'+@strCCJoin+'
where D.RefCCID=0 and D.[Description] is not null and D.DocumentType in (15,18,22,23)'+@strCCWhere+'

union

select D.DocID AccDocDetailsID,convert(datetime,D.DocDate) DocDate,D.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber
,DA.AccountName DrMainAccName,CA.AccountName CrMainAccName
,D.Net TotalAmount,D.CommonNarration,D.LineNarration
,D.DocumentType,D.[Description] PreXML'+@Select+'
FROM INV_DocDetails D with(nolock) 
join ACC_Accounts DA with(nolock) on D.DebitAccount=DA.AccountID
join ACC_Accounts CA with(nolock) on D.CreditAccount=CA.AccountID'+REPLACE(@strCCJoin,'AccDocDetailsID','InvDocDetailsID')+'
where D.RefCCID=0 and D.[Description] is not null and D.DocumentType in (1,11)'+@strCCWhere+'
) AS T
where convert(float,convert(xml,PreXML).value(''/XML[1]/@StartDate'',''datetime'')) between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)+'

order by DocDate,DocAbbr,DocPrefix,DocNumber

select T.AccDocDetailsID,convert(datetime,D.DocDate) DocDate,D.VoucherNo,sum(Amount) Amount
,DA.AccountName DrAccName,CA.AccountName CrAccName
from ACC_DocDetails D with(nolock)
join ACC_Accounts DA with(nolock) on D.DebitAccount=DA.AccountID
join ACC_Accounts CA with(nolock) on D.CreditAccount=CA.AccountID
join (
select AccDocDetailsID from
(
select convert(xml,D.[Description]) PreXML,D.AccDocDetailsID
FROM ACC_DocDetails D with(nolock) '+@strCCJoin+'
where D.[Description] is not null and D.DocumentType in (15,18,22,23)'+@strCCWhere+'
) AS T
where convert(float,PreXML.value(''/XML[1]/@StartDate'',''datetime'')) between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)+'
) AS T on D.RefCCID=400 and D.RefNodeID=T.AccDocDetailsID
where D.InvDocDetailsID is null
group by T.AccDocDetailsID,D.DocDate,D.VoucherNo,DA.AccountName,CA.AccountName
union
select T.AccDocDetailsID,convert(datetime,D.DocDate) DocDate,D.VoucherNo,sum(Amount) Amount
,DA.AccountName DrAccName,CA.AccountName CrAccName
from ACC_DocDetails D with(nolock)
join ACC_Accounts DA with(nolock) on D.DebitAccount=DA.AccountID
join ACC_Accounts CA with(nolock) on D.CreditAccount=CA.AccountID
join (
select AccDocDetailsID from
(
select convert(xml,D.[Description]) PreXML,D.DocID AccDocDetailsID
FROM INV_DocDetails D with(nolock) '+REPLACE(@strCCJoin,'AccDocDetailsID','InvDocDetailsID')+'
where D.[Description] is not null and D.DocumentType in (1,11)'+@strCCWhere+'
) AS T
where convert(float,PreXML.value(''/XML[1]/@StartDate'',''datetime'')) between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)+'
) AS T on D.RefCCID=300 and D.RefNodeID=T.AccDocDetailsID
where D.InvDocDetailsID is null and D.DocumentType in (15,18,22,23)
group by T.AccDocDetailsID,D.DocDate,D.VoucherNo,DA.AccountName,CA.AccountName

order by AccDocDetailsID,DrAccName,CrAccName,VoucherNo'
 	--print (@SQL) 
	EXEC (@SQL)  
END
ELSE IF (@ReportID=203 or @ReportID=204)
BEGIN
	DECLARE @CCID INT
	select @CCID=CONVERT(INT,Value) from COM_CostCenterPreferences P with(nolock) where name='BinsDimension' and isnumeric(Value)=1
	select @SQL=TableName from ADM_Features with(nolock) where FeatureID=@CCID
	
	SET @SQL='
	select P.ProductCode,P.ProductName,BIN.Code BinCode,BIN.Name BinName,sum(B.Quantity*D.UOMConversion*B.VoucherType) Qty'+@Select+'
from INV_BinDetails B with(nolock)  
join '+@SQL+' BIN with(nolock) on BIN.NodeID=B.BinID  
join INV_DocDetails D with(nolock) on D.InvDocDetailsID=B.InvDocDetailsID  
join INV_Product P with(nolock) on P.ProductID=D.ProductID  
'+@strCCJoin+'
where D.IsQtyIgnored=0 AND D.DocDate<='+convert(nvarchar,@To)+REPLACE(@strCCWhere,'DCC.dcCCNID'+CONVERT(NVARCHAR,(@CCID-50000)),'B.BinID')+'
group by P.ProductCode,P.ProductName,BIN.Code,BIN.Name'+@SelectAlias+'
order by '+@OptionsXML+',BIN.Code'
 print (@SQL) 
	EXEC (@SQL)  
END
ELSE IF @ReportID=299
BEGIN
--,case when BT.BatchID>1 then BT.BatchNumber else null end BatchNumber
--,case when BT.BatchID>1 then convert(datetime,BT.ExpiryDate) else null end ExpiryDate
--join INV_Batches BT with(nolock) on BT.BatchID=D.BatchID
--,BT.BatchID,BT.BatchNumber,BT.ExpiryDate
--,BT.BatchNumber,BT.ExpiryDate
	SET @SQL='select F.Name DocName,R.ResourceData FieldName,L.ListViewName,L.SearchFilter from adm_costcenterdef C with(nolock)
join adm_listView L with(nolock) on L.CostCenterID=C.ColumnCostCenterID and L.ListViewTypeID=C.ColumnCCListViewTypeID
join adm_Features F with(nolock) on C.CostCenterID=F.FeatureID
join COM_LanguageResources R with(nolock) on R.ResourceID=C.ResourceID and R.LanguageID=1
where ColumnCostCenterID>0'+@strCCWhere+' and C.ColumnCostCenterID!=12 and ColumnCCListViewTypeID>0 and IsColumnInUse=1
order by DocName,R.ResourceData'
 print (@SQL) 
	EXEC (@SQL)  
END


SET NOCOUNT OFF;      
RETURN 1    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
SET NOCOUNT OFF      
RETURN -999       
END CATCH      
GO
