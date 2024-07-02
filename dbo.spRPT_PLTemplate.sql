USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_PLTemplate]
	@TemplateID [int],
	@TemplateTable [nvarchar](20),
	@IsWEF [bit],
	@FromDate [datetime],
	@ToDate [datetime],
	@IncludeOpening [bit],
	@Show [int],
	@YTDIndex [int],
	@LMIndex [int],
	@BAL_LYIndex [int],
	@YTD_LYIndex [int],
	@COLXML [nvarchar](max),
	@UnPostedDocsList [nvarchar](80),
	@DimensionFilter [nvarchar](max),
	@AccountsLocationWise [nvarchar](max),
	@ZeroBalanceAccounts [bit],
	@IncludePDC [bit],
	@IncludeTerminatedPDC [bit],
	@CurrencyType [int],
	@CurrencyID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
	declare @SQL NVARCHAR(MAX),@FSQL NVARCHAR(MAX),@FTEMPSQL NVARCHAR(MAX),@AmtColumn NVARCHAR(10),@CurrWHERE1 NVARCHAR(30)
	declare @strM1 nvarchar(max),@strM2 nvarchar(100),@strM3 nvarchar(100),@strM4 nvarchar(100),@strFY1 nvarchar(100)
	declare @strWEF1 nvarchar(50),@strWEF2 nvarchar(100),@strWEF3 nvarchar(100),@strWEF4 nvarchar(100)
	declare @str1 nvarchar(max),@str2 nvarchar(max)
	declare @strUnAppSQL nvarchar(max),@strPDCWhere nvarchar(max),@strOpeningPDCWhere nvarchar(max)
	declare @YearStartMonth DATETIME,@IsOpeningNodeWise BIT
	
	select @YearStartMonth=convert(datetime,FromDate) from ADM_FinancialYears with(nolock) where convert(float,@FromDate) between FromDate and ToDate
	if @YearStartMonth is null
		set @YearStartMonth=@FromDate	
		
	set @IsOpeningNodeWise=0

	IF @CurrencyID>0
	BEGIN
		SET @AmtColumn='AmountFC'
		SET @CurrWHERE1=' AND ACC.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
	END
	ELSE
	BEGIN
		IF @CurrencyType=1
			SET @AmtColumn='AmountBC'
		ELSE
			SET @AmtColumn='Amount'
		SET @CurrWHERE1=''
	END
	
	if(@IsWEF=1)
	begin
		set @FromDate=convert(datetime,'01 jan 1900')
		set @IncludeOpening=0
		set @YTDIndex=-1
		set @LMIndex=-1
		set @BAL_LYIndex=-1
		set @YTD_LYIndex=-1
	end
	else
	begin
		--To Check Opening Nodes Exists or Not
		set @SQL='
		if((select TOP 1 1 Opening from '+@TemplateTable+' T with(nolock),
		  (select T.NodeID GTID from '+@TemplateTable+' T with(nolock),'+@TemplateTable+' GT1 with(nolock) 
		   where T.lft BETWEEN GT1.lft AND GT1.rgt AND GT1.NodeID='+convert(nvarchar,@TemplateID)+'
		   group by T.NodeID) AS GTP 
		WHERE T.NodeID=GTP.GTID and T.NodeID!='+convert(nvarchar,@TemplateID)+' and (T.ccAlpha44=''Show Opening'' or T.ccAlpha44=''Show Closing''))=1)
			SET @IsOpeningNodeWise=1
		else
			SET @IsOpeningNodeWise=0'
		EXEC sp_executesql @SQL,N'@IsOpeningNodeWise BIT OUTPUT',@IsOpeningNodeWise OUTPUT
	end
	
	--To Select Report Template Tree Nodes, Account Nodes
	set @SQL='
