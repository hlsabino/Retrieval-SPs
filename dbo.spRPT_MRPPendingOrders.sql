USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_MRPPendingOrders]
	@Type [nvarchar](50),
	@Documents [nvarchar](max),
	@DateField [nvarchar](40),
	@DetailsIDFilter [bit],
	@WHERE [nvarchar](max),
	@CCWHERE [nvarchar](max)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	DECLARE @StrList varchar(max), @SplitChar varchar(2),@Data varchar(max),@Pos INT,@HoldOnSave BIT,@HoldQty BIT,@ReserveQty BIT,@GrpCostCenterID nvarchar(50)
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1),Document INT,HoldOnSave BIT default(0),HoldQty BIT default(0),ReserveQty BIT default(0))
	DECLARE @TblHold AS TABLE(ID INT IDENTITY(1,1),Document INT)
	SET @SplitChar=','
	SET @StrList=@Documents
	SET @StrList=LTRIM(RTRIM(@StrList))+@SplitChar  
	SET @Pos=CHARINDEX(@SplitChar,@StrList,1)  
	IF REPLACE(@StrList,@SplitChar,'')<>''  
	BEGIN  
		WHILE @Pos > 0  
		BEGIN  
			SET @Data=LTRIM(RTRIM(LEFT(@StrList,@Pos-1)))  
			INSERT INTO @Tbl(Document) VALUES(@Data)  
			SET @StrList=RIGHT(@StrList,LEN(@StrList)-@Pos)  
			SET @Pos=CHARINDEX(@SplitChar,@StrList,1)  
		END  
	END  
	--set value for HoldOnSave column for each document
	UPDATE @Tbl
	SET HoldOnSave=1
	FROM @Tbl T INNER JOIN COM_DocumentPreferences P with(nolock) ON P.CostCenterID=T.Document AND P.PrefName='enebleSaveonhold'
	WHERE P.PrefValue='True'
	
	--set value for HoldQty column for each document
	UPDATE @Tbl
	SET HoldQty=1
	FROM @Tbl T INNER JOIN COM_DocumentPreferences P with(nolock) ON P.CostCenterID=T.Document AND P.PrefName='Enable Hold'
	WHERE P.PrefValue='True'
	
	----set value for ReserveQty column for each document
	UPDATE @Tbl
	SET ReserveQty=1
	FROM @Tbl T INNER JOIN COM_DocumentPreferences P with(nolock) ON P.CostCenterID=T.Document AND P.PrefName='Enable Reserve'
	WHERE P.PrefValue='True'
	
	DECLARE @TblMaps AS TABLE(ID INT IDENTITY(1,1),Document INT,ColumnName NVARCHAR(50),LinkColumn NVARCHAR(50))
	DECLARE @CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50)
	DECLARE @I INT,@J INT,@Cnt INT,@CNTDOCS INT,@Document INT
	DECLARE @Query nvarchar(MAX),@SubQry NVARCHAR(MAX),@HoldSaveQuery nvarchar(MAX),@SubQuery nvarchar(MAX)
		,@HoldQuery nvarchar(MAX),@NormalQuery nvarchar(MAX),@ReserveQuery nvarchar(MAX),@Join nvarchar(MAX),@NumJoin nvarchar(MAX),@SELECT1 NVARCHAR(MAX),@SELECT2 NVARCHAR(MAX)
	set @Query=''
	set @SELECT1=''
	set @SELECT2=''
	set @Join=''
	set @GrpCostCenterID=''
	if @Type='ProductDocDateQty'
	begin
		set @SELECT1='A.ProductID,'+@DateField+' DocDate,'
		set @SELECT2='ProductID,DocDate,'
		set @Join=' inner join #TblProducts TP on TP.ProductID=A.ProductID'
	end
	else if @Type='DocumentProductDocDateQty'
	begin
		set @SELECT1='A.ProductID,'+@DateField+' DocDate,A.CostCenterID,'
		set @SELECT2='ProductID,DocDate,CostCenterID,'
		set @Join=' inner join #TblProducts TP on TP.ProductID=A.ProductID'
		set @GrpCostCenterID=',A.CostCenterID'
	end
	else if @Type='ProductsList'
	begin
		set @SELECT1='A.ProductID,'
		set @SELECT2='ProductID,'
	end
	else if @Type='ProductsListWithDocID'
	begin
		set @SELECT1='A.DocID,A.ProductID,'
		set @SELECT2='DocID,ProductID,'
	end
	else if @Type='OrderDetail'
	begin
		set @SELECT1='A.InvDocDetailsID,'
		set @SELECT2='InvDocDetailsID,'
	end
	else if @Type='ProductWisePendingOrderQty'
	begin
		set @SELECT1='A.ProductID,'
		set @SELECT2='ProductID,'
	end
	
	SELECT @I=1,@Cnt=COUNT(*) FROM @Tbl
	WHILE(@I<=@Cnt)
	BEGIN
		SELECT @Document=Document,@HoldOnSave=HoldOnSave,@HoldQty=HoldQty,@ReserveQty=ReserveQty FROM @Tbl WHERE ID=@I
		
		SELECT @SubQry='',@HoldSaveQuery='',@HoldQuery='',@NormalQuery='',@ReserveQuery='',@NumJoin='',@lINKColumnName='',@ColumnName=''

		IF @HoldQty=1
		BEGIN
			IF len(@HoldQuery)>0
				SET @HoldQuery=@HoldQuery+','			
			SET @HoldQuery=@HoldQuery+CONVERT(NVARCHAR,@Document)
		END
		ELSE IF @ReserveQty=1
		BEGIN
			IF len(@ReserveQuery)>0
				SET @ReserveQuery=@ReserveQuery+','			
			SET @ReserveQuery=@ReserveQuery+CONVERT(NVARCHAR,@Document)
		END		 
		ELSE 
		BEGIN
			IF @HoldOnSave=1
			BEGIN
				IF len(@HoldSaveQuery)>0
					SET @HoldSaveQuery=@HoldSaveQuery+','
				SET @HoldSaveQuery=@HoldSaveQuery+CONVERT(NVARCHAR,@Document)
			END
			
			IF len(@NormalQuery)>0
				SET @NormalQuery=@NormalQuery+','			
			SET @NormalQuery=@NormalQuery+CONVERT(NVARCHAR,@Document)
		
			DELETE FROM @TblMaps
			INSERT INTO @TblMaps(Document,ColumnName,LinkColumn)
			SELECT DISTINCT CostCenterIDBase,
				(SELECT SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterColID=[CostCenterColIDBase]),
				(SELECT SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterColID=[CostCenterColIDLinked])
			FROM COM_DocumentLinkDef WITH(NOLOCK) 
			WHERE CostCenterIDLinked=@Document AND IsQtyExecuted=1
		
			SELECT @J=MIN(ID), @CNTDOCS = MAX(ID) FROM @TblMaps	
			IF @CNTDOCS > 0
			BEGIN	
				WHILE(@J<=@CNTDOCS)
				BEGIN
					SELECT @CostCenterID=Document, @ColumnName=ColumnName, @lINKColumnName=LinkColumn FROM @TblMaps WHERE ID=@J
					IF @lINKColumnName IS NOT NULL OR @lINKColumnName<>''
					BEGIN
						IF len(@SubQry)>0
							SET @SubQry=@SubQry+'
							 UNION ALL '
						SET @SubQry=@SubQry+'SELECT B.LinkedFieldValue Qty FROM INV_DocDetails B with(nolock) WHERE A.InvDocDetailsID =B.LinkedInvDocDetailsID AND A.costcenterid='+CONVERT(NVARCHAR,@Document)+' AND B.StatusID<>376 AND B.costcenterid='+CONVERT(NVARCHAR,@CostCenterID)
					END
					SET @J=@J+1					
				END
			END
			ELSE
			BEGIN		
				IF len(@SubQry)>0
					SET @SubQry=@SubQry+' UNION ALL '
				SET @SubQry=@SubQry+'SELECT 0 Qty'
			END	
		END

	IF @NormalQuery<>''
	BEGIN
		IF @SubQry=''
			SET @SubQry='select 1 qty'
			
		if @lINKColumnName is not null and @lINKColumnName like 'dcNum%'
		begin
			set @lINKColumnName='N.'+@lINKColumnName+'*A.UOMConversion'
			SET @NumJoin=' inner join COM_DocNumData N on N.InvDocDetailsID=A.InvDocDetailsID'
		end
		else
			set @lINKColumnName='A.QUANTITY*A.UOMConversion'
		
		SET @SubQry='(case when A.LinkStatusID=445 then A.Quantity else (SELECT ISNULL(SUM(Qty),0) FROM ('+@SubQry+') AS T) END)*A.UOMConversion Executed'
		SET @SubQry='
		SELECT '+@SELECT1+@lINKColumnName+' QTY,'+@SubQry+'
