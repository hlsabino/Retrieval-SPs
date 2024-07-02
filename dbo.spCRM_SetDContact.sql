USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetDContact]
	@FEATUREID [bigint],
	@FEATURENODEID [bigint],
	@ACCOUNTID [bigint],
	@CustomerID [bigint],
	@ContactID [bigint],
	@FirstName [nvarchar](max),
	@MiddleName [nvarchar](max),
	@LastName [nvarchar](max),
	@CXML [nvarchar](max),
	@StatusID [int],
	@IsGroup [bit],
	@FromConvert [bit],
	@AssignCCCCData [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@NotesXML [nvarchar](max) = null,
	@ActivityXml [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@SelectedNodeID [int],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION 
BEGIN TRY
SET NOCOUNT ON;

	
	DECLARE @Dt float,@XML xml, @HasAccess bit,@UpdateSql nvarchar(max),@IsDuplicateNameAllowed bit,@IsResCodeAutoGen bit  ,@IsIgnoreSpace bit
    DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint,@SelectedIsGroup int,@ParentCode nvarchar(200)

		--User acces check FOR Customer 
		IF @ContactID=0
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,65,1)
		END
		ELSE
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,65,3)
		END

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END




	--User acces check FOR Notes
		IF (@NotesXML IS NOT NULL AND @NotesXML <> '')
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,65,8)

			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END
		END

		--User acces check FOR Attachments
		IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,65,12)

			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END
		END
		
	set @XML=@CXML 
    SET @Dt=convert(float,getdate())

    --GETTING PREFERENCE  
  SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=65  and  Name='DuplicateNameAllowed'  
  --SELECT @IsResCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=65 and  Name='CodeAutoGen'  
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=65 and  Name='IgnoreSpaces'  
   
		    IF @ACCOUNTID>0
			BEGIN
				SET @FEATUREID=2
			END	
 			ELSE IF @CustomerID>0
			BEGIN
				SET @FEATUREID=83
			END 
			ELSE  
				SET @FEATUREID=65	
				
			IF @CustomerID>0 AND @ACCOUNTID>0
				SET @FEATUREID=65	
	 
IF @FEATUREID=65
BEGIN				
  --DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
   BEGIN  
    IF @ContactID=0  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID and replace(FirstName,' ','')=replace(@FirstName,' ','') 
     AND replace(MiddleName,' ','')=replace(@MiddleName,' ','') AND replace(LastName,' ','')=replace(@LastName,' ','') )  
     BEGIN  
      RAISERROR('-500',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID and
     replace(FirstName,' ','')=replace(@FirstName,' ','') 
     AND replace(MiddleName,' ','')=replace(@MiddleName,' ','') AND replace(LastName,' ','')=replace(@LastName,' ','')
      AND ContactID <> @ContactID )  
     BEGIN  
      RAISERROR('-500',16,1)       
     END  
    END  
   END  
   ELSE  
   BEGIN  
    IF @ContactID=0  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID and FirstName=@FirstName AND
      MiddleName=@MiddleName AND LastName=@LastName)  
     BEGIN  
      RAISERROR('-500',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID and FirstName=@FirstName AND MiddleName=@MiddleName AND LastName=@LastName
      AND ContactID <> @ContactID )  
     BEGIN  
      RAISERROR('-500',16,1)       
     END  
    END  
   END  
  END

END
ELSE IF @FEATUREID=83  AND @CustomerID>0
BEGIN
 --DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
   BEGIN  
    IF @ContactID=0  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@CustomerID  and replace(FirstName,' ','')=replace(@FirstName,' ','') 
     AND replace(MiddleName,' ','')=replace(@MiddleName,' ','') AND replace(LastName,' ','')=replace(@LastName,' ','') )  
     BEGIN  
      RAISERROR('-500',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@CustomerID and
     replace(FirstName,' ','')=replace(@FirstName,' ','') 
     AND replace(MiddleName,' ','')=replace(@MiddleName,' ','') AND replace(LastName,' ','')=replace(@LastName,' ','')
      AND ContactID <> @ContactID )  
     BEGIN  
      RAISERROR('-500',16,1)       
     END  
    END  
   END  
   ELSE  
   BEGIN  
    IF @ContactID=0  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@CustomerID and FirstName=@FirstName AND
      MiddleName=@MiddleName AND LastName=@LastName)  
     BEGIN  
      RAISERROR('-500',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@CustomerID and FirstName=@FirstName AND MiddleName=@MiddleName AND LastName=@LastName
      AND ContactID <> @ContactID )  
     BEGIN  
      RAISERROR('-500',16,1)       
     END  
    END  
   END  
  END



