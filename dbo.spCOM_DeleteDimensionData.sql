USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteDimensionData]
	@DimensionsList [nvarchar](max),
	@IsNode [bit],
	@UserID [int] = 0,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      


--SET NOCOUNT ON;    
	--Declaration Section    
	DECLARE @TblTemp TABLE(ID BIGINT IDENTITY(1,1), NodeID bigint, CCID bigint, IsGroup bit, IsDeleted bit)
	DECLARE @Tbl TABLE(ID INT IDENTITY(1,1),FeatureID INT)
	 
	DECLARE @I INT,@CNT INT,@FeatureID bigint, @TCNT INT, @DCNT BIGINT, @ICNT bigint, @NID BIGINT
	 set @DCNT=0
	--DELETE DOCUMENTS DATA
	IF LEN(@DimensionsList)>0
	BEGIN
		INSERT INTO @Tbl
		EXEC SPSplitString @DimensionsList,','
		set @I=1
		select @CNT=COUNT(*) from @Tbl
		WHILE @I<=@CNT
		BEGIN
			SELECT @FeatureID=FeatureID from @Tbl where ID=@I
			IF (@FeatureID=2)
			BEGIN
				if exists(select id from @TblTemp)
					Select @ICNT=COUNT(*)+1 from @TblTemp
				else
					set @ICNT=1
					
				if (@IsNode=1)
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select Accountid, 2, IsGroup from acc_accounts with(nolock) where AccountID>40 and IsGroup=0
				else  
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select Accountid, 2, IsGroup from acc_accounts with(nolock) where AccountID>40  order by IsGroup,AccountID
					
				 
				SELECT @TCNT=COUNT(*) FROM @TblTemp
				while @ICNT<=@TCNT
				begin
					select @NID=Nodeid from @TblTemp where id=@ICNT
					DECLARE	@return_value int 
					EXEC	@return_value = [dbo].[spACC_DeleteAccount]
							@AccountID=@NID, @UserID=@UserID, @RoleID=@RoleID, @LangID=@LangID
					if (@return_value>0)
					begin
						set @DCNT=@DCNT+1
						update @TblTemp set IsDeleted=1 where id=@ICNT
					end
					else
						update @TblTemp set IsDeleted=0 where id=@ICNT
						
					set @ICNT=@ICNT+1	
				end 
			END
			ELSE IF (@FeatureID=3)
			BEGIN
				if exists(select id from @TblTemp)
					Select @ICNT=COUNT(*)+1 from @TblTemp
				else
					set @ICNT=1
			
				if (@IsNode=1)
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select ProductID, 3, IsGroup from INV_Product with(nolock) where ProductID >1 and IsGroup=0
				else  
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select ProductID, 3, IsGroup from INV_Product with(nolock) where ProductID >1  order by IsGroup,ProductID
					
				SELECT @TCNT=COUNT(*) FROM @TblTemp
				while @ICNT<=@TCNT
				begin
					select @NID=Nodeid from @TblTemp where id=@ICNT
					DECLARE	@retproduct int 
					EXEC	@retproduct = [dbo].spINV_DeleteProduct
							@ProductID = @NID,@UserID = @UserID,@RoleID=@RoleID,@LangID = @LangID
					if (@retproduct>0)
					begin
						set @DCNT=@DCNT+1
						update @TblTemp set IsDeleted=1 where id=@ICNT
					end
					else
						update @TblTemp set IsDeleted=0 where id=@ICNT
						
					set @ICNT=@ICNT+1	
				end 
			END
			ELSE IF (@FeatureID=16)
			BEGIN 
				if exists(select id from @TblTemp)
					Select @ICNT=COUNT(*)+1 from @TblTemp
				else
					set @ICNT=1
			
				if (@IsNode=1)
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select BatchID, 16, IsGroup from INV_Batches with(nolock) where BatchID >1 and IsGroup=0
				else  
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select BatchID, 16, IsGroup from INV_Batches with(nolock) where BatchID >1  order by IsGroup,BatchID
					
				SELECT @TCNT=COUNT(*) FROM @TblTemp
				while @ICNT<=@TCNT
				begin
					select @NID=Nodeid from @TblTemp where id=@ICNT
					DECLARE	@retBatch int 
					EXEC	@retBatch = [dbo].spINV_DeleteBatch
							@BatchID = @NID,@UserID = @UserID,@RoleID=@RoleID,@LangID = @LangID
					if (@retBatch>0)
					begin
						set @DCNT=@DCNT+1
						update @TblTemp set IsDeleted=1 where id=@ICNT
					end
					else
						update @TblTemp set IsDeleted=0 where id=@ICNT
						
					set @ICNT=@ICNT+1	
				end 
			END
			ELSE IF (@FeatureID>50000)
			BEGIN
				if exists(select id from @TblTemp)
					Select @ICNT=COUNT(*)+1 from @TblTemp
				else
					set @ICNT=1
				declare @Sql nvarchar(max), @TableName nvarchar(100)
				select @TableName=TableName from adm_features where featureid=@FeatureID
				
				if (@IsNode=1)
					set @Sql ='Select NodeID,'+convert(nvarchar,@FeatureID)+', IsGroup from '+@TableName+' with(nolock) where  NodeID>2 and IsGroup=0 and ParentID!=0 '
				else
					set @Sql ='Select NodeID,'+convert(nvarchar,@FeatureID)+', IsGroup from '+@TableName+' with(nolock) where NodeID>2 and ParentID!=0 order by IsGroup,NodeID'
				  
				INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
				exec (@Sql)  

				SELECT @TCNT=COUNT(*) FROM @TblTemp
				while @ICNT<=@TCNT
				begin
					select @NID=Nodeid from @TblTemp where id=@ICNT
					
					DECLARE	@retCCID int 
					
					BEGIN TRY 
					EXEC	@retCCID = [dbo].[spCOM_DeleteCostCenter]
							@CostCenterID = @FeatureID,
							@NodeID = @NID,
							@RoleID=@RoleID,@UserID = @UserID,@LangID = @LangID,@CheckLink = 1
					END TRY
					BEGIN CATCH 
					END CATCH
					 
					if (@retCCID>0)
					begin
						set @DCNT=@DCNT+1
						update @TblTemp set IsDeleted=1 where id=@ICNT
					end
					else
						update @TblTemp set IsDeleted=0 where id=@ICNT
						
					set @ICNT=@ICNT+1	
				end  
	 			
			END
			ELSE IF (@FeatureID=72)
			BEGIN 
				if exists(select id from @TblTemp)
					Select @ICNT=COUNT(*)+1 from @TblTemp
				else
					set @ICNT=1
			
				if (@IsNode=1)
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select AssetID, 72, IsGroup from ACC_Assets with(nolock) where AssetID >1 and IsGroup=0
				else  
					INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
					select AssetID, 72, IsGroup from ACC_Assets with(nolock) where AssetID >1  order by IsGroup,AssetID
					
				SELECT @TCNT=COUNT(*) FROM @TblTemp
				while @ICNT<=@TCNT
				begin
					select @NID=Nodeid from @TblTemp where id=@ICNT
					DECLARE	@retAsset int 
					EXEC	@retAsset = [dbo].spACC_DeleteAsset 
							@AssetID=@NID,@UserID=@UserID,@RoleID=@RoleID,@LangID = @LangID
					if (@retAsset>0)
					begin
						set @DCNT=@DCNT+1
						update @TblTemp set IsDeleted=1 where id=@ICNT
					end
					else
						update @TblTemp set IsDeleted=0 where id=@ICNT
						
					set @ICNT=@ICNT+1	
				end 
			END
			 
			SET @I=@I+1
		END 
	END
 

COMMIT TRANSACTION
--ROLLBACK TRANSACTION

select @DCNT
select * from @TblTemp
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END	
	ELSE IF ERROR_NUMBER()!=266
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	BEGIN TRY
		ROLLBACK TRANSACTION
	END TRY
	BEGIN CATCH
	END CATCH
SET NOCOUNT OFF  
RETURN -999   
END CATCH

 
GO
