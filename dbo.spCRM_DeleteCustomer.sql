USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_DeleteCustomer]
	@CustomerID [int] = 0,
	@IsContactDelete [bit] = 1,
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT,@SQL NVARCHAR(MAX)

		--SP Required Parameters Check
		if(@CustomerID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		IF EXISTS(SELECT CustomerID FROM CRM_Customer WITH(NOLOCK) WHERE CustomerID=@CustomerID AND ParentID=0)
		BEGIN
			RAISERROR('-115',16,1)
		END
		
		IF EXISTS(SELECT * FROM sys.columns WITH(NOLOCK) WHERE name='CustomerID' AND object_id=OBJECT_ID('COM_DocCCData'))
		BEGIN
			SET @SQL='SELECT @RowsDeleted=COUNT(CustomerID) FROM COM_DocCCData WITH(NOLOCK) WHERE CustomerID='+CONVERT(NVARCHAR,@CustomerID)
			EXEC sp_executesql @SQL,N'@RowsDeleted INT OUTPUT',@RowsDeleted OUTPUT
			
			IF (@RowsDeleted>0)
			BEGIN
				RAISERROR('-379',16,1)
			END
		END
	    
	    --ondelete External function
		IF (@CustomerID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=83 and Mode=8
			if(@tablename<>'')
				exec @tablename 83,@CustomerID,'',1,@LangID	
		END	
		
		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM CRM_Customer WITH(NOLOCK) WHERE CustomerID=@CustomerID

		--Delete from exteneded table
		DELETE FROM CRM_CustomerExtended WHERE CustomerID in
		(select CustomerID from CRM_Customer  WHERE lft >= @lft AND rgt <= @rgt)

	 --Delete from main table
		DELETE FROM CRM_Customer WHERE lft >= @lft AND rgt <= @rgt

		SET @RowsDeleted=@@rowcount 

		DELETE FROM CRM_ACTIVITIES WHERE CostCenterID=86 AND NodeID=@CustomerID
		DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=83 AND ParentCostCenterID=89 AND NODEID=@CustomerID
		DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=2 AND ParentCostCenterID=89 AND NODEID=@CustomerID
		--Delete from Contacts
		if(@IsContactDelete=1)
		begin
			 DELETE FROM  COM_ContactsExtended
			WHERE ContactID IN (SELECT CONTACTID FROM COM_CONTACTS WITH(NOLOCK) WHERE FeatureID=83 and  FeaturePK=@CustomerID)
			DELETE FROM  COM_Contacts 
			WHERE FeatureID=83 and  FeaturePK=@CustomerID
		end
		else if(@IsContactDelete=0)
			update COM_Contacts set FeatureID=65, FeaturePK=0 WHERE FeatureID=83 and  FeaturePK=@CustomerID 
			
		--Delete from Notes
		DELETE FROM  COM_Notes 
		WHERE FEATUREID=83 and  FeaturePK=@CustomerID

		--Delete from Files
		DELETE FROM  COM_Files  
		WHERE FEATUREID=83 and  FeaturePK=@CustomerID

		DELETE FROM  COM_Address  
		WHERE FEATUREID=83 and  FeaturePK=@CustomerID

		--Update left and right extent to set the tree
		UPDATE CRM_Customer SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE CRM_Customer SET lft = lft - @Width WHERE lft > @rgt;
	

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
