USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SaveMappingDimension]
	@CallType [int] = 0,
	@CostCenterID [int] = 0,
	@LinkXML [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@LANGID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;	 
	IF @CallType=0
	BEGIN
		if not exists(select * from com_costcenterpreferences WITH(NOLOCK) where costcenterid=@CostCenterID and Name='DIMCPRMapping')
			BEGIN
				insert into COM_CostCenterPreferences(CostCenterID,FeatureID,ResourceID,Name,Value,DefaultValue,CreatedBy,CreatedDate,GUID)
				  values(@CostCenterID,@CostCenterID,0,'DIMCPRMapping','','',@UserName,1,'GUID')
 			END
		UPDATE com_costcenterpreferences SET Value=@LinkXML,CreatedBy=@UserName where  costcenterid=@CostCenterID and Name='DIMCPRMapping'
	END
	ELSE IF @CallType=1
	BEGIN
		Select isnull(Value,'') as Value from  com_costcenterpreferences   WITH(NOLOCK)  where  costcenterid=@CostCenterID and Name='DIMCPRMapping'
	END


COMMIT TRANSACTION    
--ROLLBACK TRANSACTION
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	ROLLBACK TRANSACTION
	SET NOCOUNT OFF  
	RETURN -999   
END CATCH






GO
