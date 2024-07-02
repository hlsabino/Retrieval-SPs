USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetFeatureWiseContacts]
	@CostCenterID [int],
	@NodeID [bigint],
	@ContactType [int] = 0,
	@ContactQuery [nvarchar](max),
	@UserName [nvarchar](50),
	@Dt [float] = null,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
          
	--Declaration Section    
	DECLARE @ContactQueryXML XML,@IsDuplicateNameAllowed bit,@FirstName nvarchar(300),@MiddleName nvarchar(300),@LastName nvarchar(300), @ExtraFields nvarchar(max),@UpdateSql NVARCHAR(MAX), @CCFields nvarchar(max),@PrimaryContactID int 
	SET @ContactQueryXML=@ContactQuery
	DECLARE @CONTACTSTABLE TABLE(ID INT IDENTITY(1,1),ACTIONNAME NVARCHAR(300),CONTACTTYPE INT,CONTACTID INT,STATICIFLEDS NVARCHAR(MAX),ALPHAFIELDS NVARCHAR(MAX),
	CCFIELDS NVARCHAR(MAX))
 
 	SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE CostCenterID=65 and  Name='DuplicateNameAllowed'
 	 
	IF @ContactType=1 --FOR PRIMARY CONTACT
	BEGIN
		SELECT @PrimaryContactID=ISNULL(CONTACTID,0) FROM COM_Contacts WITH(NOLOCK) WHERE 
		FEATUREID=@CostCenterID AND [AddressTypeID] = 1 AND [FeaturePK]=@NodeID  
		IF @PrimaryContactID IS NULL OR @PrimaryContactID=''
		SET @PrimaryContactID=0
		
		 IF @PrimaryContactID=0
		 BEGIN
				INSERT  [COM_Contacts]  
						([AddressTypeID]  
						,[FeatureID]  
						,[FeaturePK]  
						,[CompanyGUID]  
						,[GUID]   
						,[CreatedBy]  
						,[CreatedDate]  
						)  
						VALUES  
						(1
						,@CostCenterID  
						,@NodeID  
						,NEWID()  
						,NEWID()  
						,@UserName,@Dt  
						)  
						SET @PrimaryContactID=SCOPE_IDENTITY()
						INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 						VALUES(@PrimaryContactID, @UserName, convert(float,getdate()))
		END	 						
		DELETE FROM  COM_CCCCDATA WHERE NodeID=@PrimaryContactID  AND  CostCenterID = 65

		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
		VALUES(65,@PrimaryContactID,newid(),  @UserName, @Dt)  
	     
	  
		SELECT @ContactQuery=X.value('@StaticFields','NVARCHAR(max)') ,@ExtraFields=X.value('@ExtraTextFields','NVARCHAR(max)'),
		@CCFields=X.value('@CCFields','NVARCHAR(max)')   from @ContactQueryXML.nodes('/Data/Row') as Data(X)
	   
	   IF (@ContactQuery IS NOT NULL AND @ContactQuery <> '')  
	   BEGIN 
		set @UpdateSql='update [COM_Contacts]  
		SET '+@ContactQuery+',[ModifiedBy] ='''+ @UserName  
		+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ContactID='+convert(nvarchar,@PrimaryContactID)     
		--SELECT @UpdateSql 
		exec(@UpdateSql) 
		--PRINT @UpdateSql
	  end	
	  
	   IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
	   BEGIN 
		set @UpdateSql='update COM_ContactsExtended
		SET '+@ExtraFields+', [ModifiedBy] ='''+ @UserName
		+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE ContactID ='+convert(nvarchar,@PrimaryContactID)	
		exec(@UpdateSql)
		--PRINT @UpdateSql
		END
		
		 IF (@CCFields IS NOT NULL AND @CCFields <> '')  
	    BEGIN 
			set @UpdateSql='UPDATE COM_CCCCDATA
			SET '+@CCFields+',[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
			WHERE NodeID='+convert(nvarchar,@PrimaryContactID)+'  AND CostCenterID = 65'
			exec(@UpdateSql)
		END
		--PRINT @UpdateSql 
		
		--DUPLICATE CHECK
		IF(@PrimaryContactID>0)
		BEGIN
			   IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
			   BEGIN
					SELECT @FirstName=FirstName,@MiddleName=MiddleName,@LastName=LastName FROM COM_Contacts
					WITH(NOLOCK) WHERE ContactID=@PrimaryContactID
					
				
					
					IF(SELECT ISNULL(COUNT(*),0) FROM COM_Contacts WHERE ContactID<>@PrimaryContactID AND 
					@FirstName=FirstName AND @MiddleName=MiddleName AND @LastName=LastName AND [FeatureID]=@CostCenterID AND FeaturePK=@NodeID)>0
					BEGIN
						 
						--ROLLBACK TRANSACTION  
						 RETURN -1000 
						 
					END
				END	
					
		END
		
		
		
		
	END
	ELSE IF @ContactType=2
	BEGIN 
		DECLARE @COUNT INT,@I INT,@ACTION NVARCHAR(300),@CONTACTID INT,@TEMPCONTACTTYPE INT		
		INSERT INTO @CONTACTSTABLE
		SELECT X.value('@Action','NVARCHAR(30)') ,ISNULL(X.value('@AddressTypeID','NVARCHAR(300)'),0),ISNULL(X.value('@ContactID','NVARCHAR(300)'),0) ,X.value('@StaticFields','NVARCHAR(max)') ,X.value('@ExtraTextFields','NVARCHAR(max)'),
		X.value('@CCFields','NVARCHAR(max)')   from @ContactQueryXML.nodes('/Data/Row') as Data(X)
		SELECT @COUNT=COUNT(*),@I=1 FROM @CONTACTSTABLE
	
		WHILE @I<=@COUNT
		BEGIN
		
			SELECT @ACTION=ACTIONNAME,@TEMPCONTACTTYPE=CONTACTTYPE,@CONTACTID=CONTACTID,@ContactQuery=STATICIFLEDS ,@ExtraFields=ALPHAFIELDS,
			@CCFields=CCFIELDS FROM @CONTACTSTABLE WHERE ID=@I
				--SELECT @ACTION,@CONTACTID,@ContactQuery,@ExtraFields,@CCFields 
				IF @ACTION='NEW' AND (@CONTACTID=0 OR @CONTACTID IS NULL)
				BEGIN
						   --INSERT SECONDARY CONTACT  
						INSERT  [COM_Contacts]  
						([AddressTypeID]  
						,[FeatureID]  
						,[FeaturePK]  
						,[CompanyGUID]  
						,[GUID]   
						,[CreatedBy]  
						,[CreatedDate]  
						)  
						VALUES  
						(2  
						,@CostCenterID  
						,@NodeID  
						,NEWID()  
						,NEWID()  
						,@UserName,@Dt  
						)  
						SET @PrimaryContactID=SCOPE_IDENTITY()
						INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 						VALUES(@PrimaryContactID, @UserName, convert(float,getdate()))

						INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
						VALUES(65,@PrimaryContactID,newid(),  @UserName, @Dt)  
					      
					     SET @CONTACTID=@PrimaryContactID
					     IF (@ContactQuery IS NOT NULL AND @ContactQuery <> '')  
						 BEGIN    
						set @UpdateSql='update [COM_Contacts]  
						SET '+@ContactQuery+',[ModifiedBy] ='''+ @UserName  
						+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ContactID='+convert(nvarchar,@PrimaryContactID)     
						--SELECT @UpdateSql 
						exec(@UpdateSql) 
						--PRINT @UpdateSql
						END
						 IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
						BEGIN 
						set @UpdateSql='update COM_ContactsExtended
						SET '+@ExtraFields+', [ModifiedBy] ='''+ @UserName
						+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE ContactID ='+convert(nvarchar,@PrimaryContactID)	
						exec(@UpdateSql)
						--PRINT @UpdateSql
						END
						
						IF (@CCFields IS NOT NULL AND @CCFields <> '')  
						BEGIN 
						set @UpdateSql='UPDATE COM_CCCCDATA
						SET '+@CCFields+',[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
						WHERE NodeID='+convert(nvarchar,@PrimaryContactID)+'  AND CostCenterID = 65'
						exec(@UpdateSql)
						END
				END
				IF @ACTION='MODIFY' AND @CONTACTID>0
				BEGIN
					 	IF (@ContactQuery IS NOT NULL AND @ContactQuery <> '')  
						BEGIN 
						set @UpdateSql='update [COM_Contacts]  
						SET '+@ContactQuery+',[ModifiedBy] ='''+ @UserName  
						+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ContactID='+convert(nvarchar,@CONTACTID)     
						--SELECT @UpdateSql 
						exec(@UpdateSql) 
						--PRINT @UpdateSql
						END
						IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
						BEGIN 
						set @UpdateSql='update COM_ContactsExtended
						SET '+@ExtraFields+', [ModifiedBy] ='''+ @UserName
						+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE ContactID ='+convert(nvarchar,@CONTACTID)	
						exec(@UpdateSql)
						--PRINT @UpdateSql
						END
						
						IF (@CCFields IS NOT NULL AND @CCFields <> '')  
						BEGIN 
						set @UpdateSql='UPDATE COM_CCCCDATA
						SET '+@CCFields+',[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
						WHERE NodeID='+convert(nvarchar,@CONTACTID)+'  AND CostCenterID = 65'
						exec(@UpdateSql)
						END
				END
				IF @ACTION='DELETE' AND @CONTACTID>0
				BEGIN 
					DELETE FROM COM_ContactsExtended WHERE ContactID=@CONTACTID
					DELETE FROM COM_Contacts WHERE ContactID=@CONTACTID
				END	
				
					IF (@ACTION='NEW' OR @ACTION='MODIFY') AND @TEMPCONTACTTYPE=1 --IF SOMEONE WANT TO UPDATE HIS SECONDARY CONTACT TO PRIMAY CONTACT
					BEGIN  
						IF(EXISTS(SELECT * FROM COM_CONTACTS WHERE [FeatureID]=@CostCenterID  AND [FeaturePK]=@NodeID AND [AddressTypeID]=1))
						BEGIN
							UPDATE COM_CONTACTS SET  [AddressTypeID]=2 WHERE [FeatureID]=@CostCenterID  AND [FeaturePK]=@NodeID AND [AddressTypeID]=1
							UPDATE COM_CONTACTS SET  [AddressTypeID]=1 WHERE ContactID=@CONTACTID 
						END  
					END
					
					--DUPLICATE CHECK
					IF(@CONTACTID>0)
					BEGIN 
						   IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
						   BEGIN
								SELECT @FirstName=FirstName,@MiddleName=MiddleName,@LastName=LastName FROM COM_Contacts
								WITH(NOLOCK) WHERE ContactID=@CONTACTID
							 
							 --SELECT * FROM COM_Contacts WHERE ContactID<>@CONTACTID AND 
								--@FirstName=FirstName AND @MiddleName=MiddleName AND @LastName=LastName AND [FeatureID]=@CostCenterID AND FeaturePK=@NodeID
								
								IF(SELECT ISNULL(COUNT(*),0) FROM COM_Contacts WHERE ContactID<>@CONTACTID AND 
								@FirstName=FirstName AND @MiddleName=MiddleName AND @LastName=LastName AND [FeatureID]=@CostCenterID AND FeaturePK=@NodeID)>0
								BEGIN  
								--	ROLLBACK TRANSACTION 
									SELECT 124
									RETURN -1000
								END
							END	
								
					END
		
		SET @I=@I+1
		END
	END
  
--COMMIT TRANSACTION     
 
SET NOCOUNT OFF;      
RETURN  1    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    

ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH    
    
    
GO