END 
ELSE IF @FEATUREID=2  AND @ACCOUNTID>0
BEGIN
 --DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
   BEGIN  
    IF @ContactID=0  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@ACCOUNTID  and replace(FirstName,' ','')=replace(@FirstName,' ','') 
     AND replace(MiddleName,' ','')=replace(@MiddleName,' ','') AND replace(LastName,' ','')=replace(@LastName,' ','') )  
     BEGIN  
      RAISERROR('-500',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@ACCOUNTID and
     replace(FirstName,' ','')=replace(@FirstName,' ','') 
     AND replace(MiddleName,' ','')=replace(@MiddleName,' ','') AND replace(LastName,' ','')=replace(@LastName,' ','')
      AND ContactID <> @ContactID )  
     BEGIN  
      RAISERROR('-500',16,1)       
     END  
    END  
   END  
   ELSE  
   BEGIN  
    IF @ContactID=0  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@ACCOUNTID and FirstName=@FirstName AND
      MiddleName=@MiddleName AND LastName=@LastName)  
     BEGIN  
      RAISERROR('-500',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContactID FROM COM_Contacts WITH(nolock) WHERE FeatureID=@FEATUREID AND FeaturePK=@ACCOUNTID and FirstName=@FirstName AND MiddleName=@MiddleName AND LastName=@LastName
      AND ContactID <> @ContactID )  
     BEGIN  
      RAISERROR('-500',16,1)       
     END  
    END  
   END  
  END



