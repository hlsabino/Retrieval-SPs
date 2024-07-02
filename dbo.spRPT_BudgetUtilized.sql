USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_BudgetUtilized]
	@BudgetID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@CCWHERE NVARCHAR(500),@TblCols NVARCHAR(500),@FromDate DATETIME,@IsQtyBudget INT,@NumDimensions INT
	declare @StatusWhere NVARCHAR(MAX),@NonAccDocs nvarchar(MAX),@NonAccDocsField nvarchar(50),@InvAccDocs nvarchar(MAX),@InvAccDocsField nvarchar(50),@AccountTypes nvarchar(max)
	create table #TblLinkDocs(ID INT IDENTITY (1,1) PRIMARY KEY,Document int,ExeDocument nvarchar(max))

	--BudgetTypeID
	SELECT @NumDimensions=NumDimensions,@IsQtyBudget=QtyBudget,@AccountTypes=AccountTypes,@FromDate=CONVERT(DATETIME,FinYearStartDate) 
	,@NonAccDocs=NonAccDocs,@NonAccDocsField=NonAccDocsField,@InvAccDocs=InvAccDocs,@InvAccDocsField=InvAccDocsField
	FROM COM_BudgetDef WITH(NOLOCK)
	WHERE BudgetDefID=@BudgetID

	SET @CCWHERE=''
	SET @TblCols=''
	
	SELECT  @CCWHERE=@CCWHERE+' AND DCC.dcCCNID'+CONVERT(NVARCHAR,CostCenterID-50000)+'=T.CCNID'+CONVERT(NVARCHAR,CostCenterID-50000) ,
			@TblCols=@TblCols+' ,CCNID'+CONVERT(NVARCHAR,CostCenterID-50000)+' INT'
	FROM COM_BudgetDefDims C WITH(NOLOCK)
	WHERE C.BudgetDefID=@BudgetID AND C.CostCenterID>50000
	
	SET @SQL='DECLARE @From FLOAT,@To FLOAT,@BudgetID INT	
		SET @From='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+'
		SET @To='+CONVERT(NVARCHAR,CONVERT(FLOAT,DATEADD(YEAR,1,@FromDate)))+'
		SET @BudgetID='+CONVERT(NVARCHAR,@BudgetID)+'
		
		SELECT CONVERT(DATETIME,FinYearStartDate) WEF FROM COM_BudgetDef WITH(NOLOCK)
		WHERE BudgetDefID=@BudgetID
		
		CREATE TABLE #BUDTEMP (ID INT IDENTITY(1,1) PRIMARY KEY,BudgetDefID INT,BudgetAllocID INT,AccountID INT,ProductID INT'+@TblCols+')
		
		INSERT INTO #BUDTEMP
		SELECT BudgetDefID,BudgetAllocID,AccountID,ProductID'+REPLACE(@TblCols,' INT','')+' FROM COM_BudgetAlloc WITH(NOLOCK)
		WHERE BudgetDefID=@BudgetID
		'

	set @StatusWhere=' and D.StatusID<>376'
	if exists (select * from ADM_GlobalPreferences with(nolock) where name='BudgetExcludeRejectedDocs' and Value='True')
		set @StatusWhere=@StatusWhere+' and D.StatusID<>372'

IF @IsQtyBudget=1
BEGIN

	SELECT  @CCWHERE=@CCWHERE+' AND T.ProductID=D.ProductID'
	FROM COM_BudgetDefDims C WITH(NOLOCK)
	WHERE C.BudgetDefID=@BudgetID AND C.CostCenterID=3
	
	SET @SQL=@SQL+'
	SELECT  BudgetAllocID,YEAR(DocDate) YYYY,MONTH(DocDate) MM,ISNULL(SUM(QTY),0) Balance FROM (

	SELECT T.BudgetAllocID,CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo, 
	D.UOMConvertedQty*D.VoucherType QTY
	FROM INV_DocDetails D WITH(NOLOCK)
	INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWHERE+'
	WHERE D.DocDate>=@From AND D.DocDate<=@To

	) AS T GROUP BY BudgetAllocID,YEAR(DocDate),MONTH(DocDate)'
