USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetOrderManagement]
	@CCList [nvarchar](500),
	@ReportType [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@IsRefExists [bit],
	@LocationWHERE [nvarchar](max) = NULL,
	@SELECTQUERY [nvarchar](max),
	@FROMQUERY [nvarchar](max),
	@SELECTQUERYALIAS [nvarchar](max),
	@WHERE [nvarchar](max),
	@GTPQuery [nvarchar](max),
	@GTPWHERE [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON	
	DECLARE @HasAccess bit,@CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50)
	DECLARE @Query nvarchar(MAX),@SubQry NVARCHAR(MAX)
	DECLARE @I INT,@J INT,@Cnt INT,@CNTDOCS INT,@Document INT
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1),Document INT)
	DECLARE @TblMaps AS TABLE(ID INT IDENTITY(1,1),Document INT,ColumnName NVARCHAR(50),LinkColumn NVARCHAR(50))
	

	SET @Query = ''
	SET @SubQry=''
		
	INSERT INTO @Tbl(Document)	
	EXEC SPSplitString @CCList,','

	IF @ReportType=2 OR @ReportType=3
	BEGIN
		DECLARE @Status INT
		
		IF @ReportType=2
			SET @Status=371
		ELSE IF @ReportType=3
			SET @Status=369
			
		IF @LocationWHERE IS NOT NULL OR @WHERE like '%DCC.DCCCNID%'
			SET @SubQry=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'

		IF @LocationWHERE IS NOT NULL
			SET @SubQry=@SubQry +' AND DCC.DCCCNID2 IN ('+@LocationWHERE+')'
			
		SET @Query='SELECT CONVERT(DATETIME, D.DocDate) AS DocDate, D.VoucherNo, PRO.ProductName, D.Quantity, D.Rate, D.StockValue AS VALUE, D.Gross AS NETVALUE, ACC.AccountName
		FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN INV_Product PRO WITH(NOLOCK) ON D.ProductID = PRO.ProductID
			INNER JOIN ACC_Accounts ACC WITH(NOLOCK) ON D.DebitAccount = ACC.AccountID
		'+@SubQry+@GTPQuery+'
		WHERE D.CostCenterID IN ('+@CCList+') AND D.StatusID<>376 AND D.DocDate >='+convert(nvarchar,convert(FLOAT,@FromDate))+' AND D.DocDate<='+CONVERT(nvarchar,CONVERT(FLOAT,@ToDate))
		+' AND D.StatusID='+CONVERT(nvarchar,@Status)+@GTPWHERE+@WHERE
		--print(@Query)
		EXEC(@Query)
	END
	ELSE
	BEGIN

		DECLARE @TblRefDocs AS TABLE(CostCenterID INT)

		SELECT @I=1,@Cnt=COUNT(*) FROM @Tbl

		WHILE(@I<=@Cnt)
		BEGIN
			SELECT @Document=Document FROM @Tbl WHERE ID=@I
		
			DELETE FROM @TblMaps
			INSERT INTO @TblMaps(Document,ColumnName,LinkColumn)
			SELECT [CostCenterIDBase],
				(SELECT SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterColID=[CostCenterColIDBase]),
				(SELECT SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterColID=[CostCenterColIDLinked])
			FROM [COM_DocumentLinkDef] WITH(NOLOCK) 
			WHERE CostCenterIDLinked=@Document AND IsQtyExecuted=1
			
			SELECT @J=MIN(ID), @CNTDOCS = MAX(ID) FROM @TblMaps	
			IF @CNTDOCS > 0
			BEGIN	
				WHILE(@J<=@CNTDOCS)
				BEGIN
 					SELECT @CostCenterID=Document, @ColumnName=ColumnName, @lINKColumnName=LinkColumn FROM @TblMaps WHERE ID=@J
					if(@lINKColumnName is not null)
					BEGIN
						IF len(@SubQry)>0
							SET @SubQry=@SubQry+' UNION ALL '
				
						--IF @lINKColumnName LIKE 'dcNum%'
						--	SET @SubQry=@SubQry+'SELECT N.'+@lINKColumnName+' Qty FROM INV_DocDetails B WITH(NOLOCK) INNER JOIN COM_DocNumData N WITH(NOLOCK) ON N.InvDocdetailsID=B.InvDocdetailsID WHERE D.InvDocDetailsID =B.LinkedInvDocDetailsID AND D.costcenterid='+CONVERT(NVARCHAR,@Document)+' AND B.StatusID<>376 AND B.costcenterid='+CONVERT(NVARCHAR,@CostCenterID)
						--ELSE
						--	SET @SubQry=@SubQry+'SELECT B.'+@lINKColumnName+' Qty FROM INV_DocDetails B WITH(NOLOCK) WHERE D.InvDocDetailsID =B.LinkedInvDocDetailsID AND D.costcenterid='+CONVERT(NVARCHAR,@Document)+' AND B.StatusID<>376 AND B.costcenterid='+CONVERT(NVARCHAR,@CostCenterID)
						
						SET @SubQry=@SubQry+'SELECT B.LinkedFieldValue Qty FROM INV_DocDetails B WITH(NOLOCK) WHERE D.InvDocDetailsID =B.LinkedInvDocDetailsID AND D.costcenterid='+CONVERT(NVARCHAR,@Document)+' AND B.StatusID<>376 AND B.costcenterid='+CONVERT(NVARCHAR,@CostCenterID)
						
						--Holding Referenced Documents CostcenterID
						INSERT INTO @TblRefDocs(CostCenterID) VALUES(@CostCenterID)
					END
					SET @J=@J+1					
				END
			
			END -- IF @CNTDOCS > 0
			ELSE
			BEGIN		
				IF len(@SubQry)>0
					SET @SubQry=@SubQry+' UNION ALL '

				SET @SubQry=@SubQry+'SELECT 0 Qty'
			END	

			SET @I=@I+1
		END


		SET @SubQry='case when D.LinkStatusID=445 then D.Quantity else (SELECT ISNULL(SUM(Qty),0) FROM ('+@SubQry+') AS T) end Executed'

		SET @Query='SELECT D.InvDocDetailsID,D.ProductID,Convert(DATETIME,D.DocDate) DocDate, D.VoucherNo,PRO.PRODUCTNAME,   
					D.Quantity,'+@SubQry+', D.RATE ,D.STOCKVALUE VALUE  ,D.GROSS NETVALUE ,ACC.ACCOUNTNAME'+@SELECTQUERY+'
					FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@FROMQUERY
		SET @Query = @Query +' INNER JOIN INV_PRODUCT PRO ON D.PRODUCTID = PRO.PRODUCTID'
		SET @Query = @Query +' INNER JOIN ACC_ACCOUNTS ACC ON D.DEBITACCOUNT  = ACC.ACCOUNTID'+@GTPQuery

		SET @Query=@Query+' WHERE D.CostCenterID IN ('+@CCList+') AND D.StatusID<>376'+@GTPWHERE
		
		IF @LocationWHERE IS NOT NULL
			SET @Query=@Query +' AND DCC.DCCCNID2 IN ('+@LocationWHERE+')'
			
		IF @WHERE<>''
			SET @Query=@Query+@WHERE

		IF @FromDate != -1
			SET @Query=@Query+' AND  D.DocDate  >= '' ' + CONVERT(NVARCHAR(10), CONVERT(FLOAT,@FromDate)) +''''
	 
		IF @ToDate != -1
			SET @Query=@Query+' AND D.DocDate  <= '' ' +  CONVERT(NVARCHAR(10), CONVERT(FLOAT,@ToDate))+''''		
		

		DECLARE @RefQuery NVARCHAR(MAX)

		IF @ReportType = 0--pending quotations
		BEGIN

			SET @RefQuery='SELECT InvDocDetailsID FROM ('+ @Query+') AS T WHERE Quantity-Executed>0'

			SET @Query='SELECT DocDate, VoucherNo,D.InvDocDetailsID,D.ProductID ProductName_ID, ProductName,Quantity Act_Qty,Executed Exec_Qty,Quantity-Executed AS Bal_Qty,Rate,AccountName'+@SELECTQUERYALIAS+' FROM ('
					+ @Query+') AS D WHERE Quantity-Executed>0'
		END
		ELSE IF @ReportType = 1--executed quotations
		BEGIN
			SET @RefQuery='SELECT InvDocDetailsID FROM ('+ @Query+') AS D WHERE Executed>0'

			SET @Query='SELECT DocDate, VoucherNo,D.InvDocDetailsID,D.ProductID ProductName_ID, ProductName,Executed AS Quantity,Rate,AccountName'+@SELECTQUERYALIAS+' FROM ('
					+ @Query+') AS D WHERE Executed>0'
		END
		ELSE--list of quotations
		BEGIN
			SET @RefQuery='SELECT InvDocDetailsID FROM ('+ @Query+') AS T'

			SET @Query='SELECT DocDate, VoucherNo,D.InvDocDetailsID,D.ProductID ProductName_ID, ProductName,Quantity AS Quantity,Rate,Executed Exec_Qty,AccountName'+@SELECTQUERYALIAS+' FROM ('
					+ @Query+') AS D'
		END

		set @Query=@Query+' order by DocDate,VoucherNo'
		PRINT @Query
		EXEC (@Query)
		
		IF @IsRefExists=1
		BEGIN
			DECLARE @TblRef AS TABLE(InvDocDetailsID INT)

			INSERT INTO @TblRef
			EXEC (@RefQuery)
			--VoucherNo , A.AccountName
			SELECT LinkedInvDocDetailsID,Convert(DATETIME,DocDate) RefDocDate,VoucherNo RefDocNo,Quantity RefQty,Rate RefRate,A.AccountName RefAccount1
			FROM INV_DocDetails WITH(NOLOCK) INNER JOIN
			ACC_Accounts A WITH(NOLOCK) ON DebitAccount=A.AccountID
			WHERE LinkedInvDocDetailsID IN (SELECT InvDocDetailsID FROM @TblRef) AND CostCenterID IN (SELECT CostCenterID FROM @TblRefDocs)
		END
		
		--select @Query,@RefQuery
	END
 
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
