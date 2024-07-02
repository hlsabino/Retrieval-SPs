USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_ARALAnalysis]
	@IsReceivable [bit],
	@IsConsolidated [bit],
	@ShowAdjustments [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@GTPQuery [nvarchar](max),
	@GTPWhere [nvarchar](max),
	@StatusWhere [nvarchar](200),
	@DIMWHERE [nvarchar](max),
	@IncludePDC [bit],
	@IncludeTerminatedPDC [bit],
	@PDCOnConveredDate [bit],
	@CollectionOn [nvarchar](20),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
	DECLARE @SQL NVARCHAR(MAX),@AccID NVARCHAR(20),@AccIDAlias NVARCHAR(20),@TEMPSQL NVARCHAR(MAX)
	DECLARE	@From NVARCHAR(20),@To NVARCHAR(20),@PDCAdjustWhere NVARCHAR(MAX)
	CREATE TABLE #TblBills(DocNo NVARCHAR(50),DocSeqNo int, CONSTRAINT [PK_ABC] PRIMARY KEY CLUSTERED([DocNo] ASC,[DocSeqNo] ASC))
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	
	if @IsConsolidated=0
	begin
		set @AccID='B.AccountID,'
		set @AccIDAlias='AccountID,'
	end
	else
	begin
		set @AccID=''
		set @AccIDAlias=''
	end
	
	--Ignore PDC Conversion Date If Viewving on Maturity Date
	if @PDCOnConveredDate=1 and @CollectionOn!='DocDate'
		set @PDCOnConveredDate=0

	if (@IncludePDC=1)
	begin
		declare @Temp nvarchar(200)
		SET @Temp='(B.StatusID=370 OR B.StatusID=439'
		IF @IncludeTerminatedPDC=1
			SET @Temp=@Temp+' OR B.StatusID=452'
		SET @Temp=@Temp+')'
		set @PDCAdjustWhere=' AND  ('+@Temp+' OR (B.DocType<>14 AND B.DocType<>19 '+replace(@StatusWhere,'StatusID','B.StatusID')+'))'
	end
	else
		set @PDCAdjustWhere=' AND B.DocType<>14 AND B.DocType<>19 '+replace(@StatusWhere,'StatusID','B.StatusID')

	/******* Amount *********/
	set @SQL='select '+@AccID
	if(@PDCOnConveredDate=1)
		set @SQL=@SQL+'year(convert(datetime,isnull(B.ConvertedDate,B.DocDate))) Yr,month(convert(datetime,isnull(B.ConvertedDate,B.DocDate))) Mn'
	else
		set @SQL=@SQL+'year(convert(datetime,DocDate)) Yr,month(convert(datetime,DocDate)) Mn'
	set @SQL=@SQL+',abs(SUM(AdjAmount)) Amount' 
	
	SET @TEMPSQL=' from COM_Billwise B with(nolock)'+@GTPQuery
	set @TEMPSQL=@TEMPSQL+'
	 where '
	if(@IsReceivable=1)
		set @TEMPSQL=@TEMPSQL+' AdjAmount>0'
	else
		set @TEMPSQL=@TEMPSQL+' AdjAmount<0'
	set @TEMPSQL=@TEMPSQL+@DIMWHERE
	if(@PDCOnConveredDate=1)
		set @TEMPSQL=@TEMPSQL+' AND isnull(B.ConvertedDate,B.DocDate)>='+@From+' AND isnull(B.ConvertedDate,B.DocDate)<='+@To
	else
		set @TEMPSQL=@TEMPSQL+' AND B.DocDate>='+@From+' AND B.DocDate<='+@To
	if len(@GTPWhere)>0
		set @TEMPSQL=@TEMPSQL+' AND B.'+@GTPWhere
	set @TEMPSQL=@TEMPSQL+@PDCAdjustWhere
	
	SET @SQL=@SQL+@TEMPSQL
	if(@PDCOnConveredDate=1)
		set @SQL=@SQL+' 
    Group By '+@AccID+'year(convert(datetime,isnull(B.ConvertedDate,B.DocDate))),month(convert(datetime,isnull(B.ConvertedDate,B.DocDate)))'
    else
		set @SQL=@SQL+' 
    Group By '+@AccID+'year(convert(datetime,DocDate)),month(convert(datetime,DocDate))'
   -- print(@SQL)
	EXEC(@SQL)
	
	SET @SQL='SELECT B.DocNo,B.DocSeqNo '+@TEMPSQL+' GROUP BY B.DocNo,B.DocSeqNo'
	--PRINT(@SQL)
	INSERT INTO #TblBills
	EXEC(@SQL)
	
	
		
	/******* UnAdjusted Amount *********/
	SET @SQL='select '+@AccIDAlias+'year(convert(datetime,DocDate)) Yr,month(convert(datetime,DocDate)) Mn,abs(SUM(Amount)) Amount
	from (
	select '+@AccID
	if(@PDCOnConveredDate=1)
		set @SQL=@SQL+'isnull(B.ConvertedDate,B.DocDate) DocDate'
	else
		set @SQL=@SQL+'B.DocDate'
		
	set @SQL=@SQL+',AdjAmount+isnull((select sum(AdjAmount) from COM_Billwise CB with(nolock) where CB.RefDocNo=B.DocNo and CB.RefDocSeqNo=B.DocSeqNo '
	
	if @CollectionOn='DocDate'
		set @SQL=@SQL+' AND CB.DocDate>='+@From+' AND CB.DocDate<='+@To
	else if @CollectionOn='ChequeMaturityDate'
		set @SQL=@SQL+' AND isnull((SELECT top(1) ChequeMaturityDate FROM ACC_DocDetails ACC WITH(NOLOCK) WHERE ACC.VoucherNo=CB.DocNo),cb.DocDate) BETWEEN '+@From+' AND '+@To
	else if @CollectionOn='ConvertedOn'
		set @SQL=@SQL+' AND (SELECT top(1) CPDC.DocDate FROM ACC_DocDetails ACC WITH(NOLOCK) 
	inner join ACC_DocDetails CPDC with(nolock) ON CPDC.RefCCID=400 AND CPDC.refnodeid=ACC.AccDocDetailsID 
	WHERE ACC.VoucherNo=CB.DocNo and CPDC.CostCenterID=(select ConvertAS from ADM_DocumentTypes D with(nolock) where d.CostCenterID=ACC.CostCenterID ))
	 BETWEEN '+@From+' AND '+@To
	
	SET @SQL=@SQL+replace(@PDCAdjustWhere,'B.','CB.')+'),0) Amount
from COM_Billwise B with(nolock)'
    SET @SQL=@SQL+@GTPQuery
	SET @SQL=@SQL+' where IsNewReference=1'+@DIMWHERE
	if(@IsReceivable=1)
		set @SQL=@SQL+' and AdjAmount<0'
	else
		set @SQL=@SQL+' and AdjAmount>0'
		
	if(@PDCOnConveredDate=1)
		set @SQL=@SQL+' AND isnull(B.ConvertedDate,B.DocDate)>='+@From+' AND isnull(B.ConvertedDate,B.DocDate)<='+@To
	else
		set @SQL=@SQL+' AND B.DocDate>='+@From+' AND B.DocDate<='+@To
	--SET @SQL=@SQL+' AND B.DocDate>='+@From+' AND B.DocDate<='+@To
	
	if len(@GTPWhere)>0
		SET @SQL=@SQL+' AND B.'+@GTPWhere
	SET @SQL=@SQL+@PDCAdjustWhere
	SET @SQL=@SQL+') as T'
	SET @SQL=@SQL+' Group By '+@AccIDAlias+'year(convert(datetime,DocDate)),month(convert(datetime,DocDate))'
  --   print(@SQL)
	EXEC(@SQL)

	
	/******* Collection Details *********/
	
	DECLARE @FromWHERE NVARCHAR(50),@ToWHERE NVARCHAR(50)
	if(@PDCOnConveredDate=1)
	begin
		set @FromWHERE=' AND isnull(CB.ConvertedDate,CB.DocDate)>='+@From
		set @ToWHERE=' AND isnull(CB.ConvertedDate,CB.DocDate)<='+@To
	end
	else
	begin
		set @FromWHERE=' AND CB.DocDate>='+@From
		set @ToWHERE=' AND CB.DocDate<='+@To
	end

	if @AccID!=''
		set @AccID='CB.AccountID,'
		
		
	if @CollectionOn='DocDate'
	begin
		set @SQL='select '+@AccID+'year(convert(datetime,CB.RefDocDate)) Yr,month(convert(datetime,CB.RefDocDate)) Mn'
		
		if(@PDCOnConveredDate=1)
			set @SQL=@SQL+',year(convert(datetime,isnull(CB.ConvertedDate,CB.DocDate))) CYr,month(convert(datetime,isnull(CB.ConvertedDate,CB.DocDate))) CMn'
		else
			set @SQL=@SQL+',year(convert(datetime,CB.DocDate)) CYr,month(convert(datetime,CB.DocDate)) CMn'
			
		set @SQL=@SQL+',abs(CB.AdjAmount) Amount from COM_Billwise CB with(nolock)
		inner join #TblBills B ON CB.RefDocNo collate database_default=B.DocNo and CB.RefDocSeqNo=B.DocSeqNo'
		
		set @SQL=@SQL+'
		 where CB.IsNewReference=0'
			
		set @SQL=@SQL+replace(@PDCAdjustWhere,'B.','CB.')
	
		IF @ShowAdjustments=0 OR @ShowAdjustments=2
			set @SQL=@SQL+@FromWHERE
		
		IF @ShowAdjustments=0 OR @ShowAdjustments=1
			set @SQL=@SQL+@ToWHERE
		
		set @TEMPSQL='select '+@AccID+'year(convert(datetime,CB.DocDate)) Yr,month(convert(datetime,CB.DocDate)) Mn'
		
		if(@PDCOnConveredDate=1)
			set @TEMPSQL=@TEMPSQL+',year(convert(datetime,isnull(CB.ConvertedDate,CB.RefDocDate))) CYr,month(convert(datetime,isnull(CB.ConvertedDate,CB.RefDocDate))) CMn'
		else
			set @TEMPSQL=@TEMPSQL+',year(convert(datetime,CB.RefDocDate)) CYr,month(convert(datetime,CB.RefDocDate)) CMn'
			
		set @TEMPSQL=@TEMPSQL+',abs(CB.AdjAmount) Amount from COM_Billwise CB with(nolock)
		inner join #TblBills B ON CB.DocNo collate database_default=B.DocNo and CB.DocSeqNo=B.DocSeqNo'
		
		set @TEMPSQL=@TEMPSQL+'
		 where CB.IsNewReference=0'
			
		set @TEMPSQL=@TEMPSQL+replace(@PDCAdjustWhere,'B.','CB.')

		IF @ShowAdjustments=0 OR @ShowAdjustments=2
			set @TEMPSQL=@TEMPSQL+replace(@FromWHERE,'.DocDate','.RefDocDate')
		
		IF @ShowAdjustments=0 OR @ShowAdjustments=1
			set @TEMPSQL=@TEMPSQL+replace(@ToWHERE,'.DocDate','.RefDocDate')
		
		SET @SQL='SELECT '+@AccIDAlias+'Yr,Mn,CYr,CMn,SUM(Amount) Amount FROM ('+@SQL
		SET @SQL=@SQL+'
		UNION ALL
		'+@TEMPSQL
		SET @SQL=@SQL+') AS T GROUP BY '+@AccIDAlias+'Yr,Mn,CYr,CMn'
		
		--PRINT(@SQL)		
		EXEC(@SQL)
		
		/*set @SQL='select C'+@AccID+'year(convert(datetime,B.DocDate)) Yr,month(convert(datetime,B.DocDate)) Mn'
		if(@PDCOnConveredDate=1)
			set @SQL=@SQL+',year(convert(datetime,isnull(CB.ConvertedDate,CB.DocDate))) CYr,month(convert(datetime,isnull(CB.ConvertedDate,CB.DocDate))) CMn'
		else
			set @SQL=@SQL+',year(convert(datetime,CB.DocDate)) CYr,month(convert(datetime,CB.DocDate)) CMn'
		set @SQL=@SQL+',abs(SUM(CB.AdjAmount)) Amount from COM_Billwise CB with(nolock)
		inner join (SELECT B.DocNo,B.DocSeqNo,B.DocDate FROM COM_Billwise B with(nolock)'+@GTPQuery+'
WHERE B.DocDate>='+@From+' AND B.DocDate<='+@To+@DIMWHERE+@PDCAdjustWhere
		if len(@GTPWhere)>0
			set @SQL=@SQL+' AND B.'+@GTPWhere
		set @SQL=@SQL+' GROUP BY B.DocNo,B.DocSeqNo,B.DocDate) B on CB.RefDocNo=B.DocNo and CB.RefDocSeqNo=B.DocSeqNo'
		
		set @SQL=@SQL+'
		 where CB.IsNewReference=0'
		--if @IsReceivable=1
		--	set @SQL=@SQL+' and B.AdjAmount>0'
		--else
		--	set @SQL=@SQL+' and B.AdjAmount<0'
			
		set @SQL=@SQL+replace(@PDCAdjustWhere,'B.','CB.')
		if(@PDCOnConveredDate=1)
			set @SQL=@SQL+' AND isnull(CB.ConvertedDate,CB.DocDate)>='+@From+' AND isnull(CB.ConvertedDate,CB.DocDate)<='+@To
		else
			set @SQL=@SQL+' AND CB.DocDate>='+@From+' AND CB.DocDate<='+@To
		--if len(@GTPWhere)>0
		--	set @SQL=@SQL+' AND B.'+@GTPWhere
		if(@PDCOnConveredDate=1)
			set @SQL=@SQL+'
		 Group By C'+@AccID+'year(convert(datetime,B.DocDate)),month(convert(datetime,B.DocDate)),year(convert(datetime,isnull(CB.ConvertedDate,CB.DocDate))),month(convert(datetime,isnull(CB.ConvertedDate,CB.DocDate)))'
		else
			set @SQL=@SQL+'
		 Group By C'+@AccID+'year(convert(datetime,B.DocDate)),month(convert(datetime,B.DocDate)),year(convert(datetime,CB.DocDate)),month(convert(datetime,CB.DocDate))'
		print(@SQL)
		EXEC(@SQL)*/
	end
	else
	begin
		set @SQL='select '+@AccID+'CB.RefDocDate DocDate'
		set @SQL=@SQL+',isnull((SELECT top(1) ChequeMaturityDate FROM ACC_DocDetails ACC WITH(NOLOCK) WHERE ACC.VoucherNo=CB.DocNo),CB.DocDate) CDATE'
		set @SQL=@SQL+',abs(CB.AdjAmount) Amount from COM_Billwise CB with(nolock)
		inner join #TblBills B ON CB.RefDocNo collate database_default=B.DocNo and CB.RefDocSeqNo=B.DocSeqNo'
		set @SQL=@SQL+'
		 where CB.IsNewReference=0'
		set @SQL=@SQL+replace(@PDCAdjustWhere,'B.','CB.')
		
		set @TEMPSQL='select '+@AccID+'CB.DocDate'
		set @TEMPSQL=@TEMPSQL+',isnull((SELECT top(1) ChequeMaturityDate FROM ACC_DocDetails ACC WITH(NOLOCK) WHERE ACC.VoucherNo=CB.RefDocNo),CB.RefDocDate) CDATE'
		set @TEMPSQL=@TEMPSQL+',abs(CB.AdjAmount) Amount from COM_Billwise CB with(nolock)
		inner join #TblBills B ON CB.DocNo collate database_default=B.DocNo and CB.DocSeqNo=B.DocSeqNo'
		set @TEMPSQL=@TEMPSQL+'
		 where CB.IsNewReference=0'
		set @TEMPSQL=@TEMPSQL+replace(@PDCAdjustWhere,'B.','CB.')
		
		SET @SQL=@SQL+'
		UNION ALL
		'+@TEMPSQL
		
		SET @TEMPSQL=@SQL
		
		--PRINT(@TEMPSQL)
		
		
		set @SQL='select '+@AccIDAlias+'year(convert(datetime,DocDate)) Yr,month(convert(datetime,DocDate)) Mn
,year(convert(datetime,CDATE)) CYr,month(convert(datetime,CDATE)) CMn,sum(Amount) Amount 
 from
('
		set @SQL=@SQL+@TEMPSQL+'
)
as t'
		set @SQL=@SQL+' where 1=1 '

		IF @ShowAdjustments=0 OR @ShowAdjustments=2
			set @SQL=@SQL+' AND CDATE>='+@From
		
		IF @ShowAdjustments=0 OR @ShowAdjustments=1
			set @SQL=@SQL+' AND CDATE<='+@To

		set @SQL=@SQL+'
Group By '+@AccIDAlias+'year(convert(datetime,DocDate)),month(convert(datetime,DocDate)),year(convert(datetime,CDATE)),month(convert(datetime,CDATE))'
		 
		--print(@SQL)
		EXEC(@SQL)
		
		/*set @SQL='select '+@AccIDAlias+'year(convert(datetime,DocDate)) Yr,month(convert(datetime,DocDate)) Mn
,year(convert(datetime,CDATE)) CYr,month(convert(datetime,CDATE)) CMn,sum(abs(AdjAmount)) Amount 
 from
(select '+@AccID+'B.DocDate,CB.AdjAmount'
		if @CollectionOn='ChequeMaturityDate'
			set @SQL=@SQL+',isnull((SELECT top(1) ChequeMaturityDate FROM ACC_DocDetails ACC WITH(NOLOCK) WHERE ACC.VoucherNo=CB.DocNo),cb.DocDate) CDATE'
		else
			set @SQL=@SQL+',(SELECT top(1) CPDC.DocDate FROM ACC_DocDetails ACC WITH(NOLOCK) 
	inner join ACC_DocDetails CPDC with(nolock) ON CPDC.RefCCID=400 AND CPDC.refnodeid=ACC.AccDocDetailsID 
	WHERE ACC.VoucherNo=CB.DocNo and CPDC.CostCenterID=(select ConvertAS from ADM_DocumentTypes D with(nolock) where d.CostCenterID=ACC.CostCenterID )) CDATE'
		
		set @SQL=@SQL+' from COM_Billwise CB with(nolock)
		inner join (SELECT B.DocNo,B.DocSeqNo,B.DocDate FROM COM_Billwise B with(nolock)'+@GTPQuery+'
WHERE B.DocDate>='+@From+' AND B.DocDate<='+@To+@DIMWHERE+@PDCAdjustWhere
		if len(@GTPWhere)>0
			set @SQL=@SQL+' AND B.'+@GTPWhere
		set @SQL=@SQL+' GROUP BY B.DocNo,B.DocSeqNo,B.DocDate) B on CB.RefDocNo=B.DocNo and CB.RefDocSeqNo=B.DocSeqNo'
		
		set @SQL=@SQL+'
		 where CB.IsNewReference=0'
		--if @IsReceivable=1
		--	set @SQL=@SQL+' and B.AdjAmount>0'
		--else
		--	set @SQL=@SQL+' and B.AdjAmount<0'

		set @SQL=@SQL+replace(@PDCAdjustWhere,'B.','CB.')

		set @SQL=@SQL+')
as t
where CDATE>='+@From+' AND CDATE<='+@To+' 
Group By '+@AccIDAlias+'year(convert(datetime,DocDate)),month(convert(datetime,DocDate)),year(convert(datetime,CDATE)),month(convert(datetime,CDATE))'
		 
		print(@SQL)
		EXEC(@SQL)*/
	end
	
	
	if @IsConsolidated=0
	begin
		set @SQL='select A.AccountID,A.AccountName from ACC_Accounts A with(nolock)'
		set @SQL=@SQL+@GTPQuery
		set @SQL=@SQL+' where A.IsGroup=0 AND A.AccountID>0'
		if len(@GTPWhere)>0
			set @SQL=@SQL+' AND A.'+@GTPWhere
		set @SQL=@SQL+' ORDER BY A.AccountName'
		EXEC(@SQL)
	end
	else
		select 1 AccountName where 1<>1
		
	DROP TABLE #TblBills

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