END
ELSE IF @IsQtyBudget=2
BEGIN

	SELECT  @CCWHERE=@CCWHERE+' AND T.ProductID=D.ProductID'
	FROM COM_BudgetDefDims C WITH(NOLOCK)
	WHERE C.BudgetDefID=@BudgetID AND C.CostCenterID=3
	
	SET @SQL=@SQL+'
	SELECT  BudgetAllocID,YEAR(DocDate) YYYY,MONTH(DocDate) MM,ISNULL(SUM(Gross),0) Balance FROM (

	SELECT T.BudgetAllocID,CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo, 
	D.Gross*D.VoucherType Gross
	FROM INV_DocDetails D WITH(NOLOCK)
	INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWHERE+'
	WHERE D.DocDate>=@From AND D.DocDate<=@To

	) AS T GROUP BY BudgetAllocID,YEAR(DocDate),MONTH(DocDate)'
END
ELSE
BEGIN

	declare @CommonAccount INT,@BudDim int,@sqlAccs nvarchar(max),@CAFrom1 nvarchar(max),@CAFrom2 nvarchar(max),@AccWhere1 nvarchar(max),@AccWhere2 nvarchar(max)
	declare @TblRefDocs as table(Document int, ExeDocument INT)	
	declare @TblNonAcc as table(ID INT IDENTITY(1,1),Document INT)
	DECLARE @TblMaps AS TABLE(ID INT IDENTITY(1,1),Document INT)
	declare @I int,@Cnt int,@Document int,@J int,@CNTDOCS int,@ColumnName nvarchar(50),@lINKColumnName  nvarchar(50),@SubQry nvarchar(max)
		,@K int,@SubDocument int,@AccMastJoin1 nvarchar(max),@AccMastJoin2 nvarchar(max)
	CREATE TABLE #tblMapAccs(ID INT,BudDimID INT)
	select @CommonAccount=value from ADM_GlobalPreferences with(nolock) where  name='BudgetAccount' and isnumeric(value)=1
	select @BudDim=value from ADM_GlobalPreferences with(nolock) where  name='BudgetDimension' and isnumeric(value)=1
	
	set @CAFrom1=''
	set @CAFrom2=''	
	if(@AccountTypes is not null and @AccountTypes!='')
	begin
		set @AccWhere1=' AND A.AccountTypeID IN ('+@AccountTypes+')'
		set @AccWhere2=' AND A.AccountTypeID IN ('+@AccountTypes+')'
		set @AccMastJoin1=' inner join ACC_Accounts A with(nolock) on A.AccountID=D.DebitAccount'
		set @AccMastJoin2=' inner join ACC_Accounts A with(nolock) on A.AccountID=D.CreditAccount'
	end
	else
	begin
		set @AccWhere1=' AND T.AccountID=D.DebitAccount'
		set @AccWhere2=' AND T.AccountID=D.CreditAccount'
		set @AccMastJoin1=''
		set @AccMastJoin2=''
	end
	
	if @CommonAccount is not null and @CommonAccount>0 and @BudDim is not null and @BudDim>0
	begin
		set @sqlAccs='
		select ParentNodeID AccountID,A.NodeID BudDimID
		from COM_CostCenterCostCenterMap A with(nolock) 
		inner join COM_BudgetAlloc B with(nolock) ON B.CCNID'+convert(nvarchar,convert(int,@BudDim)-50000)+'=A.NodeID
		where B.BudgetDefID='+CONVERT(NVARCHAR,@BudgetID)+' and B.AccountID='+convert(nvarchar,@CommonAccount)+' and ParentCostCenterID=2 and CostCenterID='+convert(nvarchar,@BudDim)
		insert into #tblMapAccs
		exec(@sqlAccs)		
		if exists (select * from #tblMapAccs)
		begin
			set @CAFrom1=' left join #tblMapAccs CA On CA.ID=D.DebitAccount and CA.BudDimID=DCC.dcCCNID'+convert(nvarchar,@BudDim-50000)
			set @CAFrom2=' left join #tblMapAccs CA On CA.ID=D.CreditAccount and CA.BudDimID=DCC.dcCCNID'+convert(nvarchar,@BudDim-50000)
			set @AccWhere1=' AND (T.AccountID=D.DebitAccount or CA.ID is not null)'
			set @AccWhere2=' AND (T.AccountID=D.CreditAccount or CA.ID is not null)'
		end
	end

	SET @SQL=@SQL+'
	SELECT  BudgetAllocID,YEAR(DocDate) YYYY,MONTH(DocDate) MM,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) Balance'
	
	if(@NonAccDocs is not null and @NonAccDocs!='' and @NonAccDocsField is not null and @NonAccDocsField!='')
		SET @SQL=@SQL+',ISNULL(SUM(DrNonAcc),0)-ISNULL(SUM(CrNonAcc),0) NonAccBalance,ISNULL(SUM(D2DrNonAcc),0)-ISNULL(SUM(D2CrNonAcc),0) D1NonAccBalance,ISNULL(SUM(D25DrNonAcc),0)-ISNULL(SUM(D25CrNonAcc),0) D2NonAccBalance '
	
	if exists (SELECT CostCenterID FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName='IsBudgetDocument' and DocumentType in (5,8,13))
		SET @SQL=@SQL+',ISNULL(SUM(BudgetTransfer0),0) BudgetTransfer0,ISNULL(SUM(BudgetTransfer1),0) BudgetTransfer1,ISNULL(SUM(BudgetTransfer2),0) BudgetTransfer2,ISNULL(SUM(BudgetShortage),0) BudgetTransfer3,ISNULL(SUM(BudgetExcess),0) BudgetTransfer4'

	SET @SQL=@SQL+'
	FROM (
	SELECT T.BudgetAllocID,CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo, 
	D.Amount DebitAmount,NULL CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
	FROM ACC_DocDetails D WITH(NOLOCK)'+@AccMastJoin1+'
	INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=D.AccDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWHERE+@CAFrom1+'
	WHERE D.DocumentType<>16 AND D.DocumentType<>14 
	AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<= @To'+@AccWhere1+@StatusWhere+'
	UNION ALL
	SELECT T.BudgetAllocID,CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,
	NULL DebitAmount,D.Amount CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
	FROM ACC_DocDetails D WITH(NOLOCK)'+@AccMastJoin2+'
	INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=D.AccDocDetailsID 
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWHERE+@CAFrom2+'
	WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<=@To'+@AccWhere2+@StatusWhere
	
	DECLARE @DateField nvarchar(200),@AccountField nvarchar(50)
	if exists (select Value from Com_costcenterpreferences with(nolock) where CostCenterID=101 and Name='BudgetDateField' and Value Like 'dcAlpha%')
	begin
		set @CCWhere=@CCWhere+' INNER JOIN COM_DocTextData DTX with(nolock) ON DTX.InvDocDetailsID=D.InvDocDetailsID '
		select @DateField='CONVERT(FLOAT,CONVERT(DATETIME,DTX.'+Value+'))' from Com_costcenterpreferences with(nolock) 
		where CostCenterID=101 and Name='BudgetDateField'
	end
	else if exists (select Value from Com_costcenterpreferences with(nolock) where CostCenterID=101 and Name='BudgetDateField' and Value='DueDate')
		set @DateField='D.DueDate'--isnull(INV.DueDate,INV.DocDate)'
	else
		set @DateField='D.DocDate'
	
	SET @SQL=@SQL+' UNION ALL
	SELECT T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate, D.VoucherNo, 
	D.Amount DebitAmount,NULL CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
	FROM ACC_DocDetails D WITH(NOLOCK)'+@AccMastJoin1+'
	INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWHERE+@CAFrom1+'
	WHERE D.CostCenterID NOT IN ('+CASE WHEN @InvAccDocs is not null and @InvAccDocs!='' and @InvAccDocsField is not null and @InvAccDocsField!='' THEN @InvAccDocs ELSE '0' END+') and 
	'+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere1+@StatusWhere+'
	UNION ALL
	SELECT T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate, D.VoucherNo,
	NULL DebitAmount,D.Amount CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
	FROM ACC_DocDetails D WITH(NOLOCK)'+@AccMastJoin2+'
	INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID 
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWHERE+@CAFrom2+'
	WHERE D.CostCenterID NOT IN ('+CASE WHEN @InvAccDocs is not null and @InvAccDocs!='' and @InvAccDocsField is not null and @InvAccDocsField!='' THEN @InvAccDocs ELSE '0' END+') and 
	'+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere2+@StatusWhere
	
	DECLARE @TEMPSQL NVARCHAR(MAX)
	DECLARE @TEMPLink TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT)

	if(@InvAccDocs is not null and @InvAccDocs!='' and @InvAccDocsField is not null and @InvAccDocsField!='')
	begin
		select @AccountField=Value from Com_costcenterpreferences with(nolock) where CostCenterID=101 and Name='BudgetAccountField' and Value Like 'dcAlpha%'
		if @AccountField is not null and @AccountField<>'' and @AccountField Like 'dcAlpha%'
		begin
			if @CCWhere not Like '%COM_DocTextData%'
				set @CCWhere=@CCWhere+' INNER JOIN COM_DocTextData DTX with(nolock) ON DTX.InvDocDetailsID=D.InvDocDetailsID '
			SET @SQL=@SQL+' UNION ALL
	SELECT T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate,D.VoucherNo, 
	CASE WHEN D.VoucherType=1 THEN N.dcCalcNum'+@InvAccDocsField+' ELSE 0 END DebitAmount,CASE WHEN D.VoucherType=-1 THEN N.dcCalcNum'+@InvAccDocsField+' ELSE 0 END CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
	FROM inv_docdetails D with(nolock)
	inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+'
	WHERE D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To and CONVERT(NVARCHAR,T.AccountID)=DTX.'+@AccountField+@StatusWhere
			SET @TEMPSQL='
	SELECT DISTINCT D.CostCenterID
	FROM inv_docdetails D with(nolock)
	inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+'
	WHERE D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+' AND '+@DateField+'<='+CONVERT(NVARCHAR,CONVERT(FLOAT,DATEADD(YEAR,1,@FromDate)))+' and ''''=ISNULL(DTX.'+@AccountField+','''')'+@StatusWhere
			
			INSERT INTO @TEMPLink
			EXEC (@TEMPSQL)
		end
		else
		begin
			SET @SQL=@SQL+'
	UNION ALL
	select T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate,D.VoucherNo,N.dcCalcNum'+@InvAccDocsField+' DebitAmount,null CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
	from inv_docdetails D with(nolock)'+@AccMastJoin1+'
	inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+@CAFrom1+'
	where D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere1+@StatusWhere+' and (D.DocumentType!=5 or D.VoucherType=-1)
	UNION ALL
	select T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate,D.VoucherNo,null DebitAmount,N.dcCalcNum'+@InvAccDocsField+' CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
	from inv_docdetails D with(nolock)'+@AccMastJoin2+'
	inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID
	INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+@CAFrom2+'
	where D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere2+@StatusWhere+' and (D.DocumentType!=5 or D.VoucherType=1)'
		end
	end
	
	set @CCWhere=replace(@CCWhere,'=D.','=INV.')
	set @DateField=replace(@DateField,'D.','INV.')
	set @StatusWhere=replace(@StatusWhere,'D.','INV.')
		
	if(@NonAccDocs is not null and @NonAccDocs!='' and @NonAccDocsField is not null and @NonAccDocsField!='')
	begin
		insert into @TblNonAcc
		exec SPSplitString @NonAccDocs,','
		select @I=1,@Cnt=count(*) from @TblNonAcc
		WHILE(@I<=@Cnt)
		BEGIN
			SELECT @Document=Document FROM @TblNonAcc WHERE ID=@I
			
			DELETE FROM @TblMaps
			
			INSERT INTO @TblMaps
			VALUES(@Document)
			
			SELECT @J=MAX(ID) FROM @TblMaps
			
			while(1=1)
			begin
				select @SubDocument=Document from @TblMaps where ID=@J

				INSERT INTO @TblRefDocs
				SELECT @Document,[CostCenterIDBase]
				FROM [COM_DocumentLinkDef] WITH(NOLOCK) 
				left join @TblRefDocs TR ON TR.Document=@Document and TR.ExeDocument=[CostCenterIDBase]
				WHERE CostCenterIDLinked=@SubDocument and [CostCenterIDBase]>40000 AND IsQtyExecuted=1 and TR.ExeDocument IS NULL
				
				INSERT INTO @TblMaps(Document)
				SELECT [CostCenterIDBase]
				FROM [COM_DocumentLinkDef] WITH(NOLOCK) 
				WHERE CostCenterIDLinked=@SubDocument and [CostCenterIDBase]>40000 AND IsQtyExecuted=0 and [CostCenterIDBase] NOT IN (select Document FROM @TblMaps)
				
				if(@J=(SELECT MAX(ID) FROM @TblMaps))
					break
				set @J=@J+1
			end
			
			SET @I=@I+1
		END
		
		insert into #TblLinkDocs
		select Document,stuff((select ','+convert(nvarchar,ExeDocument) from @TblRefDocs where Document=T.Document FOR XML PATH('')),1,1,'') 
		from @TblRefDocs T
		group by Document

		--SELECT * FROM #TblLinkDocs
		
		if @DateField='INV.DocDate' AND exists (select Value from Com_costcenterpreferences with(nolock) where CostCenterID=101 and Name='DueDateCheck' and Value='True') 
			set @DateField='INV.DueDate'--isnull(INV.DueDate,INV.DocDate)'
			
		
		
		SET @SQL=@SQL+'
