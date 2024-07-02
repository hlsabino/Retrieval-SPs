USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_DeleteBatch]
	@BatchID [bigint],
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section  
		DECLARE @lft BIGINT,@rgt BIGINT,@Width int,@RowsDeleted BIGINT  	  
		DECLARE @HasAccess bit

		--SP Required Parameters Check
		IF(@BatchID<1)
		BEGIN
			RAISERROR('-100',16,1)
		END


		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,16,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		IF((SELECT PARENTID FROM INV_Batches WITH(NOLOCK) WHERE BatchID=@BatchID  )=0)
		BEGIN
			RAISERROR('-117',16,1)
		END
		
		IF exists(SELECT BatchID FROM INV_DocDetails WITH(NOLOCK) WHERE BatchID=@BatchID and InvDocDetailsID>0)
		BEGIN
			RAISERROR('-505',16,1)
		END

		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1  
		FROM INV_Batches WITH(NOLOCK) WHERE BatchID=@BatchID  

		IF exists(SELECT BatchID FROM INV_DocDetails WITH(NOLOCK) WHERE BatchID
		in (SELECT BatchID FROM INV_Batches WITH(NOLOCK)  WHERE lft >= @lft AND rgt <= @rgt) and InvDocDetailsID>0)
		BEGIN
			RAISERROR('-505',16,1)
		END
		
		

		--Delete from main table  
		DELETE FROM INV_Batches WHERE lft >= @lft AND rgt <= @rgt  

		SET @RowsDeleted=@@rowcount

		--Delete from Contacts
		 DELETE FROM  COM_ContactsExtended
		WHERE ContactID IN (SELECT CONTACTID FROM COM_CONTACTS WITH(NOLOCK) WHERE FeatureID=16 and  FeaturePK=@BatchID)
		DELETE FROM  COM_Contacts 
		WHERE FeatureID=16 and  FeaturePK=@BatchID

		--Delete from Notes
		DELETE FROM  COM_Notes 
		WHERE FeatureID=16 and  FeaturePK=@BatchID

		--Delete from Files
		DELETE FROM  COM_CCCCData  
		WHERE CostCenterID=16 and  NodeID=@BatchID

		--Delete from Files
		DELETE FROM  COM_Files  
		WHERE FeatureID=16 and  FeaturePK=@BatchID
		
		if exists(select RefDimensionID from com_docbridge WITH(NOLOCK) where CostCenterID=16 and NodeID=@BatchID)
		BEGIN
			DECLARE @NodeID bigint, @Dimesion bigint ,@return_value int
			select @NodeID=RefDimensionNodeID,@Dimesion=RefDimensionID from com_docbridge WITH(NOLOCK) where CostCenterID=16 and NodeID=@BatchID
		
			EXEC	@return_value = [dbo].[spCOM_DeleteCostCenter]
				@CostCenterID = @Dimesion,
				@NodeID = @NodeID,
				@RoleID=1,
				@UserID = 1,
				@LangID = @LangID,
				@CheckLink = 0
					
			--Deleting from Mapping Table
			Delete from com_docbridge WHERE CostCenterID = 16 and NodeID=@BatchID 
		END	 

		--Update left and right extent to set the tree  
		UPDATE INV_Batches SET rgt = rgt - @Width WHERE rgt > @rgt;  
		UPDATE INV_Batches SET lft = lft - @Width WHERE lft > @rgt;  
    
  
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
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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
