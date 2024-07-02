USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeletingSelectedDimData]
	@CostCenterID [int] = 0,
	@NodeID [nvarchar](max) = null,
	@Type [int] = 0,
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@UserName [nvarchar](max) = null,
	@UserID [int] = 1,
	@LangID [int] = 1,
	@RoleID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY    
SET NOCOUNT ON;    
 
--SET NOCOUNT ON;    
	--Declaration Section    
	DECLARE @TblTemp TABLE(ID INT IDENTITY(1,1), NodeID INT, CCID INT, IsGroup bit, IsDeleted bit)
	DECLARE @Tbl TABLE(ID INT IDENTITY(1,1),NodeID INT)
	 
	DECLARE @I INT,@CNT INT, @TCNT INT, @DCNT INT, @ICNT INT, @NID INT
	 set @DCNT=0
	--DELETE Dimension DATA
	 INSERT INTO @Tbl
	 EXEC SPSplitString @NodeID,','

	        IF (@CostCenterID=2)
			BEGIN
				INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
				Select Accountid, 2, IsGroup from acc_accounts with(nolock) where AccountID>40 and AccountID In (select NodeID from @Tbl) order by IsGroup,AccountID

				SELECT @ICNT = 1, @TCNT=COUNT(*) FROM @TblTemp
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
			ELSE IF (@CostCenterID=3)
			BEGIN

			    INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
				select ProductID, 3, IsGroup from INV_Product with(nolock) where ProductID >1 and ProductID In (select NodeID from @Tbl)  order by IsGroup,ProductID
					
				SELECT @ICNT = 1, @TCNT=COUNT(*) FROM @TblTemp
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
			ELSE IF (@CostCenterID=23)
			BEGIN
				INSERT INTO @TblTemp (NodeID)
				exec SPSplitString @NodeID,','
				
				SELECT @ICNT = 1, @TCNT=COUNT(*) FROM @TblTemp
				WHILE @ICNT<=@TCNT
				BEGIN
					SELECT @NID=NodeID FROM @TblTemp WHERE id=@ICNT
					DELETE FROM PS FROM INV_ProductSubstitutes PS WITH(NOLOCK) WHERE SubstituteGroupID=@NID
										
					SET @ICNT=@ICNT+1
				END
			END
			ELSE IF (@CostCenterID>50000)
			BEGIN
			declare @Sql nvarchar(max), @TableName nvarchar(100)

				select @TableName=TableName from adm_features where featureid=@CostCenterID
				
				set @Sql ='Select NodeID,'+convert(nvarchar,@CostCenterID)+', IsGroup from '+@TableName+' with(nolock) where  NodeID>2 and NodeID in ('+@NodeID+')  and ParentID!=0 '
				
				INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
				exec (@Sql)  
				
				SELECT @ICNT = 1, @TCNT=COUNT(*) FROM @TblTemp
				while @ICNT<=@TCNT
				begin
					select @NID=Nodeid from @TblTemp where id=@ICNT
					
					DECLARE	@retCCID int 
				
					EXEC	@retCCID = [dbo].[spCOM_DeleteCostCenter]
							@CostCenterID = @CostCenterID,
							@NodeID = @NID,
							@RoleID=@RoleID,@UserID = @UserID,@LangID = @LangID,@CheckLink = 1
				
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
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()<>266  
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