UNION ALL
SELECT BudgetAllocID,DocDate,null VoucherNo,null DebitAmount,null CreditAmount,T.DebitAmount*(Quantity-(Executed+Rejected))/Quantity DrNonAcc,T.CreditAmount*(Quantity-(Executed+Rejected))/Quantity CrNonAcc
,CASE WHEN T.DocumentType=2 THEN T.DebitAmount*(Quantity-(Executed+Rejected))/Quantity ELSE 0 END D2DrNonAcc,CASE WHEN T.DocumentType=2 THEN T.CreditAmount*(Quantity-(Executed+Rejected))/Quantity ELSE 0 END  D2CrNonAcc
,CASE WHEN T.DocumentType=25 THEN T.DebitAmount*(Quantity-(Executed+Rejected))/Quantity ELSE 0 END D25DrNonAcc,CASE WHEN T.DocumentType=25 THEN T.CreditAmount*(Quantity-(Executed+Rejected))/Quantity ELSE 0 END  D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
FROM (
select T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate,(CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,TL.ExeDocument)=''Gross'' THEN INV.Gross ELSE INV.Quantity END) Quantity,[dbo].[fnRPT_RejQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null) Rejected,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null,0) Executed,N.dcCalcNum'+@NonAccDocsField+' DebitAmount,null CreditAmount,INV.DocumentType
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join #TblLinkDocs TL WITH(NOLOCK) on TL.Document=INV.CostCenterID
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+replace(@CAFrom1,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere1,'D.','INV.')+@StatusWhere+'
UNION ALL
select T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate,(CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,TL.ExeDocument)=''Gross'' THEN INV.Gross ELSE INV.Quantity END) Quantity,[dbo].[fnRPT_RejQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null) Rejected,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null,0) Executed,null DebitAmount,N.dcCalcNum'+@NonAccDocsField+' CreditAmount,INV.DocumentType
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join #TblLinkDocs TL WITH(NOLOCK) on TL.Document=INV.CostCenterID
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+replace(@CAFrom2,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere2,'D.','INV.')+@StatusWhere+'
) as T
WHERE Quantity>(Executed+Rejected)'
		
		IF EXISTS ((SELECT CostCenterID FROM @TEMPLink) )
		BEGIN
			SET @NonAccDocs=stuff((select ','+convert(nvarchar,CostCenterID) from @TEMPLink FOR XML PATH('')),1,1,'') 

			SET @SQL=@SQL+'
