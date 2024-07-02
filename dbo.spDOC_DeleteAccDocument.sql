USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_DeleteAccDocument]
	@CostCenterID [int],
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@DocID [int],
	@LockWhere [nvarchar](max) = '',
	@sysinfo [nvarchar](max) = '',
	@AP [varchar](10) = '',
	@UserID [int] = 0,
	@UserName [nvarchar](100),
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
  --Declaration Section    
  DECLARE @HasAccess bit,@VoucherNo nvarchar(200),@PrefValue NVARCHAR(500),@NodeID INT ,@DocDate datetime,@PrePayment INT ,@DocType int
  DECLARE @sql nvarchar(max),@tablename nvarchar(200),@CurrentNo INT,@IsLineWisePDC bit,@CrossDimension bit,@return_value int
  declare @AccDocID INT,@DELETECCID INT,@delcnt int,@deli int,@DeleteDOcid INT,@CompanyGUID nvarchar(200)			
  declare @ttdel table(id int identity(1,1),docid INT,CCID INT)  
  
	--SP Required Parameters Check
	IF(@CostCenterID<40000 or (@DocNumber='' and (@DocID is null or @DocID=0)))
	BEGIN
		RAISERROR('-100',16,1)
	END


	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,4)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
	if(@DocID>0)
		SELECT @DocDate=convert(datetime,DocDate),@VoucherNo=VoucherNo,@DocPrefix=DocPrefix,@DocNumber=DocNumber,@DocType=Documenttype FROM [ACC_DocDetails] with(nolock)
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID 
	ELSE
		SELECT @DocDate=convert(datetime,DocDate),@VoucherNo=VoucherNo,@DocID=DocID,@DocType=Documenttype FROM [ACC_DocDetails] with(nolock)
		WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber
		
	IF @VoucherNo IS NULL
	BEGIN
		COMMIT TRANSACTION         
		SET NOCOUNT OFF;  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=102 AND LanguageID=@LangID  
		RETURN 1	
	END


