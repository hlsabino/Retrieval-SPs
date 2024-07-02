USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_SetDeprBook]
	@DeprBookID [bigint],
	@DeprBookCode [nvarchar](200),
	@DeprBookName [nvarchar](500),
	@DeprBookMethod [int],
	@DeprMethodBasedOn [int],
	@DeprMethodBasedOnValue [float],
	@StatusID [int],
	@AveragingMethod [int],
	@SalvType [int],
	@SalvValue [float],
	@IncludeSalv [bit],
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

		IF @DeprBookID=0  
		BEGIN  
			IF EXISTS (SELECT @DeprBookID FROM [ACC_DeprBook] WITH(nolock) WHERE replace(DeprBookCode,' ','')=replace(@DeprBookCode,' ',''))  
			BEGIN  
				RAISERROR('-116',16,1)  
			END  
			IF EXISTS (SELECT @DeprBookID FROM [ACC_DeprBook] WITH(nolock) WHERE replace(DeprBookName,' ','')=replace(@DeprBookName,' ',''))  
			BEGIN  
				RAISERROR('-112',16,1)  
			END  
				
		END
		ELSE
		BEGIN  
			IF EXISTS (SELECT @DeprBookID FROM [ACC_DeprBook] WITH(nolock) WHERE replace(DeprBookCode,' ','')=replace(@DeprBookCode,' ','') AND DeprBookID<> @DeprBookID)  
			BEGIN  
				RAISERROR('-116',16,1)  
			END  
			IF EXISTS (SELECT @DeprBookID FROM [ACC_DeprBook] WITH(nolock) WHERE replace(DeprBookName,' ','')=replace(@DeprBookName,' ','') AND DeprBookID<> @DeprBookID)  
			BEGIN  
				RAISERROR('-112',16,1)  
			END  
				
		END
		IF @DeprBookID=0--------START INSERT RECORD-----------
		BEGIN--CREATE DeprBook  
				-- Insert statements for procedure here
				
				INSERT INTO [ACC_DeprBook]
							([DeprBookCode] ,
							[DeprBookName] ,
							[DeprBookMethod],DeprMethodBasedOn,BasedOnValue,
							[StatusID],
							[AveragingMethod],SalvageValueType,SalvageValue,IncludeSalvageInDepr,
							[CompanyGUID],
							[GUID],
							[CreatedBy],
							[CreatedDate])
							VALUES
							(@DeprBookCode,
							@DeprBookName,
							@DeprBookMethod,@DeprMethodBasedOn,@DeprMethodBasedOnValue,
							@StatusID,
							@AveragingMethod,@SalvType,@SalvValue,@IncludeSalv,
						 	@CompanyGUID,
							newid(),
							@UserName,
							@Dt)
				SET @DeprBookID=SCOPE_IDENTITY()
				--To get inserted record primary key
		END--------END INSERT RECORD-----------
		ELSE--------START UPDATE RECORD-----------
		BEGIN	
	 
			SELECT @TempGuid=[GUID] from [ACC_DeprBook]  WITH(NOLOCK) 
			WHERE DeprBookID=@DeprBookID

			IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ  
			BEGIN  
				   RAISERROR('-101',16,1)	
			END  
			ELSE  
			BEGIN 
			UPDATE [ACC_DeprBook]
				   SET [DeprBookCode] = @DeprBookCode
					  ,[DeprBookName] = @DeprBookName
					  ,[DeprBookMethod] = @DeprBookMethod
					  ,DeprMethodBasedOn=@DeprMethodBasedOn
					  ,BasedOnValue=@DeprMethodBasedOnValue
					  ,[StatusID] = @StatusID
					  ,[AveragingMethod]=@AveragingMethod
					  ,SalvageValueType=@SalvType,SalvageValue=@SalvValue,IncludeSalvageInDepr=@IncludeSalv
					  ,[ModifiedBy] = @UserName
					  ,[ModifiedDate] = @Dt
				 WHERE DeprBookID=@DeprBookID
			END
		END

COMMIT TRANSACTION  
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
RETURN @DeprBookID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [ACC_DeprBook] WITH(nolock) WHERE DeprBookID=@DeprBookID  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