UNION ALL
SELECT BudgetAllocID,DocDate,null VoucherNo,null DebitAmount,null CreditAmount,T.DebitAmount*(Quantity-Executed)/Quantity DrNonAcc,T.CreditAmount*(Quantity-Executed)/Quantity CrNonAcc
,T.DebitAmount*(Quantity-Executed)/Quantity D2DrNonAcc,T.CreditAmount*(Quantity-Executed)/Quantity D2CrNonAcc
,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,0 BudgetTransfer2,0 BudgetShortage,0 BudgetExcess
FROM (
select T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate,CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,'''+@InvAccDocs+''')=''Gross'' THEN INV.Gross ELSE INV.Quantity END Quantity,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,'''+@InvAccDocs+''',null,0) Executed,N.dcCalcNum'+@InvAccDocsField+' DebitAmount,null CreditAmount,INV.DocumentType
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+replace(@CAFrom1,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere1,'D.','INV.')+@StatusWhere+'
UNION ALL
select T.BudgetAllocID,CONVERT(DATETIME,'+@DateField+') DocDate,CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,'''+@InvAccDocs+''')=''Gross'' THEN INV.Gross ELSE INV.Quantity END Quantity,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,'''+@InvAccDocs+''',null,0) Executed,null DebitAmount,N.dcCalcNum'+@InvAccDocsField+' CreditAmount,INV.DocumentType
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+replace(@CAFrom2,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere2,'D.','INV.')+@StatusWhere+'
) as T
WHERE Quantity>Executed'
		END	
	end
	
	if exists (SELECT CostCenterID FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName='IsBudgetDocument' and DocumentType in (5,8,13))
	begin
		SET @SQL=@SQL+'
