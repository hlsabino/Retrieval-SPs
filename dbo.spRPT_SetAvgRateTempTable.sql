USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SetAvgRateTempTable]
	@IsOpening [bit],
	@ProductID [nvarchar](max),
	@TagID [nvarchar](max),
	@JoinSQL [nvarchar](max),
	@WhereSQL [nvarchar](max),
	@FromDate [datetime],
	@ToDate [datetime],
	@IncludeUpPostedDocs [bit],
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@TempTable NVARCHAR(MAX),@INSERTTagColumn NVARCHAR(20),@TagColumn NVARCHAR(20),@Order NVARCHAR(100)
	
	--DROPPING UN-USED TABLES
	set @SQL=''
	select @SQL=@SQL+'
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].['+TempTableName+']'') AND type in (N''U''))
DROP TABLE '+TempTableName+'
DELETE FROM RPT_TempTables WHERE TempTableName='''+TempTableName+''''
	from PACT2C.[dbo].RPT_TempTables with(nolock)
	where convert(float,GETDATE())-1>CreatedDate
	if(@SQL!='')
	begin
		set @SQL='USE PACT2C'+@SQL
		--print(@SQL)
		exec(@SQL)		
	end
	
	--CREATE TEMP TABLE
	set @TempTable='RPT_X'+ replace(NEWID(),'-','') 
	SET @SQL=' CREATE TABLE PACT2C.[dbo].['+@TempTable+'](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[ProductID] [bigint] NOT NULL,'
	if(@TagID>50000)
		SET @SQL=@SQL+'[TagID] [bigint] NULL,'
	SET @SQL=@SQL+'[DocDate] [float] NOT NULL,
	[Qty] [float] NOT NULL,
	[RecRate] [float] NULL,
	[RecValue] [float] NULL,
	[VoucherType] [smallint] NOT NULL,
	[DocumentType] [smallint] NOT NULL
) ON [PRIMARY]

CREATE NONCLUSTERED INDEX ['+@TempTable+'_ProductID_Index] ON PACT2C.[dbo].['+@TempTable+']
(
	[ProductID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
'
if(@TagID>50000)
set @SQL=@SQL+'
CREATE NONCLUSTERED INDEX ['+@TempTable+'_TagID_Index] ON PACT2C.[dbo].['+@TempTable+']
(
	[TagID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
'
--print(@SQL)
exec(@SQL)
	
	INSERT INTO PACT2C.[dbo].RPT_TempTables(TempTableName,CreatedBy,CreatedDate)
	VALUES(@TempTable,@UserName,CONVERT(float,getdate()))


		
	if(@TagID>50000)
	begin
		set @TagColumn=',DCC.DCCCNID'+convert(nvarchar,@TagID-50000)+' TAGID'
		set @INSERTTagColumn=',TagID'
	end
	else
	begin
		set @TagColumn=''
		set @INSERTTagColumn=''
	end

	IF @WhereSQL like '%DCCCNID%'
		set @Order='DocDate,ST DESC,VoucherType DESC,VoucherNo'
	ELSE
		set @Order='DocDate,ST DESC,VoucherNo,VoucherType DESC'
		
	IF @IncludeUpPostedDocs=0
		SET @WhereSQL=@WhereSQL+' AND D.StatusID=369'
	
	
	SET @SQL='DECLARE @FromDate FLOAT,@ToDate FLOAT
	SET @FromDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+'
	SET @ToDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))+'
	
	INSERT INTO PACT2C.[dbo].['+@TempTable+'](ProductID'+@INSERTTagColumn+',DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType)
	'

	IF @IsOpening=1
	BEGIN
		SET @SQL=@SQL+'SELECT ProductID'+@INSERTTagColumn+',DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType FROM (
		SELECT ProductID'+@TagColumn+',D.DocDate DocDate,D.VoucherNo,UOMConvertedQty Qty,StockValue/UOMConvertedQty RecRate,StockValue RecValue,VoucherType,DocumentType,case when DocumentType=5 then 1 else 2 end ST
		FROM INV_DocDetails D WITH(NOLOCK) '+@JoinSQL+'
		WHERE IsQtyIgnored=0 AND UOMConvertedQty!=0 AND D.VoucherType=1 
			AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'+@WhereSQL
		
		if(@ProductID!='')
			set @SQL=@SQL+' AND D.ProductID IN ('+@ProductID+')'
			
		SET @SQL=@SQL+' UNION ALL
		SELECT ProductID'+@TagColumn+',D.DocDate,D.VoucherNo,UOMConvertedQty,NULL RecRate,NULL RecValue,-1 VoucherType,DocumentType,case when DocumentType=5 then 1 else 0 end ST
		FROM INV_DocDetails D WITH(NOLOCK) '+@JoinSQL+'
		WHERE IsQtyIgnored=0 AND D.VoucherType=-1
			AND D.DocDate<@FromDate'+@WhereSQL
		if(@ProductID!='')
			set @SQL=@SQL+' AND D.ProductID IN ('+@ProductID+')'
	END
	ELSE
	BEGIN
		SET @SQL=@SQL+'SELECT ProductID'+@INSERTTagColumn+',DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType FROM (
		SELECT ProductID'+@TagColumn+',D.DocDate DocDate,D.VoucherNo,UOMConvertedQty Qty,StockValue/UOMConvertedQty RecRate,StockValue RecValue,VoucherType,DocumentType,case when DocumentType=5 then 1 else 2 end ST
		FROM INV_DocDetails D WITH(NOLOCK) '+@JoinSQL+'
		WHERE IsQtyIgnored=0 AND UOMConvertedQty!=0 AND D.VoucherType=1 AND D.DocDate<=@ToDate'+@WhereSQL
		
		if(@ProductID!='')
			set @SQL=@SQL+' AND D.ProductID IN ('+@ProductID+')'
		
		SET @SQL=@SQL+' 
		UNION ALL
		SELECT ProductID'+@TagColumn+',D.DocDate,D.VoucherNo,UOMConvertedQty,NULL RecRate,NULL RecValue,-1 VoucherType,DocumentType,case when DocumentType=5 then 1 else 0 end ST
		FROM INV_DocDetails D WITH(NOLOCK) '+@JoinSQL+'
		WHERE IsQtyIgnored=0 AND D.VoucherType=-1
			AND D.DocDate<=@ToDate'+@WhereSQL
		if(@ProductID!='')
		begin
			set @SQL=@SQL+' AND D.ProductID IN ('+@ProductID+')'
		end
	END

	SET @SQL=@SQL+') AS T'

	--BELOW CODE COMMENTED TO ADD ST ORDER BY 
	SET @SQL=@SQL+' ORDER BY '+@Order

--print(@SQL)
	
	EXEC(@SQL)
	
--	exec('select * from PACT2C.[dbo].['+@TempTable+']')
	select @TempTable TABLENAME
	RETURN 1
GO
