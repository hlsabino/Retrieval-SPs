USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_SetAssetClass]
	@AssetClassID [bigint],
	@AssetClassCode [nvarchar](200),
	@AssetClassName [nvarchar](500),
	@FAAccountsID [bigint],
	@DeprBookID [bigint],
	@DeprPosting [int],
	@TotalYears [float],
	@StatusID [int],
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@Description [nvarchar](500),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section
		DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@HasAccess bit
		--User acces check FOR Customer 

		SET @Dt=convert(float,getdate())--Setting Current Date
		IF @AssetClassID=0  
		BEGIN  
			if(replace(@AssetClassName,' ','')='')
				RAISERROR('-112',16,1)  
			IF EXISTS (SELECT @AssetClassID FROM [ACC_AssetClass] WITH(nolock) WHERE replace(AssetClassName,' ','')=replace(@AssetClassName,' ','')    )
				RAISERROR('-112',16,1)  
			IF EXISTS (SELECT @AssetClassID FROM [ACC_AssetClass] WITH(nolock) WHERE replace(AssetClassCode,' ','')=replace(@AssetClassCode,' ',''))  
				RAISERROR('-116',16,1)  
		END
		ELSE
		BEGIN  
			IF EXISTS (SELECT @AssetClassID FROM [ACC_AssetClass] WITH(nolock) WHERE replace(AssetClassName,' ','')=replace(@AssetClassName,' ','') and AssetClassID <>@AssetClassID)
				RAISERROR('-112',16,1)  
			IF EXISTS (SELECT @AssetClassID FROM [ACC_AssetClass] WITH(nolock) WHERE replace(AssetClassCode,' ','')=replace(@AssetClassCode,' ','')   and AssetClassID <>@AssetClassID)
				RAISERROR('-116',16,1)  
		END
				   
		IF @AssetClassID=0--------START INSERT RECORD-----------
		BEGIN--CREATE Asset Class
			-- Insert statements for procedure here
			INSERT INTO [ACC_AssetClass]
					([AssetClassCode] ,
					[AssetClassName] ,
					FAAccountsID,DeprBookID,DeprPosting,TotalYears,
					[StatusID],
					[CompanyGUID],
					[GUID],
					[CreatedBy],
					[CreatedDate])
					VALUES
					(@AssetClassCode,
					@AssetClassName,
					@FAAccountsID,@DeprBookID,@DeprPosting,@TotalYears,
					@StatusID,
				 	@CompanyGUID,
					newid(),
					@UserName,
					@Dt) 
			SET @AssetClassID=SCOPE_IDENTITY()
			--To get inserted record primary key

    
		END--------END INSERT RECORD-----------
		ELSE--------START UPDATE RECORD-----------
		BEGIN	
			SELECT @TempGuid=[GUID] from [ACC_AssetClass]  WITH(NOLOCK) 
			WHERE AssetClassID=@AssetClassID

			IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ  
			BEGIN  
				RAISERROR('-101',16,1)	
			END  
			ELSE  
			BEGIN 
		 		UPDATE [ACC_AssetClass]
				SET [AssetClassCode] = @AssetClassCode
					  ,[AssetClassName] = @AssetClassName
					  ,FAAccountsID=@FAAccountsID,DeprBookID=@DeprBookID,DeprPosting=@DeprPosting,TotalYears=@TotalYears
					  ,[StatusID] = @StatusID
					  ,[ModifiedBy] = @UserName
					  ,[ModifiedDate] = @Dt
				 WHERE AssetClassID=@AssetClassID
			END
		END

COMMIT TRANSACTION  
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
RETURN @AssetClassID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [ACC_AssetClass] WITH(nolock) WHERE AssetClassID=@AssetClassID  
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
