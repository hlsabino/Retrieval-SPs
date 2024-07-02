USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_ReorderABC]
	@Join [nvarchar](max),
	@WHERE [nvarchar](max),
	@SalesDocs [nvarchar](max),
	@Slot1 [int],
	@Slot2 [int],
	@Slot3 [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@ToDate datetime,@EndDate datetime,@StDate datetime,@i int
	
	declare @TotalSales float,@Percentage float,@CumPer float,@ID int
	declare @Tbl as table(ID int identity(1,1),ProductID bigint,TotalSales float,StockValue float,class nvarchar(3),Percentage float)
	
	SET @ToDate=getdate()
	SET @ToDate=CONVERT(DATETIME, CONVERT(NVARCHAR,DATEPART(day,@ToDate))+' '+datename(month,@ToDate)+' '+CONVERT(NVARCHAR,DATEPART(year,@ToDate)))

	SET @EndDate=@ToDate
	SET @StDate=DATEADD(dd,-(@Slot1-1),@ToDate)
	
	if @SalesDocs!=''
		set @SalesDocs=' and INV.CostCenterID IN ('+@SalesDocs+') '
	else
		set @SalesDocs=' and IsQtyIgnored=0 and (VoucherType=-1 or documenttype=6) '

	set @SQL='
	SELECT P.ProductID
	,isnull((select -sum(VoucherType*INV.StockValue) from INV_DocDetails INV with(nolock) where INV.ProductID=P.ProductID'+@SalesDocs+' AND INV.StatusID<>438 AND INV.StatusID<>376
		AND convert(datetime,INV.DocDate) BETWEEN @FromDate AND @ToDate),0) [TotalSales]
	,0 --SV.BalValue StockValue
	FROM INV_Product P with(nolock)'+@Join+'
	--left join dbo.fnRPT_AvgRateAllProds('''','''',@FromDate,@ToDate,0,0,0,0,'''') SV on SV.ProductID=P.ProductID
	where P.IsGroup=0 and P.ProductID>0 and P.ProductTypeID!=6'+@WHERE+'
	order by TotalSales desc'

set @i=1
while @i<=3
begin
	if @i=2
	begin
		set @EndDate=DATEADD(dd,-1,@StDate)
		set @StDate=DATEADD(dd,-@Slot2,@StDate)	
	end
	else if @i=3
	begin
		set @EndDate=DATEADD(dd,-1,@StDate)
		set @StDate=DATEADD(dd,-@Slot3,@StDate)	
	end
	
	
	insert into @Tbl(ProductID,TotalSales,StockValue)
	EXEC sp_executesql @SQL,N'@FromDate datetime,@ToDate datetime',@StDate,@EndDate
	
	--print(@SQL)

	select @TotalSales=sum(TotalSales) from @Tbl where TotalSales>0
	set @CumPer=0
	if @TotalSales is null or @TotalSales=0
		update @Tbl set Percentage=0
	else
		update @Tbl set Percentage=(TotalSales*100)/@TotalSales

	--select @StDate,@EndDate,@TotalSales

	declare @SPInvoice cursor, @nStatusOuter int,@I80 int,@I95 int,@I100 int
	SET @SPInvoice=cursor for 
	select ID,Percentage from @Tbl

	OPEN @SPInvoice 

	FETCH NEXT FROM @SPInvoice Into @ID,@Percentage
	SET @nStatusOuter = @@FETCH_STATUS
	while(@nStatusOuter!=-1)
	begin
		set @CumPer=@CumPer+@Percentage
		if @CumPer<80
			set @I80=@ID
		else if @CumPer<95
			set @I95=@ID
		else if @CumPer<100 and @Percentage>0
			set @I100=@ID
		else
		begin
			update @Tbl set Class='D' where ID>=@ID
			break
		end
		FETCH NEXT FROM @SPInvoice Into @ID,@Percentage
		SET @nStatusOuter = @@FETCH_STATUS
	end

	CLOSE @SPInvoice
	DEALLOCATE @SPInvoice	

	if @I80 is null
		set @I80=(select max(ID) from @Tbl)
	if @I95 is null
		set @I95=(select max(ID) from @Tbl)
	if @I100 is null
		set @I100=(select max(ID) from @Tbl)
	update @Tbl set Class='A' where ID>=1 and ID<=@I80
	update @Tbl set Class='B' where ID>@I80 and ID<=@I95
	update @Tbl set Class='C' where ID>@I95 and ID<=@I100

	select ProductID,Class from @Tbl order by ProductID
	
	--select * from @Tbl order by ProductID
	--select * from @Tbl where productid=40804
	
	delete from @Tbl

	set @i=@i+1
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
