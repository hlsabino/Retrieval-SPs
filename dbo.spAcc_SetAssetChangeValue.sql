USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAcc_SetAssetChangeValue]
	@AssetID [int],
	@Type [int],
	@ChangeValue [int],
	@AssetNetValue [int],
	@ChangeDate [datetime],
	@Remarks [nvarchar](200) = null,
	@AssetDepreciationXML [nvarchar](max) = null,
	@ChangeValueXML [nvarchar](max) = null,
	@HistoryXML [nvarchar](max) = null,
	@LocationID [int] = null,
	@IsIncreaseAssetValue [bit],
	@PostingXML [nvarchar](max) = null,
	@ChangeValueTypeID [int],
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@CreatedBy [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION          
BEGIN TRY          
SET NOCOUNT ON;        
        
    DECLARE @Dt FLOAT,@DTTime float,@DeprStartValue float,@DocXml nvarchar(max) ,  @return_value INT,  
    @PrefValue NVARCHAR(500), @XML XML,@DepXML XML,@Prefix nvarchar(200) 
          
	Set @DTTime=convert(float,getdate())
	Set @DT=floor(@DTTime)
          
	select @DeprStartValue = isnull(DeprStartValue,0) from ACC_Assets with(nolock) where  AssetID=@AssetID    
	--select * from ACC_Assets  

	update ACC_Assets         
	set LocationID= @LocationID  
		, AssetNetValue = @AssetNetValue  
		--, PurchaseValue = @DeprStartValue +  @ChangeValue   
		, Description = @Remarks  
		,ModifiedBy = @CreatedBy  
		,ModifiedDate = @DTTime       
	 where AssetID=@AssetID       
       
	IF (@AssetDepreciationXML IS NOT NULL AND @AssetDepreciationXML <> '')          
	BEGIN          
		SET @DepXML=@AssetDepreciationXML
		if @Type=25
		begin
			DELETE  FROM [ACC_AssetDepSchedule] WHERE ASSETID = @AssetID AND DOCID IS NULL AND VOUCHERNO IS NULL AND STATUSID = 0   
			
			INSERT INTO  [ACC_AssetDepSchedule]
			   ([AssetID]    
			   ,[DeprStartDate]    
			   ,[DeprEndDate]    
			   ,[DepAmount]    
			   ,[AccDepreciation]    
			   ,[AssetNetValue]    
			   ,[PurchaseValue]    
			   ,[DocID],[VoucherNo],[DocDate]
			   ,[StatusID],[CreatedBy],[CreatedDate]
			   ,ActualDeprAmt)    
			SELECT @AssetID, convert(float,X.value('@From','datetime')) ,convert(float,X.value('@To','datetime')) ,X.value('@DepAmt','FLOAT') ,     
				X.value('@AccDep','FLOAT') ,   X.value('@NetValue','FLOAT') ,@DeprStartValue ,NULL,NULL,NULL,ISNULL(X.value('@StatusID','INT'), 0),           
				@CreatedBy,@DTTime,X.value('@ActDepAmt','FLOAT')
			FROM @DepXML.nodes('/XML/Row') as Data(X)
			where x.value('@ScheduleID','INT') is null 

			--select * from ACC_AssetDepSchedule where assetid=@AssetID
		end
		else
		begin
			IF EXISTS(select ASSETID from ACC_AssetDepSchedule with(nolock) where ASSETID=@AssetID)
			BEGIN
				 update ACC_AssetDepSchedule       
				 set DepAmount=X.value('@DepAmt','FLOAT'),
					 AccDepreciation=X.value('@AccDep','FLOAT'),
					 AssetNetValue=X.value('@NetValue','FLOAT')
				from ACC_AssetDepSchedule A inner join @DepXML.nodes('/XML/Row') as data(x) on A.DPScheduleID=x.value('@ScheduleID','INT')  
				where x.value('@ScheduleID','INT') is not null    
			END
			ELSE
			BEGIN
				--DELETE  FROM [ACC_AssetDepSchedule] WHERE ASSETID = @AssetID AND DOCID IS NULL AND VOUCHERNO IS NULL AND STATUSID = 0   
				INSERT INTO  [ACC_AssetDepSchedule]
			   ([AssetID]    
			   ,[DeprStartDate]    
			   ,[DeprEndDate]    
			   ,[DepAmount]    
			   ,[AccDepreciation]    
			   ,[AssetNetValue]    
			   ,[PurchaseValue]    
			   ,[DocID],[VoucherNo],[DocDate]
			   ,[StatusID],[CreatedBy],[CreatedDate]
			   ,ActualDeprAmt)    
				SELECT @AssetID, convert(float,X.value('@From','datetime')) ,convert(float,X.value('@To','datetime')) ,X.value('@DepAmt','FLOAT') ,     
				X.value('@AccDep','FLOAT') ,   X.value('@NetValue','FLOAT') ,@DeprStartValue ,NULL,NULL,NULL,ISNULL(X.value('@StatusID','INT'), 0),           
				@CreatedBy,@DTTime,X.value('@ActDepAmt','FLOAT')
				FROM @DepXML.nodes('/XML/Row') as Data(X)
			END
		end
	END    
    
	IF (@ChangeValueXML IS NOT NULL AND @ChangeValueXML <> '')          
    BEGIN          
		SET @XML=@ChangeValueXML

		--select * from ACC_AssetChanges   
		--If Action is NEW then insert new Changes        
		INSERT INTO ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,          
		AssetOldValue,ChangeValue,AssetNewValue,          
		LocationID,GUID,CreatedBy,CreatedDate)          
		SELECT @AssetID,X.value('@ChangeType','int'),X.value('@ChangeName','NVARCHAR(50)'),          
		X.value('@StatusID','INT'),convert(float,X.value('@ChangeDate','datetime')),X.value('@AssetOldValue','float'),          
		X.value('@ChangeValue','nvarchar(50)'),X.value('@AssetNewValue','float'),X.value('@LocationID','INT'),          
		newid(),@CreatedBy,@DTTime          
		FROM @XML.nodes('/ChangeValueXML/Row') as Data(X) 

		if @Type=25
		begin
			SELECT @DocXml='update Acc_Assets set EstimateLife='''+X.value('@NewEsitmateLife','NVARCHAR(50)')+'''
			,DeprEndDate='+convert(nvarchar,convert(int,X.value('@NewEsitmateEndDate','datetime')))+' where AssetId='+convert(nvarchar,@AssetID)
			FROM @XML.nodes('/ChangeValueXML/Row') as Data(X) 
			print(@DocXml)
			exec(@DocXml)
		end
		
		if(@ChangeValueTypeID=0 or	@ChangeValueTypeID=2)
		begin		 
			update Acc_Assets set AssetNetValue=@ChangeValue+@AssetNetValue where AssetId=@AssetID
		end
		else if(@ChangeValueTypeID=1 or @ChangeValueTypeID=3) 
		begin
			update Acc_Assets set AssetNetValue=@AssetNetValue+@ChangeValue where AssetId=@AssetID
		end
		
		select * FROM ACC_AssetChanges with(nolock) WHERE AssetID=@AssetID
    END    
          
	/*IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')          
	BEGIN          
  
		SET @XML=@HistoryXML          
		if exists(select * from ACC_AssetsHistory WHERE AssetManagementID=@AssetID)      
			DELETE FROM ACC_AssetsHistory WHERE AssetManagementID=@AssetID      

		 --If Action is NEW then insert new Changes        
		 INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,[Date],Vender,VendorID,NextServiceDate,Remarks,Amount,DebitAccount,CreditAccount,PostJV,GUID,CreatedBy,CreatedDate)          
		 SELECT X.value('@HistoryType','INT'),@AssetID,convert(float,X.value('@Date','datetime')) ,X.value('@Vendor','NVARCHAR(50)'),X.value('@VendorID','INT'),       
		 convert(float,X.value('@NextStartDate','datetime')),X.value('@Remarks','NVARCHAR(500)') ,X.value('@Amount','Float'),          
		 X.value('@DebitAccount','INT'),X.value('@CreditAccount','INT'),X.value('@PostJV','INT'),          
		 newid(),@CreatedBy,@DTTime          
		 FROM @XML.nodes('/XML/MaintenanceGrid/Rows') as Data(X)         
	            
		 INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,Vender,VendorID,PolicyType,PolicyNumber,StartDate,EndDate,Coverage,GUID,CreatedBy,CreatedDate)          
		 SELECT X.value('@HistoryType','INT'),@AssetID,X.value('@Vendor','NVARCHAR(50)'),X.value('@VendorID','INT'),       
		 X.value('@PolicyType','INT'),X.value('@PolicyNumber','NVARCHAR(50)'),convert(float,X.value('@StartDate','datetime')),  
		 convert(float,X.value('@EndDate','datetime')),X.value('@Coverage','NVARCHAR(50)'),          
		 newid(),@CreatedBy,@DTTime          
		 FROM @XML.nodes('/XML/InsuranceGrid/Rows') as Data(X)     
	       
		 INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,[Date],Amount,CurrentValue,Remarks,DebitAccount,CreditAccount,GainAccount,LossAccount,GUID,CreatedBy,CreatedDate)          
		 SELECT X.value('@HistoryType','INT'),@AssetID,convert(float,X.value('@Date','datetime')),X.value('@Amount','Float'),X.value('@CurrentValue','Float'),     
		 X.value('@Remarks','NVARCHAR(500)'), X.value('@DebitAccount','INT'),X.value('@CreditAccount','INT'),  
		 X.value('@GainAccount','INT'),X.value('@LossAccount','INT'),newid(),@CreatedBy,@DTTime          
		 FROM @XML.nodes('/XML/DisposeGrid/Rows') as Data(X)     
    END*/
    
    if( @IsIncreaseAssetValue = 1)
    BEGIN
		select @PrefValue = Value from COM_CostCenterPreferences with(nolock) where CostCenterID=72 and  Name = 'IncreaseAssetJV'
	END 
	ELSE
	BEGIN
		select   @PrefValue = Value from COM_CostCenterPreferences with(nolock) where CostCenterID=72 and  Name = 'DecreaseAssetJV'
	END
	
	if(@PrefValue is not null and @PrefValue<>'' and @PostingXML is not null and @PostingXML <> '' and @Type!=25)
	begin
		declare @DT_INT int
		
		set @XML = @PostingXML
		SELECT  @DocXml = CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')) from @XML.nodes('/JVXML/ROWS') as Data(X)      
		
		
		set @Prefix=''
		set @DT_INT=floor(convert(float,@ChangeDate))

		EXEC [sp_GetDocPrefix] @DocXml,@DT_INT,@PrefValue,@Prefix output 
		
		EXEC	@return_value = [dbo].[spDOC_SetTempAccDocument]
			@CostCenterID = @PrefValue,
			@DocID = 0,
			@DocPrefix = @Prefix,
			@DocNumber = N'',
			@DocDate = @DT_INT,
			@DueDate =NULL,
			@BillNo = NULL,
			@InvDocXML = @DocXml,
			@NotesXML =  N'',
			@AttachmentsXML =  N'',
			@ActivityXML = N'',
			@IsImport = 0,
			@LocationID = 1,
			@DivisionID = 1,
			@WID = 0,
			@RoleID = 1,
			@RefCCID = 72,
			@RefNodeid =@AssetID ,
			@CompanyGUID = @CompanyGUID,
			@UserName = @CreatedBy,
			@UserID = @UserID,
			@LangID = @LangID
	end
      
COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SET NOCOUNT OFF;         
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)         
WHERE ErrorNumber=100 AND LanguageID=1          
RETURN 1        
END TRY          
BEGIN CATCH          
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