END

	IF(@ContactID=0)
	---New Insert of record
	BEGIN
	  --To Set Left,Right And Depth of Record  
    SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
    from COM_Contacts with(NOLOCK) where ContactID=@SelectedNodeID  
   
    --IF No Record Selected or Record Doesn't Exist  
    if(@SelectedIsGroup is null)   
     select @SelectedNodeID=@ContactID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
     from COM_Contacts with(NOLOCK) where ParentID =0  
         
    if(@SelectedIsGroup = 1)--Adding Node Under the Group  
     BEGIN  
      UPDATE COM_Contacts SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
      UPDATE COM_Contacts SET lft = lft + 2 WHERE lft > @Selectedlft;  
      set @lft =  @Selectedlft + 1  
      set @rgt = @Selectedlft + 2  
      set @ParentID = @SelectedNodeID  
      set @Depth = @Depth + 1  
     END  
    else if(@SelectedIsGroup = 0)--Adding Node at Same level  
     BEGIN  
      UPDATE COM_Contacts SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
      UPDATE COM_Contacts SET lft = lft + 2 WHERE lft > @Selectedrgt;  
      set @lft =  @Selectedrgt + 1  
      set @rgt = @Selectedrgt + 2   
     END  
    else  --Adding Root  
     BEGIN  
      set @lft =  1  
      set @rgt = 2   
      set @Depth = 0  
      set @ParentID =0  
      set @IsGroup=1  
     END  
  
  end
	 	 if (@ContactID=0)
		 BEGIN
		 INSERT INTO COM_Contacts (FeatureID,FeaturePK, AddressTypeID, ContactTypeID,StatusId,Depth,ParentID,lft,
				 rgt,IsGroup,CompanyGUID,GUID,CreatedBy,CreatedDate)
				 Values (@FEATUREID,@FEATURENODEID,2,54,@StatusID, @Depth, @SelectedNodeID,@lft,
				 @rgt,@IsGroup,@CompanyGUID,newid(),@UserName,convert(float,getdate()))

			--To get inserted record primary key  
				  SET @ContactID=SCOPE_IDENTITY() 
			--Insert into COM_ContactsExtended table
			 INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 	VALUES(@ContactID, @UserName, convert(float,getdate()))
			 
			 INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
			   VALUES(65,@ContactID,newid(),  @UserName, @Dt)  
		END
		
		IF(NOT EXISTS (SELECT * FROM COM_ContactsExtended WHERE ContactID=@ContactID))
		INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 	VALUES(@ContactID, @UserName, convert(float,getdate()))


	IF(NOT EXISTS (SELECT * FROM COM_CCCCDATA WHERE [CostCenterID]=65 AND [NodeID]=@ContactID))
		 INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
			   VALUES(65,@ContactID,newid(),  @UserName, @Dt)  


 
		IF @FromConvert=0
		BEGIN
		update COM_Contacts 
			set FirstName=x.value('@FirstName','NVARCHAR(500)'),
				MiddleName=X.value('@MiddleName','NVARCHAR(500)'),  
				LastName=X.value('@LastName','NVARCHAR(500)'),  
				SalutationID=X.value('@SalutationID','INT'),  
				JobTitle=X.value('@JobTitle','NVARCHAR(500)'),  
				Company=X.value('@Company','NVARCHAR(500)'),  
				Phone1=X.value('@Phone1','NVARCHAR(50)'),  
				Phone2=X.value('@Phone2','NVARCHAR(50)'),  
				Email1=X.value('@Email','NVARCHAR(50)'),  
				Fax=X.value('@Fax','NVARCHAR(50)'),  
				Department=X.value('@Department','NVARCHAR(50)'),  
				RoleLookupID=X.value('@RoleLookup','INT'), 
				Address1=X.value('@Address1','NVARCHAR(500)'),  
				Address2=X.value('@Address2','NVARCHAR(500)'),  
				Address3=X.value('@Address3','NVARCHAR(500)'),  
				City=X.value('@City','NVARCHAR(100)'),  
				State=X.value('@State','NVARCHAR(100)'),  
				Zip=X.value('@Zip','NVARCHAR(50)'),  
				Country=X.value('@Country','int'),  
				Gender=X.value('@Gender','nvarchar(10)'),
				Birthday=convert(float,X.value('@BirthDay','DATETIME')),
				Anniversary=convert(float,X.value('@Anniversary','DATETIME')),
				PreferredID = X.value('@PreferredID','int'),  
				PreferredName=X.value('@PreferredName','NVARCHAR(50)'),  
				IsEmailOn=X.value('@IsEmailon','bit'),
				IsBulkEMailOn=X.value('@IsBulkEmailOn','bit'),
				IsMailOn=X.value('@IsMailon','bit'),
				IsPhoneOn=X.value('@IsPhoneon','bit'),
				IsFaxOn=X.value('@IsFaxon','bit'),
				IsVisible=1,  
				ModifiedBy=@UserName,   
				ModifiedDate=@Dt  
			    FROM COM_Contacts C   
			    INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
			    ON ContactID =@ContactID   
		END
		ELSE
		BEGIN
		update COM_Contacts 
			set FirstName=x.value('@FirstName','NVARCHAR(500)'),
				MiddleName=X.value('@MiddleName','NVARCHAR(500)'),  
				LastName=X.value('@LastName','NVARCHAR(500)'),  
				SalutationID=X.value('@SalutationID','INT'),  
				JobTitle=X.value('@JobTitle','NVARCHAR(500)'),  
				Company=X.value('@Company','NVARCHAR(500)'),  
				Phone1=X.value('@Phone1','NVARCHAR(50)'),  
				Phone2=X.value('@Phone2','NVARCHAR(50)'),  
				Email1=X.value('@Email','NVARCHAR(50)'),  
				Fax=X.value('@Fax','NVARCHAR(50)'),  
				Department=X.value('@Department','NVARCHAR(50)'),  
				RoleLookupID=X.value('@RoleLookup','INT'), 
				Address1=X.value('@Address1','NVARCHAR(500)'),  
				Address2=X.value('@Address2','NVARCHAR(500)'),  
				Address3=X.value('@Address3','NVARCHAR(500)'),  
				City=X.value('@City','NVARCHAR(100)'),  
				State=X.value('@State','NVARCHAR(100)'),  
				Zip=X.value('@Zip','NVARCHAR(50)'),  
				Country=X.value('@Country','int'),  
				Gender=X.value('@Gender','nvarchar(10)'),
				Birthday=convert(float,X.value('@BirthDay','DATETIME')),
				Anniversary=convert(float,X.value('@Anniversary','DATETIME')),
				PreferredID = X.value('@PreferredID','int'),  
				PreferredName=X.value('@PreferredName','NVARCHAR(50)'),  
				IsEmailOn=X.value('@IsEmailon','bit'),
				IsBulkEMailOn=X.value('@IsBulkEmailOn','bit'),
				IsMailOn=X.value('@IsMailon','bit'),
				IsPhoneOn=X.value('@IsPhoneon','bit'),
				IsFaxOn=X.value('@IsFaxon','bit'),
				IsVisible=1,  
				ModifiedBy=@UserName,   
				ModifiedDate=@Dt  
			    FROM COM_Contacts C   
			    INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
			    ON ContactID =@ContactID   AND AddressTypeID=2
		END	
				set @UpdateSql='update COM_ContactsExtended
				SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName
				+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE ContactID='+convert(nvarchar,@ContactID)
				exec(@UpdateSql)
				
				
				set @UpdateSql='UPDATE COM_CCCCDATA
				SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@ContactID) + ' AND CostCenterID = 65'
				exec(@UpdateSql)
			--Inserts Multiple Attachments
		IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
		BEGIN
			SET @XML=@AttachmentsXML

			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
			FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,
			GUID,CreatedBy,CreatedDate)
			SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),
			X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),65,65,@ContactID,
			X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt
			FROM @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
			WHERE X.value('@Action','NVARCHAR(10)')='NEW'

			--If Action is MODIFY then update Attachments
			UPDATE COM_Files
			SET FilePath=X.value('@FilePath','NVARCHAR(500)'),
				ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),
				RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),
				FileExtension=X.value('@FileExtension','NVARCHAR(50)'),
				FileDescription=X.value('@FileDescription','NVARCHAR(500)'),
				IsProductImage=X.value('@IsProductImage','bit'),						
				GUID=X.value('@GUID','NVARCHAR(50)'),
				ModifiedBy=@UserName,
				ModifiedDate=@Dt
			FROM COM_Files C 
			INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
			ON convert(bigint,X.value('@AttachmentID','bigint'))=C.FileID
			WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'

			--If Action is DELETE then delete Attachments
			DELETE FROM COM_Files
			WHERE FileID IN(SELECT X.value('@AttachmentID','bigint')
				FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)
				WHERE X.value('@Action','NVARCHAR(10)')='DELETE')
  
					 
