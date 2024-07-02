USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetBudgetDefn]
	@CostCenterID [int],
	@DocID [bigint],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @Dt float,@SQL nvarchar(max),@BudgetID bigint,@selectcols nvarchar(max),@insertcols nvarchar(max),@AmtInDecimals int

	SET @Dt=CONVERT(FLOAT,GETDATE())

	declare @BudgetName nvarchar(100),@BudgetYear float,@BudgetTypeID int,@BudgetTypeName nvarchar(20),@NumDimensions int,@Dims nvarchar(100),@CFField nvarchar(20)
	declare @txtShiftDate nvarchar(20),@AssDimID int,@LocationDimID int,@CNT INT,@TransferDim nvarchar(max),@XML xml
	select @TransferDim=PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='BudgetMapFields'
	set @XML=@TransferDim
		
	select @BudgetTypeID=x.value('@BudgetType','bigint'),@CFField=x.value('@CF','nvarchar(20)'),@Dims=x.value('@Dims','nvarchar(100)') from @XML.nodes('/XML') as data(x)
	if @BudgetTypeID='0'
		set @BudgetTypeName='Annual'
	else if @BudgetTypeID='1'
		set @BudgetTypeName='Half Yearly'
	else if @BudgetTypeID='2'
		set @BudgetTypeName='Quarterly'
	else if @BudgetTypeID='3'
		set @BudgetTypeName='Monthly'
	
	declare @TblDim as table(Name nvarchar(50),CCID INT)  
	insert into @TblDim (Name)
	exec SPSplitString @Dims,','  
	update @TblDim set CCID=2 where Name='DebitAccount' or Name='CreditAccount'
	update @TblDim set CCID=3 where Name='ProductID'
	update @TblDim set CCID=50000+convert(int,replace(Name,'dcCCNID','')) where Name like 'dcCCNID%'
	
	select @NumDimensions=count(*) from @TblDim

	select @BudgetID=RefDimensionNodeID from COM_DocBridge with(nolock) where CostCenterID=@CostCenterID and NodeID=@DocID and RefDimensionID=101
	
	if @BudgetID is null--NEW
	begin
		select @BudgetName=VoucherNo,@BudgetYear=isnull(BillDate,DocDate) from INV_DocDetails with(nolock) where CostCenterID=@CostCenterID and DocID=@DocID
		
		DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint  
		DECLARE @SelectedIsGroup bit,@SelectedNodeID int

		set @SelectedNodeID=1

		--To Set Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		from COM_BudgetDef with(NOLOCK) where BudgetDefID=@SelectedNodeID
   
		--IF No Record Selected or Record Doesn't Exist  
		if(@SelectedIsGroup is null)   
			select @SelectedNodeID=BudgetDefID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			from COM_BudgetDef with(NOLOCK) where ParentID =0  
         
		if(@SelectedIsGroup = 1)--Adding Node Under the Group  
		BEGIN  
			UPDATE COM_BudgetDef SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
			UPDATE COM_BudgetDef SET lft = lft + 2 WHERE lft > @Selectedlft;  
			set @lft =  @Selectedlft + 1  
			set @rgt = @Selectedlft + 2  
			set @ParentID = @SelectedNodeID  
			set @Depth = @Depth + 1  
		END  
		else if(@SelectedIsGroup = 0)--Adding Node at Same level  
		BEGIN  
			UPDATE COM_BudgetDef SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
			UPDATE COM_BudgetDef SET lft = lft + 2 WHERE lft > @Selectedrgt;  
			set @lft =  @Selectedrgt + 1  
			set @rgt = @Selectedrgt + 2   
		END  
		else  --Adding Root  
		BEGIN  
			set @lft =  1  
			set @rgt = 2   
			set @Depth = 0  
			set @ParentID =0  
		END  
	
		--Inserting into COM_BudgetDef
		INSERT INTO COM_BudgetDef(BudgetName, FinYearStartDate, BudgetTypeID, BudgetType,NumDimensions,StatusID,
								QtyType,Depth,ParentID,lft,rgt,IsGroup,CompanyGUID,GUID,CreatedBy,CreatedDate,QtyBudget,ChkBudgetOnlyForDefnAccounts,NonAccDocs,NonAccDocsField)
		VALUES(@BudgetName,convert(float,@BudgetYear),@BudgetTypeID,@BudgetTypeName,@NumDimensions,1,
								0,@Depth,@ParentID,@lft,@rgt,0,@CompanyGUID,newid(),@UserName,@DT,0,1,null,null)
		SET @BudgetID=scope_identity()
		
		INSERT INTO COM_DocBridge(CostCenterID,NodeID,AccDocID,InvDocID,Abbreviation,CompanyGUID,GUID,CreatedBy,CreatedDate,RefDimensionID,RefDimensionNodeID)
		VALUES(@CostCenterID,@DocID,0,0,'','','','',convert(float,getdate()),101,@BudgetID)
	end
	else
	begin
		DELETE FROM COM_BudgetDefDims WHERE BudgetDefID=@BudgetID

		DELETE FROM COM_BudgetAlloc WHERE BudgetDefID=@BudgetID

		--DELETE FROM COM_BudgetDimRelations WHERE BudgetDefID=@BudgetID
	end
	
	INSERT INTO COM_BudgetDefDims(BudgetDefID,CostCenterID,CompanyGUID,CreatedBy,CreatedDate)
	SELECT  @BudgetID,CCID,@CompanyGUID,@UserName,@DT from @TblDim
	
	set @insertcols=''
	set @selectcols=''
	select @insertcols=@insertcols+','+x.value('@B','nvarchar(30)'),@selectcols=@selectcols+','+x.value('@D','nvarchar(30)') from @XML.nodes('/XML/Map/R') as data(x)
	
	if not exists(select x.value('@B','nvarchar(30)') from @XML.nodes('/XML/Map/R') as data(x) where x.value('@B','nvarchar(30)')='Rate')
	begin
		select @insertcols=@insertcols+',Rate'
		select @selectcols=@selectcols+',0'
	end
	
	if @CFField!=''
	begin
		select @insertcols=@insertcols+',CF'
		select @selectcols=@selectcols+',case when T.'+@CFField+'=''Monthly'' then ''M'' else null end'
	end
	--='AnnualBudget'
	
	--select @insertcols,@selectcols
	
	SELECT @insertcols=@insertcols+','+(case when CCID=2 then 'AccountID' when CCID=3 then 'ProductID' else 'CCNID'+convert(nvarchar,CCID-50000) end) 
		,@selectcols=@selectcols+','+(case when CCID=2 or CCID=3 then 'D.'+Name else 'DCC.dcCCNID'+convert(nvarchar,CCID-50000) end) 
	from @TblDim
	
	
	--IF @BudgetTypeID=3
	--BEGIN
	--	select x.value('@B','nvarchar(100)'),x.value('@D','nvarchar(100)') from @XML.nodes('/XML/Map/R') as data(x)
	--	where x.value('@B','nvarchar(100)') like 'aM%'
	--END
	
	set @SQL='INSERT INTO COM_BudgetAlloc(BudgetDefID,CurrencyID,ExchangeRT,DocStatus'+@insertcols+'
	,RowID,CompanyGUID,GUID,CreatedBy,CreatedDate
	)'
	set @SQL=@SQL+'
	SELECT '+convert(nvarchar,@BudgetID)+',CurrencyID,ExchangeRate,StatusID'+@selectcols+'
		,D.DocSeqNo,DID.CompanyGUID,newid(),ModifiedBy,ModifiedDate		
	FROM INV_DocDetails D with(nolock)
	inner join Com_DocID DID with(nolock) ON D.DocID=DID.ID
	inner join COM_DocNumData N with(nolock) on D.InvDocDetailsID=N.InvDocDetailsID
	inner join COM_DocCCData DCC with(nolock) on D.InvDocDetailsID=DCC.InvDocDetailsID'
	if @CFField!=''
		set @SQL=@SQL+' inner join COM_DocTextData T with(nolock) on D.InvDocDetailsID=T.InvDocDetailsID'
	set @SQL=@SQL+' where StatusID=369 and CostCenterID='+convert(nvarchar,@CostCenterID)+' and DocID='+convert(nvarchar,@DocID)
	print(@SQL)
	exec(@SQL)
	
	set @AmtInDecimals=2
	select @AmtInDecimals=convert(int,value) from adm_globalpreferences where name like '%DecimalsinAmount%'
	
	if @BudgetTypeID='0'
	begin
		update COM_BudgetAlloc
		set Month1Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month2Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month3Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month4Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals))
			,Month5Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month6Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month7Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month8Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals))
			,Month9Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month10Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month11Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set Month12Amount=convert(float,round(AnnualAmount-(Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount+Month6Amount+Month7Amount+Month8Amount+Month9Amount+Month10Amount+Month11Amount),@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set YearH1Amount=convert(float,round(Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount+Month6Amount,@AmtInDecimals))
			,Qtr1Amount=convert(float,round(Month1Amount+Month2Amount+Month3Amount,@AmtInDecimals))
			,Qtr2Amount=convert(float,round(Month4Amount+Month5Amount+Month6Amount,@AmtInDecimals))
			,Qtr3Amount=convert(float,round(Month7Amount+Month8Amount+Month9Amount,@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set YearH2Amount=convert(float,round(AnnualAmount-YearH1Amount,@AmtInDecimals)),Qtr4Amount=convert(float,round(AnnualAmount-(Qtr1Amount+Qtr2Amount+Qtr3Amount),@AmtInDecimals))
		where BudgetDefID=@BudgetID		
	end
	else if @BudgetTypeID='1'
	begin
		update COM_BudgetAlloc
		set Month1Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals)),Month2Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals)),Month3Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals))
			,Month4Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals)),Month5Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals))
			,Month7Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals)),Month8Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals)),Month9Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals))
			,Month10Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals)),Month11Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set Month6Amount=convert(float,round(YearH1Amount-(Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount),@AmtInDecimals))
			,Month12Amount=convert(float,round(YearH2Amount-(Month7Amount+Month8Amount+Month9Amount+Month10Amount+Month11Amount),@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set  Qtr1Amount=convert(float,round(Month1Amount+Month2Amount+Month3Amount,@AmtInDecimals))
			,Qtr2Amount=convert(float,round(Month4Amount+Month5Amount+Month6Amount,@AmtInDecimals))
			,Qtr3Amount=convert(float,round(Month7Amount+Month8Amount+Month9Amount,@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set Qtr4Amount=convert(float,round(AnnualAmount-(Qtr1Amount+Qtr2Amount+Qtr3Amount),@AmtInDecimals))
		where BudgetDefID=@BudgetID
	end
	else if @BudgetTypeID='2'
	begin
		update COM_BudgetAlloc
		set Month1Amount=convert(float,round(Qtr1Amount/3,@AmtInDecimals)),Month2Amount=convert(float,round(Qtr1Amount/3,@AmtInDecimals))
		--,Month3Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals))
			,Month4Amount=convert(float,round(Qtr2Amount/3,@AmtInDecimals)),Month5Amount=convert(float,round(Qtr2Amount/3,@AmtInDecimals))
			,Month7Amount=convert(float,round(Qtr3Amount/3,@AmtInDecimals)),Month8Amount=convert(float,round(Qtr3Amount/3,@AmtInDecimals))
			--,Month9Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals))
			,Month10Amount=convert(float,round(Qtr4Amount/3,@AmtInDecimals)),Month11Amount=convert(float,round(Qtr4Amount/3,@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set Month3Amount=convert(float,round(Qtr1Amount-(Month1Amount+Month2Amount),@AmtInDecimals))
			,Month6Amount=convert(float,round(Qtr2Amount-(Month4Amount+Month5Amount),@AmtInDecimals))
			,Month9Amount=convert(float,round(Qtr3Amount-(Month7Amount+Month8Amount),@AmtInDecimals))
			,Month12Amount=convert(float,round(Qtr4Amount-(Month10Amount+Month11Amount),@AmtInDecimals))
		where BudgetDefID=@BudgetID	
		
		update COM_BudgetAlloc
		set YearH1Amount=convert(float,round(Qtr1Amount+Qtr2Amount,@AmtInDecimals))
			,YearH2Amount=convert(float,round(Qtr3Amount+Qtr4Amount,@AmtInDecimals))
		where BudgetDefID=@BudgetID
	end
	else if @BudgetTypeID='3'
	begin
		update COM_BudgetAlloc
		set YearH1Amount=Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount+Month6Amount
			,YearH2Amount=Month7Amount+Month8Amount+Month9Amount+Month10Amount+Month11Amount+Month12Amount
			,Qtr1Amount=Month1Amount+Month2Amount+Month3Amount,Qtr2Amount=Month4Amount+Month5Amount+Month6Amount
			,Qtr3Amount=Month7Amount+Month8Amount+Month9Amount,Qtr4Amount=Month10Amount+Month11Amount+Month12Amount
		where BudgetDefID=@BudgetID	
	end
	
	--select * from COM_BudgetAlloc with(nolock) where BudgetDefID=@BudgetID
GO
