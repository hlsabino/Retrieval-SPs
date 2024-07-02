USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_CreateAssets]
	@InvDocDetID [int],
	@CostCenterID [int],
	@ProductID [int],
	@DOCID [int],
	@VNO [varchar](200),
	@DT [datetime],
	@XML [nvarchar](max),
	@CompanyGUID [varchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;      
	
	declare @retVal INT,@isautocode bit,@Code nvarchar(max),@Prefix nvarchar(200),@num INT,@ASSETQTY FLOAT,@CNT FLOAT,@Prodname NVARCHAR(500),@QTY float
	,@name nvarchar(max),@PID INT,@gid nvarchar(200),@colName nvarchar(200),@SQL NVARCHAR(MAX),@NUMVALUE FLOAT,@SNO NVARCHAR(MAX),@PrefXml nvarchar(max)
	
	declare @Codetemp table (prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200),IsManualCode bit) 	
	
	select @colName=PrefValue from COM_DocumentPreferences WITH(NOLOCK)
	where CostCenterID=@CostCenterID and PrefName='AssetBasedOn'
	
	SELECT 	@QTY=Quantity FROM INV_DocDetails WITH(NOLOCK) WHERE InvDocDetailsID=@InvDocDetID
	
	IF(@colName<>'') 
	begin
		SET	@SQL='SELECT @NUMVALUE='+@colName+' FROM COM_DOCNUMDATA WITH(NOLOCK) WHERE INVDOCDETAILSID='+CONVERT(NVARCHAR,@InvDocDetID)
		print @SQL
		EXEC sp_executesql @SQL,N'@NUMVALUE FLOAT OUTPUT',@NUMVALUE output	
		
		IF(@NUMVALUE=0)
		BEGIN
			COMMIT TRANSACTION  
			RETURN 1
		END			
		ELSE IF(@NUMVALUE=1 or @NUMVALUE=2)
			SELECT 	@ASSETQTY=@QTY
		ELSE IF(@NUMVALUE=3 or @NUMVALUE=4)
			SELECT 	@ASSETQTY=1
	END
	ELSE		
		SELECT 	@ASSETQTY=@QTY
		
	select @Prodname=ProductName,@PID=ASSETGROUPID,@isautocode=IsGroup,@retVal=ParentID from INV_Product WITH(NOLOCK)	
	where ProductID=@ProductID
	
	if(@isautocode=0 and @PID=0)
		select @PID=ASSETGROUPID from INV_Product WITH(NOLOCK) where ProductID=@retVal
	
	select @isautocode=IsEnable,@PrefXml=PrefixContent from [COM_CostCenterCodeDef] WITH(NOLOCK)	
	where FeatureID=72 and IsGroupCode=0 and IsName=0

	
	SET @CNT=0
	DECLARE @TAB TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,SNO NVARCHAR(MAX))
	INSERT INTO @TAB
	select SerialNumber from INV_SerialStockProduct WITH(NOLOCK)
	where InvDocDetailsID=@InvDocDetID
	
	WHILE(@CNT<@ASSETQTY)
	begin
		SET @CNT=@CNT+1
		
		set @gid=newid()
		
		select @SNO=SNO from @TAB where ID=@CNT
		
		SET @name=@Prodname+ISNULL('-'+@SNO,'')
				
		if(@NUMVALUE=3 or @NUMVALUE=4)
			SET @SQL='TotalQtyPurchase='+CONVERT(nvarchar,@QTY)+', UOM=1,'
		else	
			SET @SQL='TotalQtyPurchase=1 ,UOM=1,'
		
		
		set @Code=@name 
		
		set @XML=REPLACE(@XML,'DeprXML','XML')
		
		exec @retVal= spAcc_SetAssetManagement
			@AssetID =0,      
			@AssetCode =@Code,      
			@AssetName =@name,      
			@StatusID =1,      
			@PurchaseValue  ='',      
			@ParentAssetID =@PID,      
			@IsGroup =0,  
			@CodePrefix ='',
			@CodeNumber =0,
			@Sno=@SNO,   
			@DetailXML =@SQL,      
			@ChangeValueXML =null,      
			@CustomFieldsQuery =null,      
			@CustomCostCenterFieldsQuery =null,     
			@AssetDepreciationXML =@XML,    
			@HistoryXML  =null,   
			@NotesXML =null,
			@AttachmentsXML =null, 
			@CompanyGUID =@CompanyGUID,      
			@GUID =@gid,      
			@CreatedBy =@UserName,      
			@UserID =@UserID,      
			@LangID =@LangID  
		
		if(@retVal>0)
		BEGIN
			update ACC_Assets set
				[DeprBookGroupID] =  T.DeprBookGroupID
				,[ClassID] =  T.ClassID
				,[SubClassID] =  T.SubClassID
				,[PostingGroupID] =  T.PostingGroupID
				,[EstimateLife] =  T.EstimateLife
				,[SalvageValueType] =  T.SalvageValueType
				,[SalvageValueName] =  T.SalvageValueName
				,[SalvageValue] =  T.SalvageValue
				,[IsComponent] =  T.IsComponent
				,[ParentAssetID] =  T.ParentAssetID				
				,[SupplierAccountID] =  T.SupplierAccountID		
				,[MainVendorAccID] =  T.MainVendorAccID
				,[Period] =  T.Period     				
				,[DepreciationMethod] =  T.DepreciationMethod
				,[AveragingMethod] =  T.AveragingMethod
				,[IsDeprSchedule] =  T.IsDeprSchedule
				,[PreviousDepreciation] =  T.PreviousDepreciation
				,[DeprBookID] =  T.DeprBookID			
				,[CapitalizationNo] =  @VNO
				,[CapitalizationDate] =CONVERT(FLOAT, @DT)
				,[AcqnCostACCID] =   T.AcqnCostACCID
				,[AccumDeprACCID] =   T.AccumDeprACCID
				,[AcqnCostDispACCID] =   T.AcqnCostDispACCID
				,[AccumDeprDispACCID] =   T.AccumDeprDispACCID
				,[GainsDispACCID] =   T.GainsDispACCID
				,[LossDispACCID] =   T.LossDispACCID
				,[MaintExpenseACCID] =   T.MaintExpenseACCID
				,[DeprExpenseACCID] =   T.DeprExpenseACCID
			from (SELECT * FROM ACC_Assets WITH(NOLOCK)) AS T
			WHERE ACC_Assets.AssetID=@retVal AND T.AssetID=@PID  	
			
			INSERT INTO COM_DocBridge([CostCenterID],[NodeID],[AccDocID],[InvDocID],[Abbreviation],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],[RefDimensionID],[RefDimensionNodeID])
			VALUES(@CostCenterID,@InvDocDetID,0,@DOCID,'',@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),72,@retVal)
           
			select @num=@retVal

			declare @LocationDimID int,@LocationDimNodeID INT
			
			EXEC @retVal = [spDOC_SetLinkDimension]
				@InvDocDetailsID=@InvDocDetID, 
				@Costcenterid=@CostCenterID,         
				@DimCCID=72,
				@DimNodeID=@retVal,
				@UserID=@UserID,    
				@LangID=@LangID   

			update ACC_AssetDepSchedule set PurchaseValue=(select PurchaseValue from ACC_Assets with(nolock) where AssetID=@num) where AssetID=@num
			
			declare @DeprEndDate datetime,@DeprStartDate float,@EstimateLife nvarchar(50),@s1 int,@s2 int,@Yrs int,@Mn int,@Days int
			set @Mn=0
			set @Days=0
			select @DeprStartDate=DeprStartDate,@EstimateLife=EstimateLife from ACC_Assets with(nolock) where AssetID=@num
			set @s1=CHARINDEX('.',@EstimateLife)
			if(@s1>0)
			begin
				set @Yrs=SUBSTRING(@EstimateLife,0,@s1)
				set @s2=CHARINDEX('.',@EstimateLife,@s1+1)
				if (@s2>0)
				begin
					set @Mn=SUBSTRING(@EstimateLife,@s1+1,@s2-(@s1+1))
					set @Days=SUBSTRING(@EstimateLife,@s2+1,100)
				end
				else
				begin
					set @Mn=SUBSTRING(@EstimateLife,@s1+1,100)
				end
			end
			else
				set @Yrs=@EstimateLife
			
			set @DeprEndDate=DATEADD(year,@Yrs,convert(datetime,@DeprStartDate))
			set @DeprEndDate=DATEADD(month,@Mn,@DeprEndDate)
			set @DeprEndDate=DATEADD(day,@Days,@DeprEndDate)
	
			update ACC_Assets
			set  DeprEndDate=convert(float,@DeprEndDate)
			WHERE AssetID=@num

			set @LocationDimID=isnull((select convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetLocationDim' and isnumeric(value)=1),0)
			if(@LocationDimID>0)
			begin
				select @LocationDimNodeID=LocationID from ACC_Assets with(nolock) where AssetID=@num
				if(@LocationDimNodeID is not null and @LocationDimNodeID!=0)
					insert into COM_HistoryDetails(CostCenterID,NodeID,HistoryCCID,HistoryNodeID,FromDate,CreatedBy,CreatedDate)
					values(72,@num,1,@LocationDimNodeID,floor(CONVERT(FLOAT,@DT)),@UserName,CONVERT(FLOAT,@DT))
			end
			
			set @LocationDimID=isnull((select top 1 convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetOwner' and isnumeric(value)=1),0)
			if(@LocationDimID>0)
			begin
				select @LocationDimNodeID=EmployeeID from ACC_Assets with(nolock) where AssetID=@num
				if(@LocationDimNodeID is not null and @LocationDimNodeID!=0)
					insert into COM_HistoryDetails(CostCenterID,NodeID,HistoryCCID,HistoryNodeID,FromDate,CreatedBy,CreatedDate)
					values(72,@num,2,@LocationDimNodeID,floor(CONVERT(FLOAT,@DT)),@UserName,CONVERT(FLOAT,@DT))
			end			
			
			if(@isautocode=1)
			BEGIN	
				delete from @Codetemp
									 
				exec [spCom_GetAutCodeXML]  @PrefXml,@num,'AssetID',@SQL output
				
				insert into @Codetemp
				EXEC [spCOM_GetCodeData] 72,@PID,@SQL
				
				select @Code=code,@Prefix= prefix, @retVal=number from @Codetemp
				
				if(@Code is not null)
					update ACC_Assets
					set  AssetCode=@Code,CodePrefix=@Prefix,CodeNumber=@retVal
					WHERE AssetID=@num
			END
			
			exec @retVal =[spCom_ValidateMandatory] 72,@num,@UserID,@LangID
			
			IF(@retVal=-999)
			BEGIN
				ROLLBACK TRANSACTION      
				SET NOCOUNT OFF  
				RETURN -999    
			END
			
			set @LocationDimID=0
			set @LocationDimID=isnull((select convert(int,value) from com_costcenterpreferences WITH(NOLOCK) where CostCenterID=72 and Name='AssetDimension' and isnumeric(value)=1),0)
			if(@LocationDimID>0)
			begin
				
				select @retVal=RefDimensionNodeID from COM_DocBridge WITH(NOLOCK)
				where	CostCenterID=72 and NodeID=@num and RefDimensionID=@LocationDimID
	
				EXEC @retVal = [spDOC_SetLinkDimension]
					@InvDocDetailsID=@num, 
					@Costcenterid=72,         
					@DimCCID=@LocationDimID,
					@DimNodeID=@retVal,
					@UserID=@UserID,    
					@LangID=@LangID   
			END
		END	
     END 
     
     
COMMIT TRANSACTION          
SET NOCOUNT OFF;       
END TRY        
BEGIN CATCH  
	IF(@retVal=-999)
		RETURN -999      
 IF ERROR_NUMBER()=50000      
 BEGIN          
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1      
 END      
 ELSE      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1      
 END      
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
END CATCH
GO