select T.NodeID,T.Code,T.Name,T.IsGroup,T.Depth,T.StatusID,T.ccAlpha50 F,T.ccAlpha49 TotShow,T.ccAlpha48 Negative,T.ccAlpha45 Positive,T.ccAlpha47 Bold,T.ccAlpha46 TotText,T.ccAlpha44 Opening,T.ccAlpha43 ShowDetail
	,T.ccAlpha42 TotalBg,T.ccAlpha41 TotalBor,T.ccAlpha40 TotalBorRow
from '+@TemplateTable+' T with(nolock),
	  (select T.NodeID GTID from '+@TemplateTable+' T with(nolock),'+@TemplateTable+' GT1 with(nolock) 
	   where T.lft BETWEEN GT1.lft AND GT1.rgt AND GT1.NodeID='+convert(nvarchar,@TemplateID)+'
	   group by T.NodeID) AS GTP 
WHERE T.NodeID=GTP.GTID and T.NodeID!='+convert(nvarchar,@TemplateID)+'
order by lft

SELECT T.AccountID,A.AccountName,DrNodeID,CrNodeID,A.IsGroup,A.lft,A.rgt'
if(@IsWEF=1)
	set @SQL=@SQL+',convert(datetime,RTDate) WEF,isnull(RTGroup,'''') RTGroup'
set @SQL=@SQL+'
FROM ACC_ReportTemplate T with(nolock) inner join ACC_Accounts A with(nolock) ON T.AccountID=A.AccountID
where T.TemplateNodeID='+convert(nvarchar,@TemplateID)
if(@IsWEF=1)
begin
	set @SQL=@SQL+' and (RTDate is null or RTDate<='+convert(nvarchar,convert(float,@ToDate))+')'
	set @SQL=@SQL+' order by AccountID,RTGroup,WEF'
end

	exec(@SQL)

	
	if(@IsWEF=1)
	begin
		set @strWEF1=',WEFMn'
		set @strWEF2=',CONVERT(DATETIME,DocDate) WEFDocDate'
		set @strWEF3=',''Y''+CONVERT(NVARCHAR,YEAR(WEFDocDate))+''M''+ CONVERT(NVARCHAR,Month(WEFDocDate)) WEFMn'
        set @strWEF4=',YEAR(WEFDocDate), MONTH(WEFDocDate)'
	end
	else
	begin
		set @strWEF1=''
		set @strWEF2=''
		set @strWEF3=''
		set @strWEF4=''
	end
	
	set @strM1=''
	set @strM2=''
	set @strM3=''
	set @strM4=''
	set @strFY1=''
	if @Show=1
	begin
        set @strM1=',Mn'
		set @strM2=',CONVERT(DATETIME,DocDate) DocDate'
		set @strM3=',''Y''+CONVERT(NVARCHAR,YEAR(DocDate))+''M''+ CONVERT(NVARCHAR,Month(DocDate)) Mn'
        set @strM4=',YEAR(DocDate), MONTH(DocDate)'
	end
	else if @Show=2
	begin
        set @strM1=',FromDate,ToDate'
		set @strM2=',CONVERT(DATETIME,FY.FromDate) FromDate,CONVERT(DATETIME,FY.FromDate) ToDate'
		set @strM3=',CONVERT(DATETIME,FromDate) FromDate,CONVERT(DATETIME,ToDate) ToDate'
        set @strM4=',FromDate,ToDate'
        set @strFY1='inner join ADM_FinancialYears FY with(nolock) on DocDate between FY.FromDate and FY.ToDate'
	end
    else if @Show>50000
	begin
        set @strM1=',TagID Mn'
		set @strM2=',DCC.dcCCNID' + convert(nvarchar,(@Show-50000))+' TagID'
		set @strM3=',TagID'
        set @strM4=',TagID'
	end

	declare @CADimension int,@CAJoin nvarchar(max),@CAWhere nvarchar(max),@RTJoin nvarchar(max),@CNT INT
	set @CADimension=0
	--if @Show = 0
		select @CADimension=Value from ADM_GlobalPreferences with(nolock) where Name='ControlAccDimension' and ISNUMERIC(Value)=1
	set @CAJoin=''
	set @CAWhere=''
	set @RTJoin=' INNER JOIN (select AccountID from ACC_ReportTemplate with(nolock) where TemplateNodeID='+convert(nvarchar,@TemplateID)+' group by AccountID) RT ON GT1.AccountID=RT.AccountID'
	if @CADimension>0
	begin
		set @SQL=' select @CNT=count(*) from ACC_ReportTemplate R with(nolock)  JOIN COM_CCCCDATA ACA WITH(NOLOCK) ON ACA.CostCenterID=2 and ACA.NodeID=R.AccountID
		where TemplateNodeID='+convert(nvarchar,@TemplateID)+' and ACA.CCNID' + convert(nvarchar,(@CADimension-50000))+'!=1'
		EXEC sp_executesql @SQL,N'@CNT INT OUTPUT',@CNT OUTPUT 
		if @CNT=0
			set @CADimension=0
		else
		begin
			set @strM1=@strM1+',isnull(CADID,1) CADID,ACA.CCNID' + convert(nvarchar,(@CADimension-50000))+' CAD,A.AccountTypeID,RT.IsRT'
			set @strM2+=',DCC.dcCCNID' + convert(nvarchar,(@CADimension-50000))+' CADID'
			--set @strM3+=',case when CA.AccountTypeID=6 or CA.AccountTypeID=7 then CADID else 1 end CADID'
			set @strM3+=',CADID'
			set @strM4+=',CADID'
			set @CAJoin=' JOIN COM_CCCCDATA ACA WITH(NOLOCK) ON ACA.CostCenterID=2 and ACA.NodeID=A.AccountID'
			set @RTJoin=' JOIN (select AccountID,max(IsRT) IsRT from (select AccountID,1 IsRT from ACC_ReportTemplate with(nolock)
where TemplateNodeID=12
union all
(select AccountID,0 IsRT from ACC_Accounts with(nolock) where IsGroup=0 and (AccountTypeID=6 or AccountTypeID=7))
) RT group by AccountID
) RT ON GT1.AccountID=RT.AccountID'
			set @CAWhere=' and (CADID>1 or RT.IsRT=1) and (CADID is not null or ACA.CCNID' + convert(nvarchar,(@CADimension-50000))+'>1)'--' and (CADID>1 or (A.AccountTypeID!=6 and A.AccountTypeID!=7))'
			--set @CAWhere=' and (CADID=3 or RT.IsRT=1) '--' and (CADID>1 or (A.AccountTypeID!=6 and A.AccountTypeID!=7))'
			-- and AccountID=2092
		end
	end

	
	
	if len(@DimensionFilter)>0 OR @Show>50000 or @CADimension>0
	begin
		set @str1=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=ACC.AccDocDetailsID '
        set @str2=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=ACC.InvDocDetailsID '
	end
	else
	begin
		set @str1=''
		set @str2=''
	end

	if @UnPostedDocsList=''
		set @strUnAppSQL=' AND (ACC.StatusID=369 or ACC.StatusID=429)'
    else
		set @strUnAppSQL=' AND ACC.StatusID IN (369,429,'+@UnPostedDocsList+')'

	if @IncludePDC=1
    begin
		declare @Temp nvarchar(200)
		SET @Temp='(ACC.StatusID=370 OR ACC.StatusID=439'
		IF @IncludeTerminatedPDC=1
			SET @Temp=@Temp+' OR ACC.StatusID=452'
		SET @Temp=@Temp+')'
		
		if(@IsWEF=1)
			set @strPDCWhere=' AND ('+@Temp+' OR (ACC.DocumentType<>14 AND ACC.DocumentType<>19'+@strUnAppSQL+'))'
		else
			set @strPDCWhere=' AND ACC.DocumentType<>16 AND ('+@Temp+' OR (ACC.DocumentType<>14 AND ACC.DocumentType<>19'+@strUnAppSQL+'))'
        set @strOpeningPDCWhere=' AND ('+@Temp+' OR (ACC.DocumentType<>14 AND ACC.DocumentType<>19'+@strUnAppSQL+'))'
    end
    else
    begin
		if(@IsWEF=1)
			set @strPDCWhere=' AND ACC.DocumentType NOT IN (14,19)'+@strUnAppSQL
		else
			set @strPDCWhere=' AND ACC.DocumentType NOT IN (16,14,19)'+@strUnAppSQL
        set @strOpeningPDCWhere=' AND ACC.DocumentType<>14 AND ACC.DocumentType<>19'+@strUnAppSQL
    end
    
    
    
    set @SQL='
SELECT A.AccountCode Code,A.AccountName Name,ACC.Balance'+@strM1+@strWEF1+',A.AccountID,A.IsGroup,A.lft,A.rgt'
	set @SQL=@SQL+'
FROM (
SELECT AccountID'+@strM3+@strWEF3+',SUM(OP_Dr)+SUM(TR_Dr)-(SUM(OP_Cr)+SUM(TR_Cr)) Balance
FROM ('

	if @IncludeOpening=1
	begin
		set @SQL=@SQL+'
--Opening Dr
SELECT DebitAccount AccountID'+@strM2+',ACC.'+@AmtColumn+' OP_Dr,0 OP_Cr,0 TR_Dr,0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str1+@strFY1+'
WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter+'
UNION ALL--Opening Cr
SELECT CreditAccount AccountID'+@strM2+',0 OP_Dr,ACC.'+@AmtColumn+' OP_Cr,0 TR_Dr, 0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str1+@strFY1+'
WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter
		set @SQL=@SQL+'
UNION ALL--Transaction Dr'
	end

set @SQL=@SQL+'
SELECT DebitAccount AccountID'+@strM2+@strWEF2+',0 OP_Dr,0 OP_Cr,'+@AmtColumn+' TR_Dr,0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str1+@strFY1+'
WHERE (DocDate BETWEEN @From AND @To)'+@strPDCWhere+@CurrWHERE1+@DimensionFilter+'
UNION ALL--Transaction Cr
SELECT CreditAccount AccountID'+@strM2+@strWEF2+',0 OP_Dr,0 OP_Cr,0 TR_Dr,'+@AmtColumn+' TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str1+@strFY1+'
WHERE (DocDate BETWEEN @From AND @To)'+@strPDCWhere+@CurrWHERE1+@DimensionFilter

	if (@str2!='')
    begin
		if @IncludeOpening=1
		begin
    --INEVENTORY DATA
		set @SQL=@SQL+'
UNION ALL--Opening Dr
SELECT DebitAccount AccountID'+@strM2+@strWEF2+',ACC.'+@AmtColumn+' OP_Dr,0 OP_Cr,0 TR_Dr,0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str2+@strFY1+'
WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter+'
UNION ALL--Opening Cr
SELECT CreditAccount AccountID'+@strM2+@strWEF2+',0 OP_Dr,ACC.'+@AmtColumn+' OP_Cr,0 TR_Dr, 0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str2+@strFY1+'
WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter

		end
		
		set @SQL=@SQL+'
UNION ALL--Transaction Dr
SELECT DebitAccount AccountID'+@strM2+@strWEF2+',0 OP_Dr,0 OP_Cr,'+@AmtColumn+' TR_Dr,0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str2+@strFY1+'
WHERE (DocDate BETWEEN @From AND @To)'+@strPDCWhere+@CurrWHERE1+@DimensionFilter+'
UNION ALL--Transaction Cr
SELECT CreditAccount AccountID'+@strM2+@strWEF2+',0 OP_Dr,0 OP_Cr,0 TR_Dr,'+@AmtColumn+' TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str2+@strFY1+'
WHERE (DocDate BETWEEN @From AND @To)'+@strPDCWhere+@CurrWHERE1+@DimensionFilter
	end

	set @SQL=@SQL+') AS T1 GROUP BY AccountID'+@strM4+@strWEF4+'
) AS ACC'

if(@ZeroBalanceAccounts=1 OR @CADimension>0)
	set @SQL=@SQL+' RIGHT JOIN'
else
	set @SQL=@SQL+' INNER JOIN'

set @SQL=@SQL+' ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.AccountID'+@CAJoin+'
,ACC_Accounts GT1 with(nolock)
'+@RTJoin+'
WHERE A.AccountID>1 and A.lft BETWEEN GT1.lft AND GT1.rgt'

	set @SQL=@SQL+' AND A.AccountID>1'+@AccountsLocationWise+@CAWhere

	set @SQL=@SQL+' Order By lft'
	if(@IsWEF=1)
		set @SQL=@SQL+',AccountID'
	
            
	set @FSQL='DECLARE @From FLOAT,@To FLOAT
set @From='+convert(nvarchar,convert(float,@FromDate))+'
set @To='+convert(nvarchar,convert(float,@ToDate))+@SQL
	print(@FSQL)
	print(substring(@FSQL,4001,4000))
	exec(@FSQL)	
--print(substring(@FSQL,1,4000))
--if(len(@FSQL)>4000)

-- select len(@SQL)

	SET @FTEMPSQL=@SQL
	--Current Year Balance As On Date
	if(@YTDIndex!=-1)
	begin
		set @FSQL='DECLARE @From FLOAT,@To FLOAT
set @From='+convert(nvarchar,convert(float,@YearStartMonth))+'
set @To='+convert(nvarchar,convert(float,@ToDate))+@SQL
		exec(@FSQL)	
	end
	else
		select '' YTDIndex where 1!=1

	--Last Year Balance For Current Period
	if(@BAL_LYIndex!=-1)
	begin
		set @FSQL='DECLARE @From FLOAT,@To FLOAT
set @From='+convert(nvarchar,convert(float,dateadd(yy,-1,@FromDate)))+'
set @To='+convert(nvarchar,convert(float,dateadd(yy,-1,@ToDate)))+@SQL
		exec(@FSQL)	
		print(@FSQL)
	end
	else
		select '' BAL_LYIndex where 1!=1
		
	--Last Year Balance From Starting To Current Perios Of Last Year
	if(@YTD_LYIndex!=-1)
	begin
		set @FSQL='DECLARE @From FLOAT,@To FLOAT
set @From='+convert(nvarchar,convert(float,dateadd(yy,-1,@YearStartMonth)))+'
set @To='+convert(nvarchar,convert(float,dateadd(yy,-1,@ToDate)))+@SQL
		exec(@FSQL)	
	end
	else
		select '' YTD_LYIndex where 1!=1
	
	--Last Month Balance
	if(@LMIndex!=-1)
	begin
		set @FSQL='DECLARE @From FLOAT,@To FLOAT
set @From='+convert(nvarchar,convert(float,dateadd(mm,-1,@FromDate)))+'
set @To='+convert(nvarchar,convert(float,dateadd(dd,-1,@FromDate)))+@SQL
		exec(@FSQL)	
	end
	else
		select '' LMIndex where 1!=1
		
	--To Get Year Start
	select @YearStartMonth YearStart

	--To Get Opening Balance
	if @IsOpeningNodeWise=1
	begin
		if @Show<50000
		begin
			set @strM1=''
			set @strM2=''
			set @strM3=''
			set @strM4=''
		end

		if @CAJoin!=''
		begin
			set @strM1=@strM1+',CADID,ACA.CCNID' + convert(nvarchar,(@CADimension-50000))+' CAD,A.AccountTypeID,RT.IsRT'
			set @strM2+=',DCC.dcCCNID' + convert(nvarchar,(@CADimension-50000))+' CADID'
			--set @strM3+=',case when CA.AccountTypeID=6 or CA.AccountTypeID=7 then CADID else 1 end CADID'
			set @strM3+=',CADID'
			set @strM4+=',CADID'			
		end
	
		set @SQL='DECLARE @From FLOAT,@To FLOAT
	set @From='+convert(nvarchar,convert(float,@FromDate))+'
	SELECT A.AccountCode Code,A.AccountName Name,ACC.Balance,A.AccountID'+@strM1+',A.IsGroup,A.lft,A.rgt
	FROM (
	SELECT AccountID'+@strM3+',SUM(OP_Dr)-SUM(OP_Cr) Balance
	FROM ('
		set @SQL=@SQL+'
	--Opening Dr
	SELECT DebitAccount AccountID'+@strM2+',ACC.'+@AmtColumn+' OP_Dr,0 OP_Cr
	FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str1+'
	WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter+'
	UNION ALL--Opening Cr
	SELECT CreditAccount AccountID'+@strM2+',0 OP_Dr,ACC.'+@AmtColumn+' OP_Cr
	FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str1+'
	WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter
		if (@str2!='')
		begin
		--INEVENTORY DATA
			set @SQL=@SQL+'
	UNION ALL--Opening Dr
	SELECT DebitAccount AccountID'+@strM2+',ACC.'+@AmtColumn+' OP_Dr,0 OP_Cr
	FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str2+'
	WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter+'
	UNION ALL--Opening Cr
	SELECT CreditAccount AccountID'+@strM2+',0 OP_Dr,ACC.'+@AmtColumn+' OP_Cr
	FROM ACC_DocDetails ACC WITH(NOLOCK)'+@str2+'
	WHERE (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371 '+@strOpeningPDCWhere+@CurrWHERE1+@DimensionFilter
		end

		set @SQL=@SQL+') AS T1 GROUP BY AccountID'+@strM4+'
	) AS ACC'

	if(@ZeroBalanceAccounts=1 OR @CADimension>0)
	set @SQL=@SQL+' RIGHT JOIN'
	else
	set @SQL=@SQL+' INNER JOIN'
	
	set @SQL=@SQL+' ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.AccountID'+@CAJoin+'
	,ACC_Accounts GT1 with(nolock)
	'+@RTJoin+'
	WHERE A.AccountID>1 and A.lft BETWEEN GT1.lft AND GT1.rgt'
		set @SQL=@SQL+' AND A.AccountID>1'+@AccountsLocationWise+@CAWhere
		--set @SQL=@SQL+' Order By lft'
		--PRINT(@SQL)
		EXEC(@SQL)
	end
	else
		select '' OpBalance where 1!=1
		
	select StatusID InActiveStatus from com_status with(nolock) where CostCenterID IN (select FeatureID from adm_features with(nolock) where TableName=@TemplateTable) and Status='In Active'
	
	select 1 'Unused' where 1!=1
	
	-- Table 11 form custom date cols
	if @COLXML!=''
	begin
		declare @XML xml,@ID nvarchar(50),@From int,@To int
		set @XML=@COLXML
		DECLARE @SPInvoice cursor, @nStatusOuter int
		
		SET @SPInvoice = cursor for 
		select X.value('@ID','nvarchar(50)'),convert(int,convert(datetime,X.value('@From','nvarchar(50)'))),convert(int,convert(datetime,X.value('@To','nvarchar(50)')))
		from @XML.nodes('/XML/Row') AS DATA(X)
		
		OPEN @SPInvoice 
		SET @nStatusOuter = @@FETCH_STATUS
		
		FETCH NEXT FROM @SPInvoice Into @ID,@From,@To
		SET @nStatusOuter = @@FETCH_STATUS
		WHILE(@nStatusOuter <> -1)
		BEGIN
					set @FSQL='DECLARE @From FLOAT,@To FLOAT
set @From='+convert(nvarchar,@From)+'
set @To='+convert(nvarchar,@To)+@FTEMPSQL
print(@FSQL)
		exec(@FSQL)	
			
			FETCH NEXT FROM @SPInvoice Into @ID,@From,@To
			SET @nStatusOuter = @@FETCH_STATUS
		END

	end

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
