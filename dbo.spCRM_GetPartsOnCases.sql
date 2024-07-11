USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetPartsOnCases]
	@DOCUMENTID [bigint] = 0,
	@COSTCENTERID [bigint] = 0,
	@CASEID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON
		
		 
	IF @DOCUMENTID=0
	BEGIN	
		CREATE TABLE #TBL(ID INT IDENTITY(1,1),DOCID BIGINT,DOCNAME NVARCHAR(MAX))
		DECLARE @DATA NVARCHAR(MAX),@DOCID BIGINT,@DOCNAME NVARCHAR(300)

		SET @DATA=(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='DocumentTypes' and CostCenterID=@COSTCENTERID) 
 
		INSERT INTO #TBL(DOCID)
		EXEC SPSPLITSTRING @DATA,';'

		DECLARE @I INT,@COUNT INT
		SELECT @COUNT=COUNT(*) FROM #TBL
		SET @I=1
		WHILE @I<=@COUNT
		BEGIN
			SELECT @DOCID=DOCID FROM #TBL WHERE ID=@I 
			SELECT @DOCNAME=DocumentName FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@DOCID 
			UPDATE #TBL SET DOCNAME=@DOCNAME
			WHERE DOCID=@DOCID
			SET @I=@I+1
		END

		SELECT * FROM #TBL
		DROP TABLE #TBL 
	END
	ELSE
	BEGIN  
	DECLARE @INDEXID BIGINT, @CCID BIGINT,@SQL NVARCHAR(MAX),@TABLENAME NVARCHAR(300),@WHERE NVARCHAR(300)
	 IF @COSTCENTERID=73
		SELECT @CCID=Value FROM  COM_CostCenterPreferences WHERE FeatureID=@COSTCENTERID AND Name='CasesLinkDimension'
		ELSE IF @COSTCENTERID=89  
			SELECT @CCID=Value FROM  COM_CostCenterPreferences WHERE FeatureID=89 AND Name='OppLinkDimension'
 	ELSE IF @COSTCENTERID=86  
			SELECT @CCID=Value FROM  COM_CostCenterPreferences WHERE FeatureID=86 AND Name='LeadLinkDimension'

		 
	SET @INDEXID=@CCID-50000
	 SELECT @TABLENAME=TABLENAME FROM ADM_Features WHERE FEATUREID=@CCID
	 
	 
	  
  
	 
	 IF @COSTCENTERID=73
		SET @WHERE='SELECT CCCASEID FROM CRM_CASES WHERE CASEID='''+Convert(nvarchar,@CASEID)+''' '
	 ELSE IF @COSTCENTERID=89 
		SET @WHERE='SELECT CCOpportunityID FROM CRM_Opportunities WHERE OpportunityID='''+Convert(nvarchar,@CASEID)+''' '
	 ELSE IF  @COSTCENTERID=86	
		SET @WHERE='SELECT CCLEADID FROM CRM_LEADS WHERE LEADID='''+Convert(nvarchar,@CASEID)+''' '
		
		DECLARE @TEMPWHERE NVARCHAR(300)
		SET @TEMPWHERE=''
		IF @DOCUMENTID<>-100
		BEGIN
			SET @TEMPWHERE='D.CostCenterID='+CONVERT(VARCHAR,@DOCUMENTID)+' AND '
		END
		
		 SET @SQL='
		 SELECT    STATUS.Status, I.DocID,i.Quantity,  I.CostCenterID,P.ProductName,P.ProductCode, I.VoucherNo, CONVERT(DATETIME, I.DocDate) AS DocDate, D.DocumentName, I.DocPrefix, I.DocNumber
	     FROM         INV_DocDetails AS I INNER JOIN
							  ADM_DocumentTypes AS D ON I.DocumentTypeID = D.DocumentTypeID
							  LEFT JOIN INV_Product P ON P.ProductID=I.ProductID 
							  LEFT JOIN COM_DocCCData CC ON CC.InvDocDetailsID=I.InvDocDetailsID
							  LEFT JOIN COM_STATUS STATUS ON STATUS.STATUSID=I.STATUSID 
							  LEFT JOIN '+@TABLENAME+' C ON C.NODEID=CC.dcCCNID'+CONVERT(VARCHAR,@INDEXID)+'
		WHERE    '+@TEMPWHERE+'  C.NODEID IN 
		('+@WHERE+') '
		
		 IF @COSTCENTERID=73
		 SET @SQL=@SQL+'UNION
		 SELECT    STATUS.Status, I.DocID,i.Quantity,  I.CostCenterID,P.ProductName,P.ProductCode, I.VoucherNo, CONVERT(DATETIME, I.DocDate) AS DocDate, D.DocumentName, I.DocPrefix, I.DocNumber
	     FROM         INV_DocDetails AS I INNER JOIN
							  ADM_DocumentTypes AS D ON I.DocumentTypeID = D.DocumentTypeID
							  LEFT JOIN INV_Product P ON P.ProductID=I.ProductID 
							  LEFT JOIN COM_DocCCData CC ON CC.InvDocDetailsID=I.InvDocDetailsID
							  LEFT JOIN COM_STATUS STATUS ON STATUS.STATUSID=I.STATUSID 
						Where I.DocID=(SElect RefNodeID from CRM_CASES WHERE CASEID='+Convert(nvarchar,@CASEID)+' and RefNodeID is not null and RefNodeID>0 )
		
		'			
		
		--CHECK WHETHER OPPORTUNITY IS CONVERTED FROM LEAD,IF YES THEN GET DOCUMENTS BASED ON LEADID
		IF @COSTCENTERID=89 
		BEGIN
			IF(EXISTS(SELECT * FROM CRM_Opportunities WHERE OpportunityID=@CASEID AND ConvertFromLeadID>0
			AND ConvertFromLeadID IN (SELECT LEADID FROM CRM_LEADS)))
			BEGIN
				SET @WHERE=' SELECT CCLEADID FROM CRM_LEADS WHERE LEADID IN(
				SELECT ConvertFromLeadID FROM CRM_Opportunities WHERE OpportunityID='''+Convert(nvarchar,@CASEID)+''') '
				
			    	SELECT @CCID=Value FROM  COM_CostCenterPreferences WHERE FeatureID=86 AND Name='LeadLinkDimension'
					SET @INDEXID=@CCID-50000
					SELECT @TABLENAME=TABLENAME FROM ADM_Features WHERE FEATUREID=@CCID
	 
	 
	 
				SET @SQL=@SQL+ ' UNION 
		 SELECT    STATUS.Status, I.DocID,i.Quantity,  I.CostCenterID,P.ProductName,P.ProductCode, I.VoucherNo, CONVERT(DATETIME, I.DocDate) AS DocDate, D.DocumentName, I.DocPrefix, I.DocNumber
	     FROM         INV_DocDetails AS I INNER JOIN
							  ADM_DocumentTypes AS D ON I.DocumentTypeID = D.DocumentTypeID
							  LEFT JOIN INV_Product P ON P.ProductID=I.ProductID 
							  LEFT JOIN COM_DocCCData CC ON CC.InvDocDetailsID=I.InvDocDetailsID
							  LEFT JOIN COM_STATUS STATUS ON STATUS.STATUSID=I.STATUSID 
							  LEFT JOIN '+@TABLENAME+' C ON C.NODEID=CC.dcCCNID'+CONVERT(VARCHAR,@INDEXID)+'
		WHERE    '+@TEMPWHERE+'  C.NODEID IN 
		('+@WHERE+') '		
			END
		END	
		
	   PRINT @SQL
		EXEC (@SQL)
		  
		 
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
