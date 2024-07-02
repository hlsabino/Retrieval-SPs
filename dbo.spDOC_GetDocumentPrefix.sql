USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocumentPrefix]
	@CostCenterID [int],
	@Locations [nvarchar](500) = NULL,
	@Divisions [nvarchar](500) = NULL,
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
		  --Declaration Section
		DECLARE @HasAccess BIT,@Sql nvarchar(max),@Series bigint,@ConCCID bigint,@DType bigint  

		--SP Required Parameters Check
		IF @CostCenterID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)
		 
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		SELECT @Series=Series,@ConCCID=ConvertAs,@DType=DocumentType FROM  ADM_DocumentTypes  WITH(NOLOCK)  where CostCenterID=@CostCenterID    

			--GETTING DOCUMENT PREFIX

		set @Sql='SELECT CodePrefix,CodeNumberLength,CurrentCodeNumber+CodeNumberInc,isnull(CurrentCodeNumber,0)+1 NextNumber
		FROM COM_CostCenterCodeDef WITH(NOLOCK) WHERE CostCenterID='
		  if((@DType=14 or @DType=19) and @Series=1 and @ConCCID is not null and  @ConCCID>0)--alternate series     
		  begin  set @Sql=@Sql+convert(nvarchar,@ConCCID)    end  
			else if(@Series>0)     
		  begin set @Sql=@Sql+convert(nvarchar,@Series) end  
   			else     
		  begin set @Sql=@Sql+convert(nvarchar,@CostCenterID) end  
   
		if(@Locations is not null and @Locations<>'')
			set @Sql=@Sql+' and Location in ('+@Locations+')'
		if(@Divisions is not null and @Divisions<>'')
			set @Sql=@Sql+' and Division in ('+@Divisions+')'
		print @Sql
		exec(@Sql)
 
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH





GO
