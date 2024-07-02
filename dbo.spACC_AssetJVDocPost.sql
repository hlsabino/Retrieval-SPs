USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_AssetJVDocPost]
	@AssetID [bigint],
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
SET NOCOUNT ON;  
BEGIN TRANSACTION         
BEGIN TRY     
	DECLARE   @XML XML ,@ScopeID bigint,@DXML XML , @CNT INT , @ICNT INT , @AA XML, @DocXml nvarchar(max) , @return_value BIGINT ,@DT datetime ,@Vendor bigint,@PN nvarchar(50),@Ast bigint
	DECLARE @DEPID BIGINT ,@DEPIDXML XML,  @VOUCHERNO NVARCHAR(200) ,@DocDate float ,@STATUSID INT  , @AssetNetValue FLOAT, @ScheduleID BIGINT,@DoXML xml
	DECLARE @MPSNO NVARCHAR(MAX),@Prefix nvarchar(200),@DT_INT int
	declare @DSVNO nvarchar(200),@DSDOCID bigint,@DSCCID int,@DSName nvarchar(50),
	@DSDocPrefix nvarchar(50),@DSDocNumber nvarchar(500),@DTypeID int,@Cv float,@Amt float,@id bigint,@PV float
	Set @DT=getdate() 

	IF(@TypeID=1)
	BEGIN
		SET @XML = @DocSave  
		select @Vendor=X.value('@VendorID','bigint'),@PN=X.value('@PolicyNo','nvarchar(50)'),@Ast=X.value('@AssetID','nvarchar(50)') from @XML.nodes('/Row') as Data(X)
		
		select * from ACC_AssetsHistory WITH(NOLOCK) where VendorID=@Vendor and PolicyNumber=@PN
		
		if not exists (select * from ACC_AssetsHistory WITH(NOLOCK) where VendorID=@Vendor and PolicyNumber=@PN)
		begin		  
			if(@RecordType='NEW')
			begin
				INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,Vender,VendorID,
				PolicyType,PolicyNumber,Premium,StartDate,EndDate,Coverage,
				GUID,CreatedBy,CreatedDate)        
				SELECT 2,X.value('@AssetID','bigint'),X.value('@Vendor','NVARCHAR(50)'),X.value('@VendorID','bigint'),     
				X.value('@PolicyType','bigint'),  X.value('@PolicyNo','NVARCHAR(50)'),X.value('@Premium','NVARCHAR(50)'),convert(float,X.value('@StartDate','datetime')),convert(float,X.value('@EndDate','datetime')),X.value('@Coverage','NVARCHAR(50)'),        
				newid(),@UserID,convert(float,@Dt)        
				FROM @XML.nodes('/Row') as Data(X)
				set  @ScopeID=scope_identity() 
			END
			ELSE
			BEGIN
				update	ACC_AssetsHistory 
				set Vender=X.value('@Vendor','NVARCHAR(50)'),
					VendorID=X.value('@VendorID','bigint'),
					PolicyType=X.value('@PolicyType','bigint'),
					PolicyNumber=X.value('@PolicyNo','NVARCHAR(50)'),
					Premium=X.value('@Premium','NVARCHAR(50)'),
					StartDate=convert(float,X.value('@StartDate','datetime')),
					EndDate=convert(float,X.value('@EndDate','datetime')),
					Coverage=X.value('@Coverage','NVARCHAR(50)') from @XML.nodes('/Row') as Data(X)
					where HISTORYID=X.value('@HistoryID','bigint')
				set @ScopeID=1
			END
		end
	END
	Else if(@TypeID=2)
	BEGIN	 
		set @DoXML=@DocSave
		IF(@Post = 1)
		BEGIN
			IF(@JVXML is not null and @JVXML<>'')  
		    BEGIN  
				SET @XML = @JVXML  
				set  @DXML=@DocuXML
				if(@DocuXML is not null and @DocuXML<>'') 
				Begin 
					declare @DocUID int,@Amount float,@Date float,@DAccount bigint,@CAccount bigint	,@HistoryID int
								 
					select @DocUID=X.value('@DocID','bigint'),@Amount=X.value('@Amount','Float'),
						@Date=convert(float,X.value('@Date','datetime')),@DAccount=X.value('@DebitAccount','bigint'),
						@CAccount=X.value('@CreditAccount','bigint') 
					from @DXML.nodes('/XML') as Data(X) 
							  
					update acc_docdetails
					set Amount=  @Amount,DocDate=@Date,
					DebitAccount=@DAccount,AmountFC=@Amount
					where DocID=@DocUID and CreditAccount=-99
					
					update acc_docdetails
					set Amount=  @Amount,DocDate=@Date,
					CreditAccount=@CAccount,AmountFC=@Amount
					where DocID=@DocUID and DebitAccount=-99
				END
				ELSE
				BEGIN
					SELECT  @DocXml =  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')) 
					from @XML.nodes('/JVXML/ROWS') as Data(X)   
					set @DT_INT=floor(convert(float,getdate()))
					EXEC [sp_GetDocPrefix] @DocXml,@DT_INT,@COSTCENTERID,@Prefix output 

					EXEC	@return_value = [dbo].[spDOC_SetTempAccDocument]
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
						
					SELECT distinct ACC_DOCDETAILS.VOUCHERNO,ACC_DOCDETAILS.Docdate,ACC_DOCDETAILS.DOCID,ADM_FEATURES.Name DocumentName,ACC_DOCDETAILS.CostCenterID,
					ACC_DOCDETAILS.DocPrefix,ACC_DOCDETAILS.DocNumber  FROM ACC_DOCDETAILS with(nolock)
					Join ADM_FEATURES with(nolock) ON ACC_DOCDETAILS.CostCenterID=ADM_FEATURES.FeatureID
					WHERE DOCID = @return_value 
						
					select @DTypeID=X.value('@HistoryType','bigint') FROM @DoXML.nodes('/XML') as Data(X)
									
					if(@DocSave is not null and @DocSave<>'')
					begin
						SELECT  @DSVNO=ACC_DOCDETAILS.VOUCHERNO,@DSDOCID=ACC_DOCDETAILS.DOCID,
								@DSName=ADM_FEATURES.Name,@DSCCID=ACC_DOCDETAILS.CostCenterID,
								@DSDocPrefix=ACC_DOCDETAILS.DocPrefix,@DSDocNumber=ACC_DOCDETAILS.DocNumber  
						FROM ACC_DOCDETAILS with(nolock)
						Join ADM_FEATURES WITH(NOLOCK) ON ACC_DOCDETAILS.CostCenterID=ADM_FEATURES.FeatureID
						WHERE DOCID = @return_value 
										
						if(@DTypeID=1)
						begin
							if(@RecordType='NEW')
							begin
								INSERT INTO ACC_AssetsHistory(
									HistoryTypeID,
									AssetManagementID,[Date],
									Vender,VendorID,
									NextServiceDate,Remarks,Amount,
									DebitAccount,CreditAccount,
									PostJV,DocID,VoucherNo,CostCenterID,
									DocumentName,DocPrefix,DocNumber,
									GUID,CreatedBy,CreatedDate) 
								SELECT X.value('@HistoryType','bigint'),
									X.value('@AssetID','bigint'),convert(float,X.value('@Date','datetime')) ,
									X.value('@Vendor','NVARCHAR(100)'),X.value('@VendorID','bigint'),     
									convert(float,X.value('@NextStartDate','datetime')),X.value('@Remarks','NVARCHAR(500)') ,X.value('@Amount','Float'),        
									X.value('@DebitAccount','bigint'),X.value('@CreditAccount','bigint'),X.value('@PostJV','int'),
									@DSDOCID,   
									@DSVNO,
									@DSCCID,
									@DSName,
									@DSDocPrefix,
									@DSDocNumber,             
									newid(),@UserID,convert(float,@Dt)
								FROM @DoXML.nodes('/XML') as Data(X)
								set @ScopeID=scope_identity()
							end
							else
							begin
								update ACC_AssetsHistory
								set	 [Date]= convert(float,X.value('@Date','datetime')),
														 Vender= X.value('@Vendor','NVARCHAR(100)'),
														 VendorID=	X.value('@VendorID','bigint'),     
														 NextServiceDate=convert(float,X.value('@NextStartDate','datetime')),
														 Remarks= X.value('@Remarks','NVARCHAR(500)') ,
														 Amount= X.value('@Amount','Float'),      
														 DebitAccount=X.value('@DebitAccount','bigint'),
														 CreditAccount=X.value('@CreditAccount','bigint'),
														 PostJV=X.value('@PostJV','int')
														 from   @DoXML.nodes('/XML') as Data(X)
								where HistoryID=X.value('@HistoryID','int')
								set @ScopeID=1
							end
						end	
						else if(@DTypeID=3)
						BEGIN
							if(@RecordType='NEW')
							begin
								INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,[Date],Amount,CurrentValue,Remarks,PostJV,DebitAccount,CreditAccount,GainAccount,LossAccount,DocID,VoucherNo,GUID,CreatedBy,CreatedDate,CostCenterID,DocumentName,DocPrefix,DocNumber)        
							   SELECT X.value('@HistoryType','bigint'),X.value('@AssetID','bigint'),convert(float,X.value('@Date','datetime')),X.value('@Amount','Float'),X.value('@CurrentValue','Float'),   
							   X.value('@Remarks','NVARCHAR(500)'),X.value('@PostJV','bigint'), X.value('@DebitAccount','bigint'),X.value('@CreditAccount','bigint'),
								X.value('@GainAccount','bigint'),X.value('@LossAccount','bigint'), @DSDOCID,@DSVNO,newid(),@UserID,convert(float,@Dt), 
								@DSCCID, @DSName , @DSDocPrefix, @DSDocNumber        
							   FROM @DoXML.nodes('/XML') as Data(X) 
								set @ScopeID=scope_identity()
							end
							else
							begin
								update ACC_AssetsHistory
								 set [Date]= convert(float,X.value('@Date','datetime')),
									 Amount= X.value('@Amount','Float'), 
									 CurrentValue=X.value('@CurrentValue','Float'),
									 Remarks= X.value('@Remarks','NVARCHAR(500)') ,
									 PostJV=X.value('@PostJV','int'),
									 DebitAccount=X.value('@DebitAccount','bigint'),
									 CreditAccount=X.value('@CreditAccount','bigint'),
									 GainAccount=X.value('@GainAccount','bigint'),
									 LossAccount=X.value('@LossAccount','bigint')  
									 from   @DoXML.nodes('/XML') as Data(X)
									 where HistoryID=X.value('@HistoryID','int')
								set @ScopeID=1
							end
							select   @Cv=X.value('@CurrentValue','Float'),  @Amt=  X.value('@Amount','Float'),@id=X.value('@AssetID','bigint') from	@DoXML.nodes('/XML') as Data(X) 
											   
							 UPDATE ACC_Assets
							 SET AssetNetValue=@Cv-@Amt
							 WHERE  AssetID=@id 
							 
							 insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)
							 values(@AssetID,5,'Dispose',1,convert(float,@DT),@Cv,@Amt,@Cv-@Amt,NULL,newid(),'ADMIN',convert(float,@DT))
	
						END
					end
				END
		 END 
	END
	ELSE
	BEGIN
		select @DTypeID=X.value('@HistoryType','bigint') FROM @DoXML.nodes('/XML') as Data(X)
		if(@DocSave is not null and @DocSave<>'')
		begin
			if(@DTypeID=1)
			begin
				if(@RecordType='NEW')
				begin
					INSERT INTO ACC_AssetsHistory(
						HistoryTypeID,
						AssetManagementID,
						[Date],
						Vender,
						VendorID,
						NextServiceDate,
						Remarks,
						Amount,
						DebitAccount,
						CreditAccount,
						PostJV,GUID,CreatedBy,CreatedDate) 						    
						SELECT 
						X.value('@HistoryType','bigint'),
						X.value('@AssetID','bigint'),
						convert(float,X.value('@Date','datetime')) ,
						X.value('@Vendor','NVARCHAR(100)'),
						X.value('@VendorID','bigint'),     
						convert(float,X.value('@NextStartDate','datetime')),
						X.value('@Remarks','NVARCHAR(500)') ,
						X.value('@Amount','Float'),        
						X.value('@DebitAccount','bigint'),
						X.value('@CreditAccount','bigint'),
						X.value('@PostJV','int'),newid(),@UserID,convert(float,@Dt)
						FROM @DoXML.nodes('/XML') as Data(X)
						set @ScopeID=scope_identity()
				end
				else
				begin
					update ACC_AssetsHistory
					set	 [Date]= convert(float,X.value('@Date','datetime')),
							 Vender= X.value('@Vendor','NVARCHAR(100)'),
							 VendorID=	X.value('@VendorID','bigint'),     
							 NextServiceDate=convert(float,X.value('@NextStartDate','datetime')),
							 Remarks= X.value('@Remarks','NVARCHAR(500)') ,
							 Amount= X.value('@Amount','Float'),      
							 DebitAccount=X.value('@DebitAccount','bigint'),
							 CreditAccount=X.value('@CreditAccount','bigint'),
							 PostJV=X.value('@PostJV','int')
							 from   @DoXML.nodes('/XML') as Data(X)
							 where HistoryID=X.value('@HistoryID','int')
						set @ScopeID=1
				end
			end
			else if(@DTypeID=3)
			BEGIN
				--DISPOSE ADD/EDIT
				
				select @Cv=X.value('@CurrentValue','Float'),@Amt=X.value('@Amount','Float'),@PV=X.value('@PurchaseValue','FLOAT')
				,@id=X.value('@AssetID','bigint'),@DocDate=convert(float,X.value('@Date','datetime'))
				from @DoXML.nodes('/XML') as Data(X) 
				   
				UPDATE ACC_Assets
				SET AssetNetValue=@Cv-@Amt
				WHERE  AssetID=@id 

				if(@RecordType='NEW')
				begin
					INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,[Date],Amount,PolicyType,CurrentValue,Remarks,PostJV,DebitAccount,CreditAccount,GainAccount,LossAccount,GUID,CreatedBy,CreatedDate)        
					SELECT X.value('@HistoryType','bigint'),X.value('@AssetID','bigint'),convert(float,X.value('@Date','datetime')),X.value('@Amount','Float')
						,X.value('@Type','INT'),X.value('@CurrentValue','Float'),   
					   X.value('@Remarks','NVARCHAR(500)'),X.value('@PostJV','bigint'), X.value('@DebitAccount','bigint'),X.value('@CreditAccount','bigint'),
						X.value('@GainAccount','bigint'),X.value('@LossAccount','bigint'),newid(),@UserID,convert(float,@Dt) 
					FROM @DoXML.nodes('/XML') as Data(X) 
					set @ScopeID=scope_identity()
					
					insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,Descriptions,LocationID,GUID,CreatedBy,CreatedDate)
					values(@AssetID,5,'Dispose',1,@DocDate,@Cv,@Amt,@Cv-@Amt,@ScopeID,NULL,newid(),'ADMIN',convert(float,@DT))
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
						 ModifiedBy=@UserID,ModifiedDate=convert(float,@DT)
					from   @DoXML.nodes('/XML') as Data(X)
					where HistoryID=X.value('@HistoryID','int')
					set @ScopeID=1
					
					update ACC_AssetChanges
					set ChangeDate=@DocDate,AssetOldValue=@Cv,ChangeValue=@Amt,AssetNewValue=@Cv-@Amt
						,ModifiedBy=@UserID,ModifiedDate=convert(float,@DT)
					from @DoXML.nodes('/XML') as Data(X)
					where AssetID=@AssetID and Descriptions=X.value('@HistoryID','int')
				end
				
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
						from ACC_AssetDepSchedule A inner join @DepXML.nodes('/Row') as data(x) on A.DPScheduleID=x.value('@ScheduleID','bigint')  
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
						@UserID,convert(float,@Dt),X.value('@ActDepAmt','FLOAT')
						FROM @DepXML.nodes('/XML/Row') as Data(X)
					END
				END
				
				
			END
		end
	END