FROM INV_DocDetails A with(nolock)
'+@Join+@NumJoin

		if @DetailsIDFilter=1
			SET @SubQry=@SubQry+' inner join #TblOrderFilter TID on TID.InvDetailsID=A.InvDocDetailsID'
		SET @SubQry=@SubQry+@CCWHERE
		
		SET @NormalQuery=@SubQry+' WHERE A.CostCenterID IN ('+@NormalQuery+') AND A.StatusID<>376'+@WHERE
		IF @HoldSaveQuery!=''
		BEGIN
			SET @HoldSaveQuery=' AND (A.CostCenterID NOT IN ('+@HoldSaveQuery+') OR A.StatusID<>369)'
			SET @NormalQuery=@NormalQuery+@HoldSaveQuery
		END

		SET @NormalQuery='select '+@SELECT2+'QTY,case when Executed>QTY then QTY else Executed end Executed from('+@NormalQuery+') as T'
	END
	
	declare @cancelleddocs nvarchar(max)
	select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs'    
	if(@cancelleddocs is not null and @cancelleddocs<>'')
		set @cancelleddocs=' or l.Costcenterid in('+@cancelleddocs+') '	
	else
		set @cancelleddocs=''
	
	IF @HoldQuery<>''
	BEGIN
		SET @SubQuery='select '+@SELECT2+'HoldQuantity QTY,case when release>HoldQuantity then HoldQuantity else release end Executed
