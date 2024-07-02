USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_DeleteAsset]
	@AssetID [int] = 0,
	@UserID [int] = 1,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	--Declaration Section
	DECLARE @HasAccess bit,@lft INT,@rgt INT,@Width INT,@UserName NVARCHAR(50)

	if(@AssetID=0)
	BEGIN
		RAISERROR('-100',16,1)
	END
	
	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,72,4)
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	
	IF((SELECT ParentID FROM Acc_Assets WITH(NOLOCK) WHERE AssetID=@AssetID)=0)
	BEGIN
		RAISERROR('-117',16,1)
	END
	
	IF exists (select * from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DocID>0)
	BEGIN
		RAISERROR('-134',16,1)
	END
	
	SELECT @UserName=USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE UserID=@UserID

	--INSERT INTO HISTROY   
	EXEC [spCOM_SaveHistory]  
		@CostCenterID =72,    
		@NodeID =@AssetID,
		@HistoryStatus ='Deleted',
		@UserName=@UserName

	DELETE FROM ACC_AssetDepSchedule WHERE AssetID=@AssetID
	
	--Fetch left, right extent of Node along with width.
	SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
	FROM Acc_Assets WITH(NOLOCK) WHERE AssetID=@AssetID
		
	--Delete from CostCenter Mapping
	DELETE FROM COM_CCCCDATA WHERE CostCenterID=72 and NodeID=@AssetID
	
	--Delete CostCenter Hisory
	DELETE FROM COM_HistoryDetails where CostCenterID=72 and NodeID=@AssetID

	--For deleting Asset dimension if exists
	declare @assetccid INT
	
	SELECT @assetccid=Convert(INT,isnull(Value,0)) FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=72 and  Name='AssetDimension'      

	if(@assetccid>50000)
	begin
		
		declare @temp table(id int identity(1,1), AssetID INT)
		
		--SELECT @lft,@rgt,@assetccid,@AssetID
		insert into @temp
		select AssetID from Acc_Assets WITH(nolock) WHERE lft >= @lft AND rgt <= @rgt

		declare @i int, @cnt int
		DECLARE @NodeID INT, @Dimesion INT 
				
		set @i=1
		select @cnt=count(*) from @temp
		while @i<=@cnt
		begin
			set @NodeID=0
			set @Dimesion=0
			select  @NodeID = CCNodeID, @Dimesion=CCID from Acc_Assets WITH(nolock) where AssetID in (select AssetID from @temp where id=@i)
			if (@NodeID is not null and @NodeID>0)
			begin

				--INSERT INTO HISTROY   
				EXEC [spCOM_SaveHistory]  
					@CostCenterID =@Dimesion,    
					@NodeID =@NodeID,
					@HistoryStatus ='Deleted',
					@UserName=@UserName

				Update Acc_Assets set CCID=0, CCNodeID=0 where AssetID in (select AssetID from @temp where id=@i)
				
				--Deleting from Mapping Table
				select AssetID from @temp where id=@i
				
				Delete from com_docbridge WHERE CostCenterID = 72 AND RefDimensionNodeID = @NodeID AND RefDimensionID = @Dimesion
			
				declare @return_value INT
				
				EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
					@CostCenterID = @Dimesion,
					@NodeID = @NodeID,
					@RoleID=1,
					@UserID = 1,
					@LangID = @LangID,
					@CheckLink = 0		
			end
			set @i=@i+1
		end
	end
	
	--Delete from exteneded table
	DELETE FROM Acc_AssetsExtended WHERE AssetID in
	(select AssetID from Acc_Assets WITH(nolock) WHERE lft >= @lft AND rgt <= @rgt)

	DELETE FROM ACC_AssetDepSchedule WHERE AssetID in
	(select AssetID from Acc_Assets WITH(nolock) WHERE lft >= @lft AND rgt <= @rgt)

	DELETE FROM ACC_AssetChanges WHERE AssetID in
	(select AssetID from Acc_Assets WITH(nolock) WHERE lft >= @lft AND rgt <= @rgt)
	
	DELETE FROM ACC_AssetsHistory WHERE AssetManagementID in
	(select AssetID from Acc_Assets WITH(nolock) WHERE lft >= @lft AND rgt <= @rgt)
	
	--Delete from main table
	DELETE FROM Acc_Assets WHERE lft >= @lft AND rgt <= @rgt
	delete from Acc_Assets	where AssetID=@AssetID
	

	--Update left and right extent to set the tree
	UPDATE Acc_Assets SET rgt = rgt - @Width WHERE rgt > @rgt;
	UPDATE Acc_Assets SET lft = lft - @Width WHERE lft > @rgt;

		
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)
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
