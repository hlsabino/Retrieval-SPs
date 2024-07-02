USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_DeleteEmp]
	@NodeID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @ErrorMsg NVARCHAR(MAX),@NIDS NVARCHAR(MAX),@CostCenterID int
		DECLARE @HasAccess BIT,@Width int,@Table nvarchar(50),@SQL nvarchar(max),@ParentNode INT
		DECLARE @TEMPSQL NVARCHAR(300),@Audit NVARCHAR(100),@LinkDimCC nvarchar(max),@iLinkDimCC int
		
		SET @CostCenterID=50051

		SELECT @Audit=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID and Name='AuditTrial'
		
		--SP Required Parameters Check
		IF @CostCenterID=0 OR @NodeID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		SET @Table=(SELECT Top 1 SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId)  	

		declare @temptbl table(id int identity(1,1),NodeID INT)
		 
		if @NodeID>0
		begin
			SET @SQL=' DECLARE @lft INT,@rgt INT,@Width INT
			 SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1  
		FROM '+@Table+' WITH(NOLOCK) WHERE NodeID='+convert(nvarchar,@NodeID)+'		
		select NodeID from '+@Table+' WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt'
			insert into @temptbl
			EXEC sp_executesql @SQL
		end
		else
		begin
			insert into @temptbl
			values(@NodeID)
			
			delete from ADM_OfflineOnlineIDMap where CostCenterID=@CostCenterId and OfflineID=@NodeID
		end
		
		--ondelete External function
		IF (@NodeID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=8
			if(@tablename<>'')
				exec @tablename @CostCenterID,@NodeID,'',1,@LangID	
		END	
		
		set @NIDS=''
		select @NIDS=@NIDS+convert(nvarchar,NodeID)+',' from @temptbl
		if exists(select NodeID from @temptbl)
			set @NIDS=substring(@NIDS,0,len(@NIDS))
		
		-- CHECK FOR IF PARENT IS GETTING DELETED
		SET @SQL =' SELECT @ParentNode=PARENTID FROM '+ @Table +' WHERE NODEID='+CONVERT(VARCHAR,@NodeID)
		SET @TEMPSQL=' @ParentNode INT OUTPUT' 
		EXEC sp_executesql @SQL, @TEMPSQL,@ParentNode OUTPUT  
		
		IF @ParentNode=0 or @NodeID=1
		BEGIN
			RAISERROR('-117',16,1)
		END		
		
		IF NOT EXISTS(SELECT * FROM INV_DocDetails I
					JOIN COM_DocCCData CC on CC.InvDocDetailsID=I.InvDocDetailsID
					WHERE I.CostCenterID<>40081 AND CC.dcCCNID51 IN(select NodeID from @temptbl))
		BEGIN
			DECLARE @TblDeleteRows AS Table(idid INT identity(1,1), ID INT)

			INSERT INTO @TblDeleteRows
			SELECT I.InvDocDetailsID FROM INV_DocDetails I
			JOIN COM_DocCCData CC on CC.InvDocDetailsID=I.InvDocDetailsID
			WHERE I.CostCenterID=40081 AND CC.dcCCNID51 IN(select NodeID from @temptbl)

			DELETE T FROM COM_DocNumData t
				join @TblDeleteRows a on t.InvDocDetailsID=a.ID	

			DELETE T FROM COM_DocTextData t
				join @TblDeleteRows a on t.InvDocDetailsID=a.ID	

			DELETE T FROM COM_DocCCData t
				join @TblDeleteRows a on t.InvDocDetailsID=a.ID	

			DELETE T FROM INV_DocDetails t
				join @TblDeleteRows a on t.InvDocDetailsID=a.ID	
		END

		DELETE FROM COM_CCCCDATA WHERE CostCenterID=@CostCenterID and NodeID in (select NodeID from @temptbl)
		--Delete CostCenter Hisory
		DELETE FROM COM_HistoryDetails where CostCenterID=@CostCenterID and NodeID in (select NodeID from @temptbl)
		
		SET @SQL=' DECLARE @lft INT,@rgt INT,@Width INT '  
		 
		--Fetch left, right extent of Node along with width.  
		SET @SQL=@SQL+' SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1  
		FROM '+@Table+' WITH(NOLOCK) WHERE NodeID='+convert(nvarchar,@NodeID)  

		--UPDATING HISTORY TABLE
		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN
			insert into [COM_CC50051_History]         
			select 50051,'Delete',* FROM COM_CC50051 WHERE NODEID IN (@NIDS)
		END

		SELECT @LinkDimCC=[Value] FROM com_costcenterpreferences with(nolock) WHERE CostCenterID=@CostCenterID and [Name]='LinkDimension'
			if(ISNUMERIC(@LinkDimCC)=1)
				set @iLinkDimCC=CONVERT(int,@LinkDimCC)
			else
				set @iLinkDimCC=0

		declare @LinkDimNodeID INT

		declare @i int, @cnt int,@tempnodeid INT
		select @i=1,@cnt=count(*) from @temptbl 
		while @i<=@cnt
		begin
			select @tempnodeid=nodeid from @temptbl  where id=@i
		
			select @LinkDimNodeID=RefDimensionNodeID from com_docbridge with(nolock) WHERE CostCenterID=@CostCenterID AND NodeID=@tempnodeid AND RefDimensionID=@iLinkDimCC

			if (@LinkDimNodeID>1 and @iLinkDimCC>50000 and @iLinkDimCC!=@CostCenterID)
			begin
				
					EXEC [dbo].[spCOM_DeleteCostCenter]
					@CostCenterID = @iLinkDimCC,
					@NodeID = @LinkDimNodeID,
					@RoleID=1,
					@UserID=1,
					@LangID = @LangID,
					@CheckLink = 0
			end
		
			--Deleting from Mapping Table
			delete from com_docbridge WHERE CostCenterID=@CostCenterID AND NodeID=@tempnodeid AND RefDimensionID=@iLinkDimCC
			
			set @i=@i+1
		end

		--Delete from main table  
		SET @SQL=@SQL+' DELETE FROM '+@Table+' WHERE NodeID IN ('+@NIDS+')'  

		--Update left and right extent to set the tree  
		SET @SQL=@SQL+' UPDATE '+@Table+' SET rgt = rgt - @Width WHERE rgt > @rgt;   
		  UPDATE '+@Table+' SET lft = lft - @Width WHERE lft > @rgt;'  
		EXEC sp_executesql @SQL  		
		
		DELETE FROM  COM_ContactsExtended
		WHERE ContactID IN (SELECT CONTACTID FROM COM_CONTACTS WITH(NOLOCK) WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from @temptbl))
		
		DELETE FROM  COM_Contacts 
		WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from @temptbl)
		
		--Delete from Notes
		DELETE FROM  COM_Notes 
		WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from @temptbl)

		--Delete from Files
		DELETE FROM  COM_Files  
		WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from @temptbl)
		
		
		DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=@CostCenterID and NodeID in (select NodeID from @temptbl)
		DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@CostCenterID and ParentNodeID in (select NodeID from @temptbl)
		
COMMIT TRANSACTION 
--ROLLBACK TRANSACTION
SET NOCOUNT OFF; 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID  
RETURN 1
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  

		IF ERROR_NUMBER()=50000
		BEGIN
			if isnumeric(ERROR_MESSAGE())=1
				SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
			else
				SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber
		END
		ELSE IF ERROR_NUMBER()=547
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
			WHERE ErrorNumber=-110 AND LanguageID=@LangID
		END
		ELSE 
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
