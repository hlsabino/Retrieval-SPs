USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_DeleteProduct]
	@ProductID [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section  
		DECLARE @lft INT,@rgt INT,@Width int,@RowsDeleted INT  	  
		DECLARE @HasAccess bit,@HasRecord INT,@CCID int,@ErrorMsg nvarchar(max),@SQL nvarchar(max),@UserName NVARCHAR(50)

		--SP Required Parameters Check
		IF(@ProductID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		IF((SELECT PARENTID FROM INV_Product WITH(NOLOCK) WHERE ProductID=@ProductID)=0)
		BEGIN
			RAISERROR('-117',16,1)
		END
		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1  
		FROM INV_Product WITH(NOLOCK) WHERE ProductID=@ProductID  
           
		CREATE table #tmpPRD (id int identity(1,1),ProductID INT)
		 
		if @ProductID>0
		begin
			if exists(SELECT * FROM Inv_Product WITH(NOLOCK) WHERE ProductID=@ProductID and IsGroup=1)
			BEGIN
				insert into #tmpPRD 
				select ProductID from Inv_Product WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt
			END
			else
				insert into #tmpPRD(ProductID)values(@ProductID)
		end
		else
		begin
			insert into #tmpPRD 
			select ProductID from Inv_Product with(nolock) WHERE ProductID=@ProductID
			
			delete from ADM_OfflineOnlineIDMap where CostCenterID=3 and OfflineID=@ProductID
		end
		
		/*****Check Refrences here****/
		if @ProductID>0
		begin
			--INV_LinkedProducts
			set @HasRecord=0
			--INV_DocDetails(Documents)
			select top 1 @HasRecord=InvDocDetailsID,@ErrorMsg=VoucherNo FROM INV_DocDetails with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Product used in Document "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			--Check In COM_CCCCDATA
			select top 1 @CCID=CostCenterID,@HasRecord=NodeID FROM COM_CCCCDATA with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
			if(@HasRecord>0)
			begin
				EXEC [spCOM_GetErrorMsg] @CCID,@HasRecord,'Product used in ',@ErrorMsg output
				RAISERROR(@ErrorMsg,16,1)
			end
			--Substitutes
			select top 1 @HasRecord=ProductSubstituteID,@ErrorMsg=SubstituteGroupName FROM INV_ProductSubstitutes with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Product used in Substitue group "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			--Kit
			select top 1 @HasRecord=ParentProductID FROM INV_ProductBundles with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
			if(@HasRecord>0)
			begin
				select @ErrorMsg='Product used as kit sub item for "'+ProductName+'"' from Inv_Product with(nolock) where ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
				RAISERROR(@ErrorMsg,16,1)
			end
			--Batches
			select top 1 @HasRecord=BatchID,@ErrorMsg=BatchNumber FROM INV_Batches with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Product used in Batch "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			--Case Product
			if exists(select name from sys.tables where name='CRM_Cases')
			begin
				SET @SQL='select top 1 @HasRecord=CaseID,@ErrorMsg=CaseNumber FROM CRM_Cases with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))'
				EXEC sp_executesql @SQL, N'@HasRecord INT OUTPUT,@ErrorMsg nvarchar(max) OUTPUT',@HasRecord OUTPUT,@ErrorMsg OUTPUT
				if(@HasRecord>0)
				begin
					set @ErrorMsg='Product used in case "'+@ErrorMsg+'"'
					RAISERROR(@ErrorMsg,16,1)
				end
			end
			--BillOfMaterial Product
			if exists(select name from sys.tables where name='PRD_BillOfMaterial')
			begin
				SET @SQL='select top 1 @HasRecord=BOMID,@ErrorMsg=BOMName FROM PRD_BillOfMaterial with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))'
				EXEC sp_executesql @SQL, N'@HasRecord INT OUTPUT,@ErrorMsg nvarchar(max) OUTPUT',@HasRecord OUTPUT,@ErrorMsg OUTPUT
				if(@HasRecord>0)
				begin
					set @ErrorMsg='Product used in BillOfMaterial "'+@ErrorMsg+'"'
					RAISERROR(@ErrorMsg,16,1)
				end
			end
			if exists(select name from sys.tables where name='PRD_BOMProducts')
			begin
				SET @SQL='select top 1 @HasRecord=BMP.BOMProductID,@ErrorMsg=''Product used in BillOfMaterial "''+BM.BOMName
				+CASE WHEN BMS.lft IS NULL THEN '''' ELSE ''" --> Stage :''+CONVERT(NVARCHAR,BMS.lft) END + '' --> ''
				+CASE WHEN BMP.ProductUse=1 THEN ''Input'' ELSE ''Output'' END +''Tab'' 
				from PRD_BOMProducts BMP with(nolock)
				JOIN PRD_BillOfMaterial BM with(nolock) ON BM.BOMID=BMP.BOMID
				JOIN PRD_BOMStages BMS with(nolock) ON BMS.BOMID=BMP.BOMID AND BMS.StageID=BMP.StageID
				WHERE BMP.ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))'
				EXEC sp_executesql @SQL, N'@HasRecord INT OUTPUT,@ErrorMsg nvarchar(max) OUTPUT',@HasRecord OUTPUT,@ErrorMsg OUTPUT
				if(@HasRecord>0)
				begin
					RAISERROR(@ErrorMsg,16,1)
				end
			end
			if exists(select name from sys.tables where name='PRD_JobOuputProducts')
			begin
				SET @SQL='select top 1 @CCID=CostCenterID,@HasRecord=NodeID FROM PRD_JobOuputProducts with(nolock) WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))'
				EXEC sp_executesql @SQL, N'@HasRecord INT OUTPUT,@CCID INT OUTPUT',@HasRecord OUTPUT,@CCID OUTPUT
				
				if(@HasRecord>0)
				begin
					EXEC [spCOM_GetErrorMsg] @CCID,@HasRecord,'Product used in Output tab of ',@ErrorMsg output
					RAISERROR(@ErrorMsg,16,1)
				end
			end
		end
		--ondelete External function
		IF (@ProductID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=3 and Mode=8
			if(@tablename<>'')
				exec @tablename 3,@ProductID,'',@UserID,@LangID	
		END	
		
		SELECT @UserName=USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE UserID=@UserID
		
		declare @i int, @cnt int
		DECLARE @NodeID INT, @Dimesion INT,@pid INT
		
		select @i=1,@cnt=count(*) from #tmpPRD WITH(NOLOCK) 
		while @i<=@cnt
		begin
			select @NodeID=ProductID from #tmpPRD WITH(NOLOCK) where id=@i
			
			--INSERT INTO HISTROY   
			EXEC [spCOM_SaveHistory]  
				@CostCenterID =3,    
				@NodeID =@NodeID,
				@HistoryStatus ='Deleted',
				@UserName=@UserName
			
			set @i=@i+1
		end	
  
		--select ProductID from #tmpPRD WITH(NOLOCK)
		delete from INV_ProductBundles where ParentProductID IN (select ProductID from #tmpPRD WITH(NOLOCK)) 
		
		--Delete from exteneded table  
		DELETE FROM INV_ProductExtended WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK)) 
		
		--Delete from CostCenter table  
		--DELETE FROM INV_ProductCostCenterMap WHERE ProductID=@ProductID
		DELETE FROM COM_CCCCDATA WHERE CostCenterID=3 and NodeID in (select ProductID from #tmpPRD WITH(NOLOCK))

		--Delete CostCenter Hisory
		DELETE FROM COM_HistoryDetails where CostCenterID=3 and NodeID in (select ProductID from #tmpPRD WITH(NOLOCK))
		
		--Delete Status Hisory
		DELETE FROM COM_CostCenterStatusMap where CostCenterID=3 and NodeID IN (select ProductID from #tmpPRD WITH(NOLOCK))
		
		--Delete Assign/Map Data
		DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=3 and NodeID in (select ProductID from #tmpPRD WITH(NOLOCK))
		DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=3 and ParentNodeID in (select ProductID from #tmpPRD WITH(NOLOCK))
	
		set @i=1
		select @cnt=count(*) from #tmpPRD WITH(NOLOCK)
		 
		while @i<=@cnt
		begin
			set @NodeID=0
			set @Dimesion=0
			select @pid=ProductID from #tmpPRD WITH(NOLOCK) where id=@i
			
			select  @NodeID = CCNodeID, @Dimesion=CCID from Inv_Product with(nolock) where ProductID=@pid
		 
			if (@NodeID is not null and @NodeID>0)
			begin
				Update Inv_Product set CCID=0, CCNodeID=0 where ProductID=@pid
				declare @return_value INT
		  
				EXEC	@return_value = [dbo].[spCOM_DeleteCostCenter]
				@CostCenterID = @Dimesion,
				@NodeID = @NodeID,
				@RoleID=1,
				@UserID = @UserID,
				@LangID = @LangID,
				@CheckLink = 0
				
				--Deleting from Mapping Table
				Delete from com_docbridge WHERE CostCenterID = 3 AND RefDimensionNodeID = @NodeID AND RefDimensionID = 	@Dimesion
			end
			set @i=@i+1
			
			
			--Delete Stock Code
			if(select Value from ADM_GlobalPreferences with(nolock) where Name='POSEnable')='True'
				exec spDoc_SetStockCode 2,1,'',@pid,null,0,0,null,''
		end
		
		SET @RowsDeleted=@@rowcount 
	 
		--Delete from Notes
		DELETE FROM  COM_Notes 
		WHERE FeatureID=3 and FeaturePK in (select ProductID from #tmpPRD WITH(NOLOCK))

		--To Remove Unit of Measure(s)
		UPDATE INV_Product SET UOMID=NULL
		WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
		
		DELETE FROM COM_UOM WHERE PRODUCTID in (select ProductID from #tmpPRD WITH(NOLOCK)) AND ISPRODUCTWISE=1
		
		delete from INV_ProductBarcode where productid in (select ProductID from #tmpPRD WITH(NOLOCK))
		delete from INV_ProductVendors where productid in (select ProductID from #tmpPRD WITH(NOLOCK))
		
		delete from inv_productsubstitutes where productid in (select ProductID from #tmpPRD WITH(NOLOCK))
		
		--Delete from Files
		DELETE FROM  COM_Files  
		WHERE FeatureID=3 and  FeaturePK in (select ProductID from #tmpPRD WITH(NOLOCK))

		--Delete from main table  
		DELETE FROM INV_Product WHERE ProductID in (select ProductID from #tmpPRD WITH(NOLOCK))
		
		DROP TABLE #tmpPRD
		
		--Update left and right extent to set the tree  
		UPDATE INV_Product SET rgt = rgt - @Width WHERE rgt > @rgt;  
		UPDATE INV_Product SET lft = lft - @Width WHERE lft > @rgt;  
 
		
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
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
