USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetSameLevelCostCenter]
	@CostCenterId [int],
	@NodeID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON  
BEGIN TRY  
		--Declaration Section
		DECLARE @HasAccess BIT,@Table nvarchar(50),@SQL nvarchar(max),@strNodeID nvarchar(50),@strSelectedNodeID nvarchar(50)  

		--SP Required Parameters Check
		IF @CostCenterID=0 OR @NodeID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterId,5)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
	
		--To get costcenter table name
		SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId

		SET @strNodeID=convert(nvarchar,@NodeID)   
		
		SET @SQL=' 
		declare @ParentID bigint
		
		SELECT @ParentID=ParentID
		FROM ['+@Table+'] WITH(NOLOCK) WHERE NodeID='+@strNodeID+'   

		--Fetch left, right extent of Node along with width.  
		SELECT NodeID,Name
		FROM '+@Table+' WITH(NOLOCK) WHERE NodeID!='+@strNodeID+' and parentid=@ParentID' 
		
		EXEC(@SQL)  
  
COMMIT TRANSACTION 
SET NOCOUNT OFF;   
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=101 AND LanguageID=@LangID
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
