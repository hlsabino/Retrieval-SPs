USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetContact]
	@CostCenterID [int],
	@NodeID [bigint],
	@ContactID [bigint],
	@ContactQuery [nvarchar](max),
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
          
	--Declaration Section    
	DECLARE @ContactQueryXML XML,@IsDuplicateNameAllowed bit,@FirstName nvarchar(300),@MiddleName nvarchar(300),@LastName nvarchar(300), @ExtraFields nvarchar(max),@UpdateSql NVARCHAR(MAX), @CCFields nvarchar(max),@PrimaryContactID int,@Dt float=null

	SET @ContactQueryXML=@ContactQuery
	DECLARE @CONTACTSTABLE TABLE(ID INT IDENTITY(1,1),ACTIONNAME NVARCHAR(300),CONTACTTYPE INT,CONTACTID INT,STATICIFLEDS NVARCHAR(MAX),ALPHAFIELDS NVARCHAR(MAX),
	CCFIELDS NVARCHAR(MAX))
 
	set @Dt=convert(float,getdate())
 	  
		 IF @ContactID=0
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
						
						SET @ContactID=SCOPE_IDENTITY()
						INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 			VALUES(@ContactID, @UserName, convert(float,getdate()))
			 						
			 			INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
						VALUES(65,@ContactID,newid(),  @UserName, @Dt)  
		END	 						
		 
		SELECT @ContactQuery=X.value('@StaticFields','NVARCHAR(max)') ,@ExtraFields=X.value('@ExtraTextFields','NVARCHAR(max)'),
		@CCFields=X.value('@CCFields','NVARCHAR(max)')   from @ContactQueryXML.nodes('/Data/Row') as Data(X)
	   
	  
	   IF (@ContactQuery IS NOT NULL AND @ContactQuery <> '')  
	   BEGIN 
		set @UpdateSql='update [COM_Contacts]  
		SET '+@ContactQuery+',[ModifiedBy] ='''+ @UserName  
		+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ContactID='+convert(nvarchar,@ContactID)     
		 
		exec(@UpdateSql) 
		 
	  end	
	  
	   IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
	   BEGIN 
		set @UpdateSql='update COM_ContactsExtended
		SET '+@ExtraFields+', [ModifiedBy] ='''+ @UserName
		+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE ContactID ='+convert(nvarchar,@ContactID)	
		exec(@UpdateSql)
		 
		END
		
		 IF (@CCFields IS NOT NULL AND @CCFields <> '')  
	    BEGIN 
			set @UpdateSql='UPDATE COM_CCCCDATA
			SET '+@CCFields+',[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
			WHERE NodeID='+convert(nvarchar,@ContactID)+'  AND CostCenterID = 65'
			exec(@UpdateSql)
		END
		 
  
COMMIT TRANSACTION     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  

SET NOCOUNT OFF;      
RETURN  @ContactID    
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
