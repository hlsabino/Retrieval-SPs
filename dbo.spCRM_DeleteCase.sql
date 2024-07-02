USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_DeleteCase]
	@CASEID [int] = 0,
	@USERID [int] = 0,
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	--Declaration Section
	DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT

	--SP Required Parameters Check
	if(@CASEID=0)
	BEGIN
		RAISERROR('-100',16,1)
	END 
	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,4)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
	
	IF((SELECT ParentID FROM CRM_Cases WITH(NOLOCK) WHERE CaseID=@CASEID)=0)
	BEGIN
		RAISERROR('-117',16,1)
	END
	
	--ondelete External function
	IF (@CASEID>0)
	BEGIN
		DECLARE @tablename NVARCHAR(200)
		set @tablename=''
		select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=73 and Mode=8
		if(@tablename<>'')
			exec @tablename 73,@CASEID,'',@UserID,@LangID	
	END	
	
	 select 1
	IF(EXISTS(SELECT VALUE FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK)  WHERE COSTCENTERID=73 AND NAME='LinkDimension'))
	 BEGIN
		DECLARE @DIMID INT=0,@CCID INT
		SELECT @DIMID=VALUE FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK)  WHERE COSTCENTERID=73 AND NAME='LinkDimension'
		IF(@DIMID>=50000)
		BEGIN	
			SELECT @CCID=CCCaseID FROM CRM_Cases WITH(NOLOCK) WHERE Caseid=@CASEID	
			IF 	@CCID>1	 
			BEGIN
				declare @UpdateSql nvarchar(max)
				SET @UpdateSql='UPDATE COM_CCCCData   
				   SET  CCNID'+CONVERT(NVARCHAR,(@DIMID-50000))+'=1 WHERE COSTCENTERID=73 AND Nodeid='+CONVERT(NVARCHAR,@CASEID)+' '  
				 EXEC(@UpdateSql)    
		
				EXEC [spCOM_DeleteCostCenter] @DIMID,@CCID,1,1,1,0  
			END
		END 
	 END		
	
	--Fetch left, right extent of Node along with width.
	SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
	FROM CRM_Cases WITH(NOLOCK) WHERE CaseID=@CASEID  
	
		--Delete from exteneded table
	DELETE FROM CRM_Casesextended WHERE CaseID in
	(select CaseID from CRM_Cases WITH(NOLOCK)  WHERE lft >= @lft AND rgt <= @rgt)
	
	DELETE FROM crm_assignment WHERE CCID=73 AND CCNODEID IN
	(select CaseID from CRM_Cases WITH(NOLOCK)  WHERE lft >= @lft AND rgt <= @rgt)
	
	DELETE FROM CRM_ACTIVITIES WHERE CostCenterID=73 AND NodeID IN 
	(select CaseID from CRM_Cases WITH(NOLOCK)  WHERE lft >= @lft AND rgt <= @rgt)

	--Delete from main table
	DELETE FROM CRM_Cases WHERE lft >= @lft AND rgt <= @rgt
	
	
	--Update left and right extent to set the tree
	UPDATE CRM_Cases SET rgt = rgt - @Width WHERE rgt > @rgt;
	UPDATE CRM_Cases SET lft = lft - @Width WHERE lft > @rgt;
	
	DELETE FROM CRM_CaseSvcTypeMap WHERE CaseID=@CASEID 
	Delete From CRM_Cases where CASEID=@CASEID
	Delete From CRM_ProductMapping where costcenterid=73 and ccnodeid=@CASEID	 
	Delete From CRM_Feedback where CCID=73 and ccnodeid=@CASEID
	delete from CRM_Activities where CostCenterID=73 and NodeID=@CASEID

		
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
