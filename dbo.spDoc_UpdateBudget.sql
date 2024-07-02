USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_UpdateBudget]
	@CostCenterID [int],
	@DocID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@isDel [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @Dt float,@SQL nvarchar(max),@BudgetID INT,@Query nvarchar(max),@AmtInDecimals int,@where  nvarchar(max),@cols nvarchar(max),@stat int

	SET @Dt=CONVERT(FLOAT,GETDATE())

	declare @BudgetName nvarchar(100),@BudgetYear float,@BudgetTypeID int,@BudgetTypeName nvarchar(20),@i int,@cnt int,@Dims nvarchar(100),@CFField nvarchar(20)
	declare @txtShiftDate nvarchar(20),@BudgetAllocID INT,@docseq int,@TransferDim nvarchar(max),@XML xml,@INVID INT,@vtype int,@rowcnt int
	select @TransferDim=PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='BudgetMapFields'
	set @XML=@TransferDim
		
	select @BudgetTypeID=x.value('@BudgetType','INT'),@CFField=x.value('@CF','nvarchar(20)'),@Dims=x.value('@Dims','nvarchar(100)') from @XML.nodes('/XML') as data(x)
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
	
	set @cols=''
	select @cols=@cols+','+name from sys.columns
	where object_id=object_id('COM_BudgetAlloc_history')
	and name like  'CCNID%'
	
	declare @tab table(id int identity(1,1),InvID INT,Vtype int,seq int,STAT int)
	
	if(@isDel=1)
	BEGIN
		insert into @tab
		select Invdocdetailsid,Vouchertype,DocSeqNo,statusid from Inv_docdetails a with(nolock)
		where CostCenterID=@CostCenterID and DocID=@DocID 		
	END
	ELSE
	BEGIN
		insert into @tab
		select Invdocdetailsid,Vouchertype,DocSeqNo,statusid from Inv_docdetails a with(nolock)
		where CostCenterID=@CostCenterID and DocID=@DocID 
		and (vouchertype=-1 or statusid in(369,376))
	END
	
	set @i =0
	select @cnt=count(*) from @tab
	
	WHILE(@i<@cnt)
	BEGIN
		
		set @i=@i+1
		
		select @INVID =InvID,@vtype=Vtype,@docseq=seq,@stat=STAT from @tab where id=@i
		
		set @SQL='select @BudgetID=isnull('+@CFField+',0) from   Com_DocTextData b with(nolock)
		where Invdocdetailsid='+convert(nvarchar,@INVID)
		
		EXEC sp_executesql @SQL, N'@BudgetID INT OUTPUT', @BudgetID OUTPUT   
			
		if @BudgetID is null and @BudgetID=0--NEW
		begin			
			raiserror('select budget',16,1)
		end
		
		
		set @Query=''		
		set @where=''
		
		select @Query=@Query+x.value('@B','nvarchar(30)')+'=case when AH.'+x.value('@B','nvarchar(30)')+' is not null then AH.'+x.value('@B','nvarchar(30)')+' ELSE a.'+x.value('@B','nvarchar(30)')+' end '+case when @stat in(372,376) or @isDel=1 THEN '' else case when @vtype=1 THEN '+' ELSE '-' END +x.value('@D','nvarchar(30)')  end from @XML.nodes('/XML/Map/R') as data(x)
		
		SELECT @where=@where+' and a.'+(case when CCID=2 then 'AccountID' when CCID=3 then 'ProductID' else 'CCNID'+convert(nvarchar,CCID-50000) end) 
			+'='+(case when CCID=2 and @vtype=1 then 'D.CreditAccount' when CCID=2 and @vtype=-1 then 'D.DebitAccount' when CCID=3 THEN 'D.ProductID' else 'DCC.dcCCNID'+convert(nvarchar,CCID-50000) end) 
		from @TblDim
		 
		set @SQL='set @rowcnt=0 select @rowcnt=isnull(Count(*),0),@BudgetAllocID=max(BudgetAllocID) from COM_BudgetAlloc  a with(nolock)
		join INV_DocDetails D with(nolock) on D.Invdocdetailsid='+convert(nvarchar,@INVID)+'		
		inner join COM_DocCCData DCC with(nolock) on D.InvDocDetailsID=DCC.InvDocDetailsID
		where BudgetDefID='+convert(nvarchar(max),@BudgetID)+@where
		
		EXEC sp_executesql @SQL, N'@rowcnt INT OUTPUT,@BudgetAllocID INT OUTPUT', @rowcnt OUTPUT,@BudgetAllocID OUTPUT
		
		if @rowcnt<>1--NEW
		begin
			set @SQL='budget rows mismatch at row no.'+convert(nvarchar(max),@docseq)
			raiserror(@SQL,16,1)
		end
		
		if not exists(select InvDocdetailsID from COM_BudgetAlloc_history WITH(NOLOCK) where InvDocdetailsID=@INVID)
		BEGIN
			set @SQL='insert into COM_BudgetAlloc_history(InvDocdetailsID,[BudgetAllocID],
			[BudgetDefID],
			[CurrencyID] ,
			[ExchangeRT] ,
			[AnnualAmount] ,
			[YearH1Amount] ,
			[YearH2Amount] ,
			[Qtr1Amount] ,
			[Qtr2Amount] ,
			[Qtr3Amount] ,
			[Qtr4Amount] ,
			[Month1Amount] ,
			[Month2Amount] ,
			[Month3Amount] ,
			[Month4Amount] ,
			[Month5Amount] ,
			[Month6Amount] ,
			[Month7Amount] ,
			[Month8Amount] ,
			[Month9Amount] ,
			[Month10Amount] ,
			[Month11Amount] ,
			[Month12Amount] ,
			[CompanyGUID] ,
			[GUID] ,
			[Description],
			[CreatedBy] ,
			[CreatedDate],
			[ModifiedBy] ,
			[ModifiedDate],
			[RowID]  ,
			[CF] ,
			[AccountID] ,
			[ProductID] ,
			[Rate] ,
			[dcNumField1] ,
			[dcNumField2] ,
			[dcNumField3] ,
			[dcNumField4] ,
			[dcNumField5] ,
			[DocStatus] '+@cols+') select '+convert(nvarchar(max),@INVID)+',BudgetAllocID,[BudgetDefID],
			[CurrencyID] ,
			[ExchangeRT] ,
			[AnnualAmount] ,
			[YearH1Amount] ,
			[YearH2Amount] ,
			[Qtr1Amount] ,
			[Qtr2Amount] ,
			[Qtr3Amount] ,
			[Qtr4Amount] ,
			[Month1Amount] ,
			[Month2Amount] ,
			[Month3Amount] ,
			[Month4Amount] ,
			[Month5Amount] ,
			[Month6Amount] ,
			[Month7Amount] ,
			[Month8Amount] ,
			[Month9Amount] ,
			[Month10Amount] ,
			[Month11Amount] ,
			[Month12Amount] ,
			[CompanyGUID] ,
			[GUID] ,
			[Description],
			[CreatedBy] ,
			[CreatedDate],
			[ModifiedBy] ,
			[ModifiedDate],
			[RowID] ,
			[CF] ,
			[AccountID] ,
			[ProductID] ,
			[Rate] ,
			[dcNumField1] ,
			[dcNumField2] ,
			[dcNumField3] ,
			[dcNumField4] ,
			[dcNumField5] ,
			[DocStatus] '+@cols+' from COM_BudgetAlloc WITH(NOLOCK)
			 where BudgetDefID='+convert(nvarchar(max),@BudgetID)+' and BudgetAllocID='+convert(nvarchar(max),@BudgetAllocID)
			 print @SQL
			exec(@SQL)
		 END
			
		set @SQL='update a set '+@Query+'
		FROM COM_BudgetAlloc a with(nolock)
		left join COM_BudgetAlloc_history AH with(nolock) on AH.Invdocdetailsid='+convert(nvarchar,@INVID)+'
		join INV_DocDetails D with(nolock) on D.Invdocdetailsid='+convert(nvarchar,@INVID)+'
		inner join COM_DocNumData N with(nolock) on D.InvDocDetailsID=N.InvDocDetailsID
		inner join COM_DocCCData DCC with(nolock) on D.InvDocDetailsID=DCC.InvDocDetailsID
		where a.BudgetDefID='+convert(nvarchar(max),@BudgetID)+' and a.BudgetAllocID='+convert(nvarchar(max),@BudgetAllocID)+@where
		--print(@SQL)
		exec(@SQL)
		 
		
		set @AmtInDecimals=2
		select @AmtInDecimals=convert(int,value) from adm_globalpreferences where name like '%DecimalsinAmount%'
		
		if @BudgetTypeID='0'
		begin
			update COM_BudgetAlloc
			set Month1Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month2Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month3Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month4Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals))
				,Month5Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month6Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month7Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month8Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals))
				,Month9Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month10Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals)),Month11Amount=convert(float,round(AnnualAmount/12,@AmtInDecimals))
			where BudgetDefID=@BudgetID	and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set Month12Amount=convert(float,round(AnnualAmount-(Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount+Month6Amount+Month7Amount+Month8Amount+Month9Amount+Month10Amount+Month11Amount),@AmtInDecimals))
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set YearH1Amount=convert(float,round(Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount+Month6Amount,@AmtInDecimals))
				,Qtr1Amount=convert(float,round(Month1Amount+Month2Amount+Month3Amount,@AmtInDecimals))
				,Qtr2Amount=convert(float,round(Month4Amount+Month5Amount+Month6Amount,@AmtInDecimals))
				,Qtr3Amount=convert(float,round(Month7Amount+Month8Amount+Month9Amount,@AmtInDecimals))
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set YearH2Amount=convert(float,round(AnnualAmount-YearH1Amount,@AmtInDecimals)),Qtr4Amount=convert(float,round(AnnualAmount-(Qtr1Amount+Qtr2Amount+Qtr3Amount),@AmtInDecimals))
			where BudgetDefID=@BudgetID			and BudgetAllocID=@BudgetAllocID
		end
		else if @BudgetTypeID='1'
		begin
			update COM_BudgetAlloc
			set Month1Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals)),Month2Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals)),Month3Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals))
				,Month4Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals)),Month5Amount=convert(float,round(YearH1Amount/6,@AmtInDecimals))
				,Month7Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals)),Month8Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals)),Month9Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals))
				,Month10Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals)),Month11Amount=convert(float,round(YearH2Amount/6,@AmtInDecimals))
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set Month6Amount=convert(float,round(YearH1Amount-(Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount),@AmtInDecimals))
				,Month12Amount=convert(float,round(YearH2Amount-(Month7Amount+Month8Amount+Month9Amount+Month10Amount+Month11Amount),@AmtInDecimals))
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set  Qtr1Amount=convert(float,round(Month1Amount+Month2Amount+Month3Amount,@AmtInDecimals))
				,Qtr2Amount=convert(float,round(Month4Amount+Month5Amount+Month6Amount,@AmtInDecimals))
				,Qtr3Amount=convert(float,round(Month7Amount+Month8Amount+Month9Amount,@AmtInDecimals))
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set Qtr4Amount=convert(float,round(AnnualAmount-(Qtr1Amount+Qtr2Amount+Qtr3Amount),@AmtInDecimals))
			where BudgetDefID=@BudgetID	and BudgetAllocID=@BudgetAllocID
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
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set Month3Amount=convert(float,round(Qtr1Amount-(Month1Amount+Month2Amount),@AmtInDecimals))
				,Month6Amount=convert(float,round(Qtr2Amount-(Month4Amount+Month5Amount),@AmtInDecimals))
				,Month9Amount=convert(float,round(Qtr3Amount-(Month7Amount+Month8Amount),@AmtInDecimals))
				,Month12Amount=convert(float,round(Qtr4Amount-(Month10Amount+Month11Amount),@AmtInDecimals))
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
			
			update COM_BudgetAlloc
			set YearH1Amount=convert(float,round(Qtr1Amount+Qtr2Amount,@AmtInDecimals))
				,YearH2Amount=convert(float,round(Qtr3Amount+Qtr4Amount,@AmtInDecimals))
			where BudgetDefID=@BudgetID	and BudgetAllocID=@BudgetAllocID
		end
		else if @BudgetTypeID='3'
		begin
			update COM_BudgetAlloc
			set YearH1Amount=Month1Amount+Month2Amount+Month3Amount+Month4Amount+Month5Amount+Month6Amount
				,YearH2Amount=Month7Amount+Month8Amount+Month9Amount+Month10Amount+Month11Amount+Month12Amount
				,Qtr1Amount=Month1Amount+Month2Amount+Month3Amount,Qtr2Amount=Month4Amount+Month5Amount+Month6Amount
				,Qtr3Amount=Month7Amount+Month8Amount+Month9Amount,Qtr4Amount=Month10Amount+Month11Amount+Month12Amount
			where BudgetDefID=@BudgetID		and BudgetAllocID=@BudgetAllocID
		end
		
	END
GO
