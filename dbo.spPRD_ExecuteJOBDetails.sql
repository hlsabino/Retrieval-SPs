USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_ExecuteJOBDetails]
	@CostCenterID [int],
	@DocID [bigint],
	@DetIDs [nvarchar](max),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	
	DECLARE @JobDimension NVARCHAR(15),@BomDimension NVARCHAR(15),@StageDimension NVARCHAR(15),@SQL NVARCHAR(MAX)
	SELECT @JobDimension='CC.dcCCNID'+CONVERT(NVARCHAR,(CONVERT(INT,Value)-50000)) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='JobDimension'
	SELECT @BomDimension='CC.dcCCNID'+CONVERT(NVARCHAR,(CONVERT(INT,Value)-50000)) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='BomDimension'
	SELECT @StageDimension='CC.dcCCNID'+CONVERT(NVARCHAR,(CONVERT(INT,Value)-50000)) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='StageDimension'
	
    DECLARE @I INT,@COUNT INT,@ACTUALQTY FLOAT,@EXECUTEDQTY FLOAT,@InvDocDetailsID BIGINT,@DocumentType INT
	,@ProductID BIGINT,@BOMID BIGINT,@BOMNodeID BIGINT,@JOBNodeID BIGINT,@StageID BIGINT,@StageNodeID BIGINT

    DECLARE @DOCLIST TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,InvDocDetailsID BIGINT,ProductID BIGINT,BOMNodeID BIGINT,JOBNodeID BIGINT,StageNodeID BIGINT)
	

	IF @DetIDs<>''
	BEGIN
		
		CREATE TABLE #DTAB (ID INT IDENTITY(1,1) PRIMARY KEY,InvDocDetailsID BIGINT)

		INSERT INTO #DTAB (InvDocDetailsID)
		EXEC SPSplitString @DetIDs,','  

		IF EXISTS (SELECT InvDocDetailsID FROM #DTAB WITH(NOLOCK) WHERE InvDocDetailsID>1)
		BEGIN
			SET @SQL='SELECT I.InvDocDetailsID,I.ProductID,'+@BomDimension+','+@JobDimension+','+@StageDimension+' 
			FROM INV_DocDetails I WITH(NOLOCK)
			JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
			WHERE I.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND I.DocID='+CONVERT(NVARCHAR,@DocID)+' 
			AND '+@BomDimension+'<>1 AND '+@JobDimension+'<>1
			AND I.InvDocDetailsID IN (SELECT InvDocDetailsID FROM #DTAB WITH(NOLOCK) WHERE InvDocDetailsID>1)'
			
			INSERT INTO @DOCLIST
			EXEC (@SQL)
		END

		SELECT @COUNT=COUNT(*) FROM #DTAB WITH(NOLOCK)

		IF @COUNT=1 
		BEGIN
			SET @SQL='SELECT 0,I.ProductID,'+@BomDimension+','+@JobDimension+','+@StageDimension+' 
			FROM INV_DocDetails I WITH(NOLOCK)
			JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
			WHERE I.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND I.DocID='+CONVERT(NVARCHAR,@DocID)+' 
			AND '+@BomDimension+'<>1 AND '+@JobDimension+'<>1'

			INSERT INTO @DOCLIST
			EXEC (@SQL)
		END

		DROP TABLE #DTAB

	END
	ELSE
	BEGIN
		SET @SQL='SELECT I.InvDocDetailsID,I.ProductID,'+@BomDimension+','+@JobDimension+','+@StageDimension+' 
		FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		WHERE I.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND I.DocID='+CONVERT(NVARCHAR,@DocID)+' 
		AND '+@BomDimension+'<>1 AND '+@JobDimension+'<>1'
			
		INSERT INTO @DOCLIST
		EXEC (@SQL)
	END

	SELECT @DocumentType=DocumentType FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
    SELECT @I=1,@COUNT=COUNT(*) FROM @DOCLIST
    WHILE(@I<=@COUNT)
    BEGIN
        SELECT @InvDocDetailsID=InvDocDetailsID,@ProductID=ProductID,@BOMNodeID=BOMNodeID,@JOBNodeID=JOBNodeID,@StageNodeID=StageNodeID 
		FROM @DOCLIST WHERE ID=@I

        SELECT @SQL='SELECT @EXECUTEDQTY=SUM(I.UOMConvertedQty) FROM INV_DocDetails I WITH(NOLOCK)
        JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
        WHERE I.InvDocDetailsID<>'+CONVERT(NVARCHAR,@InvDocDetailsID)+' AND I.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND I.DocumentType='+CONVERT(NVARCHAR,@DocumentType)+'
		AND '+@BomDimension+'='+CONVERT(NVARCHAR,@BOMNodeID)+' AND '+@JobDimension+'='+CONVERT(NVARCHAR,@JOBNodeID)+' AND '+@StageDimension+'='+CONVERT(NVARCHAR,@StageNodeID)

		EXEC sp_executesql  @SQL,N'@EXECUTEDQTY FLOAT OUTPUT',@EXECUTEDQTY OUTPUT 

        SELECT @BOMID=BOMID FROM PRD_BillOfMaterial WITH(NOLOCK) WHERE CCNodeID=@BOMNodeID
		SELECT @StageID=StageID FROM PRD_BOMStages WITH(NOLOCK) WHERE StageNodeID=@StageNodeID AND BOMID=@BOMID

		SELECT * FROM PRD_JobOuputProducts WITH(NOLOCK)

        SELECT @ACTUALQTY=JP.Qty*ISNULL(U.Conversion,1) FROM PRD_JobOuputProducts JP WITH(NOLOCK)
		LEFT JOIN COM_UOM U WITH(NOLOCK) ON U.UOMID=JP.UOMID
        WHERE JP.ProductID=@ProductID AND JP.BOMID=@BOMID AND JP.StageID=@StageID AND JP.NodeID=@JOBNodeID

        IF(@ACTUALQTY<=@EXECUTEDQTY)
        BEGIN
            UPDATE PRD_JobOuputProducts SET StatusID=6
            WHERE ProductID=@ProductID AND BOMID=@BOMID AND StageID=@StageID AND NodeID=@JOBNodeID
        END
		ELSE 
		BEGIN
            UPDATE PRD_JobOuputProducts SET StatusID=5
            WHERE ProductID=@ProductID AND BOMID=@BOMID AND StageID=@StageID AND NodeID=@JOBNodeID
        END

        IF NOT EXISTS(SELECT NodeID FROM PRD_JobOuputProducts WITH(NOLOCK) WHERE StatusID<>6 AND NodeID=@JOBNodeID )
        BEGIN
			SELECT @SQL='UPDATE '+TableName+' SET StatusID=(SELECT StatusID FROM COM_Status WITH(NOLOCK) WHERE Status=''In Active'' AND CostCenterID='+CONVERT(NVARCHAR,FeatureID)+')
			WHERE NodeID='+CONVERT(NVARCHAR,@JOBNodeID)+' AND StatusID<>461'
			FROM ADM_Features WITH(NOLOCK)
			WHERE FeatureID=(50000+CONVERT(INT,REPLACE(@JobDimension,'CC.dcCCNID','')))

			EXEC (@SQL)
        END
		ELSE
		BEGIN
			SELECT @SQL='UPDATE '+TableName+' SET StatusID=(SELECT StatusID FROM COM_Status WITH(NOLOCK) WHERE Status=''Active'' AND CostCenterID='+CONVERT(NVARCHAR,FeatureID)+')
			WHERE NodeID='+CONVERT(NVARCHAR,@JOBNodeID)+' AND StatusID<>461'
			FROM ADM_Features WITH(NOLOCK)
			WHERE FeatureID=(50000+CONVERT(INT,REPLACE(@JobDimension,'CC.dcCCNID','')))

			EXEC (@SQL)
        END

        SET @I=@I+1
    END
END

GO
