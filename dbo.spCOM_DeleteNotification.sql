USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteNotification]
	@CostCenterID [int],
	@NodeID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY
		
	--Declaration Section
	DECLARE @HasAccess BIT,@RowsDeleted INT
	DECLARE @ScheduleID BIGINT
	
	SET @RowsDeleted=0
	--SP Required Parameters Check
	IF @NodeID=0
	BEGIN
		RAISERROR('-100',16,1)
	END

	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,7,4)
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	IF @CostCenterID=47 OR @CostCenterID=48--Email/SMS
	BEGIN
		DECLARE @CCID bigint
		
		SELECT @CCID=CostCenterID
		FROM COM_NotifTemplate WITH(NOLOCK) WHERE TemplateID=@NodeID
		
		IF @CCID=50
		BEGIN
			SELECT @ScheduleID=ScheduleID FROM COM_CCSchedules WITH(NOLOCK) WHERE (CostCenterID=47 OR CostCenterID=48) AND NodeID=@NodeID
			
			--IF (SELECT COUNT(*) FROM COM_SchEvents WITH(NOLOCK) WHERE ScheduleID=@ScheduleID AND StatusID=2)=0
			IF @ScheduleID>0
			BEGIN
				DELETE FROM COM_CCSchedules WHERE @ScheduleID=ScheduleID
				DELETE FROM COM_Schedules WHERE @ScheduleID=ScheduleID
				DELETE FROM COM_SchEvents WHERE @ScheduleID=ScheduleID
			END
		END
		
		--Delete from main table
		DELETE FROM COM_NotifTemplate WHERE TemplateID=@NodeID
		SET @RowsDeleted=@@rowcount

		--DELETE FROM COM_NotifTemplate WHERE TemplateType=1 AND TemplateID=@NodeID AND IsGroup=0
 		--SET @RowsDeleted=@@rowcount 
	END
	ELSE IF @CostCenterID=162
	BEGIN		
		delete from adm_assign where costcenterid=162 and nodeid=@NodeID
		DELETE FROM ADM_IMPORTDEF WHERE PROFILEID=@NodeID
	END


COMMIT TRANSACTION
SET NOCOUNT OFF;
IF @RowsDeleted>0
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
	WHERE ErrorNumber=102 AND LanguageID=@LangID
RETURN @RowsDeleted
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