DECLARE @DLockFromDate DATETIME,@DLockToDate DATETIME,@DAllowLockData BIT ,@DLockCC INT  
 DECLARE @LockFromDate DATETIME,@LockToDate DATETIME,@AllowLockData BIT,@LockCC INT,@LockCCValues nvarchar(max)     
    
 SELECT @AllowLockData=CONVERT(BIT,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='Lock Data Between'       
 SELECT @DAllowLockData=CONVERT(BIT,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='Lock Data Between'  
   
 if(dbo.fnCOM_HasAccess(@RoleID,43,193)=0 and (SELECT PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='OverrideLock')<>'true')  
 BEGIN  
  IF (@AllowLockData=1)  
  BEGIN   
   SELECT @LockFromDate=CONVERT(DATETIME,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='LockDataFromDate'      
   SELECT @LockToDate=CONVERT(DATETIME,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='LockDataToDate'      
   SELECT @LockCC=CONVERT(INT,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='LockCostCenters' and isnumeric(Value)=1  
  
   if(@DocDate BETWEEN @LockFromDate AND @LockToDate)  
   BEGIN  
     if(@LockCC is null or @LockCC=0)  
		RAISERROR('-125',16,1)    
     else if(@LockCC>50000)  
     BEGIN  
       SELECT @LockCCValues=CONVERT(INT,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='LockCostCenterNodes'  
  
      set @LockCCValues= rtrim(@LockCCValues)  
      set @LockCCValues=substring(@LockCCValues,0,len(@LockCCValues)- charindex(',',reverse(@LockCCValues))+1)  
  
      set @sql ='if exists (select a.AccDocDetailsID FROM  [COM_DocCCData] a  
      join [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID  
      WHERE b.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND b.docid='+convert(nvarchar,@DocID)+' and a.dcccnid'+convert(nvarchar,(@LockCC-50000))+' in('+@LockCCValues+'))  
      RAISERROR(''-125'',16,1)  '  
      exec(@sql)  
     END  
   END      
  END  
  
  if(dbo.fnCOM_HasAccess(@RoleID,43,193)=0 and @LockWhere <>'')
  BEGIN
	  if(@LockWhere like '<XML%')
		BEGIN
					declare @xml xml
					set @xml=@LockWhere					
					select @LockWhere=isnull(X.value('@where','nvarchar(max)'),''),@LockCCValues=isnull(X.value('@join','nvarchar(max)'),'')
					from @xml.nodes('/XML') as Data(X)    		         
					  set @sql ='if exists (select a.CostCenterID from Acc_DocDetails a WITH(NOLOCK)
					join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
					join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1 '+@LockCCValues+'
					where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
					RAISERROR(''-125'',16,1)  '  
		END
		ELSE
		BEGIN
		  set @sql ='if exists (select a.CostCenterID from Acc_DocDetails a WITH(NOLOCK)
				join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
				join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1 
				where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
				RAISERROR(''-125'',16,1)  ' 
		END		 
      exec(@sql)
  END
    
  IF (@DAllowLockData=1)  
  BEGIN  
   SELECT @DLockFromDate=CONVERT(DATETIME,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='LockDataFromDate'  
   SELECT @DLockToDate=CONVERT(DATETIME,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='LockDataToDate'  
   SELECT @DLockCC=CONVERT(INT,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='LockCostCenters' and isnumeric(PrefValue)=1  
    
   if(@DocDate BETWEEN @DLockFromDate AND @DLockToDate)  
   BEGIN  
    if(@DLockCC is null or @DLockCC=0)  
		RAISERROR('-125',16,1)    
     else if(@DLockCC>50000)  
     BEGIN  
		  SELECT @LockCCValues=CONVERT(INT,PrefValue) FROM COM_DocumentPreferences with(nolock) WHERE CostCenterID=@CostCenterID and  PrefName='LockCostCenterNodes'  
	  
		  set @LockCCValues= rtrim(@LockCCValues)  
		  set @LockCCValues=substring(@LockCCValues,0,len(@LockCCValues)- charindex(',',reverse(@LockCCValues))+1)  
	  
		  set @sql ='if exists (select a.AccDocDetailsID FROM  [COM_DocCCData] a with(nolock) 
		  join [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID  
		  WHERE b.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND b.docid='+convert(nvarchar,@DocID)+' and a.dcccnid'+convert(nvarchar,(@DLockCC-50000))+' in('+@LockCCValues+'))  
		  RAISERROR(''-125'',16,1)  '  
		  exec(@sql)  
     END   
   END         
  END  
 END  
--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA
DECLARE @AuditTrial BIT,@dt FLOAT
SET @AuditTrial=0
SELECT @AuditTrial=CONVERT(BIT,PrefValue) FROM [COM_DocumentPreferences] with(nolock)
WHERE CostCenterID=@CostCenterID AND PrefName='AuditTrial'

SET @dt=CONVERT(FLOAT,GETDATE())

IF (@DocID is not null and @DocID>0 AND @AuditTrial=1)
BEGIN
	INSERT INTO ACC_DocDetails_History_ATUser(DocType,DocID,VoucherNo,ActionType,ActionTypeID,UserID,CreatedBy,CreatedDate)
	VALUES(@CostCenterID,@DocID,@VoucherNo,'Delete',3,@UserID,@UserName,@dt)

	declare @ModDate float
	set @ModDate=convert(float,getdate())
	EXEC @return_value = [spDOC_SaveHistory]      
			@DocID =@DocID ,
			@HistoryStatus='Delete',
			@Ininv =0,
			@ReviseReason ='',
			@LangID =@LangID,
			@UserName=@UserName,
			@ModDate=@ModDate,
			@sysinfo=@sysinfo,
			@AP=@AP
END


			insert into @ttdel
			SELECT distinct b.DocID,b.COSTCENTERID FROM  [ACC_DocDetails] a WITH(NOLOCK)
			join  [INV_DocDetails] b WITH(NOLOCK) on a.AccDocDetailsID=b.RefNodeid 
			WHERE a.DocID =@DocID and b.RefCCID=400
			
			select @deli=min(id),@delcnt=max(id) from @ttdel
			while(@deli<=@delcnt)
			BEGIN				
				select @DeleteDOcid=docid,@DELETECCID=CCID from @ttdel where id=@deli
				set @deli=@deli+1	    
				 EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
				 @CostCenterID = @DELETECCID,  
				 @DocPrefix = '',  
				 @DocNumber = '',
				 @DocID=@DeleteDOcid,
				 @UserID = @UserID,  
				 @UserName = @UserName,  
				 @LangID = @LangID,  
				 @RoleID= @RoleID
			END

	set @IsLineWisePDC=0
	select @IsLineWisePDC=isnull(PrefValue,0) from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@CostCenterID and PrefName='LineWisePDC'   	
	set @CrossDimension=0
	select @CrossDimension=isnull(PrefValue,0) from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@CostCenterID and PrefName='UseasCrossDimension'
	set @PrePayment=0
	select @PrePayment=isnull(PrefValue,0) from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@CostCenterID and PrefName='PrepaymentDoc'

	if(@IsLineWisePDC=1 or @CrossDimension=1 or @PrePayment<>0 or @DocType not in(14,19))	
	BEGIN
			if(@IsLineWisePDC=1 and exists (SELECT a.ACCDocDetailsID from ACC_DocDetails a  with(nolock)	 
			 join ACC_DocDetails B with(nolock) on a.ACCDocDetailsID =b.RefNodeid and b.RefCCID=400  
			 where a.CostCenterid=@CostCenterID and a.DocID =@DocID and b.Statusid<>370))
				RAISERROR('-399',16,1) 	
	 
			delete from @ttdel	
			insert into @ttdel
			SELECT distinct b.DocID,b.COSTCENTERID FROM  [ACC_DocDetails] a WITH(NOLOCK)
			join  [ACC_DocDetails] b WITH(NOLOCK) on a.AccDocDetailsID=b.RefNodeid 
			WHERE a.DocID =@DocID and b.RefCCID=400
			
			select @deli=min(id),@delcnt=max(id) from @ttdel
			while(@deli<=@delcnt)
			BEGIN				
				select @DeleteDOcid=docid,@DELETECCID=CCID from @ttdel where id=@deli
				set @deli=@deli+1	    
				 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
				 @CostCenterID = @DELETECCID,  
				 @DocPrefix = '',  
				 @DocNumber = '',
				 @DocID=@DeleteDOcid,
				 @UserID = @UserID,  
				 @UserName = @UserName,  
				 @LangID = @LangID,  
				 @RoleID= @RoleID
			END
	END
   
	
	 
	 
		SELECT @CurrentNo=CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock)
		WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix

		if(@CurrentNo=convert(INT,@DocNumber))
		begin
			UPDATE cd     
			SET cd.CurrentCodeNumber=convert(INT,@DocNumber)-1
			from COM_CostCenterCodeDef cd with(nolock)
			WHERE cd.CostCenterID=@CostCenterID AND cd.CodePrefix=@DocPrefix  
		end
		select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
		where CostCenterID=@CostCenterID and PrefName='DocumentLinkDimension'
		
		if(@PrefValue is not null and @PrefValue<>'' and ISNUMERIC(@PrefValue)=1)
		begin
			declare @Dimesion INT
			set @Dimesion=0
			begin try
				select @Dimesion=convert(INT,@PrefValue)
			end try
			begin catch
				set @Dimesion=0
			end catch
			if(@Dimesion>0)
			begin
				
				select @tablename=tablename from ADM_Features with(nolock) where FeatureID=@Dimesion
				set @sql='select @NodeID=NodeID from '+@tablename+' with(nolock) where Name='''+@VoucherNo+''''
				print @sql
				EXEC sp_executesql @sql,N'@NodeID INT OUTPUT',@NodeID output
				 
				if(@NodeID>1)
				begin
					SET @sql='UPDATE a 
					SET a.dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'=1'
					+' from COM_DocCCData a with(nolock) WHERE a.AccDocDetailsID IN (SELECT AccDocDetailsID FROM [ACC_DocDetails] with(nolock) 
					WHERE COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND DOCID='+CONVERT(NVARCHAR,@DocID)+')'
					EXEC(@sql)
					EXEC	@return_value = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @Dimesion,
						@NodeID = @NodeID,
						@RoleID=1,
						@UserID = @UserID,
						@LangID = @LangID
				end
			end
		end	
		
		--ondelete External function
		set @tablename=''
		select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=8
		if(@tablename<>'')
			exec @tablename @CostCenterID,@DocID,'',@UserID,@LangID
		
		if exists (SELECT a.ACCDocDetailsID from ACC_DocDetails a  with(nolock)	 
		 join ACC_DocDetails B with(nolock) on a.ACCDocDetailsID =b.RefNodeid and b.RefCCID=400  
		 where a.CostCenterid=@CostCenterID and a.DocID =@DocID)
		 begin
			if exists(select ACCDocDetailsID from ACC_DocDetails with(nolock) where DocID =@DocID and StatusID=369)
				RAISERROR('-370',16,1)  
			else if exists(select ACCDocDetailsID from ACC_DocDetails with(nolock) where DocID =@DocID and StatusID=447)
				RAISERROR('-398',16,1) 	
			else if exists(select ACCDocDetailsID from ACC_DocDetails with(nolock) where DocID =@DocID and StatusID=429)
				RAISERROR('-371',16,1)  
		 end
		 
		 if exists (SELECT a.ACCDocDetailsID from ACC_DocDetails a with(nolock)	 
		 join ACC_DocDetails B with(nolock) on a.ACCDocDetailsID =b.RefNodeid and b.RefCCID=109  
		 where a.CostCenterid=@CostCenterID and a.DocID =@DocID )
		 begin		
				RAISERROR('-110',16,1)  
		 end
		 
		 IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='REN_ContractDocMapping')
		 BEGIN
			 SET @sql='if exists (SELECT a.ACCDocDetailsID from ACC_DocDetails a with(nolock)	 
			 join REN_ContractDocMapping B with(nolock) on a.DocID =b.DocID
			 where a.CostCenterid='+CONVERT(NVARCHAR,@CostCenterID)+' and a.DocID ='+CONVERT(NVARCHAR,@DocID)+' and B.JVVoucherNo is not null and B.JVVoucherNo<>'''')
			 begin		
					RAISERROR(''-563'',16,1)  
			 end'
			 EXEC sp_executesql @sql
		 END
		DELETE a FROM  [COM_DocCCData] a with(nolock)
		JOIN [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID =b.AccDocDetailsID
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID
		
		DELETE a FROM  [COM_DocNumData] a with(nolock)
		JOIN [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID =b.AccDocDetailsID
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID
		
		DELETE a FROM  [COM_DocTextData] a with(nolock)
		JOIN [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID =b.AccDocDetailsID
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID
	
		DELETE a FROM COM_Billwise a with(nolock)
		WHERE DocNo=@VoucherNo
		
		DELETE a FROM COM_LCBills a with(nolock)
		WHERE DocNo=@VoucherNo

		DELETE a FROM COM_BillWiseNonAcc a with(nolock)
		WHERE DocNo=@VoucherNo

		DELETE a FROM COM_ChequeReturn a with(nolock)
		WHERE DocNo=@VoucherNo
		
		update a 
		set IsNewReference=1,RefDocNo=null,RefDocSeqNo=null,RefDocDate=null,RefDocDueDate=null
		from COM_Billwise a with(nolock)		
		WHERE RefDocNo=@VoucherNo

		DELETE a  FROM  COM_Notes a with(nolock)		
		WHERE FeatureID=@CostCenterID AND FeaturePK=@DocID	
		
		DELETE a FROM  COM_Files a with(nolock)		
		WHERE FeatureID=@CostCenterID AND FeaturePK=@DocID	
		
		DELETE a FROM [COM_DocID] a with(nolock) 
		WHERE ID=@DocID
		
		DELETE a FROM COM_DocDenominations a with(nolock)
		WHERE DOCID=@DocID
		
		DELETE a FROM [ACC_DocDetails] a with(nolock)
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID 
		
		DELETE a FROM com_approvals a with(nolock) 
		WHERE CCID=@CostCenterID AND CCNODEID=@DocID
		
		if exists (select * from sys.tables with(nolock) where name='CRM_Activities')
		begin
			SET @sql='DELETE a FROM  CRM_Activities a with(nolock)
			WHERE CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND NodeID='+CONVERT(NVARCHAR,@DocID) 
			exec (@sql)
		end
		
		update a
		set PostedVoucherNo=null,StatusID=1
		from com_schevents a with(nolock)
		where PostedVoucherNo=@VoucherNo
		
		
		
COMMIT TRANSACTION         
SET NOCOUNT OFF;  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
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
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION

--Remove if any Delete notification
delete from COM_SchEvents Where CostCenterID=@CostCenterID and NodeID=@DocID and StatusID=1 and FilterXML like '<XML><FilePath>%'

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