from  (
	SELECT '+@SELECT1+'A.HoldQuantity*max(A.UOMConversion) HoldQuantity,
	isnull(sum(case when l.IsQtyIgnored=0'+@cancelleddocs+' then l.Quantity else l.ReserveQuantity end),0)*max(A.UOMConversion) release 
	FROM INV_DocDetails A WITH(NOLOCK)'+@Join
		if @DetailsIDFilter=1
			set @SubQuery=@SubQuery+' inner join #TblOrderFilter TID on TID.InvDetailsID=A.InvDocDetailsID'
		SET @HoldQuery=@SubQuery+'	
	left join INV_DocDetails l  WITH(NOLOCK) on A.InvDocDetailsID=l.LinkedInvDocDetailsID '+@CCWHERE +'
	WHERE A.StatusID<>376 AND A.CostCenterID IN ('+@HoldQuery+')'+@WHERE+'
group by A.ProductID,A.DocDate, A.InvDocDetailsID'+@GrpCostCenterID+',A.HoldQuantity) 	as t'
		IF @NormalQuery<>''
			SET @HoldQuery=' UNION ALL '+@HoldQuery		
	END
	
	IF @ReserveQuery<>''
	BEGIN
		SET @SubQuery='select '+@SELECT2+'HoldQuantity QTY,case when release>HoldQuantity then HoldQuantity else release end Executed
from  (
	SELECT '+@SELECT1+'A.ReserveQuantity*max(A.UOMConversion) HoldQuantity,
	isnull(sum(case when l.IsQtyIgnored=0'+@cancelleddocs+' then l.Quantity else l.ReserveQuantity end),0)*max(A.UOMConversion) release 
	FROM INV_DocDetails A WITH(NOLOCK)'+@Join
		if @DetailsIDFilter=1
			set @SubQuery=@SubQuery+' inner join #TblOrderFilter TID on TID.InvDetailsID=A.InvDocDetailsID'
		SET @ReserveQuery=@SubQuery+'
	left join INV_DocDetails l  WITH(NOLOCK) on A.InvDocDetailsID=l.LinkedInvDocDetailsID '+@CCWHERE +'
	WHERE A.StatusID<>376 AND A.CostCenterID IN ('+@ReserveQuery+')'+@WHERE+'
group by A.ProductID,A.DocDate,A.InvDocDetailsID'+@GrpCostCenterID+',A.ReserveQuantity)	as t'
	
		IF @NormalQuery<>'' OR @HoldQuery<>''
			SET @ReserveQuery=' UNION ALL '+@ReserveQuery		
	END
	if(@Query!='')
		set @Query=@Query+'
UNION ALL
'
	SET @Query=@Query+@NormalQuery+@HoldQuery+@ReserveQuery
	

--	print(@NormalQuery+@HoldQuery+@ReserveQuery)
  --  exec( @Query)
    
		SET @I=@I+1
	END
	
	if @Type='ProductDocDateQty'
	begin
		SET @Query='SELECT ProductID,convert(datetime,DocDate) DocDate,SUM(QTY)-SUM(Executed) PendingOrders
FROM ('+ @Query+') AS T GROUP BY ProductID,DocDate
having SUM(QTY)-SUM(Executed)>0'
	    exec( @Query)
	end
	else if @Type='DocumentProductDocDateQty'
	begin
		SET @Query='SELECT ProductID,convert(datetime,DocDate) DocDate,CostCenterID,SUM(QTY)-SUM(Executed) PendingOrders
FROM ('+ @Query+') AS T GROUP BY ProductID,DocDate,CostCenterID
having SUM(QTY)-SUM(Executed)>0'
	    exec( @Query)
	end
	else if @Type='ProductsList'
	begin
		SET @Query='SELECT ProductID
FROM ('+ @Query+') AS T GROUP BY ProductID HAVING SUM(QTY)>sum(Executed)'
	    exec( @Query)
	end
	else if @Type='ProductsListWithDocID'
	begin
		SET @Query='SELECT DocID,ProductID,sum(QTY)-sum(Executed) Qty
FROM ('+ @Query+') AS T GROUP BY DocID,ProductID HAVING SUM(QTY)>sum(Executed) order by DocID'
	    exec( @Query)
	end
	else if @Type='OrderDetail'
	begin
		SET @Query='SELECT T.InvDocDetailsID,T.QTY,T.QTY-T.Executed PendingOrders FROM ('+ @Query+') AS T 
where T.QTY>T.Executed'
		--print(@Query)
	    exec( @Query)
	end
	else if @Type='ProductWisePendingOrderQty'
	begin
		SET @Query='SELECT ProductID,sum(T.QTY-T.Executed) PendingOrders FROM ('+ @Query+') AS T 
where T.QTY>T.Executed
group by ProductID'
	    exec( @Query)
	end
END;
GO
