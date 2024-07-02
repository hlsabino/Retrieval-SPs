USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_DeleteTenant]
	@TenantID [int] = 0,
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@lft INT,@rgt INT,@Width INT,@UserName NVARCHAR(64)

		--SP Required Parameters Check
		if(@TenantID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		IF EXISTS(SELECT [FirstName] FROM REN_Tenant with(nolock) WHERE TenantID=@TenantID AND TenantID=1)
		BEGIN
			RAISERROR('-115',16,1)
		END

		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM REN_Tenant WITH(NOLOCK) WHERE TenantID=@TenantID
		
		--ondelete External function
		IF (@TenantID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=94 and Mode=8
			if(@tablename<>'')
				exec @tablename 94,@TenantID,'',@UserID,@LangID	
		END			
		
		declare @temp table(id int identity(1,1), TenantID INT)
		
		insert into @temp
		select DISTINCT TenantID  from REN_Tenant with(nolock) WHERE lft >= @lft AND rgt <= @rgt
		
		declare @i int, @cnt int
		DECLARE @NodeID INT, @Dimesion INT 
		set @i=1
		select @cnt=count(*) from @temp
		 
		while @i<=@cnt
		begin
			set @NodeID=0
			set @Dimesion=0
			select  @NodeID = CCNodeID, @Dimesion=CCID from REN_Tenant with(nolock) 
			where TenantID  IN (select TenantID from @temp where id=@i)
			delete from com_ccccdata where costcenterid=94 and nodeid  IN (select TenantID from @temp where id=@i)

			if (@NodeID is not null and @NodeID>0)
			begin
				Update REN_Tenant set CCID=0, CCNodeID=0 where TenantID in
				(select TenantID from @temp where id=@i)
				declare @return_value INT
			  
				EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
					@CostCenterID = @Dimesion,
					@NodeID = @NodeID,
					@RoleID=1,
					@UserID = @UserID,
					@LangID = @LangID,
					@CheckLink = 0
				 
				--Deleting from Mapping Table
				Delete from com_docbridge WHERE CostCenterID = 94 AND RefDimensionNodeID = @NodeID AND RefDimensionID = 	@Dimesion					
			end

			--Delete Linked Account
				set @NodeID=0
				select  @NodeID = AccountID from REN_Tenant with(nolock) 
				where TenantID  IN (select TenantID from @temp where id=@i)

				if (@NodeID is not null and @NodeID>0)
				begin
					Update REN_Tenant set AccountID=0 where TenantID in (select TenantID from @temp where id=@i)
				
					EXEC spACC_DeleteAccount @NodeID,@UserID,1,@LangID
				
					--Deleting from Mapping Table
					Delete from com_docbridge WHERE CostCenterID = 94 AND RefDimensionNodeID = @NodeID AND RefDimensionID = 2					
				end
			--END :: Delete Linked Account


			set @i=@i+1
		end
		
		SELECT @UserName=USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE UserID=@UserID
	
		select @i=1,@cnt=count(*) from @temp
		while @i<=@cnt
		begin
			select @NodeID=TenantID from @temp where id=@i
			
			--INSERT INTO HISTROY   
			EXEC [spCOM_SaveHistory]  
				@CostCenterID =94,    
				@NodeID =@NodeID,
				@HistoryStatus ='Deleted',
				@UserName=@UserName
			
			set @i=@i+1
		end
			
		DELETE FROM  COM_Notes  
		WHERE FEATUREID=94 and  FeaturePK in (select TenantID from @temp)
		
		DELETE FROM  COM_Files  
		WHERE FEATUREID=94 and  FeaturePK in (select TenantID from @temp)
		
		DELETE FROM CRM_ACTIVITIES WHERE CostCenterID=94 AND NodeID in (select TenantID from @temp)
		
		DELETE FROM  COM_Contacts 
		WHERE FEATUREID=94 and  FeaturePK in (select TenantID from @temp)
		
		---Delete from Extended Table
     	DELETE FROM REN_TenantExtended WHERE TenantID in (select TenantID from @temp)
		
		--Delete from main table
		DELETE FROM REN_Tenant WHERE TenantID in (select TenantID from @temp)

		--Update left and right extent to set the tree
		UPDATE REN_Tenant SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE REN_Tenant SET lft = lft - @Width WHERE lft > @rgt;
	
		

COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN 1
END TRY
BEGIN CATCH 
	if(@return_value=-999)
		return 
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
