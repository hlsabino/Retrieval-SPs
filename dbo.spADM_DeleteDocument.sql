USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteDocument]
	@CostCenterId [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

	--Declaration Section
	DECLARE @HasAccess BIT,@IsUserdefined BIT,@RowsDeleted int

	--User access check 
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,43,4)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END 

	if exists (select Costcenterid from ADM_DocumentTypes with(nolock) where Costcenterid=@CostCenterId and IsUserDefined=0)
	BEGIN
		RAISERROR('-121',16,1)
	END 
	
	if exists (select Value from COM_CostCenterPreferences with(nolock) where Value like '%'+convert(nvarchar,@CostCenterId)+'%')
	BEGIN
		DECLARE @ErrorMsg NVARCHAR(MAX)=''
		SELECT @ErrorMsg='Document used in "'+F.Name+'" Preferences'
		FROM COM_CostCenterPreferences CP WITH(NOLOCK)
		JOIN ADM_FEATURES F  WITH(NOLOCK) ON F.FEATUREID=CP.CostCenterId 
		WHERE CP.Value like '%'+convert(nvarchar,@CostCenterId)+'%'
		RAISERROR(@ErrorMsg,16,1)
	END 
	
	DECLARE @DocType int  , @DELCNT INT 
	SELECT @DocType =  IsInventory FROM ADM_DocumentTypes with(nolock) WHERE (CostCenterID = @CostCenterId)

	IF @DocType = 0
		SELECT @DELCNT = COUNT(DOCID)  FROM ACC_DOCDETAILS with(nolock) WHERE COSTCENTERID = @CostCenterId
	ELSE
		SELECT @DELCNT = COUNT(DOCID)  FROM INV_DOCDETAILS with(nolock) WHERE COSTCENTERID = @CostCenterId


		IF @DELCNT = 0 
		  BEGIN
			DELETE FROM ADM_FeatureActionRoleMap WHERE FeatureActionID IN
			(SELECT FeatureActionID FROM  ADM_FeatureAction with(nolock) WHERE FeatureID=@CostCenterId )
			DELETE FROM ADM_RIBBONVIEW  WHERE FEATUREID=@CostCenterId 
			DELETE FROM ADM_ListViewColumns WHERE   ListViewID IN (
			SELECT ListViewID FROM ADM_ListView with(nolock) WHERE COSTCENTERID=@CostCenterId )
			DELETE FROM ADM_ListView  WHERE FEATUREID=@CostCenterId 

			DELETE FROM COM_DocumentPreferences  WHERE COSTCENTERID=@CostCenterId 
			DELETE FROM ADM_DocumentDef  WHERE COSTCENTERID=@CostCenterId 
			DELETE FROM COM_Status  WHERE COSTCENTERID=@CostCenterId  
			DELETE FROM ADM_CostCenterDef  WHERE COSTCENTERID=@CostCenterId 
			DELETE FROM ADM_DocumentTypes  WHERE COSTCENTERID=@CostCenterId 
			DELETE FROM ADM_FeatureAction WHERE FeatureID=@CostCenterId 
			DELETE FROM ADM_FEATURES  WHERE FEATUREID=@CostCenterId 
		  END 
		ELSE
		  BEGIN
		    RAISERROR('-144',16,1)
		  END


 		SET @RowsDeleted=@@rowcount
		
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID
RETURN @RowsDeleted
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		if isnumeric(ERROR_MESSAGE())=1
		begin
			IF (ERROR_MESSAGE() LIKE '-144' )
			BEGIN
				SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE  ErrorNumber=-144  AND LanguageID=@LangID
			END 
			ELSE
			BEGIN
				SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
			END
		end
		else
			SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber
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
