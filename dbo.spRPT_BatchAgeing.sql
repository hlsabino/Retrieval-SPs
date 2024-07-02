USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_BatchAgeing]
	@ToDate [datetime],
	@IsQty [bit],
	@CCWHERE [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON
	declare @SQL NVARCHAR(MAX),@XML xml,@CCJoin nvarchar(max),@S1 int,@S2 int,@S3 int,@S4 int,@AsOn float,@I int,@CNT int,@ID int,@S int,@BatchConsolidated bit
	create table #TblS(ID INT IDENTITY(0,1) PRIMARY KEY,FromDate FLOAT,ToDate FLOAT,Value FLOAT default(0),Slab nvarchar(max))
-- IDENTITY(-1,1)
--set @XML=@ExpirySlab
--insert into #TblS(FromDate,ToDate,Value)
--select convert(float,X.value('@Fr','datetime')),convert(float,X.value('@To','datetime')),0
--from @XML.nodes('/XML/R') as data(x)

select @XML=replace(replace(replace(replace(DefaultPreferences,'Slab1','S'),'Slab2','S'),'Slab3','S'),'Slab4','S') from adm_revenuReports with(nolock) where ReportID=83

insert into #TblS(ToDate,Slab)
select data.X.value('(.)[1]','int') Slabs,data.X.value('(.)[1]','int')
from @XML.nodes('/XML/Slabs/S') as data(x)
where data.X.value('(.)[1]','int')>0
order by Slabs

--select * from #TblS

set @AsOn=CONVERT(FLOAT,@ToDate)

select @I=0,@CNT=count(*) from #TblS
while(@I<@CNT)
begin
	select @ID=ID,@S=ToDate from #TblS where ID=@I
	update #TblS set FromDate=@AsOn+@S,Slab=convert(nvarchar,@S+1)+'-'+Slab where ID=@I+1
	update #TblS set ToDate=@AsOn+ToDate-1 where ID=@I
	set @I=@I+1
end

--select * from #TblS

update #TblS set FromDate=@AsOn,Slab='0-'+Slab where ID=0

SET IDENTITY_INSERT #TblS ON
INSERT INTO #TblS(ID,FromDate,ToDate,Value,Slab) VALUES(-1,0,@AsOn-1,0,'Expired')
SET IDENTITY_INSERT #TblS OFF

INSERT INTO #TblS(FromDate,ToDate,Value,Slab) 
select ToDate+1,123456,0,'> '+convert(nvarchar,ToDate+1-@AsOn) from #TblS where ID=@CNT-1

/*
select * from #TblS

select @XML=DefaultPreferences from adm_revenuReports with(nolock) where ReportID=83
select @S1=X.value('Slab1[1]','int'),@S2=X.value('Slab2[1]','int'),@S3=X.value('Slab3[1]','int'),@S4=X.value('Slab4[1]','int')
from @XML.nodes('/XML/Slabs') as data(x)

create table #TblS2(ID INT  PRIMARY KEY,FromDate FLOAT,ToDate FLOAT,Value FLOAT default(0))
INSERT INTO #TblS2 VALUES(-1,0,@AsOn-1,0)
INSERT INTO #TblS2 VALUES(0,@AsOn,@AsOn+@S1-1,0)
INSERT INTO #TblS2 VALUES(1,@AsOn+@S1,@AsOn+@S2-1,0)
INSERT INTO #TblS2 VALUES(2,@AsOn+@S2,@AsOn+@S3-1,0)
INSERT INTO #TblS2 VALUES(3,@AsOn+@S3,@AsOn+@S4-1,0)
INSERT INTO #TblS2 VALUES(4,@AsOn+@S4,123456,0)

select * from #TblS2
*/

if @CCWHERE!=''
	set @CCJoin=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON D.InvDocDetailsID=DCC.InvDocDetailsID '
else
	set @CCJoin=''

set @BatchConsolidated=isnull((SELECT 1 FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=16 AND Name='ConsolidatedBatches' and Value='True'),0)

IF @IsQty=1
BEGIN
	set @SQL='
declare @AsOn float
set @AsOn='+convert(nvarchar,CONVERT(FLOAT,@ToDate))+'
declare @TblSold As Table(BatchID BIGINT PRIMARY KEY,Qty FLOAT)
DECLARE @ExpiryDate FLOAT,@BatchID bigint,@Quantity FLOAT,@Rate FLOAT,@PrevBatchID bigint,@SoldQty float,@I int
set @PrevBatchID=-234565

update #TblS
set Value=T.Quantity
from #TblS S join
(
SELECT T.ID,SUM(D.UOMConvertedQty*D.VoucherType) Quantity
FROM INV_DocDetails D WITH(NOLOCK)
INNER JOIN INV_Batches B WITH(NOLOCK) ON B.BatchID=D.BatchID
INNER JOIN #TblS T ON B.ExpiryDate BETWEEN T.FromDate AND T.ToDate
INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
'+@CCJoin+'
WHERE D.BatchID>1 and D.IsQtyIgnored=0 and (D.VoucherType=1 or D.VoucherType=-1) AND D.DocDate<=@AsOn and D.StatusID=369 and B.ExpiryDate is not null
'+@CCWHERE+'
GROUP BY T.ID
) AS T on S.ID=T.ID
'
END
ELSE IF @BatchConsolidated=0
BEGIN
	set @SQL='
declare @AsOn float
set @AsOn='+convert(nvarchar,CONVERT(FLOAT,@ToDate))+'
declare @TblSold As Table(BatchID BIGINT PRIMARY KEY,Qty FLOAT)
DECLARE @ExpiryDate FLOAT,@BatchID bigint,@Quantity FLOAT,@Rate FLOAT,@PrevBatchID bigint,@SoldQty float,@I int
set @PrevBatchID=-234565

update #TblS
set Value=T.Value
from #TblS S join
(
select T.ID,sum(Value) Value
from (
SELECT T.ID,(D.UOMConvertedQty-isnull(ISS.IssQty,0))*D.Rate Value
FROM INV_DocDetails D WITH(NOLOCK)
INNER JOIN INV_Batches B WITH(NOLOCK) ON B.BatchID=D.BatchID
INNER JOIN #TblS T ON B.ExpiryDate BETWEEN T.FromDate AND T.ToDate
INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
'+@CCJoin+'
left join (SELECT RefInvDocDetailsID,sum(D.UOMConvertedQty) IssQty
FROM INV_DocDetails D WITH(NOLOCK)
WHERE D.BatchID>1 and D.VoucherType=-1 AND D.IsQtyIgnored=0 AND D.DocDate<=@AsOn and D.StatusID=369 and RefInvDocDetailsID>0
AND (D.RefInvDocDetailsID=0 OR D.RefInvDocDetailsID IS NULL) 
group by RefInvDocDetailsID) as ISS on ISS.RefInvDocDetailsID=D.InvDocDetailsID
WHERE D.BatchID>1 and D.IsQtyIgnored=0 and (D.VoucherType=1 or D.VoucherType=-1) AND D.DocDate<=@AsOn and D.StatusID=369 and B.ExpiryDate is not null
'+@CCWHERE+'
) AS T
GROUP BY T.ID
) AS T on S.ID=T.ID
'
END
ELSE
BEGIN

set @SQL='
declare @AsOn float
set @AsOn='+convert(nvarchar,CONVERT(FLOAT,@ToDate))+'
declare @TblSold As Table(BatchID BIGINT PRIMARY KEY,Qty FLOAT)
DECLARE @SPInvoice cursor, @nStatusOuter int
DECLARE @ExpiryDate FLOAT,@BatchID bigint,@Quantity FLOAT,@Rate FLOAT,@PrevBatchID bigint,@SoldQty float,@I int
set @PrevBatchID=-234565

SET @SPInvoice = cursor for 
SELECT B.ExpiryDate
,B.BatchID,SUM(D.UOMConvertedQty) Quantity,MAX(D.Rate) Rate
FROM INV_DocDetails D WITH(NOLOCK)
INNER JOIN INV_Batches B WITH(NOLOCK) ON B.BatchID=D.BatchID
INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
'+@CCJoin+'
WHERE D.BatchID>1 and D.VoucherType=1 and D.IsQtyIgnored=0 AND D.DocDate<=@AsOn and D.StatusID=369 and B.ExpiryDate is not null
'+@CCWHERE+'
GROUP BY B.BatchID,B.ExpiryDate,D.Rate
ORDER BY B.BatchID,B.ExpiryDate,Rate

OPEN @SPInvoice 
SET @nStatusOuter = @@FETCH_STATUS

INSERT INTO @TblSold
SELECT D.BatchID,SUM(D.UOMConvertedQty) Quantity
FROM INV_DocDetails D WITH(NOLOCK)
'+@CCJoin+'
WHERE D.BatchID>1 and D.VoucherType=-1 AND D.IsQtyIgnored=0 AND D.DocDate<=@AsOn and D.StatusID=369
'+@CCWHERE+'
AND (D.RefInvDocDetailsID=0 OR D.RefInvDocDetailsID IS NULL) 
GROUP BY D.BatchID

set @I=0
set @SoldQty=0

FETCH NEXT FROM @SPInvoice Into @ExpiryDate,@BatchID,@Quantity,@Rate
SET @nStatusOuter = @@FETCH_STATUS
while(@nStatusOuter!=-1)
begin
	if @PrevBatchID!=@BatchID
	begin
		if(@SoldQty<0)
		begin
			select @BatchID,@SoldQty
			update #TblS set Value=Value+@SoldQty*@Rate where @ExpiryDate between FromDate and ToDate
		end
		set @SoldQty=isnull((SELECT Qty FROM @TblSold WHERE BatchID=@BatchID),0)
	end
	if(@SoldQty>0)
	begin
		set @Quantity=@Quantity-@SoldQty;
		if (@Quantity>=0)
		begin
			set @SoldQty=0
			update #TblS set Value=Value+@Quantity*@Rate where @ExpiryDate between FromDate and ToDate
		end
		else
		begin
			set @SoldQty=@SoldQty-@Quantity;
			set @Quantity=0
		end
	end
	else
	begin
		update #TblS set Value=Value+@Quantity*@Rate where @ExpiryDate between FromDate and ToDate
	end
	
	print(convert(nvarchar,@I)+''.''+convert(nvarchar,@BatchID)+''-''+convert(nvarchar,@SoldQty))
	FETCH NEXT FROM @SPInvoice Into @ExpiryDate,@BatchID,@Quantity,@Rate
	SET @nStatusOuter = @@FETCH_STATUS
	set @I=@I+1
end
CLOSE @SPInvoice
DEALLOCATE @SPInvoice
'
END
PRINT(@SQL)
EXEC(@SQL)

select Slab,Value Balance from #TblS order by ID

/*
declare @Tbl As Table(ID INT IDENTITY(-1,1) PRIMARY KEY,FromDate FLOAT,ToDate FLOAT,Value FLOAT)
declare @TblSold As Table(BatchID BIGINT PRIMARY KEY,Qty FLOAT)
set @AsOn=CONVERT(FLOAT,@ToDate)
--INSERT INTO @Tbl VALUES(-1,0,@AsOn-1,0)
--INSERT INTO @Tbl VALUES(0,@AsOn,@AsOn+29,0)
--INSERT INTO @Tbl VALUES(1,@AsOn+30,@AsOn+59,0)
--INSERT INTO @Tbl VALUES(2,@AsOn+60,@AsOn+89,0)
--INSERT INTO @Tbl VALUES(3,@AsOn+90,@AsOn+119,0)
--INSERT INTO @Tbl VALUES(4,@AsOn+120,123456,0)

set @XML=@ExpirySlab
insert into @Tbl(FromDate,ToDate,Value)
select convert(float,X.value('@Fr','datetime')),convert(float,X.value('@To','datetime')),0
from @XML.nodes('/XML/R') as data(x)

DECLARE @SPInvoice cursor, @nStatusOuter int
DECLARE @ExpiryDate FLOAT,@BatchID bigint,@Quantity FLOAT,@Rate FLOAT,@PrevBatchID bigint,@SoldQty float,@I int
set @PrevBatchID=-234565

SET @SPInvoice = cursor for 
SELECT D.DocDate--T.ID
,B.BatchID,SUM(D.UOMConvertedQty) Quantity,MAX(D.Rate) Rate
FROM INV_DocDetails D WITH(NOLOCK)
INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON D.InvDocDetailsID=DCC.InvDocDetailsID  AND DCC.dcCCNID2=4
INNER JOIN INV_Batches B WITH(NOLOCK) ON B.BatchID=D.BatchID
--INNER JOIN @Tbl T ON B.ExpiryDate BETWEEN T.FromDate AND T.ToDate
INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
WHERE D.BatchID>1 and D.VoucherType=1 and D.IsQtyIgnored=0 AND D.DocDate<=@AsOn and B.ExpiryDate is not null
GROUP BY B.BatchID,D.DocDate,D.Rate
ORDER BY B.BatchID,D.DocDate,Rate

OPEN @SPInvoice 
SET @nStatusOuter = @@FETCH_STATUS

INSERT INTO @TblSold
SELECT B.BatchID,SUM(D.UOMConvertedQty) Quantity
FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON D.InvDocDetailsID=DCC.InvDocDetailsID  AND DCC.dcCCNID2=4
INNER JOIN INV_Batches B  WITH(NOLOCK) ON B.BatchID=D.BatchID
INNER JOIN INV_Product P WITH(NOLOCK) ON B.ProductID=P.ProductID WHERE D.BatchID>1 and D.VoucherType=-1 AND D.IsQtyIgnored=0 AND D.DocDate<=@AsOn
AND (D.RefInvDocDetailsID=0 OR D.RefInvDocDetailsID IS NULL) 
GROUP BY B.BatchID

set @I=0
set @SoldQty=0

FETCH NEXT FROM @SPInvoice Into @DocDate,@BatchID,@Quantity,@Rate
SET @nStatusOuter = @@FETCH_STATUS
while(@nStatusOuter!=-1)
begin
	if @PrevBatchID!=@BatchID
	begin
		if(@SoldQty<0)
		begin
			select @BatchID,@SoldQty
			update @Tbl set Value=Value+@SoldQty*@Rate where @DocDate between FromDate and ToDate
		end
		set @SoldQty=isnull((SELECT Qty FROM @TblSold WHERE BatchID=@BatchID),0)
	end
	if(@SoldQty>0)
	begin
		set @Quantity=@Quantity-@SoldQty;
		if (@Quantity>=0)
		begin
			set @SoldQty=0
			update @Tbl set Value=Value+@Quantity*@Rate where @DocDate between FromDate and ToDate
		end
		else
		begin
			set @SoldQty=@SoldQty-@Quantity;
			set @Quantity=0
		end
	end
	else
	begin
		update @Tbl set Value=Value+@Quantity*@Rate where @DocDate between FromDate and ToDate
	end
	
	print(convert(nvarchar,@I)+'.'+convert(nvarchar,@BatchID)+'-'+convert(nvarchar,@SoldQty))
	FETCH NEXT FROM @SPInvoice Into @DocDate,@BatchID,@Quantity,@Rate
	SET @nStatusOuter = @@FETCH_STATUS
	set @I=@I+1
end
CLOSE @SPInvoice
DEALLOCATE @SPInvoice
select * from @Tbl

*/

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
