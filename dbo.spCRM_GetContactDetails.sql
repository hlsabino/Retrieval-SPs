USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetContactDetails]
	@DetailContactID [bigint] = 0,
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit

		--SP Required Parameters Check
		IF (@DetailContactID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,65,2)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		--Getting Resources
		SELECT ContactID, ContactTypeID,A.FeatureID,A.FeaturePK, FirstName, MiddleName, LastName, SalutationID, JobTitle, Company, a.StatusID, Phone1, Phone2, Email1, Fax, Department, 
             RoleLookUpID, Address1, Address2, Address3, City, [State], Zip, Country, Gender,CONVERT(DATETIME, Birthday) Birthday,
             CONVERT(DATETIME,Anniversary) Anniversary, PreferredID, PreferredName, IsEmailOn, 
             IsBulkEmailOn, IsMailOn, IsPhoneOn, IsFaxOn,
			 CLookup.Name ContactType,
			 RLookup.Name RoleLookup,
			 SLookup.Name Salutation, CTLookup.Name Country, A.[GUID]
			 FROM COM_Contacts A WITH(NOLOCK)   
			 LEFT JOIN COM_Lookup CLookup WITH(NOLOCK) ON A.ContactTypeID=CLookup.NodeID  
			 LEFT JOIN COM_Lookup RLookup WITH(NOLOCK) ON A.RoleLookupID=RLookup.NodeID  
			 LEFT JOIN COM_Lookup SLookup WITH(NOLOCK) ON A.SalutationID=SLookup.NodeID   
			 LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON A.Country=CTLookup.NodeID                                                                                                                                                                                                                                                                                                             
			 LEFT JOIN COM_Status S WITH(NOLOCK) ON A.StatusID=S.StatusID
		WHERE ContactID=@DetailContactID

		 
		--Getting data from Resource extended table
		SELECT * FROM  COM_ContactsExtended WITH(NOLOCK) 
		WHERE ContactID=@DetailContactID

		select * from COM_CCCCData WITH(NOLOCK) where costcenterid=65 and nodeid=@DetailContactID
		
		EXEC [spCOM_GetCCCCMapDetails] 65,@DetailContactID,@LangID
		
			--Getting Notes
		SELECT NoteID, Note, FeatureID, FeaturePK, CompanyGUID, [GUID], CreatedBy, convert(datetime,CreatedDate) CreatedDate, 
		ModifiedBy, ModifiedDate, CostCenterID
		FROM COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=65 and  FeaturePK=@DetailContactID
	 
		--Getting Files
		SELECT * FROM  COM_Files WITH(NOLOCK) 
		WHERE FeatureID=65 and  FeaturePK=@DetailContactID
		
		IF(EXISTS(SELECT * FROM CRM_Activities WITH(NOLOCK) WHERE CostCenterID=65 AND NodeID=@DetailContactID))
			EXEC spCRM_GetFeatureByActvities @DetailContactID,65,'',@UserID,@LangID  
		ELSE
			SELECT 1 WHERE 1<>1

		DECLARE @TBLTEMP TABLE(ID INT IDENTITY(1,1),COSTCENTERID BIGINT,NODEID BIGINT)
		CREATE TABLE #TBLTEMP1 (CostCenterId bigint,CostCenterName nvarchar(max),NodeID BIGINT,[Value] NVARCHAR(300), Code nvarchar(300))
		
		INSERT INTO @TBLTEMP
		SELECT CostCenterID,NODEID  FROM COM_CostCenterCostCenterMap WITH(NOLOCK)
		WHERE ParentCostCenterID=65 AND ParentNodeID=@DetailContactID
		
		DECLARE @COUNT INT,@I INT,@TABLENAME NVARCHAR(300),@SQL NVARCHAR(MAX),@CCID BIGINT,@NODEID BIGINT,@FEATURENAME NVARCHAR(300), @IsGroup bit
		SELECT @I=1,@COUNT=COUNT(*) FROM @TBLTEMP
		WHILE @I<=@COUNT
		BEGIN
			SELECT @NODEID=NODEID,@CCID=CostCenterId FROM @TBLTEMP WHERE ID=@I
			SELECT @FEATURENAME=NAME,@TABLENAME=TABLENAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID =@CCID

			SET @SQL='if exists (select NodeID FROM '+@TABLENAME +' 
			WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +' and IsGroup=0)

			INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' 
			WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +'
			else
			INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' 
			WHERE ParentID='+CONVERT(VARCHAR,@NODEID) 
			EXEC (@SQL)
			SET @I=@I+1
		END
		
		SELECT * FROM #TBLTEMP1
		DROP TABLE #TBLTEMP1

COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
