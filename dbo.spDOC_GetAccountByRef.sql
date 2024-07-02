USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetAccountByRef]
	@RefID [int],
	@RefColID [int],
	@NodeID [nvarchar](max),
	@NodeName [nvarchar](500),
	@IsCode [bit],
	@Costcenterid [int],
	@DType [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON
		
		
		if(@RefID=-98)
		BEGIN
				if exists(SELECT DrAccount from ADM_CrossDimension WITH(NOLOCK) 
				where DimIn=@RefColID  and DimFor=@NodeID and Document=@Costcenterid)
				BEGIN
					SELECT DrAccount from ADM_CrossDimension WITH(NOLOCK) 
					where DimIn=@RefColID  and DimFor=@NodeID and Document=@Costcenterid
				END
				ELSE if(@DType=5)
				BEGIN
					SELECT DrAccount from ADM_CrossDimension WITH(NOLOCK) 
					where DimIn=@RefColID  and DimFor=@NodeID and Document=3
				END	
				return 1
		END
		ELSE if(@RefID=-99)
		BEGIN
			if exists(SELECT DrAccount from ADM_CrossDimension WITH(NOLOCK) 
			where DimIn=@RefColID  and DimFor=@NodeID and Document=@Costcenterid)
			BEGIN
				SELECT CrAccount from ADM_CrossDimension WITH(NOLOCK) 
				where DimIn=@RefColID  and DimFor=@NodeID and Document=@Costcenterid
			END
			ELSE if(@DType=5)
			BEGIN
				SELECT CrAccount from ADM_CrossDimension WITH(NOLOCK) 
				where DimIn=@RefColID  and DimFor=@NodeID and Document=3
			END	
				
			return 1
		END
		
		--Declaration Section
		DECLARE @HasAccess BIT,@Sql NVARCHAR(MAX),@TABLE NVARCHAR(max),@CostCCID INT
		DECLARE @ColumnName  NVARCHAR(200),@CCID INT
		--SP Required Parameters Check
		IF (@NodeID<=0 and @NodeName='') or @RefID<=0 OR @RefColID=0
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		SELECT @CCID=ColumnCostCenterID FROM ADM_CostCenterDef with(nolock) WHERE CostCenterColID=@RefID
		SELECT @CostCCID=CostCenterID,@ColumnName=SysColumnName FROM ADM_CostCenterDef with(nolock) 
		WHERE CostCenterColID=@RefColID or CostCenterColID=-@RefColID
		
		IF(@CCID=2)
		BEGIN	
			if(@ColumnName like 'acAlpha%')
			BEGIN
				if(@NodeID=0 and @NodeName<>'')
					SET @TABLE=' ACC_Accounts a  WITH(NOLOCK) join ACC_AccountsExtended b WITH(NOLOCK) on a.AccountID=b.AccountID '
				ELSE	
					SET @TABLE='ACC_AccountsExtended  WITH(NOLOCK)'
			END	
			ELSE
				SET @TABLE='ACC_Accounts  WITH(NOLOCK) '	
		END	
		else IF(@CCID=3)
		BEGIN	
			if(@CostCCID=72)
			BEGIN
				DECLARE @PID INT,@isGrp BIT,@parent INT
				select @PID=ASSETGROUPID,@isGrp=IsGroup,@parent=ParentID from INV_Product WITH(NOLOCK)	
				where ProductID=@NodeID
				
				if(@isGrp=0 and @PID=0)
					 set @NodeID=@parent
					
				SET @TABLE=' ACC_Assets a WITH(NOLOCK)  join INV_Product b WITH(NOLOCK)  on a.AssetID=b.AssetGroupID '
			END	
			else if(@ColumnName like 'ptAlpha%')
			BEGIN
				if(@RefColID<0)
					SET @TABLE=' INV_Product b WITH(NOLOCK)
					join  INV_ProductExtended a WITH(NOLOCK) on b.ParentID=a.ProductID '
				else	
					SET @TABLE='INV_ProductExtended  WITH(NOLOCK) '
			END	
			ELSE
			BEGIN
				if(@RefColID<0)
				BEGIN
					SET @TABLE=' INV_Product b WITH(NOLOCK)
					join  INV_Product a WITH(NOLOCK) on b.ParentID=a.ProductID '
					set @ColumnName='a.'+@ColumnName
				END	
				else
					SET @TABLE='INV_Product  WITH(NOLOCK)'
			END	
		END	
		ELSE
			SELECT @TABLE=TableName+'  WITH(NOLOCK) ' FROM ADM_Features with(nolock) WHERE FeatureID=@CCID
		
		SET @Sql='SELECT '+@ColumnName+' FROM '+@TABLE+' WHERE '
		IF(@CCID=2)
		BEGIN
			if(@NodeID=0 and @NodeName<>'')
			BEGIN
				if(@IsCode=1)
					SET @Sql=@Sql+'AccountCode='''
				ELSE
					SET @Sql=@Sql+'AccountName='''
			END	
			ELSE
				SET @Sql=@Sql+'AccountID in('
		END	
		else IF(@CCID=3)
		BEGIN
			if(@RefColID<0)
				SET @Sql=@Sql+'b.ProductID in('
			else
				SET @Sql=@Sql+'ProductID in('			
		END	
		ELSE
			SET @Sql=@Sql+'NodeID in('
		 
		 if(@NodeID=0 and @NodeName<>'')
			SET @Sql=@Sql+@NodeName+''''
		ELSE	
			SET @Sql=@Sql+@NodeID+')'
		 print @Sql
		 EXEC(@Sql)
			
	
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

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
