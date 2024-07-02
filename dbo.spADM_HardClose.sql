USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_HardClose]
	@Type [int],
	@YearID [bigint],
	@AccXml [nvarchar](max),
	@InvXml [nvarchar](max),
	@UserName [nvarchar](100),
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
declare @XML xml,@SQL nvarchar(max),@CC nvarchar(max),@iCloseDate int,@CloseDate datetime,@LocationID bigint,@LocWhere nvarchar(max)

select @CloseDate=convert(datetime,ToDate),@iCloseDate=ToDate,@LocationID=LocationID from ADM_FinancialYears with(nolock) where FinancialYearsID=@YearID

if @Type=1
begin
	delete from INV_ProductClose where CloseDate=convert(int,@CloseDate)
	
	update ADM_FinancialYears
	set InvClose=0,AccCloseXML=null,InvCloseXML=null
	where FinancialYearsID=@YearID
end
else if @Type=2
begin
	declare @CCCols nvarchar(max),@CCValues nvarchar(max),@AmountFC nvarchar(40),@IsLWFinal bit
	declare @Tbl as Table(PID bigint,CCWhere nvarchar(max),CCValue nvarchar(max))
	
	if exists (select Value from adm_globalpreferences with(nolock) where Name='EnableLocationWise' and Value='True') 
			and exists (select Value from adm_globalpreferences with(nolock) where Name='LWFinalization' and Value='True')
		set @IsLWFinal=1
	else
		set @IsLWFinal=0
	--ALTER TABLE
	if @AccXml!=''
	begin
		set @SQL=''
		set @XML=@AccXml
		SELECT @SQL=@SQL+',dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)+' int not null default(1)'
		FROM @XML.nodes('/XML/CC') as DATA(X)
		left join sys.columns C on C.name='dcCCNID'+convert(nvarchar,X.value('@value','int')-50000) and object_id=object_id('ACC_AccountsClose')
		where C.name is null and X.value('@value','int')>50000
		
		SELECT @SQL=@SQL+',CurrencyID int not null default(1)'
		FROM @XML.nodes('/XML/CC') as DATA(X)
		left join sys.columns C on C.name='CurrencyID' and object_id=object_id('ACC_AccountsClose')
		where C.name is null and X.value('@value','int')=12
		
		if @SQL!=''
		begin
			set @SQL=substring(@SQL,2,len(@SQL))
			set @SQL='alter table ACC_AccountsClose add '+@SQL
			exec(@SQL)
		end
	end

	set @CC=''
	set @SQL=''
	set @CCCols=''
	set @CCValues=''
	if @AccXml!=''
	begin
		set @XML=@AccXml
		SELECT @CC=@CC+',DCC.dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)
		,@CCCols=@CCCols+',dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)
		FROM @XML.nodes('/XML/CC') as DATA(X)
		WHERE X.value('@value','int')>50000
		
		SELECT @CC=@CC+',D.CurrencyID',@CCCols=@CCCols+',CurrencyID'
		FROM @XML.nodes('/XML/CC') as DATA(X)
		WHERE X.value('@value','int')=12
	end
	
	if @CC!=''
		set @CCValues=' join COM_DocCCDATA DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID'
	
	if @CCCols like '%CurrencyID%'
		set @AmountFC='sum(AmountFC)'
	else
		set @AmountFC=''

	set @LocWhere=''
	if @IsLWFinal=1
	begin
		set @SQL='delete from ACC_AccountsClose where CloseDate='+convert(nvarchar,convert(int,@CloseDate))+' and dcCCNID2='+convert(nvarchar,@LocationID)
		exec(@SQL)
		set @LocWhere=' and DCC.dcCCNID2='+convert(nvarchar,@LocationID)
	end
	else
		delete from ACC_AccountsClose where CloseDate=convert(int,@CloseDate)
		
	set @SQL='insert into ACC_AccountsClose(CloseDate,AccountID,Amount,AmountFC'+@CCCols+')
