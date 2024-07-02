USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetEmployeeQuick]
	@NodeID [int],
	@EmpCode [nvarchar](200),
	@EmpName [nvarchar](500),
	@IsGroup [bit],
	@StatusID [int],
	@CodePrefix [nvarchar](200),
	@CodeNumber [int],
	@StaticFieldsQuery [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@HistoryXML [nvarchar](max) = null,
	@CCMapXML [nvarchar](max) = null,
	@WID [int] = 0,
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1,
	@CompIndex [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @Dt float,@TempGuid nvarchar(50),@HasAccess bit,@CostCenterID int
  DECLARE @IsDuplicateNameAllowed bit,@IsCodeAutoGen bit,@IsDuplicateCodeAllowed BIT,@IsIgnoreSpace bit  
    declare @isparentcode bit,@HistoryStatus NVARCHAR(300), @tStatus INT
  
  SET @CostCenterID=50051
  
  set @EmpName=RTRIM(LTRIM(@EmpName))
  
  if(@NodeID=0)
	set @HistoryStatus='Add'
  else
	set @HistoryStatus='Update'
		
  --User acces check FOR ACCOUNTS  
  IF @NodeID=0  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,1)  
  END  
  ELSE  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,3)  
  END  
  
  IF @HasAccess=0  
  BEGIN  
   RAISERROR('-105',16,1)  
  END  
 
	--GETTING PREFERENCE  
	SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=@CostCenterID and  Name='DuplicateCodeAllowed'  
	SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=@CostCenterID and  Name='DuplicateNameAllowed'
	SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=@CostCenterID and  Name='CodeAutoGen'  
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=@CostCenterID and  Name='IgnoreSpaces'  
	select @isparentcode=IsParentCodeInherited  from COM_CostCenterCodeDef where CostCenterID=@CostCenterID

  
   --DUPLICATE CODE CHECK  
	if(@isparentcode=0)
	BEGIN 
		IF @IsDuplicateCodeAllowed=0 
		BEGIN
			IF @NodeID=0  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE Code=@EmpCode)  
					RAISERROR('-116',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE Code=@EmpCode AND NodeID <> @NodeID)  
					RAISERROR('-116',16,1)  
			END
		END		
	END
	ELSE
	BEGIN
  		IF @IsDuplicateCodeAllowed=0 
		BEGIN
			IF @NodeID=0  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE Code=@EmpCode)--  or (CodePrefix=@CodePrefix and CodeNumber=@CodeNumber)
					RAISERROR('-116',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE NodeID <> @NodeID and (Code=@EmpCode) )-- or (CodePrefix=@CodePrefix and CodeNumber=@CodeNumber)
					RAISERROR('-116',16,1)  
			END  
		END
	END
  
	--DUPLICATE CHECK  
	IF @IsDuplicateNameAllowed=0 
	BEGIN  
		IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
		BEGIN  
			IF @NodeID=0  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE replace(Name,' ','')=replace(@EmpName,' ',''))  
					RAISERROR('-108',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE replace(Name,' ','')=replace(@EmpName,' ','') AND NodeID <> @NodeID)  
					RAISERROR('-108',16,1)       
			END  
		END  
	    ELSE  
	    BEGIN  
			IF @NodeID=0  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE Name=@EmpName)  
					RAISERROR('-108',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(nolock) WHERE Name=@EmpName AND NodeID <> @NodeID)  
					RAISERROR('-108',16,1)  
			END  
	   END
	END  
  
  
  SET @Dt=convert(float,getdate())--Setting Current Date  
  
	
   SELECT @TempGuid=[GUID] from [COM_CC50051]  WITH(NOLOCK) WHERE NodeID=@NodeID  
  
   IF(@TempGuid!=@GUID)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
   BEGIN    
       RAISERROR('-101',16,1)   
   END
   
	DECLARE @SQL NVARCHAR(MAX)
   	--Update Main Table
	IF(@StaticFieldsQuery IS NOT NULL AND @StaticFieldsQuery <> '')
	BEGIN
		set @SQL='update COM_CC50051
		SET '+@StaticFieldsQuery+'[GUID]= NEWID(), [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE NodeID='+convert(NVARCHAR,@NodeID)
		print (@SQL)
		EXEC sp_executesql @SQL
	END
	
	
	
	--Update Extended
	IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')
	BEGIN
		set @SQL='update COM_CC50051
		SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE NodeID='+convert(NVARCHAR,@NodeID)
	
		print (@SQL)
			EXEC sp_executesql @SQL
	END

	--Update CostCenter Extra Fields
	set @SQL='update COM_CCCCDATA
	SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@NodeID) + ' AND COSTCENTERID ='+convert(nvarchar,@CostCenterID)
	print (@SQL)
	EXEC sp_executesql @SQL
 
	set @SQL='update COM_CC50051 SET NAME=RTRIM(LTRIM(NAME)) WHERE NodeID='+convert(NVARCHAR,@NodeID)
	EXEC sp_executesql @SQL

	declare @LoginUserID NVARCHAR(250)
	SELECT @LoginUserID=LoginUserID FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID
	IF(@LoginUserID IS NULL OR  @LoginUserID='')
	BEGIN
		UPDATE COM_CC50051 SET LoginUserID=Code WHERE NodeID=@NodeID
	END
	SELECT @LoginUserID=LoginUserID FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID
	
	----Check and Updating Default Vacation Days
	--Declare @DefVacDays FLOAT,@DefVacDaysMR NVARCHAR(10)
	--SELECT @DefVacDays=VacDaysPerMonth,@DefVacDaysMR=VacationPeriod FROM COM_CC50051 WHERE NodeID=@NodeID  
	--IF(@DefVacDays=0)
	--BEGIN
	--	SELECT @DefVacDays=CONVERT(FLOAT,Value) FROM ADM_GlobalPreferences WHERE Name='DefVacationDays'
	--	SELECT @DefVacDaysMR=Value FROM ADM_GlobalPreferences WHERE Name='DefVacationDaysMonthlyOrYearly'
	--	IF(@DefVacDays>0)
	--	BEGIN
	--		UPDATE COM_CC50051 SET VacationPeriod=@DefVacDaysMR,VacDaysPerMonth=@DefVacDays WHERE NodeID=@NodeID   
	--	END
	--END
	
	--Inserts HISTORY Information  
	IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
		EXEC spCOM_SetHistory @CostCenterID,@NodeID,@HistoryXML,@UserName
 
 SET @tStatus=@StatusID

	--CHECK WORKFLOW
	EXEC spCOM_CheckCostCentetWF @CostCenterID,@NodeID,@WID,@RoleID,@UserID,@UserName,@StatusID output

	IF(@StatusID=250)
	BEGIN
		UPDATE COM_CC50051 SET StatusID=@tStatus WHERE NodeID=@NodeID 
	END
	
	--INSERTING DEFAULT GRADE '1-ALL' TO EMPLOYEE IF NOT ASSIGNED
	IF NOT EXISTS( SELECT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@NodeID AND CostCenterID=50051 AND HistoryCCID=50053 )
	BEGIN
		DECLARE @DOJ INT
		SELECT @DOJ=DOJ FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID
		
		INSERT INTO COM_HistoryDetails(CostCenterID,NodeID,HistoryCCID,HistoryNodeID,FromDate,ToDate,Remarks,CreatedBy,CreatedDate)
		SELECT @CostCenterID,@NodeID,50053,1,@DOJ,NULL,'',@UserName, @Dt
	END
 
  --SETTING ACCOUNT CODE EQUALS NodeID IF EMPTY  
  IF(@EmpCode IS NULL OR @EmpCode='')  
  BEGIN  
   UPDATE  [COM_CC50051] SET [Code] = @NodeID  WHERE NodeID=@NodeID        
   SET @EmpCode=@NodeID
  END  
  
  --validate Data External function
  DECLARE @tempCCCode NVARCHAR(200)
  set @tempCCCode=''
  select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=9
  if(@tempCCCode<>'')
  begin
	exec @tempCCCode @CostCenterID,@NODEID,@UserID,@LangID
  end  

	IF (@CCMapXML IS NOT NULL AND @CCMapXML <> '')  
		EXEC [spCOM_SetCCCCMap] @CostCenterID,@NodeID,@CCMapXML,@UserName,@LangID
		
	--Duplicate Check
	declare @NID NVARCHAR(20)
	SET @NID=convert(nvarchar,@NodeID)
	exec [spCOM_CheckUniqueCostCenter] 50051,@NID,@LangID	
	
	--CREATE/UPDATE USER
			DECLARE @ROLECODE INT,@CANCREATEUSER VARCHAR(5),@USRID INT
			DECLARE @USERASSIGNXML NVARCHAR(MAX),@PrevPwd  NVARCHAR(MAX)
			
			SET @USERASSIGNXML='<XML><Row  CostCenterId="50051"'
			SET @USERASSIGNXML=@USERASSIGNXML+' NodeID="'+ CONVERT(VARCHAR,@NodeID) +'"' 
			SET @USERASSIGNXML=@USERASSIGNXML+'/></XML>'
			
			SELECT @ROLECODE=ISNULL(ROLEID,0),@CANCREATEUSER =ISNULL(CanCreateUser,'No') FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID and ISNULL(CanCreateUser,'No')='Yes'
			SELECT @USRID=ISNULL(USERID,0)  FROM ADM_USERS WITH(NOLOCK) WHERE USERNAME=@LoginUserID --@EmpCode
			IF ISNULL(@ROLECODE,0)>0
			BEGIN
				IF ISNULL(@USRID,0)>0
				BEGIN
					Select @PrevPwd=[Password] from ADM_Users WHERE UserName=@LoginUserID	--@EmpCode
					--EXEC spADM_SetUser  @SaveUserID=@USRID ,@RoleId=@ROLECODE,@SaveUserName=@EmpCode ,@Pwd=@PrevPwd ,@Status=1 ,@DefLanguage='1' ,@Query='FirstName='''',MiddleName='''',LastName='''',Address1='''',Address2='''',Address3='''',City='''',State='''',Zip='''',Country='''',Phone1='''',Phone2='''',Fax='''',Website='''',Description='''',' ,@CompanyIndex=@CompIndex ,@CompanyUserXML=@USERASSIGNXML ,@RestrictXML='<XML></XML>' ,@DefaultScreenXML='' ,@LicenseCnt=0 ,@LincenseXML='' ,@ImageXML='',@RolesXML='',@CompanyGUID='admin' ,@GUID='GUID' ,@UserName='admin' ,@UserID=1,@LoginRoleID=@RoleID ,@LangID=1
				END
				ELSE
				BEGIN
					EXEC spADM_SetUser  @SaveUserID=0 ,@RoleId=@ROLECODE,@SaveUserName=@LoginUserID ,@Pwd=@EmpCode ,@Status=1 ,@DefLanguage='1' ,@Query='FirstName='''',MiddleName='''',LastName='''',Address1='''',Address2='''',Address3='''',City='''',State='''',Zip='''',Country='''',Phone1='''',Phone2='''',Fax='''',Website='''',Description='''',' ,@CompanyIndex=@CompIndex ,@CompanyUserXML=@USERASSIGNXML ,@RestrictXML='<XML></XML>' ,@DefaultScreenXML='' ,@LicenseCnt=0 ,@LincenseXML='' ,@ImageXML='',@RolesXML='',@CompanyGUID='admin' ,@GUID='GUID' ,@UserName='admin' ,@UserID=1,@LoginRoleID=@RoleID ,@LangID=1
				END
			END
			--ELSE
			--BEGIN
			--	EXEC spADM_DeleteUser @USRID,@Code,@UserID,@LangID 
			--END
	--CREATE/UPDATE USER
	--INSERT EMPLOYEE IN ASSIGNED LEAVES
		EXEC spPAY_InsertPayrollCostCenter @CostCenterID,@NodeID,@UserID,@LangID
		
		
		
COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SELECT * FROM [COM_CC50051] WITH(nolock) WHERE NodeID=@NodeID  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @NodeID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
	IF ISNUMERIC(ERROR_MESSAGE())=1
	BEGIN
		--SELECT * FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)   
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  	
	END
	ELSE
		SELECT ERROR_MESSAGE() ErrorMessage
	
 END 
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=2627  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-116 AND LanguageID=@LangID  
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
