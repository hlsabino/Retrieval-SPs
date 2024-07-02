USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCostCenterType]
	@NodeID [bigint] = 0,
	@CCID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
	 
		--SP Required Parameters Check
		IF (@NodeID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		declare @TableName nvarchar(100), @SQL nvarchar(max)
		select @TableName=TableName from adm_Features where featureid=@CCID
		set @SQL='SELECT NodeID, Code FROM '+ @TableName+' WITH(NOLOCK) 	WHERE  NodeID='+convert(nvarchar,@NodeID)+' '
		exec (@SQL) 
	 set @SQL=''
		set @SQL='SELECT count(NodeID) ChildCount,isnull(max(CodeNumber),0)+1 NextNumber FROM '+ @TableName+' WITH(NOLOCK) 	WHERE ParentID='+convert(nvarchar,@NodeID)+' and isGroup=0'
		exec (@SQL)
		
			 

COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
