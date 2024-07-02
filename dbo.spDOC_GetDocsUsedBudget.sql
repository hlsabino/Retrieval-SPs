USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocsUsedBudget]
	@BudgetID [int],
	@DocID [int],
	@IsQtyBudget [int],
	@QtyType [int],
	@CostCenterID [int],
	@FromDate [datetime],
	@CCXML [nvarchar](500),
	@LinkedInvDocDetailsID [int] = 0,
	@LinkedFieldValue [float] = 0,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	DECLARE @XML XML,@ProductID INT,@AccountID INT,@SQL NVARCHAR(MAX),@CCWhere NVARCHAR(MAX),@Where NVARCHAR(MAX),@isinv bit,@dtype int,@AccountTypes nvarchar(max)
	DECLARE @tblCC AS TABLE(ID INT identity(1,1),CostCenterID INT,NodeID INT)
	CREATE TABLE #tblMapAccs(ID INT)
	create table #TblLinkDocs(Document int,ExeDocument nvarchar(max))
	declare @BudDim nvarchar(20),@From1 NVARCHAR(MAX),@From2 NVARCHAR(MAX),@StatusWhere NVARCHAR(MAX),@AccWhere1 NVARCHAR(MAX),@AccWhere2 NVARCHAR(MAX)
	,@NonAccDocs nvarchar(MAX),@NonAccDocsField nvarchar(50),@InvAccDocs nvarchar(MAX),@InvAccDocsField nvarchar(50),@TSQL NVARCHAR(MAX)
	
	SELECT @isinv=IsInventory,@dtype=DocumentType FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID 
	
	if @IsQtyBudget=0
		select @AccountTypes=AccountTypes from COM_BudgetDef with(nolock) where BudgetDefID=@BudgetID

	set @From1=''
	set @From2=''
	if @AccountTypes is not null and @AccountTypes!=''
	begin
		set @AccWhere1=' AND A.AccountTypeID IN ('+@AccountTypes+')'
		set @AccWhere2=' AND A.AccountTypeID IN ('+@AccountTypes+')'
	end
	else
	begin
		set @AccWhere1=' AND D.DebitAccount=@AccountID'
		set @AccWhere2=' AND D.CreditAccount=@AccountID'
	end
	SET @XML=@CCXML
	
	INSERT INTO @tblCC(CostCenterID,NodeID)
	SELECT X.value('@CCID','INT'),X.value('@NodeID','INT')
	FROM @XML.nodes('/XML/Row') as Data(X)
	
	SELECT @ProductID=NodeID FROM @tblCC WHERE CostCenterID=3
	
	SELECT @AccountID=NodeID FROM @tblCC WHERE CostCenterID=2
	
	select @BudDim=value from ADM_GlobalPreferences with(nolock) where  name='BudgetDimension'
	if @BudDim!='' and isnumeric(@BudDim)=1
	begin
		if @AccountID is not null and exists(select value from ADM_GlobalPreferences with(nolock) where  name='BudgetAccount' and value=convert(nvarchar,@AccountID))
		begin
			set @SQL='
			select distinct ParentNodeID AccountID
			from COM_CostCenterCostCenterMap A with(nolock) 
			inner join COM_BudgetAlloc B with(nolock) ON B.CCNID'+convert(nvarchar,convert(int,@BudDim)-50000)+'=A.NodeID
			where B.BudgetDefID='+CONVERT(NVARCHAR,@BudgetID)+' and AccountID='+convert(nvarchar,@AccountID)+' and ParentCostCenterID=2 and CostCenterID='+@BudDim
			insert into #tblMapAccs
			exec(@SQL)
			set @From1=' inner join #tblMapAccs T WITH(NOLOCK) On T.ID=D.DebitAccount'
			set @From2=' inner join #tblMapAccs T WITH(NOLOCK) On T.ID=D.CreditAccount'
			set @AccWhere1=''
			set @AccWhere2=''
		end
	end
	
	SET @CCWhere=''
	SELECT @CCWhere=@CCWhere+' AND DCC.dcCCNID'+CONVERT(NVARCHAR,CostCenterID-50000)+'='+CONVERT(NVARCHAR,NodeID) 
	FROM @tblCC WHERE CostCenterID>50000
	
	IF @DocID=0
	BEGIN
		SET @Where=''
	END
	ELSE
	BEGIN
		DECLARE @VoucherNo NVARCHAR(50)
		IF (@isinv=1)
			SELECT @VoucherNo=VoucherNo FROM INV_DocDetails WITH(NOLOCK) WHERE DocID=@DocID AND CostCenterID=@CostCenterID
		ELSE
			SELECT @VoucherNo=VoucherNo FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID=@DocID AND CostCenterID=@CostCenterID
		
		SET @Where=' AND D.VoucherNo<>'''+@VoucherNo+''''		
	END

	SET @SQL='DECLARE @AccountID INT,@From FLOAT,@To FLOAT	
		SET @From='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+'
		SET @To='+CONVERT(NVARCHAR,CONVERT(FLOAT,DATEADD(YEAR,1,@FromDate)))
	if(@IsQtyBudget=1 and @ProductID IS NOT NULL)
	BEGIN
		if(@AccountID IS NOT NULL)
		BEGIN
			if(@dtype in(11,7,9,24,33,10,8,12))      
				set @Where=@Where+' and DebitAccount='+CONVERT(NVARCHAR,@AccountID)
			else
				set @Where=@Where+' and CreditAccount='+CONVERT(NVARCHAR,@AccountID)	
		END
		
		if(@dtype in(11,7,9,24,33,10,8,12))
			set @Where=@Where+' and VoucherType=-1'
		else
			set @Where=@Where+' and VoucherType=1'
			
		if(@QtyType=1)
			set @Where=@Where+' and IsQtyFreeOffer>0'
		ELSE if(@QtyType=2)
			set @Where=@Where+' and IsQtyFreeOffer=0'
			
		SET @SQL=@SQL+' SELECT  YEAR(CONVERT(DATETIME,D.DocDate)) YYYY,MONTH(CONVERT(DATETIME,D.DocDate)) MM,SUM(UomConvertedQty) Balance 
		FROM INV_DocDetails D with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.INVDocDetailsID=D.INVDocDetailsID'+@CCWhere+'
		WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND D.DocDate>=@From AND D.DocDate<= @To'+@Where+'		
		GROUP BY YEAR(CONVERT(DATETIME,D.DocDate)),MONTH(CONVERT(DATETIME,D.DocDate))
		'
		--PRINT(@SQL)
		EXEC(@SQL)
	END
	ELSE if(@IsQtyBudget=2 and @ProductID IS NOT NULL)
	BEGIN
		if(@AccountID IS NOT NULL)
		BEGIN
			if(@dtype in(11,7,9,24,33,10,8,12))      
				set @Where=@Where+' and DebitAccount='+CONVERT(NVARCHAR,@AccountID)
			else
				set @Where=@Where+' and CreditAccount='+CONVERT(NVARCHAR,@AccountID)	
		END
		
		if(@dtype in(11,7,9,24,33,10,8,12))
			set @Where=@Where+' and VoucherType=-1'
		else
			set @Where=@Where+' and VoucherType=1'
				
		SET @SQL=@SQL+' SELECT  YEAR(CONVERT(DATETIME,D.DocDate)) YYYY,MONTH(CONVERT(DATETIME,D.DocDate)) MM,SUM(Gross) Balance 
		FROM INV_DocDetails D with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.INVDocDetailsID=D.INVDocDetailsID'+@CCWhere+'
		WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND D.DocDate>=@From AND D.DocDate<= @To'+@Where+'		
		GROUP BY YEAR(CONVERT(DATETIME,D.DocDate)),MONTH(CONVERT(DATETIME,D.DocDate))
		'
		--PRINT(@SQL)
		EXEC(@SQL)
	END
	ELSE IF (@IsQtyBudget=0 and (@AccountID IS NOT NULL or (@AccountTypes IS NOT NULL and @AccountTypes!='')))
	BEGIN
		declare @AccMastJoin1 nvarchar(max),@AccMastJoin2 nvarchar(max)
		if @AccountID is not null
		begin
			SET @SQL=@SQL+' SET @AccountID='+CONVERT(NVARCHAR,@AccountID)
			set @AccMastJoin1=''
			set @AccMastJoin2=''
		end
		else
		begin
			set @AccMastJoin1=' inner join ACC_Accounts A with(nolock) on A.AccountID=D.DebitAccount'
			set @AccMastJoin2=' inner join ACC_Accounts A with(nolock) on A.AccountID=D.CreditAccount'
		end
		SET @SQL=@SQL+' 
SELECT  YEAR(DocDate) YYYY,MONTH(DocDate) MM,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) Balance FROM ('
		
		set @StatusWhere=' and D.StatusID<>376'

		IF EXISTS (SELECT * FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='BudgetExcludeRejectedDocs' AND Value='True')
			set @StatusWhere=@StatusWhere+' and D.StatusID<>372'
		
		SET @TSQL='
SELECT CONVERT(DATETIME,D.DocDate) DocDate,D.Amount DebitAmount,NULL CreditAmount
FROM ACC_DocDetails D with(nolock)'+@AccMastJoin1+'
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID'+@CCWhere+ +'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<= @To'+@AccWhere1+@Where+@StatusWhere+'
UNION ALL
SELECT CONVERT(DATETIME,D.DocDate) DocDate,NULL DebitAmount,D.Amount CreditAmount
FROM ACC_DocDetails D with(nolock)'+@AccMastJoin2+'
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID'+@CCWhere+@From2+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<=@To'+@AccWhere2+@Where+@StatusWhere
	
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
		
		select @NonAccDocs=NonAccDocs,@NonAccDocsField=NonAccDocsField,@InvAccDocs=InvAccDocs,@InvAccDocsField=InvAccDocsField 
		from COM_BudgetDef with(nolock) where BudgetDefID=@BudgetID
		
		SET @TSQL=@TSQL+' 
UNION ALL
SELECT CONVERT(DATETIME,'+@DateField+') DocDate,D.Amount DebitAmount,NULL CreditAmount
FROM ACC_DocDetails D with(nolock)'+@AccMastJoin1+'
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere+@From1+'
WHERE D.CostCenterID NOT IN ('+CASE WHEN @InvAccDocs is not null and @InvAccDocs!='' and @InvAccDocsField is not null and @InvAccDocsField!='' THEN @InvAccDocs ELSE '0' END+') and 
'+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere1+@Where+@StatusWhere+'
UNION ALL
SELECT CONVERT(DATETIME,'+@DateField+') DocDate,NULL DebitAmount,D.Amount CreditAmount
FROM ACC_DocDetails D with(nolock)'+@AccMastJoin2+'
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere+@From2+'
WHERE D.CostCenterID NOT IN ('+CASE WHEN @InvAccDocs is not null and @InvAccDocs!='' and @InvAccDocsField is not null and @InvAccDocsField!='' THEN @InvAccDocs ELSE '0' END+') and 
'+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere2+@Where+@StatusWhere
		

		DECLARE @TEMPLink TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT)

		if(@InvAccDocs is not null and @InvAccDocs!='' and @InvAccDocsField is not null and @InvAccDocsField!='')
		begin
			select @AccountField=Value from Com_costcenterpreferences with(nolock) where CostCenterID=101 and Name='BudgetAccountField' and Value Like 'dcAlpha%'
			if @AccountField is not null and @AccountField<>'' and @AccountField Like 'dcAlpha%'
			begin
				if @CCWhere not Like '%COM_DocTextData%'
					set @CCWhere=@CCWhere+' INNER JOIN COM_DocTextData DTX with(nolock) ON DTX.InvDocDetailsID=D.InvDocDetailsID '
				SET @TSQL=@TSQL+' 
UNION ALL
SELECT CONVERT(DATETIME,'+@DateField+') DocDate,
CASE WHEN D.VoucherType=1 THEN N.dcCalcNum'+@InvAccDocsField+' ELSE 0 END DebitAmount,
CASE WHEN D.VoucherType=-1 THEN N.dcCalcNum'+@InvAccDocsField+' ELSE 0 END CreditAmount
FROM inv_docdetails D with(nolock)'+@AccMastJoin1+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere+@From1+'
WHERE D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To and DTX.'+@AccountField+'=@AccountID '+@Where+@StatusWhere

			SET @AccountTypes='
SELECT DISTINCT D.CostCenterID
FROM inv_docdetails D with(nolock)'+@AccMastJoin1+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@CCWhere+@From1+'
WHERE D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+' AND '+@DateField+'<='+CONVERT(NVARCHAR,CONVERT(FLOAT,DATEADD(YEAR,1,@FromDate)))+' and ''''=ISNULL(DTX.'+@AccountField+','''') '+@Where+@StatusWhere
			
				PRINT @AccountTypes
				INSERT INTO @TEMPLink
				EXEC (@AccountTypes)
			end
			else
			begin
				SET @TSQL=@TSQL+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,N.dcCalcNum'+@InvAccDocsField+' DebitAmount,null CreditAmount
from inv_docdetails D with(nolock)'+@AccMastJoin1+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere+@From1+'
where D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere1+@Where+@StatusWhere+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,null DebitAmount,N.dcCalcNum'+@InvAccDocsField+' CreditAmount
from inv_docdetails D with(nolock)'+@AccMastJoin2+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=D.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere+@From2+'
where D.CostCenterID IN ('+@InvAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+@AccWhere2+@Where+@StatusWhere
			end
		
		end
		
		if(@NonAccDocs is not null and @NonAccDocs!='' and @NonAccDocsField is not null and @NonAccDocsField!='')
		begin
			declare @TblRefDocs as table(Document int, ExeDocument INT)	
			declare @TblNonAcc as table(ID INT IDENTITY(1,1),Document INT)
			DECLARE @TblMaps AS TABLE(ID INT IDENTITY(1,1),Document INT)
			declare @I int,@Cnt int,@Document int,@J int,@CNTDOCS int,@ColumnName nvarchar(50),@lINKColumnName  nvarchar(50),@SubQry nvarchar(max)
				,@K int,@SubDocument int
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
			
			set @CCWhere=replace(@CCWhere,'=D.','=INV.')
			set @DateField=replace(@DateField,'D.','INV.')

			if @DateField='INV.DocDate' AND exists (select Value from Com_costcenterpreferences with(nolock) where CostCenterID=101 and Name='DueDateCheck' and Value='True') 
				set @DateField='INV.DueDate'--isnull(INV.DueDate,INV.DocDate)'
			
			set @StatusWhere=replace(@StatusWhere,'D.','INV.')
			
			if exists (select * from #TblLinkDocs WITH(NOLOCK))
				SET @TSQL=@TSQL+'
UNION ALL
SELECT DocDate,T.DebitAmount*(Quantity-(Executed+Rejected))/Quantity DebitAmount,T.CreditAmount*(Quantity-(Executed+Rejected))/Quantity CreditAmount FROM (
select CONVERT(DATETIME,'+@DateField+') DocDate,(CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,TL.ExeDocument)=''Gross'' THEN INV.Gross ELSE INV.Quantity END) Quantity,[dbo].[fnRPT_RejQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null) Rejected,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null,0) Executed,N.dcCalcNum'+@NonAccDocsField+' DebitAmount,null CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join #TblLinkDocs TL WITH(NOLOCK) on TL.Document=INV.CostCenterID
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From1,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere1,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,(CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,TL.ExeDocument)=''Gross'' THEN INV.Gross ELSE INV.Quantity END) Quantity,[dbo].[fnRPT_RejQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null) Rejected,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,TL.ExeDocument,null,0) Executed,null DebitAmount,N.dcCalcNum'+@NonAccDocsField+' CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join #TblLinkDocs TL WITH(NOLOCK) on TL.Document=INV.CostCenterID
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From2,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere2,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
) as T
WHERE Quantity>(Executed+Rejected)'
			else
				SET @TSQL=@TSQL+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,N.dcCalcNum'+@NonAccDocsField+' DebitAmount,null CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From1,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere1,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,null DebitAmount,N.dcCalcNum'+@NonAccDocsField+' CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From2,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere2,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere
			
			if @LinkedInvDocDetailsID>0 AND @DocID=0 
				SET @TSQL=@TSQL+'
UNION ALL
SELECT DocDate,T.DebitAmount-(T.DebitAmount*(Quantity-Executed)/Quantity) DebitAmount,T.CreditAmount-(T.CreditAmount*(Quantity-Executed)/Quantity) CreditAmount FROM (
select CONVERT(DATETIME,'+@DateField+') DocDate,INV.Quantity,'+CONVERT(NVARCHAR,@LinkedFieldValue)+' Executed,null DebitAmount,N.dcCalcNum'+@NonAccDocsField+'  CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From1,'D.','INV.')+'
where INV.InvDocDetailsID='+CONVERT(NVARCHAR,@LinkedInvDocDetailsID)+' and INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere1,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,INV.Quantity,'+CONVERT(NVARCHAR,@LinkedFieldValue)+' Executed,N.dcCalcNum'+@NonAccDocsField+' DebitAmount,null CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From2,'D.','INV.')+'
where INV.InvDocDetailsID='+CONVERT(NVARCHAR,@LinkedInvDocDetailsID)+' and INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere2,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
) as T'

			IF EXISTS ((SELECT CostCenterID FROM @TEMPLink) )
			BEGIN
				SET @NonAccDocs=stuff((select ','+convert(nvarchar,CostCenterID) from @TEMPLink FOR XML PATH('')),1,1,'') 

				SET @TSQL=@TSQL+'
UNION ALL
SELECT DocDate,T.DebitAmount*(Quantity-Executed)/Quantity DebitAmount,T.CreditAmount*(Quantity-Executed)/Quantity CreditAmount FROM (
select CONVERT(DATETIME,'+@DateField+') DocDate,CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,'''+@InvAccDocs+''')=''Gross'' THEN INV.Gross ELSE INV.Quantity END Quantity,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,'''+@InvAccDocs+''',null,0) Executed,N.dcCalcNum'+@InvAccDocsField+' DebitAmount,null CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From1,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere1,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,CASE WHEN [dbo].[fnRPT_GetLinkField](INV.CostCenterID,'''+@InvAccDocs+''')=''Gross'' THEN INV.Gross ELSE INV.Quantity END Quantity,[dbo].[fnRPT_ExeQtyByDocs](INV.InvDocDetailsID,INV.InvDocDetailsID,'''+@InvAccDocs+''',null,0) Executed,null DebitAmount,N.dcCalcNum'+@InvAccDocsField+' CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From2,'D.','INV.')+'
where INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere2,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
) as T
WHERE Quantity>Executed'
			END	
		end
		
		IF @QtyType=-1 AND @LinkedInvDocDetailsID>0 AND @DocID=0 
		BEGIN
				SET @TSQL='
SELECT DocDate,T.DebitAmount-(T.DebitAmount*(Quantity-Executed)/Quantity) DebitAmount,T.CreditAmount-(T.CreditAmount*(Quantity-Executed)/Quantity) CreditAmount FROM (
select CONVERT(DATETIME,'+@DateField+') DocDate,INV.Quantity,'+CONVERT(NVARCHAR,@LinkedFieldValue)+' Executed,null DebitAmount,N.dcCalcNum'+@NonAccDocsField+'  CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin1,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From1,'D.','INV.')+'
where INV.InvDocDetailsID='+CONVERT(NVARCHAR,@LinkedInvDocDetailsID)+' and INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere1,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
UNION ALL
select CONVERT(DATETIME,'+@DateField+') DocDate,INV.Quantity,'+CONVERT(NVARCHAR,@LinkedFieldValue)+' Executed,N.dcCalcNum'+@NonAccDocsField+' DebitAmount,null CreditAmount
from inv_docdetails INV with(nolock)'+replace(@AccMastJoin2,'D.','INV.')+'
inner join COM_DocNumData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=INV.InvDocDetailsID'+@CCWhere+replace(@From2,'D.','INV.')+'
where INV.InvDocDetailsID='+CONVERT(NVARCHAR,@LinkedInvDocDetailsID)+' and INV.CostCenterID IN ('+@NonAccDocs+') and '+@DateField+'>=@From AND '+@DateField+'<=@To'+replace(@AccWhere2,'D.','INV.')+replace(@Where,'D.','INV.')+@StatusWhere+'
) as T
'
		END
		
		SET @SQL=@SQL+@TSQL+'
) AS T GROUP BY YEAR(DocDate),MONTH(DocDate)'

		PRINT(substring(@SQL,1,4000))
		PRINT(substring(@SQL,4001,4000))
		PRINT(substring(@SQL,8001,4000))
		EXEC(@SQL)
		
	END
	
	DROP TABLE #tblMapAccs
	DROP TABLE #TblLinkDocs

SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