END
IF @ActivityXml <>'' AND @ActivityXml IS NOT NULL
BEGIN 

exec spCom_SetActivitiesAndSchedules @ActivityXml,65,@ContactID,@CompanyGUID,@Guid,@UserName,@dt,@LangID 

END	
	--Inserts Multiple Notes
		IF (@NotesXML IS NOT NULL AND @NotesXML <> '')
		BEGIN
			SET @XML=@NotesXML

			--If Action is NEW then insert new Notes
			INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,			
			GUID,CreatedBy,CreatedDate)
			SELECT 65,65,@ContactID,Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),  
			newid(),@UserName,@Dt
			FROM @XML.nodes('/NotesXML/Row') as Data(X)
			WHERE X.value('@Action','NVARCHAR(10)')='NEW'

			--If Action is MODIFY then update Notes
			UPDATE COM_Notes
			SET Note=Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),  
				GUID=newid(),
				ModifiedBy=@UserName,
				ModifiedDate=@Dt
			FROM COM_Notes C 
			INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X) 	
			ON convert(bigint,X.value('@NoteID','bigint'))=C.NoteID
			WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'

			--If Action is DELETE then delete Notes
			DELETE FROM COM_Notes
			WHERE NoteID IN(SELECT X.value('@NoteID','bigint')
				FROM @XML.nodes('/NotesXML/Row') as Data(X)
				WHERE X.value('@Action','NVARCHAR(10)')='DELETE')

		END
				
			IF @ACCOUNTID>0
			BEGIN
				UPDATE COM_Contacts  SET FeatureID=2,FeaturePK=@ACCOUNTID WHERE ContactID=@ContactID
			END	
 			IF @CustomerID>0
			BEGIN
				UPDATE COM_Contacts  SET FeatureID=83,FeaturePK=@CustomerID WHERE ContactID=@ContactID
			END	
			IF @CustomerID>0 AND @ACCOUNTID>0
				UPDATE COM_Contacts  SET FeatureID=65,FeaturePK=0 WHERE ContactID=@ContactID
				
			  IF  (@AssignCCCCData IS NOT NULL AND @AssignCCCCData <> '')   
			  BEGIN  
			  DECLARE @CCCCCData XML
				SET @CCCCCData=@AssignCCCCData  
				EXEC [spCOM_SetCCCCMap] 65,@ContactID,@CCCCCData,@UserName,@LangID  
			  END  	 
  --ROLLBACK TRANSACTION
  COMMIT TRANSACTION    

--SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @ContactID    
END TRY    
BEGIN CATCH    
-- Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
 -- SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
