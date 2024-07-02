USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_AssetDispose]
	@AssetID [bigint],
	@DisposeDate [datetime],
	@COSTCENTERID [bigint],
	@JVXML [nvarchar](max) = NULL,
	@Post [bit],
	@TypeID [int],
	@DocuXML [nvarchar](max) = NULL,
	@DocSave [nvarchar](max) = NULL,
	@AssetDepreciationXML [nvarchar](max) = null,
	@RecordType [nvarchar](50),
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
	DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100)    
BEGIN TRY        
	SET NOCOUNT ON;
	DECLARE   @XML XML ,@ScopeID bigint,@DXML XML , @AA XML, @DocXml nvarchar(max) , @return_value BIGINT ,@DT datetime ,@Vendor bigint,@PN nvarchar(50),@Ast bigint
	DECLARE @DEPID BIGINT ,@DEPIDXML XML,  @VOUCHERNO NVARCHAR(200) ,@DocDate float ,@STATUSID INT,@AccDepr float,@AssetNetValue FLOAT, @ScheduleID BIGINT,@DisposeXML xml
	DECLARE @MPSNO NVARCHAR(MAX),@CDate float,@Prefix nvarchar(200) ,@i int,@Cnt int,@DeprSchID bigint,@NetVal float
	declare @DSVNO nvarchar(200),@DSDOCID bigint,@DSCCID int,@DSName nvarchar(50),@DTTime float,@DisposeType int,
	@DSDocPrefix nvarchar(50),@DSDocNumber nvarchar(500),@DTypeID bigint,@Cv float,@Amt float,@id bigint,@PV float,@DT_INT int
	Set @DTTime=convert(float,getdate())
	Set @DT=floor(@DTTime)

	IF(@TypeID=2)--DISPOSE ADD/EDIT
	BEGIN
		set @DisposeXML=@DocSave
		select @Cv=X.value('@CurrentValue','Float'),@Amt=X.value('@Amount','Float'),@PV=X.value('@PurchaseValue','FLOAT')
				,@id=X.value('@AssetID','bigint'),@CDate=convert(float,X.value('@Date','datetime')),@DisposeType=X.value('@Type','INT')
		from @DisposeXML.nodes('/XML') as Data(X)
		
		if(@DisposeType=1 or @DisposeType=3 or (@DisposeType=0 and @Cv-@Amt<0))
			set @AssetNetValue=0
		else
			set @AssetNetValue=@Cv-@Amt

		UPDATE ACC_Assets SET AssetNetValue=@AssetNetValue WHERE  AssetID=@id 
		--Hold Schedule In Temp Table
		if(@DisposeType=1 or @DisposeType=3)
		begin
			insert into ACC_AssetDeprSchTemp(DPScheduleID,AssetID,DeprStartDate,DeprEndDate,PurchaseValue,DepAmount,AccDepreciation
				,AssetNetValue,DocID,VoucherNo,DocDate,StatusID,ActualDeprAmt)
			select DPScheduleID,AssetID,DeprStartDate,DeprEndDate,PurchaseValue,DepAmount,AccDepreciation
				,AssetNetValue,DocID,VoucherNo,DocDate,StatusID,ActualDeprAmt 
			from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DocID is null --and @DisposeDate<=DeprStartDate
		end

		if(@RecordType='NEW')
		begin
			INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,[Date],Amount,PolicyType,CurrentValue,Remarks,PostJV,DebitAccount,CreditAccount,GainAccount,LossAccount,DisposeClearingAccount,GUID,CreatedBy,CreatedDate)        
			SELECT X.value('@HistoryType','bigint'),X.value('@AssetID','bigint'),convert(float,X.value('@Date','datetime')),X.value('@Amount','Float')
				,X.value('@Type','INT'),X.value('@CurrentValue','Float'),   
			   X.value('@Remarks','NVARCHAR(500)'),X.value('@PostJV','bigint'), X.value('@DebitAccount','bigint'),X.value('@CreditAccount','bigint'),
				X.value('@GainAccount','bigint'),X.value('@LossAccount','bigint'),X.value('@LossAccount','bigint'),
				newid(),@UserID,@DTTime
			FROM @DisposeXML.nodes('/XML') as Data(X) 
			set @ScopeID=scope_identity()
			
			insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,Descriptions,LocationID,GUID,CreatedBy,CreatedDate)
			values(@AssetID,5,'Dispose',1,@CDate,@Cv,@Amt,@AssetNetValue,@ScopeID,NULL,newid(),'ADMIN',@DTTime)
		end
		else
		begin
			update ACC_AssetsHistory
			set [Date]= convert(float,X.value('@Date','datetime')),
				Amount= X.value('@Amount','Float'), 
				 PolicyType= X.value('@Type','INT'),
				 CurrentValue=X.value('@CurrentValue','Float'),
				 Remarks= X.value('@Remarks','NVARCHAR(500)') ,
				 PostJV=X.value('@PostJV','int'),
				 DebitAccount=X.value('@DebitAccount','bigint'),
				 CreditAccount=X.value('@CreditAccount','bigint'),
				 GainAccount=X.value('@GainAccount','bigint'),
				 LossAccount=X.value('@LossAccount','bigint'),
				 DisposeClearingAccount=X.value('@LossAccount','bigint'),
				 ModifiedBy=@UserID,ModifiedDate=@DTTime
			from   @DisposeXML.nodes('/XML') as Data(X)
			where HistoryID=X.value('@HistoryID','int')
			set @ScopeID=1
			
			update ACC_AssetChanges
			set ChangeDate=@CDate,AssetOldValue=@Cv,ChangeValue=@Amt,AssetNewValue=@AssetNetValue
				,ModifiedBy=@UserID,ModifiedDate=@DTTime
			from @DisposeXML.nodes('/XML') as Data(X)
			where AssetID=@AssetID and Descriptions=X.value('@HistoryID','int')
		end
		--Depreciation changes
		IF (@AssetDepreciationXML IS NOT NULL AND @AssetDepreciationXML <> '')          
		BEGIN
			declare @DepXML xml
			SET @DepXML=@AssetDepreciationXML     
			IF EXISTS(select ASSETID from ACC_AssetDepSchedule with(nolock) where ASSETID=@AssetID)
			BEGIN
				 update ACC_AssetDepSchedule       
				 set DepAmount=X.value('@DepAmt','FLOAT'),
					 AccDepreciation=X.value('@AccDep','FLOAT'),
					 AssetNetValue=X.value('@NetValue','FLOAT')
				from ACC_AssetDepSchedule A inner join @DepXML.nodes('/XML/Row') as data(x) on A.DPScheduleID=x.value('@ScheduleID','bigint')  
				where x.value('@ScheduleID','bigint') is not null    
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
				X.value('@AccDep','FLOAT') ,   X.value('@NetValue','FLOAT') ,@PV,NULL,NULL,NULL,ISNULL(X.value('@StatusID','INT'), 0),           
				@UserID,@DTTime,X.value('@ActDepAmt','FLOAT')
				FROM @DepXML.nodes('/XML/Row') as Data(X)
			END
		END
		
		
		IF(@Post = 1 and @JVXML is not null and @JVXML<>'')
		BEGIN
			SET @XML = @JVXML
			
			/******** FOR EDIT PENDING ************/
			--if(@DocuXML is not null and @DocuXML<>'') 
			--Begin 
			--	declare @DocUID int,@Amount float,@Date float,@DAccount bigint,@CAccount bigint	,@HistoryID int
							 
			--	select @DocUID=X.value('@DocID','bigint'),@Amount=X.value('@Amount','Float'),
			--		@Date=convert(float,X.value('@Date','datetime')),@DAccount=X.value('@DebitAccount','bigint'),
			--		@CAccount=X.value('@CreditAccount','bigint') 
			--	from @DepXML.nodes('/XML') as Data(X) 
						  
			--	update acc_docdetails
			--	set Amount=  @Amount,DocDate=@Date,
			--	DebitAccount=@DAccount,AmountFC=@Amount
			--	where DocID=@DocUID and CreditAccount=-99
				
			--	update acc_docdetails
			--	set Amount=  @Amount,DocDate=@Date,
			--	CreditAccount=@CAccount,AmountFC=@Amount
			--	where DocID=@DocUID and DebitAccount=-99
			--END
			
			declare @TblJV as table(ID INT IDENTITY(1,1),DocumentXML NVARCHAR(MAX),DeprSchID bigint,Amount float,AccDepr float,Net float)
			insert into @TblJV
			SELECT CONVERT(NVARCHAR(MAX), X.query('DocumentXML'))
			,X.value('@ScheduleID','bigint'),X.value('@Amount','float'),X.value('@AccDepr','float'),X.value('@Net','float')
			from @XML.nodes('/JVXML/ROWS') as Data(X)   
				
			select @i=1,@Cnt=count(*) from @TblJV
			while(@i<=@Cnt)
			begin
				SELECT @DocXml=DocumentXML,@DeprSchID=DeprSchID,@Amt=Amount,@AccDepr=AccDepr,@AssetNetValue=Net from @TblJV where ID=@i
				
				set @DT_INT=floor(convert(float,@DisposeDate))
				
				if(@DeprSchID is not null)
				begin
					if 'ScheduleDate'=(select Value from com_costcenterpreferences with(nolock) where costcenterid=72 and Name='AssetDeprPostDate')
						select @DT_INT=floor(convert(float,@DisposeDate))-1
				end
				
				EXEC [sp_GetDocPrefix] @DocXml,@DT_INT,@COSTCENTERID,@Prefix output 
				
				EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]
					@CostCenterID = @COSTCENTERID,
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
					@UserName = @UserName,
					@UserID = @UserID,
					@LangID = @LangID
			
				if(@DeprSchID is not null)
				begin
					SELECT @VOUCHERNO=VoucherNo,@DocDate=DocDate,@STATUSID=STATUSID FROM ACC_DOCDETAILS with(nolock)
					where costcenterid=@COSTCENTERID and docid=@return_value         
					
					UPDATE  ACC_AssetDepSchedule  
					SET DOCID=@return_value,VOUCHERNO=@VOUCHERNO,Docdate=@DocDate,STATUSID=@STATUSID
						,DepAmount=@Amt,DeprEndDate=floor(convert(float,@DisposeDate))-1,AccDepreciation=@AccDepr,AssetNetValue=@AssetNetValue
					WHERE DPScheduleID=@DeprSchID
					
					--select * from ACC_AssetDepSchedule where assetid=@AssetID
				end
				else
				begin
					SELECT distinct D.VOUCHERNO,D.Docdate,D.DOCID,F.Name DocumentName,D.CostCenterID,
					D.DocPrefix,D.DocNumber  FROM ACC_DOCDETAILS D with(nolock)
					Left Join ADM_FEATURES F with(nolock) ON D.CostCenterID=F.FeatureID
					WHERE DOCID=@return_value
					
					update ACC_AssetsHistory
					set DocID=T.DOCID,VoucherNo=T.VOUCHERNO,CostCenterID=T.CostCenterID,DocumentName=T.DocumentName
					,DocPrefix=T.DocPrefix,DocNumber=T.DocNumber
					from 
					(SELECT distinct D.VOUCHERNO,D.Docdate,D.DOCID,F.Name DocumentName,D.CostCenterID,
						D.DocPrefix,D.DocNumber  FROM ACC_DOCDETAILS D with(nolock)
						Left Join ADM_FEATURES F with(nolock) ON D.CostCenterID=F.FeatureID
						WHERE DOCID=@return_value
					) as T, ACC_AssetsHistory
					where HistoryID=@ScopeID
				end
			
				set @i=@i+1
			END
		END
		
		--Hold Schedule In Temp Table
		if(@DisposeType=1 or @DisposeType=3)
		begin
			delete from ACC_AssetDepSchedule where AssetID=@AssetID and DocID is null -- and @DisposeDate<=DeprStartDate
		end
		
	END--END OF DISPOSE
--select * from ACC_AssetDepSchedule where assetid=@AssetID
--select * from acc_docdetails with(nolock)

COMMIT TRANSACTION       
--ROLLBACK TRANSACTION       
     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;  
RETURN @ScopeID

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
