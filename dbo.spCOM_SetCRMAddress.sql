USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCRMAddress]
	@CostCenterID [int],
	@NodeID [bigint],
	@AddressID [bigint],
	@AddressXML [nvarchar](max),
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
	DECLARE @XML XML, @Dt FLOAT,@UpdateSql nvarchar(max),@AddressTypeID NVARCHAR(300),@StatXML NVARCHAR(max),@ExtraFields NVARCHAR(max),@CCFields NVARCHAR(max),@IsDefault bit

	set @XML=@AddressXML
	set @Dt=convert(float,getdate())

		SELECT @AddressTypeID=ISNULL(X.value('@AddressTypeID','NVARCHAR(300)'),0),@StatXML=X.value('@StaticFields','NVARCHAR(max)') 
		,@ExtraFields=X.value('@ExtraTextFields','NVARCHAR(max)'),@CCFields=X.value('@CCFields','NVARCHAR(max)'),@IsDefault=isnull(X.value('@IsDefault','bit'),0)
		from @XML.nodes('/Data/Row') as Data(X)
		
		if @IsDefault=1
			update COM_Address set IsDefault=0 where FeatureID=@CostCenterID and FeaturePK=@NodeID and AddressTypeID=@AddressTypeID
		
			--SELECT @ACTION,@CONTACTID,@ContactQuery,@ExtraFields,@CCFields 
			IF(@AddressID=0)
			BEGIN
				INSERT INTO COM_Address(AddressTypeID,FeatureID,FeaturePK,IsDefault,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
				VALUES (@AddressTypeID,@CostCenterID,@NodeID,@IsDefault,NEWID(),NEWID(),@UserName,@Dt)
				SET @AddressID=SCOPE_IDENTITY()
			END	
			    IF (@StatXML IS NOT NULL AND @StatXML <> '')  
				BEGIN    
					set @UpdateSql='update [COM_Address]  
					SET '+@StatXML+',[ModifiedBy] ='''+ @UserName  
					+''',[ModifiedDate] =' + convert(nvarchar,@Dt)+',IsDefault='+convert(nvarchar,@IsDefault) +' WHERE AddressID='+convert(nvarchar,@AddressID)     
					--SELECT @UpdateSql 
					exec(@UpdateSql) 
					--PRINT @UpdateSql
				END
				
				IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
				BEGIN 
					set @UpdateSql='update COM_Address
					SET '+@ExtraFields+' WHERE AddressID ='+convert(nvarchar,@AddressID)	
					exec(@UpdateSql)
					--PRINT @UpdateSql
				END
				
				IF (@CCFields IS NOT NULL AND @CCFields <> '')  
				BEGIN 
					set @UpdateSql='UPDATE COM_Address
					SET '+@CCFields+' 
					WHERE AddressID='+convert(nvarchar,@AddressID)+''
					exec(@UpdateSql)
				END
			 
			
	 
COMMIT TRANSACTION     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  

SET NOCOUNT OFF;      
RETURN  @AddressID    
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
