USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_AssetDisposeReverse]
	@AssetID [int],
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY        
SET NOCOUNT ON;
	declare @HisID INT,@DPScheduleID INT,@CostCenterID int,@DOCID INT, @return_value INT
	select @HisID=HistoryID from ACC_AssetsHistory with(nolock) where AssetManagementID=@AssetID and HistoryTypeID=3 and (PolicyType=1 or PolicyType=3)
	if @HisID is null
	begin
		rollback transaction
		return 0
	end
	
	set @return_value=1
	select @DPScheduleID=max(DPScheduleID) from ACC_AssetDepSchedule with(nolock) where assetid=@AssetID
	if(@DPScheduleID is not null and @DPScheduleID=(select min(DPScheduleID) from ACC_AssetDeprSchTemp with(nolock) where assetid=@AssetID))
	begin
		select @DOCID=DOCID from ACC_AssetDepSchedule with(nolock) where DPScheduleID=@DPScheduleID
		select @COSTCENTERID=CostCenterID from ACC_DocDetails with(nolock) where @DOCID=DocID
		
		EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]    
		@CostCenterID = @COSTCENTERID,@DocPrefix = '',@DocNumber = '', @DOcID=   @DOCID,
		@UserID = 1,@UserName = N'ADMIN',@LangID = 1,@RoleID=1
		
		if @return_value>0
		begin
			delete from ACC_AssetDeprDocDetails where DPScheduleID=@DPScheduleID
		end
	end
	else
		set @DPScheduleID=null	
	
	if @return_value>0
	begin
		select @DOCID=DOCID,@COSTCENTERID=CostCenterID from ACC_AssetsHistory with(nolock) where HistoryID=@HisID
		
		if @DOCID is not null
		begin
			EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]    
			@CostCenterID = @COSTCENTERID,@DocPrefix = '',@DocNumber = '', @DOcID=   @DOCID,
			@UserID = 1,@UserName = N'ADMIN',@LangID = 1,@RoleID=1
		end
		if @return_value>0
		begin
			declare @AssetNetValue float
			set @AssetNetValue=0
			if @DPScheduleID is not null
			begin
				delete from ACC_AssetDepSchedule where DPScheduleID=@DPScheduleID
			end
			select @AssetNetValue=AssetNetValue+DepAmount from ACC_AssetDeprSchTemp with(nolock) where DPScheduleID=@DPScheduleID
			
			update ACC_Assets set AssetNetValue=@AssetNetValue where AssetID=@AssetID
			
			set IDENTITY_INSERT ACC_AssetDepSchedule ON
			insert into ACC_AssetDepSchedule(DPScheduleID,AssetID,DeprStartDate,DeprEndDate,PurchaseValue,DepAmount,AccDepreciation
				,AssetNetValue,DocID,VoucherNo,DocDate,StatusID,ActualDeprAmt,CreatedBy,CreatedDate)
			select DPScheduleID,AssetID,DeprStartDate,DeprEndDate,PurchaseValue,DepAmount,AccDepreciation
				,AssetNetValue,DocID,VoucherNo,DocDate,StatusID,ActualDeprAmt,@UserName,convert(float,getdate())
			from ACC_AssetDeprSchTemp with(nolock) where AssetID=@AssetID
			set IDENTITY_INSERT ACC_AssetDepSchedule OFF
			
			delete from ACC_AssetDeprSchTemp where AssetID=@AssetID
			
			delete from ACC_AssetsHistory where HistoryID=@HisID
			
			--@Cv,@Amt,@AssetNetValue
			insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,Descriptions,LocationID,GUID,CreatedBy,CreatedDate)
			values(@AssetID,5,'Dispose Reversal',1,floor(convert(float,getdate())),0,@AssetNetValue,@AssetNetValue,null,NULL,newid(),@UserName,convert(float,getdate()))
		end
		
	end
/*	
select * from ACC_Assets where AssetID=@AssetID
select * from ACC_AssetsHistory where AssetManagementID=@AssetID
--select * from ACC_AssetChanges where assetid=@AssetID
select * from ACC_AssetDepSchedule where assetid=@AssetID
select * from ACC_AssetDeprSchTemp where assetid=@AssetID
select top 10 * from acc_docdetails with(nolock) order by AccDocDetailsID desc
*/

COMMIT TRANSACTION       
--ROLLBACK TRANSACTION       
     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;  
RETURN @return_value

END TRY        
BEGIN CATCH        
IF ERROR_NUMBER()=50000    
 BEGIN    
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM    
	COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM    
	COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
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