END	
ELSE	 
BEGIN
	SELECT   dep.DPScheduleID ScheduleID,  CONVERT(DATETIME, dep.DeprStartDate ) AS FromDate
      ,CONVERT(DATETIME, dep.DeprEndDate ) AS ToDate
      , dep.PurchaseValue 
      , dep.DepAmount AS DeprAmt 
      , dep.AccDepreciation AS accmDepr 
      , dep.AssetNetValue AS NetValue
      ,dep.DocID 
      ,dep.VoucherNo 
      ,dep.DocDate 
      , Sts.status StatusID 
      ,dep.CreatedBy 
      ,dep.CreatedDate 
      ,dep.ModifiedBy 
      ,dep.ModifiedDate   
      ,accdoc.CostCenterID CostCenterID
      ,accdoc.DocPrefix  DocPrefix
       ,accdoc.DocNumber  DocNumber
       , ADF.DocumentName DocumentName  
      FROM  [ACC_AssetDepSchedule] dep WITH(NOLOCK)
      LEFT JOIN Com_Status Sts WITH(NOLOCK) on  Sts.StatusID =  dep.StatusID  
       LEFT JOIN acc_docdetails accdoc WITH(NOLOCK) on dep.docid = accdoc.docid  and accdoc.docseqno = 1 
       LEFT join ADM_DocumentTypes ADF WITH(NOLOCK) on accdoc.CostCenterID = ADF.CostCenterID  
      where AssetID=@AssetID  order by CONVERT(DATETIME, DeprStartDate ) asc 
END
 
COMMIT TRANSACTION          
-- ROLLBACK TRANSACTION             
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
