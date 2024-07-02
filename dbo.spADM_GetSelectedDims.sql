USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetSelectedDims]
	@CostCenterID [int],
	@From [int],
	@To [int],
	@where [nvarchar](max),
	@IsNode [bit],
	@UserName [nvarchar](200),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;      

	declare @sql nvarchar(max),@UserWise bit,@table nvarchar(50) ,@ID nvarchar(50),@sqlCondition nvarchar(max)

	SET @UserWise=dbo.fnCOM_HasAccess(@RoleID,43,137)

	DECLARE @Tbl TABLE(ID INT IDENTITY(1,1),FeatureID INT)
	 
	DECLARE @I INT,@CNT INT,@FeatureID INT, @TCNT INT, @DCNT INT, @ICNT INT, @NID INT
	 set @DCNT=0
	IF (@CostCenterID=2)
		BEGIN
			set @table='ACC_Accounts'
			set @ID='AccountID'
			set @sql='select a.'+@ID+' as NODEID,AccountCode as CODE,AccountName as NAME,2 as CCID '
			set @sqlCondition = ' and a.AccountID > 40 '
		END
		ELSE IF (@CostCenterID=3)
		BEGIN
		    set @table='INV_Product'
			set @ID='ProductID'
			set @sql='select a.'+@ID+' as NODEID,ProductCode as CODE,ProductName as NAME,3 as CCID '
			set @sqlCondition = ' and a.ProductID > 1 '
		END
		ELSE IF (@CostCenterID=23)
		BEGIN
		    set @table='INV_ProductSubstitutes'
			set @ID='SubstituteGroupID'
			set @sql='select a.'+@ID+' as NODEID,SubstituteGroupName as CODE,SubstituteGroupName as NAME,3 as CCID '
			--set @sqlCondition = ' and a.ProductID > 1 '
		END
		--ELSE IF (@CostCenterID=16)
		--BEGIN 
		--		if exists(select id from @TblTemp)
		--			Select @ICNT=COUNT(*)+1 from @TblTemp
		--		else
		--			set @ICNT=1
			
		--		if (@IsNode=1)
		--			INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
		--			select BatchID, 16, IsGroup from INV_Batches with(nolock) where BatchID >1 and IsGroup=0
		--		else  
		--			INSERT INTO @TblTemp (NodeID,CCID,IsGroup)
		--			select BatchID, 16, IsGroup from INV_Batches with(nolock) where BatchID >1  order by IsGroup,BatchID
					
		--		SELECT @TCNT=COUNT(*) FROM @TblTemp
		--		while @ICNT<=@TCNT
		--		begin
		--			select @NID=Nodeid from @TblTemp where id=@ICNT
		--			DECLARE	@retBatch int 
		--			EXEC	@retBatch = [dbo].spINV_DeleteBatch
		--					@BatchID = @NID,@UserID = @UserID,@RoleID=@RoleID,@LangID = @LangID
		--			if (@retBatch>0)
		--			begin
		--				set @DCNT=@DCNT+1
		--				update @TblTemp set IsDeleted=1 where id=@ICNT
		--			end
		--			else
		--				update @TblTemp set IsDeleted=0 where id=@ICNT
						
		--			set @ICNT=@ICNT+1	
		--		end 
		--	END
		ELSE IF (@CostCenterID>50000)
		BEGIN
		     Select @table = TableName ,@ID =PrimaryKey from ADM_Features where FeatureID = @CostCenterID
		     set @sql='select a.'+@ID+' as NODEID,Code as CODE,Name as NAME,'++convert(nvarchar,@CostCenterID)+' as CCID '
		     set @sqlCondition = ' and a.NodeID > 2 '
		END
		
		IF(@CostCenterID=23)
		BEGIN
			set @sql= @sql +'
			from '+@table+' a with(nolock) 
			GROUP BY SubstituteGroupID,SubstituteGroupName
			order by SubstituteGroupName'
			SET @sqlCondition=''
			
		END
		ELSE
		BEGIN	
			set @sql= @sql +'
			from '+@table+' a with(nolock) 
			join COM_CCCCData b with(nolock) on a.'+@ID+'=b.NodeID'
		END
		IF(@CostCenterID<>23)
		BEGIN
			set @sql = @sql +' where 1=1'

			set @sql = @sql + @sqlCondition

			if (@IsNode=1)
				 set @sql=@sql +' and a.IsGroup = 0 ' 
			else  
				 set @sql=@sql +' and a.IsGroup = 1 '

			 if(@CostCenterID>0)
				set @sql=@sql +' and b.CostCenterID ='+convert(nvarchar,@CostCenterID) 


			--set @sql='select AccountID as NODEID,AccountCode as CODE,AccountName as NAME,2 as CCID
			--from '+@table+' a with(nolock) 
			--join COM_CCCCData b with(nolock) on a.'+@ID+'=b.'+@ID
			--set @sql =@sql +' where 1=1'
			
			--if(@isResave=1)
			--begin
			--    set @sql =@sql +' and a.statusid in (369,370)'
			--end	

			--set @sql=@sql+' and a.DOCprefix='''+@prefix+''' and a.docnumber between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)
	        
			--For AllDims
	   --     if(@CostCenterID=0)
	   --     BEGIN
				
				--set @table='INV_DocDetails'
				--set @ID='InvDocDetailsID'
				
				--set @sql=@sql+@where +'
				--UNION
				--select distinct DocID,CostCenterID,DocDate,DOCprefix,convert(INT,docnumber),VoucherNo,RefCCID,RefNodeid 
				--from '+@table+' a with(nolock) 
				--join ACC_Accounts cr with(nolock) on a.CreditAccount=cr.AccountID
				--join ACC_Accounts dr with(nolock) on a.DebitAccount=dr.AccountID
				--join COM_DocCCData b with(nolock) on a.'+@ID+'=b.'+@ID
				--set @sql =@sql +' where 1=1'

	   --     END
			--For AllDims
	        
			if(@where is not null and @where<>'')
				set @sql =@sql+@where
			if(@UserID<>1 and @UserWise=1)
				set @sql =@sql+' and a.CreatedBy ='''+@UserName+''''
			set @sql =@sql+' order by a.CreatedDate'
		END
		print @sql
	    exec(@sql) 
COMMIT TRANSACTION       
SET NOCOUNT OFF;         
RETURN 1      
END TRY      
BEGIN CATCH        
 --Return exception info [Message,Number,ProcedureName,LineNumber]        
 IF ERROR_NUMBER()=50000      
 BEGIN      
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
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
--SELECT * FROM ADM_FEATURES WHERE FEATUREID=40034

GO
