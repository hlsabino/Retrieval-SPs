USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetEmployee]
	@NodeID [int],
	@Code [nvarchar](200),
	@Name [nvarchar](500),
	@AliasName [nvarchar](500),
	@StatusID [int],
	@EmpType [int],
	@DOJ [datetime],
	@DOB [datetime],
	@RptManager [int],
	@Gender [nvarchar](50),
	@ProbationDays [int],
	@DOConfirmation [datetime],
	@NotesXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@ContactsXML [nvarchar](max),
	@AddressXML [nvarchar](max),
	@CCMapXML [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@HistoryXML [nvarchar](max) = null,
	@IDHistoryXML [nvarchar](max) = null,
	@PaymentModeXML [nvarchar](max) = null,
	@DocumentsXML [nvarchar](max) = null,
	@AccLinkXML [nvarchar](max) = null,
	@PayQuery [nvarchar](max) = null,
	@WID [int] = 0,
	@AssignLeavesXML [nvarchar](max) = null,
	@PrimaryContactQuery [nvarchar](max),
	@SelectedNodeID [int],
	@IsGroup [bit],
	@CodePrefix [nvarchar](200) = NULL,
	@CodeNumber [int] = 0,
	@GroupSeqNoLength [int] = 0,
	@IsImport [bit] = 0,
	@CompanyGUID [nvarchar](50),
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
	print 't'
	--Declaration Section 
	DECLARE @CostCenterID INT,@ActionType INT,@Hasaccesss BIT,@IsDuplicateNameAllowed BIT,@IsDuplicateCodeAllowed BIT,
			@IsCodeAutoGen BIT,@IsIgnoreSpace BIT,@IsParentCode BIT,@Dt DECIMAL(10,5),@SelectedIsGroup bit,
			@Selectedlft INT,@Selectedrgt INT,@ParentID INT,@lft INT,@rgt INT,@Depth int,
			@TempGuid NVARCHAR(50),@UpdateSql NVARCHAR(max),@XML XML,@TEMPDOJ DATETIME, @tStatus INT,@HistoryStatus NVARCHAR(300),@Audit NVARCHAR(100),@RefSelectedNodeID INT
			
	SET @CostCenterID=50051
	SET @Name=RTRIM(LTRIM(@Name))
	SELECT @TEMPDOJ=CONVERT(DATETIME,DOJ) FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NODEID
	--User access check for EMPLOYEE  
	IF @NodeID=0  
	BEGIN
		SET @ActionType=1
		SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,1)  
	END  
	ELSE  
	BEGIN  
		SET @ActionType=3
		SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,3)  
	END  

	IF @Hasaccesss=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END
	
	--User access check for NOTES  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,8)  
		IF @Hasaccesss=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  
	END  
  
  --User access check for ATTACHMENTS  
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
	BEGIN  
		SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,12)  
		IF @Hasaccesss=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  
	END  
  
  --User access check for CONTACTS  
	IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
	BEGIN  
		SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,16)  
		IF @Hasaccesss=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  
	END 
	
	if(@NodeID=0)
		set @HistoryStatus='Add'
	else
		set @HistoryStatus='Update'   
	
	SELECT * FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE COSTCENTERID=50051 and  Name='DuplicateCodeAllowed' 
	--SELECT*  FROM COM_CostCenterPreferences  WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID 
	--Getting PREFERENCES  
  
	SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID and  Name='DuplicateCodeAllowed'  
	SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID and  Name='DuplicateNameAllowed'  
	SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID and  Name='CodeAutoGen'  
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID and  Name='IgnoreSpaces'  
	select @IsParentCode=IsParentCodeInherited  FROM COM_CostCenterCodeDef WITH(NOLOCK) where CostCenterID=@CostCenterID
	SELECT @Audit=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterId and Name='AuditTrial'

	IF @NodeID=0 and @Code='' and exists (SELECT * FROM COM_CostCenterCodeDef WITH(nolock) WHERE CostCenterID=@CostCenterID and IsEnable=1 and IsName=0 and IsGroupCode=@IsGroup)
	BEGIN 
		--CALL AUTOCODEGEN 
		create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
		if(@SelectedNodeID is null)
			insert into #temp1
			EXEC [spCOM_GetCodeData] @CostCenterID,1,''  
		else
			insert into #temp1
			EXEC [spCOM_GetCodeData] @CostCenterID,@SelectedNodeID,''  
		select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1
	END	
	
	IF(@IsParentCode=0)
	BEGIN
		--DUPLICATE CODE CHECK  
		IF @IsDuplicateCodeAllowed=0
		BEGIN
			IF @NodeID=0  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE Code=@Code)  
					RAISERROR('-116',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE Code=@Code AND NodeID <> @NodeID)  
					RAISERROR('-116',16,1)  
			END  
		END
	END
	ELSE
	BEGIN 
		--DUPLICATE CODE CHECK  WHEN INHERIT PARENT CHECKED
		IF @IsDuplicateCodeAllowed=0
		BEGIN
			IF @NodeID=0  
			BEGIN  
				 IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE Code=@Code)
					RAISERROR('-116',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID <> @NodeID and Code=@Code)
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
				 IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE REPLACE(Name,' ','')=REPLACE(@Name,' ',''))  
					RAISERROR('-349',16,1)  
			END  
			ELSE  
			BEGIN  
				 IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE REPLACE(Name,' ','')=REPLACE(@Name,' ','') AND NodeID <> @NodeID)  
					RAISERROR('-349',16,1)       
			END  
		END  
		ELSE  
		BEGIN  
			IF @NodeID=0  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE Name=@Name)  
					RAISERROR('-349',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE Name=@Name AND NodeID <> @NodeID)  
					RAISERROR('-349',16,1)  
			END  
		END
	END  
	
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
	
	IF @NodeID=0 --------START INSERT RECORD----------- 
	BEGIN
		--To SET Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		from COM_CC50051 with(NOLOCK) where NodeID=@SelectedNodeID  

		--IF No Record Selected or Record Doesn't Exist  
		IF(@SelectedIsGroup is null)   
			select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			from COM_CC50051 with(NOLOCK) where ParentID =0  
	     
		IF(@SelectedIsGroup = 1)--Adding Node Under the Group  
		BEGIN  
			UPDATE COM_CC50051 SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
			UPDATE COM_CC50051 SET lft = lft + 2 WHERE lft > @Selectedlft;  
			SET @lft = @Selectedlft + 1  
			SET @rgt = @Selectedlft + 2  
			SET @ParentID = @SelectedNodeID  
			SET @Depth = @Depth + 1  
		END  
		else IF(@SelectedIsGroup = 0)--Adding Node at Same level  
		BEGIN  
			UPDATE COM_CC50051 SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
			UPDATE COM_CC50051 SET lft = lft + 2 WHERE lft > @Selectedrgt;  
			SET @lft = @Selectedrgt + 1  
			SET @rgt = @Selectedrgt + 2   
		END  
		else  --Adding Root  
		BEGIN  
			SET @lft =  1  
			SET @rgt = 2   
			SET @Depth = 0  
			SET @ParentID =0  
			SET @IsGroup=1  
		END
		
		INSERT INTO COM_CC50051  
		(CodePrefix,CodeNumber,Code,Name,AliasName,StatusID,Depth,ParentID,lft,rgt,IsGroup,
		EmpType,DOJ,DOB,RptManager,Gender,ProbationDays,DOConfirmation,
		CompanyGUID,GUID,CreatedBy,CreatedDate)  
		VALUES  
		(@CodePrefix,@CodeNumber,@Code,@Name,@AliasName,@StatusID,@Depth,@ParentID,@lft,@rgt,@IsGroup,
		@EmpType,CONVERT(FLOAT,@DOJ),CONVERT(FLOAT,@DOB),@RptManager,@Gender,@ProbationDays,CONVERT(FLOAT,@DOConfirmation),
		@CompanyGUID,NEWID(),@UserName,@Dt)  
		
		--To get inserted record primary key  
		SET @NodeID=SCOPE_IDENTITY() 
		
		INSERT INTO COM_CCCCDATA (CostCenterID,NodeID,GUID,CreatedBy,CreatedDate,CCNID51)
		VALUES(@CostCenterID,@NodeID,NEWID(),@UserName,@Dt,@NodeID)
		
		--INSERT PRIMARY CONTACT  
		INSERT INTO COM_Contacts (AddressTypeID,FeatureID,FeaturePK,CompanyGUID,GUID,CreatedBy,CreatedDate)  
		VALUES (1,@CostCenterID,@NodeID,@CompanyGUID,NEWID(),@UserName,@Dt)  

		INSERT INTO COM_ContactsExtended(ContactID,CreatedBy,CreatedDate)
		VALUES(SCOPE_IDENTITY(),@UserName,@Dt)
	END --------END INSERT RECORD-----------  
	ELSE--------START UPDATE RECORD-----------  
	BEGIN
		IF EXISTS(SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID AND ParentID=0)  
		BEGIN  
			RAISERROR('-123',16,1)  
		END  
		SELECT @TempGuid=GUID from COM_CC50051  WITH(NOLOCK) WHERE NodeID=@NodeID  
		IF(@TempGuid!=@Guid) --IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
		BEGIN    
			RAISERROR('-101',16,1)   
		END    
		ELSE    
		BEGIN
			--DELETE FROM  COM_CCCCDATA WHERE NodeID=@NodeID AND CostCenterID = @CostCenterID
			
			--INSERT INTO COM_CCCCDATA (CostCenterID ,NodeID ,CompanyGUID,Guid,CreatedBy,CreatedDate)
			--VALUES(@CostCenterID,@NodeID, @CompanyGUID,NEWID(),  @UserName, @Dt)
			UPDATE COM_CC50051  
			SET CodePrefix=@CodePrefix,CodeNumber=@CodeNumber,Code=@Code,Name=@Name,AliasName=@AliasName,
			StatusID=@StatusID,IsGroup=@IsGroup,
			EmpType=@EmpType,DOJ=CONVERT(FLOAT,@DOJ),DOB=CONVERT(FLOAT,@DOB),RptManager=@RptManager,
			Gender=@Gender,ProbationDays=@ProbationDays,DOConfirmation=CONVERT(FLOAT,@DOConfirmation),
			GUID=NEWID(),ModifiedBy=@UserName,ModifiedDate=@Dt   	  
			WHERE NodeID=@NodeID
			 print 'Empl'
			declare @IsMove bit,@PaRID INT
	        select @PaRID=ParentId from COM_CC50051 WITH(NOLOCK) where NodeID=@NodeID
	        print @PaRID
	        print @SelectedNodeID
			if(@PaRID!=@SelectedNodeID and @SelectedNodeID>0)
		    begin
		    print 'Empl'
		       exec spCOM_MoveCostCenter 50051,@NodeID,@SelectedNodeID,@RoleID,1
		    end
			 
		END		
	END --------END UPDATE RECORD-----------
	
	
	-- setting Code = NodeID, IF Code is EMPTY  
	IF(@Code IS NULL OR @Code='')  
	BEGIN  
		UPDATE COM_CC50051 SET Code=@NodeID WHERE NodeID=@NodeID
		SET @Code=@NodeID        
	END

	-- BEFORE MODIFIEDBY REQUIRES A NULL CHECK OF @PrimaryContactQuery 
	IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')
	BEGIN  
		EXEC spCOM_SetFeatureWiseContacts @CostCenterID,@NodeID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID
	END
	
	SET @tStatus=@StatusID
	
	--CHECK WORKFLOW
	EXEC spCOM_CheckCostCentetWF @CostCenterID,@NodeID,@WID,@RoleID,@UserID,@UserName,@StatusID output
	
	IF(@StatusID=250 )
		UPDATE COM_CC50051 SET StatusID=@tStatus WHERE NodeID=@NodeID 
  
  print 'k'

	--Update Extra fields  
	IF @CustomFieldsQuery is not null or @CustomFieldsQuery<>''
	BEGIN
		SET @UpdateSql='UPDATE COM_CC50051   
		SET '+@CustomFieldsQuery+'[ModifiedBy] ='''+ @UserName  
		+''',[ModifiedDate] =' + CONVERT(NVARCHAR,@Dt) +' WHERE NodeID='+CONVERT(NVARCHAR,@NodeID)   
		EXEC sp_executesql @UpdateSql  
	END
	
	SET @UpdateSql='UPDATE COM_CCCCDATA SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + CONVERT(NVARCHAR,@Dt) +' 
					WHERE NodeID = '+CONVERT(NVARCHAR,@NodeID) + ' AND CostCenterID = '+CONVERT(NVARCHAR,@CostCenterID) 
	EXEC sp_executesql @UpdateSql
	
	--Update Employee Type If 0
	IF (ISNULL(@EmpType,0)=0)
	BEGIN
		SET @EmpType=(SELECT TOP 1 NODEID FROM COM_LOOKUP WITH(NOLOCK) WHERE LOOKUPTYPE=104 AND ISNULL(ISDEFAULT,0)=1)
		UPDATE COM_CC50051 SET EmpType=@EmpType	WHERE NodeID=@NodeID 
	END

	declare @LoginUserID NVARCHAR(250)
	SELECT @LoginUserID=LoginUserID FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID
	IF(@LoginUserID IS NULL OR  @LoginUserID='')
	BEGIN
		UPDATE COM_CC50051 SET LoginUserID=Code WHERE NodeID=@NodeID
	END
	SELECT @LoginUserID=LoginUserID FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID
	
	--Check and Updating Default Vacation Days
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
	
	IF(@IsImport=0)
	BEGIN
		DELETE FROM PAY_EmpDetail 
		WHERE EmployeeID=@NodeID AND DType IN(-51001,-51002,-51003,-51004,-51005,-51006,-51007)
	END

	IF (@IDHistoryXML IS NOT NULL AND @IDHistoryXML <> '') 
	BEGIN
		DECLARE @IDXML XML
		SET @IDXML=@IDHistoryXML

		INSERT INTO PAY_EmpDetail(EmployeeID,DType,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,Field1,Field2,Field3,Field4,Field5,Field6,Field7,Field8)
		SELECT @NodeID,X.value('@DType','INT'),@UserName, @Dt,@UserName, @Dt,
		X.value('@sDType','NVARCHAR(MAX)'),X.value('@SNo','INT'),X.value('@Number','NVARCHAR(MAX)'),
		CASE WHEN X.value('@IssDate','NVARCHAR(MAX)') IS NOT NULL THEN CONVERT(INT,CONVERT(DATETIME,X.value('@IssDate','NVARCHAR(MAX)'))) ELSE NULL END,
		CASE WHEN X.value('@ExpDate','NVARCHAR(MAX)') IS NOT NULL THEN CONVERT(INT,CONVERT(DATETIME,X.value('@ExpDate','NVARCHAR(MAX)'))) ELSE NULL END,
		CASE WHEN X.value('@ExtendDate','NVARCHAR(MAX)') IS NOT NULL THEN CONVERT(INT,CONVERT(DATETIME,X.value('@ExtendDate','NVARCHAR(MAX)'))) ELSE NULL END,
		CASE WHEN X.value('@Country','NVARCHAR(MAX)') IS NOT NULL THEN CONVERT(INT,X.value('@Country','NVARCHAR(MAX)')) ELSE NULL END,
		CASE WHEN X.value('@IsDefault','NVARCHAR(MAX)') IS NOT NULL THEN X.value('@IsDefault','NVARCHAR(MAX)') ELSE NULL END
		FROM @IDXML.nodes('/XML/Row') as Data(X)

	END

	IF (@PaymentModeXML IS NOT NULL AND @PaymentModeXML <> '') 
	BEGIN
		DECLARE @PMXML XML
		SET @PMXML=@PaymentModeXML

		IF(@IsImport=0)
		BEGIN
			DELETE FROM PAY_EmpDetail WHERE DType=-51011 AND EmployeeID=@NodeID
		END 

		INSERT INTO PAY_EmpDetail(EmployeeID,DType,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,Field1,Field2,Field3,Field4,Field5,Field6,Field7)
		SELECT @NodeID,X.value('@DType','INT'),@UserName, @Dt,@UserName, @Dt,
		X.value('@sDType','NVARCHAR(MAX)'),X.value('@SNo','INT'),X.value('@PaymentMode','NVARCHAR(MAX)'),X.value('@iBank','INT'),
		X.value('@BankAccNo','NVARCHAR(MAX)'),X.value('@IBANNo','NVARCHAR(MAX)'),X.value('@StatusID','INT')
		FROM @PMXML.nodes('/XML/Row') as Data(X)

	END

	--INSERTING DEFAULT GRADE '1-ALL' TO EMPLOYEE IF NOT ASSIGNED
	IF NOT EXISTS( SELECT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@NodeID AND CostCenterID=50051 AND HistoryCCID=50053 )
	BEGIN
		INSERT INTO COM_HistoryDetails(CostCenterID,NodeID,HistoryCCID,HistoryNodeID,FromDate,ToDate,Remarks,CreatedBy,CreatedDate)
		SELECT @CostCenterID,@NodeID,50053,1,CONVERT(INT,@DOJ),NULL,'',@UserName, @Dt
	END
		
	-- INSERTING EMPPAY DETAILS	
	IF NOT EXISTS(SELECT SEQNO FROM PAY_EmpPay WITH(NOLOCK) WHERE EmployeeID=@NodeID )
	BEGIN
		INSERT INTO PAY_EmpPay(EmployeeID, EffectFrom, ApplyFrom, CreatedBy, CreatedDate)
		SELECT @NodeID,CONVERT(INT,@DOJ),CONVERT(INT,@DOJ),@UserName, @Dt
	END
	IF(@PayQuery IS NOT NULL AND @PayQuery<>'')
	BEGIN
		print @PayQuery
		SET @UpdateSql='UPDATE PAY_EmpPay   
		SET '+@PayQuery+'[ModifiedBy] ='''+ @UserName  
		+''',[ModifiedDate] =' + CONVERT(NVARCHAR,@Dt) +' WHERE SeqNo=(SELECT TOP 1 SeqNo FROM PAY_EmpPay WITH(NOLOCK) WHERE EmployeeID='+CONVERT(NVARCHAR,@NodeID)+' ORDER BY EffectFrom Desc,SeqNo Desc)'
		print @UpdateSql
		EXEC sp_executesql @UpdateSql 
		-- INSERTING EMPPAY_HISTORY DETAILS
		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN
			INSERT INTO PAY_EmpPay_History
			SELECT @CostCenterID,@HistoryStatus,* FROM PAY_EmpPay WITH(NOLOCK) WHERE EmployeeID=@NodeID 
		END
		-- END EMPPAY_HISTORY DETAILS
	END
	
	--Inserts Multiple Contacts  
	IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
	BEGIN  
		declare @rValue int
		EXEC @rValue =  spCOM_SetFeatureWiseContacts @CostCenterID,@NodeID,2,@ContactsXML,@UserName,@Dt,@LangID  
		IF @rValue=-1000  
		BEGIN  
			RAISERROR('-500',16,1)  
		END   
	END
	
	
	
	--Inserts Multiple Address  
	EXEC spCOM_SetAddress @CostCenterID,@NodeID,@AddressXML,@UserName
	
	--Inserts Multiple Documents  
	EXEC spPAY_SetEmpDocuments @NodeID,@DocumentsXML,@UserName
	
	--Inserts Multiple Notes  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @XML=@NotesXML  
		
		--If Action is NEW then insert new Notes  
		INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,GUID,CreatedBy,CreatedDate)  
		SELECT @CostCenterID,@CostCenterID,@NodeID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~',''),NEWID(),@UserName,@Dt
		FROM @XML.nodes('/NotesXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

		--If Action is MODIFY then update Notes  
		UPDATE COM_Notes SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~',''),     
		GUID=NEWID(),ModifiedBy=@UserName,ModifiedDate=@Dt  
		FROM COM_Notes C   
		INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X) ON convert(INT,X.value('@NoteID','INT'))=C.NoteID  
		WHERE X.value('@Action','NVARCHAR(10)')='MODIFY'  

		--If Action is DELETE then delete Notes  
		DELETE FROM COM_Notes 
		WHERE NoteID IN( SELECT X.value('@NoteID','INT')  
						 FROM @XML.nodes('/NotesXML/Row') as Data(X)  
						 WHERE X.value('@Action','NVARCHAR(10)')='DELETE'
						)  

	END
	
	--Inserting ATTACHMENTS

	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
	exec [spCOM_SetAttachments] @NodeID,@CostCenterID,@AttachmentsXML,@UserName,@Dt

	/*
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
	BEGIN  
		SET @XML=@AttachmentsXML  

		INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,
		FeatureID,CostCenterID,FeaturePK,GUID,CreatedBy,CreatedDate,IsDefaultImage)  
		SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
		X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),
		@CostCenterID,@CostCenterID,@NodeID,X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  ,X.value('@IsDefaultImage','bit')
		FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

		--If Action is MODIFY then update Attachments  
		UPDATE COM_Files  
		SET FilePath=X.value('@FilePath','NVARCHAR(500)'), ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
		RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'), FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
		FileDescription=X.value('@FileDescription','NVARCHAR(500)'), IsProductImage=X.value('@IsProductImage','bit'),     
		IsDefaultImage=X.value('@IsDefaultImage','bit'), GUID=X.value('@GUID','NVARCHAR(50)'),  
		ModifiedBy=@UserName, ModifiedDate=@Dt  
		FROM COM_Files C   
		INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X) ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID  
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  

		--If Action is DELETE then delete Attachments  
		DELETE FROM COM_Files  
		WHERE FileID IN( SELECT X.value('@AttachmentID','INT')  
						 FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)  
						 WHERE X.value('@Action','NVARCHAR(10)')='DELETE'
						)  
	END
	*/
	
	IF (@CCMapXML IS NOT NULL AND @CCMapXML <> '')  
		EXEC [spCOM_SetCCCCMap] @CostCenterID,@NodeID,@CCMapXML,@UserName,@LangID
	
	----Inserting ACCOUNTS LINKING
	IF (@AccLinkXML IS NOT NULL AND @AccLinkXML <> '')  
	BEGIN  
		SET @XML=@AccLinkXML 
		DELETE FROM PAY_EmpAccountsLinking WHERE EmpSeqNo=@NodeID
		INSERT INTO PAY_EmpAccountsLinking(EmpSeqNo, ComponentID, Type, SNo, DebitAccountID, CreditAccountID)
		SELECT @NodeID,A.value('@ComponentID','INT'),A.value('@Type','int'),A.value('@SNo','int'),A.value('@DebitAccountID','INT'),A.value('@CreditAccountID','INT')
		from @XML.nodes('Rows/Row') as Data(A)
		----Inserting ACCOUNTS HISTORY LINKING
		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN
		INSERT INTO PAY_EmpAccountsLinking_History
		select @CostCenterID,@HistoryStatus,* FROM PAY_EmpAccountsLinking WITH(NOLOCK) WHERE EmpSeqNo=@NodeID
		END
		----END ACCOUNTS HISTORY LINKING
	END
	----END : Inserting ACCOUNTS LINKING
	--Duplicate Check
	declare @NID NVARCHAR(20)
	SET @NID=convert(nvarchar,@NodeID)
	exec [spCOM_CheckUniqueCostCenter] @CostCenterID=50051,@NodeID =@NID,@LangID=@LangID
	
	IF(@GroupSeqNoLength>0)
		UPDATE COM_CC50051 SET GroupSeqNoLength=@GroupSeqNoLength WHERE NodeID=@NodeID
		
		
	
	/*
	IF(@ActionType=1 AND @IsGroup=0)
	BEGIN
		IF(@AssignLeavesXML IS NOT NULL AND @AssignLeavesXML <> '')
		BEGIN
			DECLARE @TEMPxml NVARCHAR(MAX),@varxml XML,@ddxml NVARCHAR(MAX),@Prefix NVARCHAR(MAX)
			DECLARE @CCID INT,@DivisionID INT,@LocationID INT,@DocDate DATETIME,@return_value int
			SET @DocDate='01/Apr/2016'
			
			SET @XML=@AssignLeavesXML	
			
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AssignLeavesXML'))
			from @XML.nodes('/XML') as Data(X)
			
			if(@TEMPxml<>'')
			begin
				set @varxml=@TEMPxml
				set @CCID=40060
				
				SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
				from @varxml.nodes('/AssignLeavesXML') as Data(X)
				
				set @ddxml=Replace(@ddxml,'<RowHead/>','')
				set @ddxml=Replace(@ddxml,'</DOCXML>','')
				set @ddxml=Replace(@ddxml,'<DOCXML>','')
				set @ddxml=Replace(@ddxml,'-999',CONVERT(NVARCHAR(MAX),@NodeID))
				set @Prefix=''
				
				EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@CCID,@Prefix output
				SELECT @ddxml
				SELECT @DivisionID=CCNID1,@LocationID=CCNID2 FROM COM_CCCCDATA WITH(NOLOCK) 
				WHERE NodeID=@NodeID AND CostCenterID=@CostCenterID
				
				EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
				  @CostCenterID = @CCID,      
				  @DocID = 0,      
				  @DocPrefix = @Prefix,      
				  @DocNumber = N'',      
				  @DocDate = @DocDate,      
				  @DueDate = NULL,      
				  @BillNo = '',      
				  @InvDocXML =@ddxml,      
				  @BillWiseXML = '',      
				  @NotesXML = N'',      
				  @AttachmentsXML = N'',    
				  @ActivityXML = '',       
				  @IsImport = 0,      
				  @LocationID = @LocationID,      
				  @DivisionID = @DivisionID,      
				  @WID = 0,      
				  @RoleID = @RoleID,      
				  @DocAddress = N'',      
				  @RefCCID = 50051,    
				  @RefNodeid  = @NodeID,    
				  @CompanyGUID = @CompanyGUID,      
				  @UserName = @UserName,      
				  @UserID = @UserID,      
				  @LangID = @LangID    
				  
				  SELECT @return_value
			END	
		END
	END
	
	*/
	--CREATE/UPDATE USER
			DECLARE @ROLECODE INT,@CANCREATEUSER VARCHAR(5),@USRID INT
			DECLARE @USERASSIGNXML NVARCHAR(MAX),@PrevPwd  NVARCHAR(MAX),@Email1 NVARCHAR(MAX),@QQ NVARCHAR(MAX),@userStatus int
			
			SET @USERASSIGNXML='<XML><Row  CostCenterId="50051"'
			SET @USERASSIGNXML=@USERASSIGNXML+' NodeID="'+ CONVERT(VARCHAR,@NodeID) +'"' 
			SET @USERASSIGNXML=@USERASSIGNXML+'/></XML>'
			
			SELECT @Email1=Email,@userStatus=StatusID FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID
			SELECT @ROLECODE=ISNULL(ROLEID,0),@CANCREATEUSER =ISNULL(CanCreateUser,'') FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@NodeID and ISNULL(CanCreateUser,'')='Yes'
			SELECT @USRID=ISNULL(USERID,0)  FROM ADM_USERS WITH(NOLOCK) WHERE USERNAME=@LoginUserID --@Code
			IF ISNULL(@ROLECODE,0)>0
			BEGIN
				IF ISNULL(@USRID,0)>0
				BEGIN
				UPDATE dbo.ADM_UserRoleMap SET RoleID=@ROLECODE,ModifiedBy='admin',ModifiedDate=CONVERT(FLOAT,GETDATE()) WHERE  UserName =@LoginUserID	-- @Code 
				UPDATE ADM_USERS SET EMAIL1=@Email1,StatusID=case when @userStatus=250 then 1 else 2 end WHERE USERNAME=@LoginUserID		--@CODE
				UPDATE [PACT2C].dbo.ADM_Users SET EMAIL1=@Email1,StatusID=case when @userStatus=250 then 1 else 2 end WHERE USERNAME=@LoginUserID --@CODE
					--Select @PrevPwd=[Password] from ADM_Users WHERE UserName=@Code
					--EXEC spADM_SetUser  @SaveUserID=@USRID ,@RoleId=@ROLECODE,@SaveUserName=@Code ,@Pwd=@PrevPwd ,@Status=1 ,@DefLanguage='1' ,@Query='FirstName='''',MiddleName='''',LastName='''',Address1='''',Address2='''',Address3='''',City='''',State='''',Zip='''',Country='''',Phone1='''',Phone2='''',Fax='''',Website='''',Description='''',' ,@CompanyIndex=@CompIndex ,@CompanyUserXML=@USERASSIGNXML ,@RestrictXML='<XML></XML>' ,@DefaultScreenXML='' ,@LicenseCnt=0 ,@LincenseXML='' ,@ImageXML='',@RolesXML='',@CompanyGUID='admin' ,@GUID='GUID' ,@UserName='admin' ,@UserID=1,@LoginRoleID=@RoleID ,@LangID=1
				END
				ELSE
				BEGIN
				SET @QQ='FirstName='''+@Name+''',MiddleName='''',LastName='''',Address1='''',Address2='''',Address3='''',City='''',State='''',Zip='''',Country='''',Phone1='''',Phone2='''',Fax='''',Website='''',Description='''',Email1='''+@Email1+''','
					EXEC spADM_SetUser  @SaveUserID=0 ,@RoleId=@ROLECODE,@SaveUserName=@LoginUserID ,@Pwd=@Code ,@Status=1 ,@DefLanguage='1' ,@IsOffline=NULL,@Query=@QQ ,@CompanyIndex=@CompIndex ,@CompanyUserXML=@USERASSIGNXML ,@RestrictXML='<XML></XML>' ,@DefaultScreenXML='' ,@LicenseCnt=0 ,@LincenseXML='' ,@RolesXML='',@CompanyGUID='admin' ,@GUID='GUID' ,@UserName='admin' ,@UserID=1,@LoginRoleID=@RoleID ,@LangID=1
					UPDATE ADM_Users SET IsNewLogin=1 WHERE UserName=@LoginUserID AND Password=@Code
				END
			END
			
	--CREATE/UPDATE USER
	--INSERT EMPLOYEE IN ASSIGNED LEAVES
		EXEC spPAY_InsertPayrollCostCenter @CostCenterID,@NodeID,@UserID,@LangID
	
	-- CREATING SALARY AND PAYABLE ACCOUNTS
	
	IF(@ActionType=1 AND @IsGroup=0)
	BEGIN
		DECLARE @CrSalAcc NVARCHAR(100),@CrPayAcc NVARCHAR(100),@CrSalAccGrp NVARCHAR(10),@CrPayAccGrp NVARCHAR(10)
		DECLARE @curSA INT,@curPA INT,@salAccType int,@payAccType int
		declare @TCode NVARCHAR(100),@TName NVARCHAR(100) ,@return_value INT
		
		SELECT @CrSalAcc=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='CreateSalaryAcc'
		SELECT @CrSalAccGrp=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='CreateSalaryAccGrp'
		SELECT @CrPayAcc=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='CreatePayableAcc'
		SELECT @CrPayAccGrp=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='CreatePayableAccGrp'
		
		-- CREATING SALARY ACCOUNT 
		IF(@CrSalAcc IS NOT NULL AND @CrSalAcc='True' AND @CrSalAccGrp IS NOT NULL AND CONVERT(INT,@CrSalAccGrp)>0 )
		BEGIN
			SET @TCode=@Code+'_SalAcc'
			SET @TName=@Name+'_'+@Code+'_SalaryAccount'
			SELECT 	@salAccType=ISNULL(AccountTypeID,0) From ACC_ACCOUNTS WITH(NOLOCK) WHERE AccountID=@CrSalAccGrp			
			
			--	CREATE ACCOUNT HERE
			EXEC	@return_value = [dbo].[spACC_SetAccount]
			@AccountID = 0,
			@AccountCode = @TCode,
			@AccountName = @TName,
			@AliasName = @TName,
			@AccountTypeID = @salAccType,
			@StatusID = 33,
			@SelectedNodeID = @CrSalAccGrp,
			@IsGroup = 0,
			@CreditDays=0,@CreditLimit=0,@DebitDays=0,@DebitLimit=0,@Currency=0,
			@PurchaseAccount=0,@SalesAccount=0,@COGSAccountID=0,@ClosingStockAccountID=0,
			@PDCReceivableAccount=0,@PDCPayableAccount=0,@IsBillwise=0,@PaymentTerms=0,
			@LetterofCredit=0,@TrustReceipt=0,@CompanyGUID='companyGUID',@GUID='GUID',@Description='DESC',
			@UserName=@UserName,@CustomFieldsQuery='',@CustomCostCenterFieldsQuery='',
			@PrimaryContactQuery='',@ContactsXML='',@AttachmentsXML='',@NotesXML='',@AddressXML=''
			
			Update COM_CC50051 SET SalaryAccID=b.AccountID 
			FROM COM_CC50051 a WITH(NOLOCK) 
			JOIN ACC_Accounts b WITH(NOLOCK) on b.AccountName= @TName 
			WHERE a.NodeID=@NodeID
			
		END
		
		--CREATETING PAYABLE ACCOUNT 
		IF(@CrPayAcc IS NOT NULL AND @CrPayAcc='True' AND @CrPayAccGrp IS NOT NULL AND CONVERT(INT,@CrPayAccGrp)>0 )
		BEGIN
			SET @TCode=@Code+'_PayAcc'
			SET @TName=@Name+'_'+@Code+'_PayableAccount'
			SELECT 	@payAccType=ISNULL(AccountTypeID,0) From ACC_ACCOUNTS WITH(NOLOCK) WHERE AccountID=@CrPayAccGrp			
			
			--	CREATE ACCOUNT HERE
			EXEC	@return_value = [dbo].[spACC_SetAccount]
			@AccountID = 0,
			@AccountCode = @TCode,
			@AccountName = @TName,
			@AliasName = @TName,
			@AccountTypeID = @payAccType,
			@StatusID = 33,
			@SelectedNodeID = @CrPayAccGrp,
			@IsGroup = 0,
			@CreditDays=0,@CreditLimit=0,@DebitDays=0,@DebitLimit=0,@Currency=0,
			@PurchaseAccount=0,@SalesAccount=0,@COGSAccountID=0,@ClosingStockAccountID=0,
			@PDCReceivableAccount=0,@PDCPayableAccount=0,@IsBillwise=0,@PaymentTerms=0,
			@LetterofCredit=0,@TrustReceipt=0,@CompanyGUID='companyGUID',@GUID='GUID',@Description='DESC',
			@UserName=@UserName,@CustomFieldsQuery='',@CustomCostCenterFieldsQuery='',
			@PrimaryContactQuery='',@ContactsXML='',@AttachmentsXML='',@NotesXML='',@AddressXML=''
			
			Update COM_CC50051 SET PayableAccID=b.AccountID 
			FROM COM_CC50051 a WITH(NOLOCK) 
			JOIN ACC_Accounts b WITH(NOLOCK) on b.AccountName= @TName 
			WHERE a.NodeID=@NodeID
		END
			
		
	END
	-- END :: CREATING SALARY AND PAYABLE ACCOUNTS
	  IF(@DOJ!=@TEMPDOJ)
		BEGIN 
		Delete  from COM_HistoryDetails where NodeID=@NodeID AND FromDate<CONVERT(FLOAT,@DOJ) And Todate<CONVERT(FLOAT,@DOJ)		
		UPDATE COM_HistoryDetails SET FromDate=convert(float,@DOJ), 
		ModifiedBy=@UserName,  
	    ModifiedDate=@Dt  FROM COM_HistoryDetails C WHERE NodeID=@NodeID AND (FromDate<=CONVERT(FLOAT,@TEMPDOJ) or FromDate<=CONVERT(FLOAT,@DOJ))  And (Todate>=CONVERT(FLOAT,@DOJ) or ToDate is Null)
	    INSERT INTO [COM_HistoryDetails_History]	    
	    SELECT *,'Update' FROM COM_HistoryDetails WITH(NOLOCK) 
	    WHERE NodeID=@NodeID AND FromDate=CONVERT(FLOAT,@TEMPDOJ)
		UPDATE PAY_EmpPay   
		SET [ModifiedBy] =@UserName ,[ModifiedDate] =CONVERT(NVARCHAR,@Dt),[EffectFrom]=CONVERT(FLOAT,@DOJ),[ApplyFrom]=CONVERT(FLOAT,@DOJ) WHERE SeqNo=(SELECT TOP 1 SeqNo FROM PAY_EmpPay WITH(NOLOCK) WHERE EmployeeID=CONVERT(NVARCHAR,@NodeID) ORDER BY EffectFrom Asc)	
		END

		--INSERT INTO HISTROY
		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN    
			insert into [COM_CC50051_History]         
			select @CostCenterID,@HistoryStatus,* FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@NODEID
		END
		--END INTO HISTROY

------------------

--CREATE/EDIT LINK DIMENSION
	declare @LinkDimCC nvarchar(max),@iLinkDimCC int,@Table NVARCHAR(50)
	SELECT @LinkDimCC=[Value] FROM com_costcenterpreferences with(nolock) WHERE CostCenterID=@CostCenterID and [Name]='LinkDimension'
	if(ISNUMERIC(@LinkDimCC)=1)
		set @iLinkDimCC=CONVERT(int,@LinkDimCC)
	else
		set @iLinkDimCC=0
	
	if ( @LinkDimCC>50000 and @iLinkDimCC!=@CostCenterID)
	begin
		declare @LinkDimNodeID INT,@CCStatusID INT
		declare @LinkDimCode nvarchar(max),@LinkDimAutoGen nvarchar(10),@CaseNumber nvarchar(500),@CaseID INT
		
		select @LinkDimNodeID=RefDimensionNodeID from com_docbridge with(nolock) 
		WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID AND RefDimensionID=@iLinkDimCC
		
		set @CCStatusID=(select top 1 statusid from com_status with(nolock) where costcenterid=@LinkDimCC and status = 'Active')

		IF EXISTS(select * from COM_DocumentBatchLinkDetails WITH(NOLOCK) WHERE BatchColID IN (SELECT CostCenterColID FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 AND		SysColumnName='StatusID'))
		BEGIN
			IF(@STATUSID=251)
				set @CCStatusID=(select top 1 statusid from com_status with(nolock) where costcenterid=@LinkDimCC and status = 'In Active')
		END

		if(@LinkDimNodeID is null or (@LinkDimNodeID<=0 and @LinkDimNodeID>-10000) or @LinkDimNodeID=1)
		BEGIN
		
			
				
			SELECT @LinkDimAutoGen=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='CodeAutoGen' AND CostCenterID=@LinkDimCC     
			if(@LinkDimAutoGen='True')
			BEGIN
					declare @Codetemp table (prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
					
					insert into @Codetemp
					EXEC [spCOM_GetCodeData] @LinkDimCC,1,'' ,null,0,0 
					
					select @LinkDimCode=code,@CaseNumber= prefix, @CaseID=number from @Codetemp
			END
			ELSE
			BEGIN
				set @LinkDimCode=@Code
				set @CaseNumber=''
				set @CaseID=0
			END
			DECLARE @Value NVARCHAR(50)
			SELECT @Value=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='CopyDimensionData' AND CostCenterID=@CostCenterID
			DECLARE @Contact NVARCHAR(max),@Addr NVARCHAR(max),@Note NVARCHAR(max),@Attach NVARCHAR(max)
			SELECT @Contact = CASE WHEN @Value LIKE '%1%' THEN @ContactsXML ELSE '' END
			SELECT @Addr = CASE WHEN @Value LIKE '%2%' THEN @AddressXML ELSE '' END
			SELECT @Note = CASE WHEN @Value LIKE '%3%' THEN @NotesXML ELSE '' END
			SELECT @Attach = CASE WHEN @Value LIKE '%4%' THEN @AttachmentsXML ELSE '' END

			SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
								WHERE CostCenterID=50051 AND RefDimensionID=@iLinkDimCC AND NodeID=@SelectedNodeID 
						
			SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)

			EXEC @return_value = [dbo].[spCOM_SetCostCenter]
			@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
			@Code = @LinkDimCode,
			@Name = @Name,
			@AliasName=@AliasName,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML=@Addr,@AttachmentsXML=@Attach,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML=@Contact,@NotesXML=@Note,
			@CostCenterID = @LinkDimCC,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1,
			@CodePrefix=@CaseNumber,@CodeNumber=@CaseID,
			@CheckLink = 0,@IsOffline=0
			
			--set @return_value=0	
			declare @Gid nvarchar(50), @NodeidXML nvarchar(max)					
			select @Table=Tablename from adm_features with(nolock) where featureid=@LinkDimCC
			set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(NOLOCK) where NodeID='+convert(nvarchar,@LinkDimNodeID)+')'

			exec sp_executesql @NodeidXML,N'@Gid nvarchar(50) output' , @Gid OUTPUT 
			
			-- Link Dimension Mapping
			INSERT INTO COM_DocBridge(CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)
			values(@CostCenterID,@NodeID,0,0,@LinkDimCC,@return_value,'',newid(),@UserName, @dt,'CostCenter')
						
		END
		ELSE
			SET @return_value=@LinkDimNodeID
		
		--UPDATE LINK DATA
		
		if(@return_value>0 or @return_value<-10000)
		begin
		
			DECLARE @CCMapSql nvarchar(max)
			set @CCMapSql='update COM_CCCCDATA  
			SET CCNID'+convert(nvarchar,(@LinkDimCC-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  
			WHERE CostCenterID='+convert(nvarchar,@CostCenterID) +' and NODEID='+convert(NVARCHAR,@NodeID)  
			EXEC sp_executesql @CCMapSql
			
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@NodeID, 
				@Costcenterid=@CostCenterID,         
				@DimCCID=@LinkDimCC,
				@DimNodeID=@return_value,
				@UserID=@UserID,    
				@LangID=@LangID  


				select @Table=Tablename from adm_features with(nolock) where featureid=@LinkDimCC
				set @CCMapSql='Update '+@Table+' SET StatusID ='+convert(nvarchar,@CCStatusID)+' WHERE NodeID='+convert(nvarchar,@return_value)
				EXEC sp_executesql @CCMapSql
			
		end	
			
	end
		--validate Data External function
		DECLARE @tempCCCode NVARCHAR(200)
		set @tempCCCode=''
		select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=9
		if(@tempCCCode<>'')
		begin
			exec @tempCCCode @CostCenterID,@NODEID,@UserID,@LangID
		end  
		--INSERT History COM_CCCCDataHistory
		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN
			declare @CommonCols nvarchar(max),@HistoryCols nvarchar(max)='',@HistoryColsInsert nvarchar(max)='',@CC nvarchar(max),@HistoryID BIGINT
			
			SELECT @HistoryID=ISNULL(MAX(NodeHistoryID)+1,1) FROM COM_CCCCDataHistory WITH(NOLOCK)

			SELECT @CommonCols=STUFF((
			select ','+CH.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			JOIN (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_CCCCDataHistory') AS CH ON CH.name=a.name
			where b.name='COM_CCCCData' FOR XML PATH('')),1,1,'')
			, @HistoryCols=STUFF((
			select ','+a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			LEFT JOIN (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_CCCCData') AS CH ON CH.name=a.name
			where b.name='COM_CCCCDataHistory' AND CH.name IS NULL AND a.name LIKE 'CCNID%' FOR XML PATH('')),1,1,'')
			, @HistoryColsInsert=STUFF((
			select ','+'1' from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			LEFT JOIN (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_CCCCData') AS CH ON CH.name=a.name
			where b.name='COM_CCCCDataHistory' AND CH.name IS NULL AND a.name LIKE 'CCNID%' GROUP BY a.name FOR XML PATH('')),1,1,'')

			IF(@HistoryCols IS NULL)
			BEGIN
				set @CC=' INSERT INTO [COM_CCCCDataHistory](NodeHistoryID,'+@CommonCols+')
				select  '+convert(nvarchar,@HistoryID)+','+@CommonCols
						
				set @CC=@CC+' FROM [COM_CCCCData] WITH(NOLOCK)
				WHERE  NodeID='+convert(nvarchar,@NodeID) + ' AND CostCenterID='+convert(nvarchar,@CostCenterID)
			END
			ELSE
			BEGIN
				set @CC=' INSERT INTO [COM_CCCCDataHistory](NodeHistoryID,'+@CommonCols+','+ISNULL(@HistoryCols,'')+')
				select  '+convert(nvarchar,@HistoryID)+','+@CommonCols+','+ISNULL(@HistoryColsInsert,'')
						
				set @CC=@CC+' FROM [COM_CCCCData] WITH(NOLOCK)
				WHERE  NodeID='+convert(nvarchar,@NodeID) + ' AND CostCenterID='+convert(nvarchar,@CostCenterID)
			END
			--PRINT @CC
			
			exec sp_executesql @CC
		END
------------------
	
	COMMIT TRANSACTION
	--ROLLBACK TRANSACTION
  
	IF @ActionType=1
		SELECT   ErrorMessage + ' ''' + ISNULL(@Code,'')+'''' AS ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)       
		WHERE ErrorNumber=105 AND LanguageID=@LangID 
	ELSE	
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)   
		WHERE ErrorNumber=100 AND LanguageID=@LangID  
	
	SET NOCOUNT OFF; 
	RETURN @NodeID   
END TRY    
BEGIN CATCH    
	--Return exception info Message,Number,ProcedureName,LineNumber    
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(NOLOCK)  
		WHERE ErrorNumber=-110 AND LanguageID=@LangID  
	END   
	ELSE  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
	END  
	ROLLBACK TRANSACTION  
	SET NOCOUNT OFF    
	RETURN -999     
END CATCH

GO