select '+convert(nvarchar,convert(int,@CloseDate))+',AccountID,sum(DrAmount)-sum(CrAmount) Amount,sum(DrAmountFC)-sum(CrAmountFC) AmountFC'+@CCCols+'
from(
	select DebitAccount AccountID,sum(Amount) DrAmount,0.0 CrAmount,sum(AmountFC) DrAmountFC,0.0 CrAmountFC'+@CC+'
	from ACC_DocDetails D with(nolock)'+@CCValues+'
	where D.DebitAccount>0 and StatusID=369 and DocumentType!=14 and DocumentType!=19 and D.DocDate<='+convert(nvarchar,convert(int,@CloseDate))+@LocWhere+'
	group by DebitAccount,VoucherNo'+@CC+'
	union all
	select CreditAccount,0.0 DrAmount,sum(Amount) CrAmount,0.0 DrAmountFC,sum(AmountFC) CrAmountFC'+@CC+'
	from ACC_DocDetails D with(nolock)'+@CCValues+'
	where D.CreditAccount>0 and StatusID=369 and DocumentType!=14 and DocumentType!=19 and D.DocDate<='+convert(nvarchar,convert(int,@CloseDate))+@LocWhere+'
	group by CreditAccount,VoucherNo'+@CC
	if @CC!=''
	begin
		set @SQL=@SQL+'
	union all
	select DebitAccount AccountID,sum(Amount) DrAmount,0.0 CrAmount,sum(AmountFC) DrAmountFC,0.0 CrAmountFC'+@CC+'
	from ACC_DocDetails D with(nolock) join COM_DocCCDATA DCC with(nolock) on DCC.InvDocDetailsID=D.InvDocDetailsID
	where D.DebitAccount>0 and StatusID=369 and DocumentType!=14 and DocumentType!=19 and D.DocDate<='+convert(nvarchar,convert(int,@CloseDate))+@LocWhere+'
	group by DebitAccount,VoucherNo'+@CC+'
	union all
	select CreditAccount,0.0 DrAmount,sum(Amount) CrAmount,0.0 DrAmountFC,sum(AmountFC) CrAmountFC'+@CC+'
	from ACC_DocDetails D with(nolock) join COM_DocCCDATA DCC with(nolock) on DCC.InvDocDetailsID=D.InvDocDetailsID
	where D.CreditAccount>0 and StatusID=369 and DocumentType!=14 and DocumentType!=19 and D.DocDate<='+convert(nvarchar,convert(int,@CloseDate))+@LocWhere+'
	group by CreditAccount,VoucherNo'+@CC
	end
	set @SQL=@SQL+'
) AS T
group by AccountID'+@CCCols+'
having sum(DrAmount)-sum(CrAmount)!=0
order by AccountID'
	--print(@SQL)
	exec(@SQL)
		
	--ALTER TABLE
	if @InvXml!=''
	begin
		set @SQL=''
		set @XML=@InvXml
		SELECT @SQL=@SQL+',dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)+' int not null default(1)'
		FROM @XML.nodes('/XML/CC') as DATA(X)
		left join sys.columns C on C.name='dcCCNID'+convert(nvarchar,X.value('@value','int')-50000) and object_id=object_id('INV_ProductClose')
		where C.name is null
		if @SQL!=''
		begin
			set @SQL=substring(@SQL,2,len(@SQL))
			set @SQL='alter table INV_ProductClose add '+@SQL
			exec(@SQL)
		end
	end
	
	set @CC=''
	set @SQL=''
	set @CCCols=''
	set @CCValues=''
	if @InvXml!=''
	begin
		set @XML=@InvXml
		SELECT @CC=@CC+',DCC.dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)
		,@CCCols=@CCCols+',dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)
		 ,@CCValues=@CCValues+''',''+convert(nvarchar,DCC.dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)+')+'
		,@SQL=@SQL+''' and DCC.dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)+'=''+convert(nvarchar,DCC.dcCCNID'+convert(nvarchar,X.value('@value','int')-50000)+')+'
		FROM @XML.nodes('/XML/CC') as DATA(X)
	end

	if @SQL!=''
	begin
		set @SQL=substring(@SQL,1,len(@SQL)-1)
		set @CCValues=','+substring(@CCValues,1,len(@CCValues)-1)
	end
	else
	begin
		set @SQL=''''''
		set @CCValues=','+''''''
	end
	set @SQL='select ProductID,'+@SQL+@CCValues+' from INV_DocDetails D with(nolock)'
	if @CC!=''
		set @SQL=@SQL+' join COM_DocCCDATA DCC with(nolock) on DCC.InvDocDetailsID=D.InvDocDetailsID'
	set @SQL=@SQL+' 
