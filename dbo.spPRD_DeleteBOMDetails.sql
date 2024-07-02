USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_DeleteBOMDetails]
	@BOMID [int] = 0,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT

		--SP Required Parameters Check
		if(@BOMID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,76,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		if exists(select * from PRD_JobOuputProducts WITH(NOLOCK) where BOMID=@BOMID)
		BEGIN
			RAISERROR('-110',16,1)
		END
		
		IF((SELECT ParentID FROM PRD_BillOfMaterial WITH(NOLOCK) WHERE BOMID=@BOMID)=0)
		BEGIN
			RAISERROR('-117',16,1)
		END
		
		--ondelete External function
		IF (@BOMID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=76 and Mode=8
			if(@tablename<>'')
				exec @tablename 76,@BOMID,'',1,@LangID	
		END	
		
		declare @Tbl as table(id int identity(1,1),BOMID INT)
		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM PRD_BillOfMaterial WITH(NOLOCK) WHERE BOMID=@BOMID
			
		if exists(SELECT * FROM PRD_BillOfMaterial WITH(NOLOCK) WHERE BOMID=@BOMID and IsGroup=1)
		BEGIN
			insert into @Tbl(BOMID)
			select BOMID  from PRD_BillOfMaterial with(nolock) WHERE lft >= @lft AND rgt <= @rgt 
		END
		else
			insert into @Tbl(BOMID)values(@BOMID)

		delete a from PRD_BOMProducts a with(nolock)
		join @Tbl b on a.BOMID=b.BOMID	 
		delete a from PRD_Expenses a with(nolock)
		join @Tbl b on a.BOMID=b.BOMID	 
		delete a from PRD_BOMResources a with(nolock)
		join @Tbl b on a.BOMID=b.BOMID	 
		delete a from PRD_BOMStages a with(nolock)
		join @Tbl b on a.BOMID=b.BOMID	 
		delete a from PRD_BillOfMaterialExtended a with(nolock)
		join @Tbl b on a.BOMID=b.BOMID	 
		delete a from COM_CCCCData a with(nolock)
		join @Tbl b on a.CostCenterID=76 and a.NodeID=b.BOMID	

		declare @bomccid INT
		
		SELECT @bomccid=Convert(INT,isnull(Value,0)) FROM COM_CostCenterPreferences  WITH(nolock) 
		WHERE COSTCENTERID=76 and  Name='BOMDimension'      
 
		if(@bomccid>50000)
		begin
			
			declare @i int, @cnt int
			DECLARE @NodeID INT, @Dimesion INT 
					
			select @i=1,@cnt=count(*) from @Tbl
			while @i<=@cnt
			begin
				set @NodeID=0
				set @Dimesion=0
				select  @NodeID = CCNodeID, @Dimesion=CCID from PRD_BillOfMaterial with(nolock)
				where BOMID in (select BOMID from @Tbl where id=@i)
				if (@NodeID is not null and @NodeID>0)
				begin
					Update PRD_BillOfMaterial set CCID=0, CCNodeID=0 
					where BOMID in (select BOMID from @Tbl where id=@i)
					
					declare @return_value INT
			
					EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @Dimesion,
						@NodeID = @NodeID,
						@RoleID=1,
						@UserID = 1,
						@LangID = @LangID,
						@CheckLink = 0
					Delete from com_docbridge WHERE CostCenterID = 76 AND RefDimensionNodeID = @NodeID AND RefDimensionID = @Dimesion
				end
				set @i=@i+1
			end
		end
		
		
		delete a from PRD_BillOfMaterial a with(nolock)
		join @Tbl b on a.BOMID=b.BOMID	 
		
		--Update left and right extent to set the tree
		UPDATE PRD_BillOfMaterial SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE PRD_BillOfMaterial SET lft = lft - @Width WHERE lft > @rgt;
		

    SET @RowsDeleted=@@rowcount
COMMIT TRANSACTION
--rollback TRANSACTION
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
