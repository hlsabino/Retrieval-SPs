USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetExecutedQtyQueryNew]
	@CallType [int],
	@CCList [nvarchar](500),
	@FromDate [datetime] = null,
	@ToDate [datetime] = null,
	@DontShowUnApproved [bit] = 1,
	@ConsiderRejected [bit] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1,
	@FinalQry [nvarchar](max) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON	
	DECLARE @HasAccess bit,@CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50),@HoldOnSave BIT,@HoldQty BIT,@ReserveQty BIT
	DECLARE @I INT,@J INT,@Cnt INT,@CNTDOCS INT,@Document INT
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1),Document INT,HoldOnSave BIT default(0),HoldQty BIT default(0),ReserveQty BIT default(0))
	DECLARE @TblMaps AS TABLE(ID INT IDENTITY(1,1),Document INT,ColumnName NVARCHAR(50),LinkColumn NVARCHAR(50),IsQtyExecuted BIT)

	INSERT INTO @Tbl(Document)
	--SELECT CostCenterID FROM ADM_DocumentTypes WHERE 40000+DocumentType=@CCList
	EXEC SPSplitString @CCList,','
	
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
	
	DECLARE @Query nvarchar(MAX),@SubQry NVARCHAR(MAX),@TagColumnAlias NVARCHAR(50),@HoldSaveQuery nvarchar(MAX)
		,@HoldQuery nvarchar(MAX),@NormalQuery nvarchar(MAX),@ReserveQuery nvarchar(MAX)
	
	SELECT @Query='',@SubQry='',@HoldSaveQuery='',@HoldQuery='',@NormalQuery='',@ReserveQuery=''
	
	--SELECT * FROM @Tbl
	
	SELECT @I=1,@Cnt=COUNT(*) FROM @Tbl
	
	
	WHILE(@I<=@Cnt)
	BEGIN
		SELECT @Document=Document,@HoldOnSave=HoldOnSave,@HoldQty=HoldQty,@ReserveQty=ReserveQty FROM @Tbl WHERE ID=@I

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
			SELECT DISTINCT CostCenterIDBase
				,(SELECT SysColumnName FROM ADM_CostCenterDef with(nolock) WHERE CostCenterColID=[CostCenterColIDBase])
				,(SELECT SysColumnName FROM ADM_CostCenterDef with(nolock) WHERE CostCenterColID=[CostCenterColIDLinked])			
			FROM COM_DocumentLinkDef with(nolock)
			WHERE CostCenterIDLinked=@Document AND IsQtyExecuted=1 and CostCenterIDBase>40000 and CostCenterIDBase<50000

			
			SELECT @J=MIN(ID), @CNTDOCS = MAX(ID) FROM @TblMaps	

			IF @CNTDOCS > 0
			BEGIN	
				WHILE(@J<=@CNTDOCS)
				BEGIN
 					SELECT @CostCenterID=Document,@ColumnName=ColumnName,@lINKColumnName=LinkColumn FROM @TblMaps WHERE ID=@J

					IF @lINKColumnName LIKE 'dcNum%'
						SET @Query=@Query+' WHEN INV.costcenterid='+CONVERT(NVARCHAR,@Document)+' THEN NUM.'+@lINKColumnName
					ELSE
						SET @Query=@Query+' WHEN INV.costcenterid='+CONVERT(NVARCHAR,@Document)+' THEN INV.'+@lINKColumnName
						
					IF len(@SubQry)>0
						SET @SubQry=@SubQry+' UNION ALL '
					IF @ColumnName LIKE 'dcNum%'
						SET @SubQry=@SubQry+'SELECT N.'+@ColumnName+' Qty FROM INV_DocDetails B with(nolock) INNER JOIN COM_DocNumData N with(nolock) ON N.InvDocdetailsID=B.InvDocdetailsID'
					ELSE
						SET @SubQry=@SubQry+'SELECT B.'+@ColumnName+' Qty FROM INV_DocDetails B with(nolock)'
					SET @SubQry=@SubQry+' WHERE INV.InvDocDetailsID=B.LinkedInvDocDetailsID AND INV.costcenterid='+CONVERT(NVARCHAR,@Document)+' AND B.costcenterid='+CONVERT(NVARCHAR,@CostCenterID)

					IF @FromDate is not null
						SET @SubQry=@SubQry+' AND B.DocDate>='+convert(nvarchar,convert(float,@FromDate))
					IF @ToDate is not null
						SET @SubQry=@SubQry+' AND B.DocDate<='+convert(nvarchar,convert(float,@ToDate))
					
					IF @DontShowUnApproved=1--To get posted docs
					begin						
						if @ConsiderRejected=1
							SET @SubQry=@SubQry+' AND (B.StatusID=369 or B.StatusID=372)'
						else
							SET @SubQry=@SubQry+' AND B.StatusID=369'
					end
					ELSE--To get all docs except cancelled
					BEGIN
						SET @SubQry=@SubQry+' AND B.StatusID<>376'
						if @ConsiderRejected=0
							SET @SubQry=@SubQry+' AND B.StatusID<>372'
					END
					--select @SubQry
					SET @J=@J+1					
				END
			END -- IF @CNTDOCS > 0
			ELSE
			BEGIN		
				IF len(@SubQry)>0
					SET @SubQry=@SubQry+' UNION ALL '

				SET @SubQry=@SubQry+'SELECT 0 Qty'
			END	
		END
		
		SET @I=@I+1
	END
	
	IF @NormalQuery<>''
	BEGIN
		IF len(@Query)>0
			SET @Query='(CASE '+@Query+' ELSE INV.Quantity END )'
		ELSE
			SET @Query='INV.Quantity'
		
		IF isnull(@SubQry,'')=''
			SET @SubQry='select 1 qty'
			
		SET @SubQry='case when INV.LinkStatusID=445 then '+@Query+' else (SELECT ISNULL(SUM(Qty),0) FROM ('+@SubQry+') AS T) end '
		SET @NormalQuery=@SubQry
		/* @SubQry='SELECT A.ProductID,A.QUANTITY,'+@SubQry+@TagColumn+' FROM INV_DocDetails A with(nolock) '+@CCWHERE
		SET @NormalQuery=@SubQry+' WHERE A.CostCenterID IN ('+@NormalQuery+')'
		SET @NormalQuery=@NormalQuery+' AND A.ProductID IN ('+@ProductID+')'
		IF @HoldSaveQuery!=''
		BEGIN
			SET @HoldSaveQuery=' AND (A.CostCenterID NOT IN ('+@HoldSaveQuery+') OR A.StatusID<>369)'
			SET @NormalQuery=@NormalQuery+@HoldSaveQuery
		END*/
	END
	
	declare @cancelleddocs nvarchar(max)
	select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs'    
	if(@cancelleddocs is not null and @cancelleddocs<>'')
		set @cancelleddocs=' or l.Costcenterid in('+@cancelleddocs+') '	
	else
		set @cancelleddocs=''
		
	IF @DontShowUnApproved=1--To get posted docs
	begin
		if @ConsiderRejected=1
			SET @lINKColumnName=' AND (INV.StatusID=369 or INV.StatusID=372)'
		else
			SET @lINKColumnName=' AND INV.StatusID=369'
	end
	ELSE--To get all docs except cancelled
	BEGIN
		if exists(select Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold' and value='true')
			set @lINKColumnName=' AND INV.StatusID in (371,441,369) '
		else
			set @lINKColumnName=' AND INV.StatusID=369 '
	END					

	IF @HoldQuery<>''
	BEGIN
		SET @HoldQuery='(select case when release>HoldQuantity then HoldQuantity else release end Executed
from  (
	SELECT INV.HoldQuantity HoldQuantity,
	isnull(sum(case when l.IsQtyIgnored=0'+@cancelleddocs+' then l.Quantity else l.ReserveQuantity end),0) release 
	FROM INV_DocDetails l  WITH(NOLOCK) 
	WHERE INV.InvDocDetailsID=l.LinkedInvDocDetailsID'+@lINKColumnName+') 	as t)'
	
		IF @NormalQuery<>''
			SET @HoldQuery=' UNION ALL '+@HoldQuery
	END
	
	IF @ReserveQuery<>''
	BEGIN
		SET @ReserveQuery='(select case when release>HoldQuantity then HoldQuantity else release end Executed
from  (
	SELECT INV.ReserveQuantity HoldQuantity,
	isnull(sum(case when l.IsQtyIgnored=0'+@cancelleddocs+' then l.Quantity else l.ReserveQuantity end),0) release 
	FROM INV_DocDetails l  WITH(NOLOCK) 
	WHERE INV.InvDocDetailsID=l.LinkedInvDocDetailsID'+@lINKColumnName+') as t)'
	
		IF @NormalQuery<>'' OR @HoldQuery<>''
			SET @ReserveQuery=' UNION ALL '+@ReserveQuery		
	END

	--SET @SubQry='case when INV.LinkStatusID=445 then INV.Quantity else (SELECT ISNULL(SUM(Qty),0) FROM ('+@SubQry+') AS T) end '
 	--SELECT @SubQry AS Qry

 	set @FinalQry=@NormalQuery+@HoldQuery+@ReserveQuery
 	if @CallType=0
 		SELECT @FinalQry AS Qry
 	
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
