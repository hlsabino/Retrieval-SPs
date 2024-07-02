USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_DeleteProperty]
	@PropertyID [int] = 0,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
DECLARE @lft INT,@rgt INT ,@Width INT

		IF((SELECT ParentID FROM REN_Property WITH(NOLOCK) WHERE NodeID=@PropertyID)=0)
		BEGIN
			RAISERROR('-117',16,1)
		END
		
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM REN_Property WITH(NOLOCK) WHERE NodeID=@PropertyID
        declare @temp table(id int identity(1,1), NodeID INT)
		
		insert into @temp
		select NodeID from REN_Property WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt
		
		--ondelete External function
		IF (@PropertyID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=92 and Mode=8
			if(@tablename<>'')
				exec @tablename 92,@PropertyID,'',@UserID,@LangID	
		END	
		
		declare @i int, @cnt int
		DECLARE @NodeID INT, @Dimesion INT 
		set @i=1
		select @cnt=count(*) from @temp
		while @i<=@cnt
		begin
			set @NodeID=0
			set @Dimesion=0 
			select  @NodeID = CCNodeID, @Dimesion=CCID from REN_Property WITH(NOLOCK) where NodeID in
			(select NodeID from @temp where id=@i)
			if (@NodeID is not null and @NodeID>0)
			begin
				Update REN_Property set CCID=0, CCNodeID=0 where NodeID in
				(select NodeID from @temp where id=@i)
				select * from REN_Property WITH(NOLOCK) where NodeID in
				(select NodeID from @temp where id=@i)
				declare @return_value INT
				EXEC	@return_value = [dbo].[spCOM_DeleteCostCenter]
					@CostCenterID = @Dimesion,
					@NodeID = @NodeID,
					@RoleID=1,
					@UserID = @UserID,
					@LangID = @LangID,
					@CheckLink = 0
					
				--Deleting from Mapping Table
				Delete from com_docbridge WHERE CostCenterID = 92 AND RefDimensionNodeID = @NodeID AND RefDimensionID = @Dimesion				
			end
			set @i=@i+1
		end
		
		delete from REN_Particulars where PropertyID=@PropertyID and UnitID=0
		delete from REN_PropertyUnits where PropertyID=@PropertyID
		delete from REN_PropertyExtended where NodeID=@PropertyID
		delete from com_ccccdata where costcenterid=92 and NodeID=@PropertyID
		delete from [ADM_PropertyUserRoleMap] where [PropertyID]=@PropertyID
		delete from [REN_PropertyShareHolder] where PropertyID=@PropertyID
		
		--Delete from Notes
		DELETE FROM  COM_Notes 
		WHERE FeatureID=92 and  FeaturePK=@PropertyID

		--Delete from Files
		DELETE FROM  COM_Files  
		WHERE FeatureID=92 and  FeaturePK=@PropertyID
		
		delete from REN_Property where  NodeID=@PropertyID
		
		--Update left and right extent to set the tree
		UPDATE REN_Property SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE REN_Property SET lft = lft - @Width WHERE lft > @rgt;
		
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN 1
END TRY
BEGIN CATCH  
		if(@return_value=-999)
			return -999
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
