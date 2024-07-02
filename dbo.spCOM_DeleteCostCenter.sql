USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteCostCenter]
	@CostCenterID [int],
	@NodeID [int],
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1,
	@CheckLink [bit] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @ErrorMsg NVARCHAR(MAX),@NIDS NVARCHAR(MAX),@ExtendedColsXML NVARCHAR(MAX)
		DECLARE @HasAccess BIT,@Width int,@Table nvarchar(50),@SQL nvarchar(max),@ParentNode INT
		DECLARE @TEMPSQL NVARCHAR(300),@CCID int,@HasRecord INT,@return_value int,@projDim int
		declare @LinkDimCC nvarchar(max),@iLinkDimCC int,@Tempcc int
		
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
		
		IF(@CostCenterId=50052) -- PAYROLL COMPONENTS
		BEGIN
			IF(@NodeID IN(1,2,3,4,5,6))
			BEGIN
				SET @ErrorMsg='You can not delete Static Groups'
				RAISERROR(@ErrorMsg,16,1)
			END
			
		END
		
		SET @Table=(SELECT Top 1 SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId)  	

		create table #temptbl(id int identity(1,1),NodeID INT)
		 
		if @NodeID>0
		begin
			SET @SQL=' 
			if exists(SELECT * FROM '+@Table+' WITH(NOLOCK) WHERE NodeID='+convert(nvarchar,@NodeID)+' and IsGroup=1)
			BEGIN
				DECLARE @lft INT,@rgt INT,@Width INT
				SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1  
				FROM '+@Table+' WITH(NOLOCK) WHERE NodeID='+convert(nvarchar,@NodeID)+'		
				insert into #temptbl
				select NodeID from '+@Table+' WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt
			END
			else
				insert into #temptbl(NodeID)values('+convert(nvarchar,@NodeID)+')'
			
			EXEC(@SQL)
		end
		else
		begin
			insert into #temptbl
			values(@NodeID)
			
			delete from ADM_OfflineOnlineIDMap where CostCenterID=@CostCenterId and OfflineID=@NodeID
		end
		
		set @NIDS=''
		select @NIDS=@NIDS+convert(nvarchar,NodeID)+',' from #temptbl WITH(NOLOCK)
		if exists(select NodeID from #temptbl WITH(NOLOCK))
			set @NIDS=substring(@NIDS,0,len(@NIDS))
		
		
		set @CCID=0		
		if @NodeID>0
		begin
			select @CCID=VALUE from COM_CostCenterPreferences with(nolock) where [Name]='StageDimension' and CostCenterID=76 and ISNUMERIC(VALUE)=1
			if(@CCID>50000 and @CCID=@CostCenterID)
			begin
				set @sql='if exists(select StageNodeID from PRD_BOMStages with(nolock) where StageNodeID in (select NodeID from #temptbl WITH(NOLOCK)))
				begin
					declare @ErrorMsg nvarchar(max)
					select top 1 @ErrorMsg=''Dimenson used as a BOMStage in "''+B.BOMName+''"'' from PRD_BOMStages BS with(nolock) 
					inner join PRD_BillOfMaterial B with(nolock) on BS.BOMID=B.BOMID
					where BS.StageNodeID in (select NodeID from #temptbl WITH(NOLOCK))
					RAISERROR(@ErrorMsg,16,1)
				end'
			end
		end
		
		IF exists(select * from COM_CostCenterPreferences with(nolock)
		where [Name]='BinsDimension' and costcenterid=3 and isnumeric(value)=1 and value=@CostCenterID)
		BEGIN
			IF exists(select * from inv_bindetails a with(nolock)
			join #temptbl t WITH(NOLOCK) on a.binid=t.NodeID)			
			BEGIN
				set @ErrorMsg='Can not delete used bins'
				RAISERROR(@ErrorMsg,16,1)
			END
		END
		
		set @projDim=0
		SELECT @projDim=isnull([Value],0) FROM Adm_globalpreferences with(nolock) 
		WHERE [Name]='ProjPlanDim' and ISNUMERIC(value)=1
		if(@projDim=@CostCenterID)
		BEGIN
			SELECT @Tempcc=RefDimensionID,@ParentNode=RefDimensionNodeID from COM_DocBridge WITH(NOLOCK) where CostCenterID=@CostCenterID and NodeID=@NodeID
			set @SQL='update COM_CCCCDATA  
				SET CCNID'+convert(nvarchar,(@CostCenterID-50000))+'=1  
				WHERE CostCenterID='+convert(nvarchar,@Tempcc) +' and NODEID='+convert(NVARCHAR,@ParentNode)  
				EXEC (@SQL)
		END
	
		--ondelete External function
		IF (@NodeID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=8
			if(@tablename<>'')
				exec @tablename @CostCenterID,@NodeID,'',@UserID,@LangID	
		END	
		--Check for deleting of Reference Records
		if(@CheckLink = 1)
		begin
			if @NodeID>0 AND LEN(@NIDS)>0
			begin
				SET @HasRecord = 0
				SELECT @HasRecord=count(RefDimensionID) from COM_DocBridge with(nolock) WHERE RefDimensionID=@CostCenterID and RefDimensionNodeID in (select NodeID from #temptbl WITH(NOLOCK))
				if (@HasRecord IS NOT NULL AND @HasRecord <>'' AND @HasRecord > 0)
					RAISERROR('-379',16,1)
				
				if exists(select * from sys.columns
				where name='dcCCNID'+convert(nvarchar,@CostCenterID-50000) and object_id=object_id('COM_DocCCDATA')	)
				BEGIN
					/*****Check Refrences here****/
					--COM_DocCCDATA(Documents)
					declare @AccDocDetailsID INT
					set @AccDocDetailsID=0
					set @SQL='select top 1 @AccDocDetailsID=AccDocDetailsID,@HasRecord=InvDocDetailsID FROM COM_DocCCDATA with(nolock) WHERE dcCCNID'+convert(nvarchar,@CostCenterID-50000)+' in ('+@NIDS+')'
					EXEC sp_executesql @SQL,N'@AccDocDetailsID int OUTPUT,@HasRecord INT OUTPUT',@AccDocDetailsID OUTPUT,@HasRecord OUTPUT
					if(@HasRecord>0 or @AccDocDetailsID>0)
					begin
						if @HasRecord>0
							select Top 1 @ErrorMsg='Dimension used in Document "'+VoucherNo+'"' from inv_docdetails with(nolock) where InvDocDetailsID=@HasRecord
						else if @AccDocDetailsID>0
							select Top 1 @ErrorMsg='Dimension used in Document "'+VoucherNo+'"' from acc_docdetails with(nolock) where AccDocDetailsID=@AccDocDetailsID
						RAISERROR(@ErrorMsg,16,1)
					end
					
					IF(@CostCenterId=50052) -- PAYROLL COMPONENTS
					BEGIN
						--COM_CC50054 -- PAYROLL STRUCTURE
						set @SQL='SELECT top 1 @ErrorMsg=REPLACE(CONVERT(NVARCHAR(11), CONVERT(DATETIME,PAYROLLDATE),106),'' '',''/''),@HasRecord=NodeID FROM COM_CC50054 WITH(NOLOCK) WHERE ComponentID IN ('+@NIDS+')'
						EXEC sp_executesql @SQL,N'@ErrorMsg nvarchar(max) OUTPUT,@HasRecord INT OUTPUT',@ErrorMsg OUTPUT,@HasRecord OUTPUT
						if(@HasRecord>0)
						begin
							set @ErrorMsg='Components used in Customize Payroll - "'+@ErrorMsg+'"'
							RAISERROR(@ErrorMsg,16,1)
						end
					END
				END
				IF(@CostCenterId=50056 AND (@NodeID=3 OR @NodeID=4)) -- Activity Type
				BEGIN
					set @ErrorMsg='Static Dimension Cannot be Delete'
					RAISERROR(@ErrorMsg,16,1)
				END
				
				IF(@CostCenterId=50057 AND (@NodeID=3 OR @NodeID=4 OR @NodeID=5 OR @NodeID=6)) -- Activity Type
				BEGIN
					set @ErrorMsg='Static Dimension Cannot be Delete'
					RAISERROR(@ErrorMsg,16,1)
				END
								
				--COM_CCCCDATA
				set @SQL='select top 1 @CCID=CostCenterID,@HasRecord=NodeID FROM COM_CCCCDATA with(nolock) WHERE CCNID'+convert(nvarchar,@CostCenterID-50000)+' in ('+@NIDS+')'
				EXEC sp_executesql @SQL,N'@CCID int OUTPUT,@HasRecord INT OUTPUT',@CCID OUTPUT,@HasRecord OUTPUT
				if(@HasRecord>0)
				begin
					EXEC [spCOM_GetErrorMsg] @CCID,@HasRecord,'Dimension used in ',@ErrorMsg output
					RAISERROR(@ErrorMsg,16,1)
				end

				--COM_CostCenterCostCenterMap
				set @SQL='select top 1 @CCID=ParentCostCenterID,@HasRecord=ParentNodeID FROM COM_CostCenterCostCenterMap with(nolock) WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID in ('+@NIDS+')'
				EXEC sp_executesql @SQL,N'@CCID int OUTPUT,@HasRecord INT OUTPUT',@CCID OUTPUT,@HasRecord OUTPUT
				if(@HasRecord>0)
				begin
					--select @CCID,@HasRecord,'Dimension assigned in ',@ErrorMsg output
					EXEC [spCOM_GetErrorMsg] @CCID,@HasRecord,'Dimension assigned in ',@ErrorMsg output
					RAISERROR(@ErrorMsg,16,1)
				end

				--PriceChart, TaxChart, Schemes & Discounts
				set @SQL='select top 1 @ErrorMsg=ProfileName,@HasRecord=PriceCCID FROM COM_CCPrices with(nolock) WHERE CCNID'+convert(nvarchar,@CostCenterID-50000)+' in ('+@NIDS+')'
				EXEC sp_executesql @SQL,N'@ErrorMsg nvarchar(max) OUTPUT,@HasRecord INT OUTPUT',@ErrorMsg OUTPUT,@HasRecord OUTPUT
				if(@HasRecord>0)
				begin
					set @ErrorMsg='Dimension used in Price chart "'+@ErrorMsg+'"'
					RAISERROR(@ErrorMsg,16,1)
				end
				IF(@CostCenterId<>50052 AND @CostCenterId<>50053)
				BEGIN
					set @SQL='select top 1 @ErrorMsg=ProfileName,@HasRecord=CCTaxID FROM COM_CCTaxes with(nolock) WHERE CCNID'+convert(nvarchar,@CostCenterID-50000)+' in ('+@NIDS+')'
					EXEC sp_executesql @SQL,N'@ErrorMsg nvarchar(max) OUTPUT,@HasRecord INT OUTPUT',@ErrorMsg OUTPUT,@HasRecord OUTPUT
					if(@HasRecord>0)
					begin
						set @ErrorMsg='Dimension used in Tax chart "'+@ErrorMsg+'"'
						RAISERROR(@ErrorMsg,16,1)
					end
				END
				set @SQL='select top 1 @ErrorMsg=ProfileName,@HasRecord=SchemeID FROM ADM_SchemesDiscounts with(nolock) WHERE CCNID'+convert(nvarchar,@CostCenterID-50000)+' in ('+@NIDS+')'
				EXEC sp_executesql @SQL,N'@ErrorMsg nvarchar(max) OUTPUT,@HasRecord INT OUTPUT',@ErrorMsg OUTPUT,@HasRecord OUTPUT
				if(@HasRecord>0)
				begin
					set @ErrorMsg='Dimension used in Scheme & Discounts "'+@ErrorMsg+'"'
					RAISERROR(@ErrorMsg,16,1)
				end
			end
			else
			begin
				delete from COM_DocBridge where RefDimensionID=@CostCenterID and RefDimensionNodeID in (select NodeID from #temptbl WITH(NOLOCK))
			end
		end 

		IF(@CostCenterId=50053) -- GRADE
		BEGIN
			SET @SQL='DELETE FROM COM_CC50054 WHERE GRADEID='+CONVERT(VARCHAR,@NodeID)
			EXEC sp_executesql @SQL
		END
		
		if exists (select * from sys.tables with(nolock) where name='PRD_JobOuputProducts')
		begin
			set @SQL='if exists (select CostCenterID from PRD_JobOuputProducts WITH(NOLOCK) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+convert(nvarchar,@NodeID)+')
							BEGIN
								delete from PRD_JobOuputProducts where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+convert(nvarchar,@NodeID)+'
								delete from INV_DocExtraDetails where [Type]=15 and LabID='+convert(nvarchar,@NodeID)+'
							END	'
								
			exec(@SQL)
		end

		SET @SQL =' SELECT @ParentNode=PARENTID FROM '+ @Table +' WHERE NODEID='+CONVERT(VARCHAR,@NodeID)
		SET @TEMPSQL=' @ParentNode INT OUTPUT' 
		EXEC sp_executesql @SQL, @TEMPSQL,@ParentNode OUTPUT  
		
		IF @ParentNode=0 or @NodeID=1
		BEGIN
			RAISERROR('-117',16,1)
		END		
		
		declare @rptid INT 
		select @rptid=CONVERT(INT,value) from ADM_GlobalPreferences with(nolock) where Name='Report Template Dimension'
		if(@rptid=@CostCenterID)
		begin 
			delete from ACC_ReportTemplate where drnodeid =@NodeID or crnodeid=@NodeID or templatenodeid =@NodeID
		end
	
	
		DELETE FROM COM_CCCCDATA WHERE CostCenterID=@CostCenterID and NodeID in (select NodeID from #temptbl WITH(NOLOCK))
		
		SET @SQL=' DECLARE @lft INT,@rgt INT,@Width INT
		'  
		 
		--Fetch left, right extent of Node along with width.  
		SET @SQL=@SQL+' SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1  
		FROM '+@Table+' WITH(NOLOCK) WHERE NodeID='+convert(nvarchar,@NodeID)  

		--Delete from main table  
		IF ( LEN(@NIDS)>0 )
		SET @SQL=@SQL+' DELETE FROM '+@Table+' WHERE NodeID IN ('+@NIDS+')'  
		
		--Audit Data(Masood)
		set @ExtendedColsXML=''
		if exists(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterId and Name='AuditTrial' and Value='True')
		begin
			exec @return_value=spADM_AuditData 1,@CostCenterID,@NodeID,'Delete','',1,1
		end	

		--Update left and right extent to set the tree  
		SET @SQL=@SQL+' UPDATE '+@Table+' SET rgt = rgt - @Width WHERE rgt > @rgt;   
		  UPDATE '+@Table+' SET lft = lft - @Width WHERE lft > @rgt;'  
		EXEC(@SQL)  		
		
		if exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='PosCoupons' and Value=@CostCenterID)
			and exists(select VoucherNodeID from COM_PosPayModes WITH(NOLOCK) WHERE VoucherNodeID in(select NodeID from #temptbl WITH(NOLOCK)))
		BEGIN
			RAISERROR('-526',16,1)
		END
			
		DELETE FROM  COM_ContactsExtended
		WHERE ContactID IN (SELECT CONTACTID FROM COM_CONTACTS WITH(NOLOCK) WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from #temptbl WITH(NOLOCK)))
		
		DELETE FROM  COM_Contacts 
		WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from #temptbl WITH(NOLOCK))
		
		--Delete from Notes
		DELETE FROM  COM_Notes 
		WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from #temptbl WITH(NOLOCK))

		--Delete from Files
		DELETE FROM  COM_Files  
		WHERE FeatureID=@CostCenterID and  FeaturePK in (select NodeID from #temptbl WITH(NOLOCK))
		
		DELETE FROM COM_HistoryDetails where CostCenterID=@CostCenterID and NodeID IN (select NodeID from #temptbl WITH(NOLOCK))
		DELETE FROM [COM_CostCenterStatusMap] where CostCenterID=@CostCenterID and NodeID IN (select NodeID from #temptbl WITH(NOLOCK))

		DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=@CostCenterID and NodeID in (select NodeID from #temptbl WITH(NOLOCK))
		DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@CostCenterID and ParentNodeID in (select NodeID from #temptbl WITH(NOLOCK))
		
		--DELETE LINKED DIMENSIONS
		if(@projDim=@CostCenterID)		
		BEGIN
			set @iLinkDimCC=0
			SELECT @iLinkDimCC=isnull([Value],0) FROM Adm_globalpreferences with(nolock) 
			WHERE [Name]='ProjectManagementDimension' and ISNUMERIC(value)=1			
		END
		ELSE
		BEGIN	
			SELECT @LinkDimCC=[Value] FROM com_costcenterpreferences with(nolock) WHERE CostCenterID=@CostCenterID and [Name]='LinkDimension'
			if(ISNUMERIC(@LinkDimCC)=1)
				set @iLinkDimCC=CONVERT(int,@LinkDimCC)
			else
				set @iLinkDimCC=0
		END
		
		declare @LinkDimNodeID INT

		declare @i int, @cnt int,@tempnodeid INT
		select @i=1,@cnt=count(*) from #temptbl WITH(NOLOCK)
		while @i<=@cnt
		begin
			select @tempnodeid=nodeid from #temptbl WITH(NOLOCK) where id=@i
		
			select @LinkDimNodeID=RefDimensionNodeID from com_docbridge WHERE CostCenterID=@CostCenterID AND NodeID=@tempnodeid AND RefDimensionID=@iLinkDimCC
			--set @SQL='select @LinkDimNodeID=CCNID'+convert(nvarchar,(@LinkDimCC-50000))+' from COM_CCCCData WHERE CostCenterID='+convert(nvarchar,@CostCenterID) +' and NODEID='+convert(NVARCHAR,@NodeID)  
			--EXEC sp_executesql @SQL,N'@LinkDimNodeID INT OUTPUT',@LinkDimNodeID OUTPUT  
			--declare @return_value int
			if (@LinkDimNodeID>1 and @iLinkDimCC>50000 and @iLinkDimCC!=@CostCenterID)
			begin
				if not (@tempnodeid<0 and @LinkDimNodeID>0)--condition added for syn offline data
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
		
		drop table #temptbl
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
