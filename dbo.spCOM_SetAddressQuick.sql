USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetAddressQuick]
	@CostCenterID [int],
	@NodeID [bigint],
	@AddressXML [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
          
	--Declaration Section    
	DECLARE @HasAccess BIT,@AddressID BIGINT,@XML XML, @Dt FLOAT 
	IF (@AddressXML IS NOT NULL AND @AddressXML <> '')  
	BEGIN  
		SET @Dt=CONVERT(FLOAT,GETDATE())
		SET @XML=@AddressXML  
		DECLARE @ContactQueryXML XML,@ExtraFields nvarchar(max),@UpdateSql NVARCHAR(MAX), @CCFields nvarchar(max)
		SET @ContactQueryXML=@AddressXML
		DECLARE @CONTACTSTABLE TABLE(ID INT IDENTITY(1,1),ACTIONNAME NVARCHAR(300),CONTACTTYPE INT,CONTACTID INT,STATICIFLEDS NVARCHAR(MAX),ALPHAFIELDS NVARCHAR(MAX),
		CCFIELDS NVARCHAR(MAX))	
		DECLARE @COUNT INT,@I INT,@ACTION NVARCHAR(300),@CONTACTID INT,@TEMPCONTACTTYPE INT,@IsPrimarAddressFound BIT
		INSERT INTO @CONTACTSTABLE
		SELECT X.value('@Action','NVARCHAR(30)') ,ISNULL(X.value('@AddressTypeID','NVARCHAR(300)'),0),ISNULL(X.value('@AddressID','NVARCHAR(300)'),0) ,X.value('@StaticFields','NVARCHAR(max)') ,X.value('@ExtraTextFields','NVARCHAR(max)'),
		X.value('@CCFields','NVARCHAR(max)')   from @ContactQueryXML.nodes('/Data/Row') as Data(X)
		SELECT @COUNT=COUNT(*),@I=1,@IsPrimarAddressFound=0 FROM @CONTACTSTABLE
	 
		SELECT @ACTION=ACTIONNAME,@TEMPCONTACTTYPE=CONTACTTYPE,@CONTACTID=CONTACTID,@AddressXML=STATICIFLEDS ,@ExtraFields=ALPHAFIELDS,
		@CCFields=CCFIELDS FROM @CONTACTSTABLE WHERE ID=1
		--SELECT @TEMPCONTACTTYPE,@ACTION,@CONTACTID,@AddressXML,@ExtraFields,@CCFields
		IF @TEMPCONTACTTYPE=1
		BEGIN
		IF @IsPrimarAddressFound=0
		BEGIN
			IF @ACTION!='DELETE'
				SET @IsPrimarAddressFound=1
		END
		ELSE
		BEGIN
			SET @TEMPCONTACTTYPE=2
		END
		END 
		--SELECT @ACTION,@CONTACTID,@ContactQuery,@ExtraFields,@CCFields  
		INSERT INTO COM_Address(AddressTypeID,FeatureID,FeaturePK,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		VALUES (@TEMPCONTACTTYPE,@CostCenterID,@NodeID,NEWID(),NEWID(),@UserName,@Dt)
		SET @AddressID=SCOPE_IDENTITY()

		IF (@AddressXML IS NOT NULL AND @AddressXML <> '')  
		BEGIN    
			set @UpdateSql='update [COM_Address]  
			SET '+@AddressXML+',[ModifiedBy] ='''+ @UserName  
			+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE AddressID='+convert(nvarchar,@AddressID)     
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

		INSERT INTO COM_Address_History 
		SELECT * FROM COM_Address with(nolock)
		WHERE FeatureID=@CostCenterID AND FeaturePK=@NodeID
	END 
	  
COMMIT TRANSACTION     
SET NOCOUNT OFF;      
RETURN  @AddressID
Select AddressID, AddressName from com_address with(nolock) where ADDRESSID=@AddressID
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