where StatusID=369 and IsQtyIgnored=0 and D.DocDate<='+convert(nvarchar,convert(int,@CloseDate))+'
group by ProductID'+@CC+'
order by ProductID'
	--print(@SQL)
	insert into @Tbl(PID,CCWhere,CCValue)
	exec(@SQL)
	
	delete from INV_ProductClose where CloseDate=convert(int,@CloseDate)
	
	--select * from @Tbl
	
	declare @SortTransactionsBy nvarchar(50)
	set @SortTransactionsBy=''
	if exists (select * from adm_globalpreferences with(nolock) where name='SortAvgRate' and Value='True')
		select @SortTransactionsBy=value from adm_globalpreferences with(nolock) where name='AvgRateBasedOn'

	DECLARE @CUR_PRODUCT cursor, @nStatusOuter int,@ProductID bigint,@AvgRate FLOAT,@BalQty FLOAT,@BalValue FLOAT,@COGS FLOAT,@CCWhere nvarchar(max)
	
	SET @CUR_PRODUCT = cursor for 
	SELECT PID,CCWhere,CCValue FROM @Tbl 
	
	OPEN @CUR_PRODUCT 
	SET @nStatusOuter = @@FETCH_STATUS
	
	FETCH NEXT FROM @CUR_PRODUCT Into @ProductID,@CCWhere,@CCValues
	SET @nStatusOuter = @@FETCH_STATUS

	WHILE(@nStatusOuter<>-1)
	BEGIN
		EXEC [spRPT_AvgRate] 0,@ProductID,@CCWhere,'',@CloseDate,@CloseDate,0,0,0,0,@SortTransactionsBy,0
		,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
		if @BalQty is not null and @BalQty!=0
		begin
			set @SQL='insert into INV_ProductClose(CloseDate,ProductID,Qty,Rate,BalValue,VoucherType'+@CCCols+')
			values(@iCloseDate,@ProductID,@BalQty,@AvgRate,@BalValue,case when @BalQty<0 then -1 else 1 end'+@CCValues+')'
			EXEC sp_executesql @SQL,N'@iCloseDate int,@ProductID bigint,@BalQty float,@AvgRate float,@BalValue float'
				,@iCloseDate,@ProductID,@BalQty,@AvgRate,@BalValue
		end
		
		FETCH NEXT FROM @CUR_PRODUCT Into @ProductID,@CCWhere,@CCValues
		SET @nStatusOuter = @@FETCH_STATUS
	END
	CLOSE @CUR_PRODUCT
	DEALLOCATE @CUR_PRODUCT
	
	update ADM_FinancialYears
	set InvClose=1,AccCloseXML=@AccXml,InvCloseXML=@InvXml
	where FinancialYearsID=@YearID
end

--ROLLBACK TRANSACTION
COMMIT TRANSACTION

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID       
SET NOCOUNT OFF;      
RETURN 1      
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT * FROM ADM_GlobalPreferences WITH(NOLOCK)     
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
       
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
 ROLLBACK TRANSACTION    
 SET NOCOUNT OFF      
 RETURN -999       
END CATCH 
GO
