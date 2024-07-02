USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpMasterDetails]
	@NodeID [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  
	--Declaration Section  
	DECLARE @HasAccess BIT,@Table nvarchar(50),@SQL nvarchar(max),@CostCenterID INT
	SET @CostCenterID=50051
	  
	--User access check   
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)  

	IF @HasAccess=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END  

	SELECT *,
	CONVERT(DATETIME,DOJ) as cDOJ,CONVERT(DATETIME,DOB) as cDOB,
	CONVERT(DATETIME,DOConfirmation) as cDOConfirmation,CONVERT(DATETIME,NextAppraisalDate) as cNextAppraisalDate,
	CONVERT(DATETIME,PassportIssDate) as cPassportIssDate,CONVERT(DATETIME,PassportExpDate) as cPassportExpDate,
	CONVERT(DATETIME,VisaIssDate) as cVisaIssDate,CONVERT(DATETIME,VisaExpDate) as cVisaExpDate,
	CONVERT(DATETIME,IqamaIssDate) as cIqamaIssDate,CONVERT(DATETIME,IqamaExpDate) as cIqamaExpDate,
	CONVERT(DATETIME,ContractIssDate) as cContractIssDate,CONVERT(DATETIME,ContractExpDate) as cContractExpDate,CONVERT(DATETIME,ContractExtendDate) as cContractExtendDate,
	CONVERT(DATETIME,IDIssDate) as cIDIssDate,CONVERT(DATETIME,IDExpDate) as cIDExpDate,
	CONVERT(DATETIME,LicenseIssDate) as cLicenseIssDate,CONVERT(DATETIME,LicenseExpDate) as cLicenseExpDate,
	CONVERT(DATETIME,MedicalIssDate) as cMedicalIssDate,CONVERT(DATETIME,MedicalExpDate) as cMedicalExpDate,
	CONVERT(DATETIME,DOResign) as cDOResign,CONVERT(DATETIME,DORelieve) as cDORelieve,
	CONVERT(DATETIME,DOTentRelieve) as cDOTentRelieve,
	CONVERT(DATETIME,OpLeavesAsOn) as cOpLeavesAsOn,CONVERT(DATETIME,OpLOPAsOn) as cOpLOPAsOn
		
	FROM COM_CC50051 WITH(nolock) WHERE NodeID=@NodeID
	    

	--Getting Contacts    
	EXEC [spCom_GetFeatureWiseContacts] @CostCenterID,@NodeID,2,1,1 

	--Getting Notes  
	SELECT NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
	ModifiedBy, ModifiedDate, CostCenterID FROM  COM_Notes WITH(NOLOCK)   
	WHERE FeatureID=@CostCenterID and  FeaturePK=@NodeID  

	--Getting Files  
	EXEC [spCOM_GetAttachments] @CostCenterID,@NodeID,@UserID

	--Getting Contacts  
	EXEC [spCom_GetFeatureWiseContacts] @CostCenterID,@NodeID,1,1,1

	--Getting Custom CostCenter Extra fields  
	EXEC [spCOM_GetCCCCMapDetails] @CostCenterId,@NodeID,@LangID
		
	--Getting ADDRESS 
	EXEC spCom_GetAddress @CostCenterId,@NodeID,1,1

	SELECT R.* FROM COM_CCCCData R WITH(NOLOCK) WHERE R.CostCenterID=@CostCenterId AND R.NODEID=@NodeID  

	SELECT Code,Name from COM_CC50051 WITH(nolock) WHERE NodeID in 
	(SELECT ParentID from COM_CC50051 with(nolock) where NodeID=@NodeID)
		
	--CCmap display data 
	CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),COSTCENTERID INT,NODEID INT)
	CREATE TABLE #TBLTEMP1 (CostCenterId INT,CostCenterName nvarchar(max),NodeID INT,[Value] NVARCHAR(300), Code nvarchar(300))
	INSERT INTO #TBLTEMP
	SELECT CostCenterID,NODEID  FROM COM_CostCenterCostCenterMap with(nolock) WHERE ParentCostCenterID=@CostCenterId AND ParentNodeID=@NodeID
	DECLARE @COUNT INT,@I INT,@TABLENAME NVARCHAR(300), @CCID INT,@ccNODEID INT,@FEATURENAME NVARCHAR(300), @IsGroup bit
	SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP
	WHILE @I<=@COUNT
	BEGIN
		SELECT @ccNODEID=NODEID,@CCID=CostCenterId FROM #TBLTEMP WHERE ID=@I
		SELECT @FEATURENAME=NAME,@TABLENAME=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID =@CCID
		 
		SET @SQL='	IF EXISTS (SELECT NodeID FROM '+@TABLENAME +' 
					WHERE NODEID='+CONVERT(VARCHAR,@ccNODEID) +' and IsGroup=0)
						INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +'  with(nolock)
						WHERE NODEID='+CONVERT(VARCHAR,@ccNODEID) +'
					ELSE
						INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +'  with(nolock)
						WHERE ParentID='+CONVERT(VARCHAR,@ccNODEID) 
		-- print(@SQL)
		 EXEC sp_executesql @SQL
		SET @I=@I+1
	END

	SELECT * FROM #TBLTEMP1
	DROP TABLE #TBLTEMP1
	DROP TABLE #TBLTEMP
		
	--WorkFlow
	EXEC spCOM_CheckCostCentetWFApprove @CostCenterID,@NodeID,@UserID,@RoleID
		
	declare @rptid INT, @tempsql nvarchar(500)
	SELECT @rptid=CONVERT(INT,value) from ADM_GlobalPreferences with(nolock) where Name='Report Template Dimension'
	if(@rptid=@CostCenterID)
		SELECT * from ACC_ReportTemplate with(nolock) where drnodeid =@NodeID or crnodeid=@NodeID or templatenodeid =@NodeID
	else
		SELECT '' ACC_ReportTemplate where 1!=1
  
	-- HISTORY Details --12
	SELECT H.HistoryID,H.HistoryCCID CCID,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
	from COM_HistoryDetails H with(nolock) 
	where H.CostCenterID=@CostCenterID and H.NodeID=@NodeID and H.HistoryCCID>50000
	order by FromDate,H.HistoryID
	
	--Documents Details --13
	Select * From PAY_EmpDetail a WITH(NOLOCK) Where a.EmployeeID=@NodeID
	
	-- Appraisals Details --14
	SELECT SeqNo,*,convert(datetime,EffectFrom) ApraisalDate 
	FROM PAY_EmpPay WITH(nolock) WHERE EmployeeID=@NodeID
	ORDER BY EffectFrom Asc
	
	-- ACCOUNT LINKING Details --15
	SELECT a.*,b.AccountName as DebitAccountName,c.AccountName as CreditAccountName,d.Name as ComponentName
	FROM PAY_EmpAccountsLinking a WITH(NOLOCK) 
	LEFT JOIN ACC_Accounts b WITH(NOLOCK) on b.AccountID=a.DebitAccountID
	LEFT JOIN ACC_Accounts c WITH(NOLOCK) on c.AccountID=a.CreditAccountID
	LEFT JOIN COM_CC50052 d WITH(NOLOCK) on d.NodeID=a.ComponentID
	WHERE EmpSeqNo=@NodeID
	ORDER BY Type,SNo ASC
	
	
	  
  
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
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