UNION ALL
select T.BudgetAllocID,CONVERT(DATETIME,INV.DocDate) DocDate,INV.VoucherNo,null DebitAmount,null CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,(CASE WHEN INV.StatusID<>369 and INV.DocumentType=5 THEN INV.Gross ELSE 0 END) BudgetTransfer0,(CASE WHEN INV.StatusID=369 and INV.DocumentType=5 and INV.VoucherType=-1 THEN INV.Gross ELSE 0 END) BudgetTransfer1,0 BudgetTransfer2,(CASE WHEN INV.StatusID=369 and INV.DocumentType in (8,13) THEN INV.Gross ELSE 0 END) BudgetShortage,0 BudgetExcess
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+replace(@CAFrom1,'D.','INV.')+'
INNER JOIN COM_DocTextData DTD with(nolock) ON DTD.InvDocDetailsID=INV.InvDocDetailsID and DTD.dcAlpha1=convert(nvarchar,T.BudgetDefID)
where INV.CostCenterID IN (SELECT CostCenterID FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName=''IsBudgetDocument'' and DocumentType in (5,8,13)) and INV.DocDate>=@From AND INV.DocDate<=@To'+replace(@AccWhere1,'D.','INV.')+@StatusWhere+'
UNION ALL
select T.BudgetAllocID,CONVERT(DATETIME,INV.DocDate) DocDate,INV.VoucherNo,null DebitAmount,null CreditAmount,0 DrNonAcc,0 CrNonAcc,0 D2DrNonAcc,0 D2CrNonAcc,0 D25DrNonAcc,0 D25CrNonAcc,0 BudgetTransfer0,0 BudgetTransfer1,(CASE WHEN INV.StatusID=369 and INV.DocumentType=5 and INV.VoucherType=1 THEN INV.Gross ELSE 0 END) BudgetTransfer2,0 BudgetShortage,(CASE WHEN INV.StatusID=369 and INV.DocumentType in (8,13) THEN INV.Gross ELSE 0 END) BudgetExcess
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN #BUDTEMP T WITH(NOLOCK) ON 1=1 '+@CCWhere+replace(@CAFrom2,'D.','INV.')+'
INNER JOIN COM_DocTextData DTD with(nolock) ON DTD.InvDocDetailsID=INV.InvDocDetailsID  and DTD.dcAlpha1=convert(nvarchar,T.BudgetDefID)
where INV.CostCenterID IN (SELECT CostCenterID FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName=''IsBudgetDocument'' and DocumentType in (5,8,13)) and INV.DocDate>=@From AND INV.DocDate<=@To'+replace(@AccWhere2,'D.','INV.')+@StatusWhere+''
	end
SET @SQL=@SQL+'
) AS T GROUP BY BudgetAllocID,YEAR(DocDate),MONTH(DocDate)'
		
	PRINT(substring(@SQL,1,4000))
	PRINT(substring(@SQL,4001,4000))
	PRINT(substring(@SQL,8001,4000))
	PRINT(substring(@SQL,12001,4000))
	
END

SET @SQL=@SQL+'
DROP TABLE #BUDTEMP '
--PRINT(@SQL)
EXEC(@SQL)

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
