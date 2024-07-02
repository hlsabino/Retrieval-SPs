USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetBatchDetails]
	@DocumentID [bigint],
	@Filter [nvarchar](max),
	@CompanyGUID [nvarchar](max),
	@UserID [bigint] = 1,
	@UserName [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON

	declare @DT float
	
	set @DT=convert(float,getdate())
	
	if not exists (select * from  ADM_BatchDefinition where DocumentID=@DocumentID)                                                                    
	BEGIN
		insert into ADM_BatchDefinition (DocumentID,Filter,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
		values (@DocumentID,@Filter,@CompanyGUID,newid(),NULL,@UserID,@DT,@UserName,@DT)
		
	END
	else
	BEGIN
		update ADM_BatchDefinition
		set Filter=@Filter,CreatedBy=@UserID,CreatedDate=@DT,ModifiedBy=@UserName,ModifiedDate=@DT
		where DocumentID=@DocumentID
	END
	
COMMIT TRANSACTION
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID 
RETURN @DocumentID
END TRY
BEGIN CATCH  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH 

GO
