USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_DeleteInvDocument]
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
	DECLARE @HasAccess bit,@VoucherNo nvarchar(200),@PrefValue NVARCHAR(500),@NodeID INT,@Dimesion INT
	DECLARE @sql nvarchar(max),@tablename nvarchar(200),@CurrentNo INT,@return_value int
	declare @AccDocID INT,@DELETECCID INT ,@DocumentType int,@CompanyGUID nvarchar(200),@DeleteDocID INT
	declare @bi int,@bcnt int,@VoucherType int,@InvDocDetailsID INT ,@DocDate datetime  ,@NID INT
	DECLARE @ConsolidatedBatches nvarchar(50),@Tot float,@BatchID INT,@WHERE nvarchar(max)
  
	DECLARE @TblPref AS TABLE(Name nvarchar(100),Value nvarchar(max))
	INSERT INTO @TblPref
	SELECT Name,Value FROM ADM_GlobalPreferences with(nolock)
	WHERE Name IN ('DW Batches','LW Batches','Maintain Dimensionwise Batches','EnableLocationWise','ConsiderUnAppInHold','EnableDivisionWise')
	
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
		SELECT @DocDate=convert(datetime,DocDate),@VoucherNo=VoucherNo,@DocPrefix=DocPrefix,@DocNumber=DocNumber,@DocumentType=DocumentType,@VoucherType=VoucherType 
		FROM [INV_DocDetails] with(nolock)
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID 
	ELSE
		SELECT @DocDate=convert(datetime,DocDate),@VoucherNo=VoucherNo,@DocID=DocID,@DocumentType=DocumentType,@VoucherType=VoucherType  
		FROM [INV_DocDetails] with(nolock)
		WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber
	
	IF @DocID IS NULL
	BEGIN
		COMMIT TRANSACTION         
		SET NOCOUNT OFF; 
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=102 AND LanguageID=@LangID  
		RETURN 1	
	END	
	
	DECLARE @DLockFromDate DATETIME,@DLockToDate DATETIME,@DAllowLockData BIT ,@DLockCC INT  
	DECLARE @LockFromDate DATETIME,@LockToDate DATETIME,@AllowLockData BIT,@LockCC INT,@LockCCValues nvarchar(max)     
	declare @caseTab table(id int identity(1,1),CaseID INT,fldName nvarchar(50))
	declare @CaseID INT,@iUNIQ int,@UNIQUECNT int
		
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
	  
		  set @sql ='if exists (select a.InvDocDetailsID FROM  [COM_DocCCData] a with(nolock)  
		  join [Inv_DocDetails] b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID  
		  WHERE b.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND b.docid='+convert(nvarchar,@DocID)+' and a.dcccnid'+convert(nvarchar,(@LockCC-50000))+' in('+@LockCCValues+'))  
		  RAISERROR(''-125'',16,1)  '  
		  EXEC sp_executesql @SQL
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
			 set @sql ='if exists (select a.CostCenterID from INV_DocDetails a WITH(NOLOCK)
			join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
			join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1 '+@LockCCValues+'
			where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
			RAISERROR(''-125'',16,1)  '  
	END
	ELSE
	BEGIN	
	  set @sql ='if exists (select a.CostCenterID from INV_DocDetails a WITH(NOLOCK)
			join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
			join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1 
			where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
			RAISERROR(''-125'',16,1)  '  
	END		
      EXEC sp_executesql @SQL
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
	  
		  set @sql ='if exists (select a.InvDocDetailsID FROM  [COM_DocCCData] a with(nolock)  
		  join [INV_DocDetails] b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID  
		  WHERE b.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND b.docid='+convert(nvarchar,@DocID)+' and a.dcccnid'+convert(nvarchar,(@DLockCC-50000))+' in('+@LockCCValues+'))  
		  RAISERROR(''-125'',16,1)  '  
		  
		  EXEC sp_executesql @SQL
     END   
   END         
  END  
 END  
	
	select @PrefValue=Value from ADM_GlobalPreferences with(nolock) where Name='Check for -Ve Stock'  	
  
	if(@PrefValue is not null and @PrefValue='true' and @DocID>0 and (@VoucherType=1 or @DocumentType in(5,30)))
	BEGIN
		select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID and PrefName='DonotupdateInventory'    
		if(@PrefValue is not null and @PrefValue='false')
		BEGIN		
			select @HasAccess=Value from @TblPref where Name='ConsiderUnAppInHold'    

			EXEC @return_value = [spDOC_Validate]      
				@InvDocXML ='', 
				@DocID =@DocID,
				@DocDate =@DocDate,
				@IsDel=1,
				@ActivityXML='',
				@docType=@DocumentType,
				@ConsiderUnAppInHold=@HasAccess,
				@UserName =@UserName,
				@LangID =@LangID
		END			
	END
	
	set @NodeID=0	
	select @NodeID=isnull(LabID,0) from [INV_DocDetails] a with(nolock) 
	join [INV_DocExtraDetails] b with(nolock)  on a.InvDocDetailsID=b.InvDocDetailsID
	WHERE a.CostCenterID=@CostCenterID AND a.DocID=@DocID and b.Type=15
	
	if (@NodeID>0)
	begin	
		SELECT @Dimesion=CONVERT(INT,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='JobDimension' 
		
		EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @Dimesion,
						@NodeID = @NodeID,
						@RoleID=1,
						@UserID = 1,
						@LangID = @LangID
	END
	
	if exists(select b.DocID from INV_DocDetails a WITH(NOLOCK) 
	join INV_DocDetails b WITH(NOLOCK) on A.InvDocDetailsId=b.refnodeid and b.refccid=300
	where a.CostCenterID=@CostCenterID AND a.DocID=@DocID)
	begin
	
		select @DeleteDocID=b.DocID,@DELETECCID = b.CostCenterID from INV_DocDetails a WITH(NOLOCK) 
		join INV_DocDetails b WITH(NOLOCK) on A.InvDocDetailsId=b.refnodeid and b.refccid=300
		where a.CostCenterID=@CostCenterID AND a.DocID=@DocID
		  
	     
	    WHILE(@DeleteDocID>0)
		BEGIN 
		    
			 EXEC @return_value = [spDOC_DeleteInvDocument]      
			@CostCenterID = @DELETECCID,      
			@DocPrefix = '',      
			@DocNumber = '', 
			@DocID=@DeleteDocID,     
			@UserID = @UserID,      
			@UserName = @UserName,      
			@LangID = @LangID ,
			@RoleID=@RoleID
			
			set @DeleteDocID=0
			
			select @DeleteDocID=b.DocID,@DELETECCID = b.CostCenterID from INV_DocDetails a WITH(NOLOCK) 
			join INV_DocDetails b WITH(NOLOCK) on A.InvDocDetailsId=b.refnodeid and b.refccid=300
			where a.CostCenterID=@CostCenterID AND a.DocID=@DocID
		END	
	end	
	
	if (@DocumentType<>32 and exists(select a.LinkedInvDocDetailsID from [INV_DocDetails] a with(nolock) 
	join [INV_DocDetails] b with(nolock)  on a.InvDocDetailsID=b.LinkedInvDocDetailsID
	WHERE a.CostCenterID=@CostCenterID AND a.DocID=@DocID))
	begin			
		RAISERROR('-127',16,1)
	end

	if exists(select a.LinkedInvDocDetailsID from [INV_DocDetails] a with(nolock) 
	join [INV_DocExtraDetails] b with(nolock)  on a.InvDocDetailsID=b.RefID
	WHERE a.CostCenterID=@CostCenterID AND a.DocID=@DocID and b.Type=1)
	begin	
			select @VoucherNo=c.Voucherno from [INV_DocDetails] a with(nolock) 
			join [INV_DocExtraDetails] b with(nolock)  on a.InvDocDetailsID=b.RefID
			join [INV_DocDetails] c with(nolock)  on b.InvDocDetailsID=c.InvDocDetailsID
			WHERE a.CostCenterID=@CostCenterID AND a.DocID=@DocID and b.Type=1
			
			RAISERROR('-566',16,1)
	end
	
	if exists(select PrefValue from COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID and  PrefName='BackTrack' and PrefValue='True')
	BEGIN
			update c
			set LinkedFieldValue=c.LinkedFieldValue+b.[Quantity]
			from INV_DocDetails a WITH(NOLOCK)    
			join INV_DocExtraDetails b WITH(NOLOCK)    on a.InvDocDetailsID=b.[RefID]
			join INV_DocDetails  c WITH(NOLOCK)  on b.InvDocDetailsID=c.InvDocDetailsID
			where b.type=10 and a.CostCenterID=@CostCenterID AND a.DocID=@DocID
	END
	
	if(@DocumentType=32)
	BEGIN
		update INV_DocDetails
		set StatusID=443
		from (select LinkedInvDocDetailsID id from INV_DocDetails WITH(NOLOCK) 
		where CostCenterID=@CostCenterID AND DocID=@DocID) as t
		where InvDocDetailsID=t.id
		
	END
	
	--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA    
	DECLARE @AuditTrial BIT,@dt FLOAT
	SET @AuditTrial=0    
	SELECT @AuditTrial=CONVERT(BIT,PrefValue)  FROM [COM_DocumentPreferences] with(nolock)    
	WHERE CostCenterID=@CostCenterID AND PrefName='AuditTrial'    
	    
    SET @dt=CONVERT(FLOAT,GETDATE())

	IF (@DocID is not null and @DocID>0 and @AuditTrial=1)  
	BEGIN
		INSERT INTO INV_DocDetails_History_ATUser(DocType,DocID,VoucherNo,ActionType,ActionTypeID,UserID,CreatedBy,CreatedDate)
		VALUES(@CostCenterID,@DocID,@VoucherNo,'Delete',3,@UserID,@UserName,@dt)			
		
		declare @ModDate float
		set @ModDate=convert(float,getdate())
		EXEC @return_value = [spDOC_SaveHistory]      
			@DocID =@DocID ,
			@HistoryStatus='Delete',
			@Ininv =1,
			@ReviseReason ='',
			@LangID =@LangID,
			@UserName=@UserName,
			@ModDate=@ModDate,
			@CCID=@CostCenterID,
			@sysinfo=@sysinfo,
			@AP=@AP
	END    
	     
	
	if exists(select AccDocDetailsID from acc_docdetails with(nolock) where refccid=300 and refnodeid=@DocID)
	begin
			 
		SELECT @DeleteDocID=DocID , @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)   
		where refccid=300 and refnodeid=@DocID	
		
		while(@DeleteDocID>0)
		BEGIN	    
			
			 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
			 @CostCenterID = @DELETECCID,  
			 @DocPrefix = '',  
			 @DocNumber = '',  
			 @DOCID=@DeleteDocID,
			 @UserID = @UserID,  
			 @UserName = @UserName,  
			 @LangID = @LangID,
			 @RoleID=@RoleID
			 
			 set @DeleteDocID=0
			 
			 SELECT @DeleteDocID=DocID , @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)   
			where refccid=300 and refnodeid=@DocID	
			 
		END	 		 
	end	
	
	if (@documenttype=5 and exists(SELECT PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) 
	where CostCenterID=@COSTCENTERID and PrefName='IsBudgetDocument' and (PrefValue='1' or PrefValue='true')))
	begin		
	
		select @CompanyGUID=CompanyGUID FROM [COM_DocID] WITH(NOLOCK) WHERE ID=@DocID
		
		exec [spDoc_UpdateBudget] @CostCenterID,@DOCID,@CompanyGUID,@UserName,1
	END
	
	
	--ondelete External function
	set @tablename=''
	select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=8
	if(@tablename<>'')
		exec @tablename @CostCenterID,@DocID,'',@UserID,@LangID
	
	 
		
	SELECT @CurrentNo=CurrentCodeNumber   FROM COM_CostCenterCodeDef with(nolock)
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
		 
		set @Dimesion=0
		begin try
			select @Dimesion=convert(INT,@PrefValue)
		end try
		begin catch
			set @Dimesion=0
		end catch
		
		if(@Dimesion>0)
		begin 
			if exists(select PrefValue from COM_DocumentPreferences with(nolock)
			where CostCenterID=@CostCenterID and PrefName='GenerateSeq' and PrefValue='true')
			BEGIN
				SET @sql='select a.dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+' from COM_DocCCData a with(nolock)
					join Inv_DocDetails b with(nolock) on a.InvDocDetailsID =b.InvDocDetailsID
					WHERE b.COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND b.DOCID='+CONVERT(NVARCHAR,@DocID)
				
				delete from @caseTab
				INSERT INTO @caseTab(CaseID)
				EXEC sp_executesql @SQL
				
				delete from @caseTab
				where CaseID=1
				
				SET @sql='UPDATE a 
				SET a.dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'=1'
				+' from COM_DocCCData a with(nolock) WHERE a.InvDocDetailsID IN (SELECT InvDocDetailsID FROM Inv_DocDetails with(nolock) 
				WHERE COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND DOCID='+CONVERT(NVARCHAR,@DocID)+')'
				
				EXEC sp_executesql @SQL
				
				select @iUNIQ=MIN(id),@UNIQUECNT=MAX(id) FROM @caseTab
		
				WHILE(@iUNIQ <= @UNIQUECNT)
				BEGIN
					SELECT @CaseID=CaseID FROM @caseTab WHERE id=@iUNIQ
					
					 EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @Dimesion,
						@NodeID = @CaseID,
						@RoleID=1,
						@UserID = 1,
						@LangID = @LangID
					 
					SET @iUNIQ=@iUNIQ+1
				END
				
			END
			ELSE
			BEGIN
				select @tablename=tablename from ADM_Features where FeatureID=@Dimesion
				set @sql='select @NodeID=NodeID from '+@tablename+' with(nolock) where Name='''+@VoucherNo+''''
				print @sql
				EXEC sp_executesql @sql,N'@NodeID INT OUTPUT',@NodeID output
				 
				if(@NodeID>1)
				begin
						 
					SET @sql='UPDATE a 
					SET a.dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'=1'
					+' from COM_DocCCData a with(nolock) WHERE a.InvDocDetailsID IN (SELECT InvDocDetailsID FROM Inv_DocDetails with(nolock) 
					WHERE COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND DOCID='+CONVERT(NVARCHAR,@DocID)+')'
					
					EXEC sp_executesql @SQL
					
					EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @Dimesion,
						@NodeID = @NodeID,
						@RoleID=1,
						@UserID = 1,
						@LangID = @LangID
				end
			END	
		end
	end	
		
	delete from @caseTab
	INSERT INTO @caseTab(CaseID)
	SELECT RefDimensionNodeID FROM COM_DocBridge with(nolock)
	WHERE InvDocID=@DocID AND RefDimensionID=72
					
	select @iUNIQ=MIN(id),@UNIQUECNT=MAX(id) FROM @caseTab

	WHILE(@iUNIQ <= @UNIQUECNT)
	BEGIN
		SELECT @CaseID=CaseID FROM @caseTab WHERE id=@iUNIQ
		
		EXEC @return_value = dbo.spACC_DeleteAsset
			@AssetID =@CaseID,
			@UserID =@UserID,
			@RoleID=@RoleID,
			@LangID =@LangID
		
		SET @iUNIQ=@iUNIQ+1
	end
	
	delete a FROM COM_DocBridge a with(nolock)
	WHERE a.InvDocID=@DocID AND a.RefDimensionID=72
	
	IF(@CostCenterID=40054) -- MONTHLY PAYROLL
	BEGIN
	
		SET @sql='DECLARE @EmpSeqNo INT,@PayrollMonth DATETIME
		SELECT @EmpSeqNo=b.dcCCNID51,@PayrollMonth=CONVERT(DATETIME,a.DueDate)
		FROM INV_DocDetails a WITH(NOLOCK)
		JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
		WHERE a.CostCenterID=40054 AND DOCID='+CONVERT(NVARCHAR,@DocID)+'
		
		DELETE a FROM PAY_EmpMonthlyArrears a with(nolock) WHERE a.EmpSeqNo=@EmpSeqNo AND a.PayrollMonth=@PayrollMonth
		DELETE a FROM PAY_EmpMonthlyAdjustments a with(nolock) WHERE a.EmpSeqNo=@EmpSeqNo AND a.PayrollMonth=@PayrollMonth
		DELETE a FROM PAY_EmpMonthlyDues a with(nolock) WHERE a.EmpSeqNo=@EmpSeqNo AND a.PayrollMonth=@PayrollMonth
		DELETE a FROM PAY_EmpMonthlyArrAdjDetails a with(nolock) WHERE a.EmpSeqNo=@EmpSeqNo AND a.PayrollMonth=@PayrollMonth'
		
		EXEC sp_executesql @SQL
		
	END
	IF(@CostCenterID=40065) -- join FromVacation
	BEGIN
		SET @sql='Declare @FrmDt Datetime,@ToDt Datetime,@Emp INT
		IF((SELECT COUNT(*) FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID AND STATUSID=369)>0)
		BEGIN
			IF((SELECT CostCenterID FROM INV_DocDetails WITH(NOLOCK) WHERE InvDocDetailsID=(SELECT LinkedInvDocDetailsID FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID))=40072)
			BEGIN
				SELECT @FrmDt=CONVERT(DATETIME,TD.DCALPHA1),@ToDt=CONVERT(DATETIME,TD.DCALPHA2),@Emp=Dcccnid51 
				FROM COM_DOCTEXTDATA TD with(nolock) 
				INNER JOIN INV_DOCDETAILS ID with(nolock) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.DOCID=@DOCID
				Inner Join com_DocccData cc with(nolock) on cc.invDocdetailsid=ID.invDocdetailsid 
				Where CostcenterID=40065
				
				UPDATE TD SET TD.dcAlpha1='''' FROM COM_DOCTEXTDATA TD with(nolock) 
				INNER JOIN COM_DOCCCDATA CC with(nolock) ON TD.INVDOCDETAILSID=CC.INVDOCDETAILSID AND CC.dcCCNID51=@Emp
				INNER JOIN INV_DOCDETAILS ID with(nolock) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID 
				WHERE ID.CostCenterId=40072 AND ISDATE(TD.DCALPHA2)=1 AND ISDATE(TD.DCALPHA3)=1 
				AND CONVERT(DATETIME,TD.DCALPHA2)=CONVERT(DATETIME,@FrmDt) AND CONVERT(DATETIME,TD.DCALPHA3)=CONVERT(DATETIME,@ToDt)
			END
			ELSE
			BEGIN
				SELECT @FrmDt=CONVERT(DATETIME,TD.DCALPHA1),@ToDt=CONVERT(DATETIME,TD.DCALPHA2),@Emp=Dcccnid51 
				FROM COM_DOCTEXTDATA TD with(nolock) 
				INNER JOIN INV_DOCDETAILS ID with(nolock) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.DOCID=@DOCID
				Inner Join com_DocccData cc with(nolock) on cc.invDocdetailsid=ID.invDocdetailsid 
				Where CostcenterID=40065
				
				UPDATE TD SET TD.dcAlpha15='''' FROM COM_DOCTEXTDATA TD with(nolock) 
				INNER JOIN COM_DOCCCDATA CC with(nolock) ON TD.INVDOCDETAILSID=CC.INVDOCDETAILSID AND CC.dcCCNID51=@Emp
				INNER JOIN INV_DOCDETAILS ID with(nolock) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID 
				WHERE ID.CostCenterId=40062 AND ISDATE(TD.DCALPHA4)=1 AND ISDATE(TD.DCALPHA5)=1
				AND CONVERT(DATETIME,TD.DCALPHA4)=CONVERT(DATETIME,@FrmDt) AND CONVERT(DATETIME,TD.DCALPHA5)=CONVERT(DATETIME,@ToDt)
			END
		END'
		EXEC  sp_executesql @sql,N'@DOCID INT',@DOCID
		print @sql
	END
	IF(@CostCenterID=40069) -- Apply Resignation
	BEGIN
		
		IF((SELECT COUNT(*) FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID)>0)
		BEGIN
			Declare @EmplRes INT,@DocFinalSettlement nvarchar(max),@EmpRelDate INT		
			SET @sql='SELECT @EmplRes=cc.dcccnid51,@EmpRelDate=CONVERT(INT,CONVERT(DATETIME,TD.dcAlpha4)) 
			FROM COM_DOCTEXTDATA TD with(nolock) 
			INNER JOIN INV_DOCDETAILS ID with(nolock) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.DOCID=@DOCID
			Inner Join com_DocccData cc with(nolock) on cc.invDocdetailsid=ID.invDocdetailsid 
			Where CostcenterID=40069
			IF((SELECT COUNT(*) FROM PAY_FinalSettlement WITH(NOLOCK) WHERE EmpSeqNo=@EmplRes)>0)
			BEGIN
				Select @DocFinalSettlement=Convert(nvarchar,DocNo) FROM PAY_FinalSettlement WITH(NOLOCK) WHERE EmpSeqNo=@EmplRes
				RAISERROR(''-577'',16,1)
			END
			ELSE
			BEGIN
				UPDATE T SET  T.RESIGNREMARKS=NULL,T.RESIGNTYPE=NULL,T.RESIGNSTATUS=NULL,T.DORESIGN=NULL, T.DOTENTRELIEVE=NULL, T.DORELIEVE=NULL 
				FROM COM_CC50051 T WITH(NOLOCK) WHERE T.NODEID=@EmplRes

				DECLARE @UpdateEmployeeStatus BIT
				SELECT @UpdateEmployeeStatus=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name=''UpdateEmployeeStatusafterRelievingautomatically''

				IF(ISNULL(@UpdateEmployeeStatus,0)=1)
				BEGIN
					UPDATE T SET  T.StatusID=250 FROM COM_CC50051 T WITH(NOLOCK) WHERE T.NODEID=@EmplRes
				END
			END'
			
			EXEC sp_executesql @sql,N'@DOCID INT,@EmplRes INT OUTPUT,@DocFinalSettlement nvarchar(max) OUTPUT,@EmpRelDate INT OUTPUT',@DOCID,@EmplRes OUTPUT,@DocFinalSettlement OUTPUT,@EmpRelDate OUTPUT
			
			--deleting the entry in user status
			DECLARE @EmpUserID INT
			SET @sql='SELECT @EmpUserID=ISNULL(UserID,0) From ADM_Users WITH(NOLOCK) Where UserName=(Select Code FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID='+ CONVERT(NVARCHAR,@EmplRes)+')'
			EXEC sp_executesql @sql,N'@EmpUserID INT OUTPUT',@EmpUserID OUTPUT
			IF(@EmpUserID IS NOT NULL AND @EmpUserID<>0)
			BEGIN
				DELETE T FROM [COM_CostCenterStatusMap] T WITH(NOLOCK) 
				WHERE T.CostCenterID=7 AND T.NodeID=@EmpUserID AND T.Status=2 AND T.FromDate=CONVERT(int,DATEADD(day,1,@EmpRelDate)) AND T.ToDate IS NULL
			END

	   END
	END
	IF(@CostCenterID=40099) -- Regularization of Attendance
	BEGIN
		DECLARE @TABEMP TABLE (ID INT IDENTITY(1,1),VNo NVARCHAR(600),DocSeqNo NVARCHAR(500),DailyAttDate NVARCHAR(100),EmpNodeID INT)
		DECLARE @I INT,@CNT INT
		
		SET @SQL='SELECT T.DCALPHA1,T.DCALPHA2,T.DCALPHA3,CC.dcCCNID51 FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		WHERE I.costcenterid='+convert(nvarchar,@CostCenterID)+' AND I.STATUSID=369 AND T.DCALPHA12=''True'' AND I.DOCID='+CONVERT(NVARCHAR,@DocID)
		INSERT INTO @TABEMP
		EXEC sp_executesql @SQL


		SELECT @CNT=COUNT(*) FROM @TABEMP
		SET @I=1
		WHILE(@I<=@CNT)
		BEGIN
			SELECT @SQL='
			UPDATE T SET dcAlpha2=dcAlpha16,dcAlpha3=dcAlpha17 FROM INV_DocDetails I with(nolock)
			JOIN COM_DocTextData T with(nolock) ON T.InvDocDetailsID=I.InvDocDetailsID
			JOIN COM_DocCCData C with(nolock) ON C.InvDocDetailsID=I.InvDocDetailsID
			WHERE I.DocumentType=67 AND I.VoucherNo='''+VNo+''' AND I.DocSeqNo='''+DocSeqNo+''' AND C.dcCCNID51='+CONVERT(NVARCHAR,EmpNodeID)+' AND ISDATE(T.DCALPHA1)=1
			AND CONVERT(DATETIME,T.DCALPHA1)=CONVERT(DATETIME,'''+DailyAttDate+''')

			UPDATE T SET dcAlpha16=NULL,dcAlpha17=NULL FROM INV_DocDetails I with(nolock)
			JOIN COM_DocTextData T with(nolock) ON T.InvDocDetailsID=I.InvDocDetailsID
			JOIN COM_DocCCData C with(nolock) ON C.InvDocDetailsID=I.InvDocDetailsID
			WHERE I.DocumentType=67 AND I.VoucherNo='''+VNo+''' AND I.DocSeqNo='''+DocSeqNo+''' AND C.dcCCNID51='+CONVERT(NVARCHAR,EmpNodeID)+' AND ISDATE(T.DCALPHA1)=1
			AND CONVERT(DATETIME,T.DCALPHA1)=CONVERT(DATETIME,'''+DailyAttDate+''')' FROM @TABEMP WHERE ID=@I 
			
			EXEC sp_executesql @SQL
			
			SET @I=@I+1
		END
	END
	IF(@CostCenterID=40072) -- Apply Vacation
	BEGIN
	
		SET @sql='DELETE a FROM PAY_EmpDetail a WITH(NOLOCK) WHERE a.DTYPE=-72000 AND a.Field1='+CONVERT(NVARCHAR(max),@DocID)
		
		EXEC sp_executesql @SQL
		
	END
	if(@DocumentType=5)
	begin
		if exists (SELECT * FROM COM_DocBridge with(nolock) where CostCenterID=@CostCenterID and NodeID=@DocID and RefDimensionID=132)
			RAISERROR('-138',16,1)
	end
	
	if exists (select PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='IsBudgetDocument' and PrefValue='1')
	begin
		declare @BudgetID INT
		SELECT @BudgetID=RefDimensionNodeID FROM COM_DocBridge with(nolock) where CostCenterID=@CostCenterID and NodeID=@DocID and RefDimensionID=101
		if @BudgetID is not null
			exec @return_value=[spADM_DeleteBudgetDetails] @BudgetID,1,@UserID,@LangID
	end
	
	set @sql='SELECT a.InvDocDetailsID,a.BatchID,a.LinkedInvDocDetailsID,t.dcccnid2,t.dcccnid1,'
	set @PrefValue=''      
	select @PrefValue= isnull(Value,'') from @TblPref where Name='Maintain Dimensionwise Batches'        
	if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)        	
		set @sql=@sql+'t.dcCCNID'+convert(nvarchar,(convert(INT,@PrefValue)-50000)) 
	else
		set @sql=@sql+'0'
		
	set @sql=@sql+' FROM [INV_DocDetails] a with(nolock)
			join COM_DocCCData t with(nolock) on t.InvDocDetailsID=a.InvDocDetailsID
			WHERE a.CostCenterID='+convert(nvarchar(20),@CostCenterID)+' AND a.DocID='+convert(nvarchar(20),@DocID )
			
			       
	DECLARE @TblDeleteRows AS Table(idid INT identity(1,1), ID INT,BatchID INT,linkinv INT,loc INT,div INT,DIM INT)
	
	insert into  @TblDeleteRows
	exec(@sql)
	
	DELETE T FROM COM_DocCCData t with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID		

	--DELETE DOCUMENT EXTRA NUMERIC FEILD DETAILS      
	DELETE T FROM [COM_DocNumData] t with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID
	
	if(@CostCenterID=40054)
	BEGIN
		set @sql='DELETE T FROM PAY_DocNumData t with(nolock)
		join [INV_DocDetails] a on t.InvDocDetailsID=a.InvDocDetailsID
		WHERE a.CostCenterID='+convert(nvarchar(Max),@CostCenterID)+' AND a.DocID= '+convert(nvarchar(Max),@DocID)
		EXEC sp_executesql @SQL
	END
	
	--DELETE DOCUMENT EXTRA TEXT FEILD DETAILS      
	DELETE T FROM [COM_DocTextData] T with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID

	--DELETE Accounts DocDetails      
	DELETE T FROM [ACC_DocDetails] T with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID 
	
	DELETE T FROM INV_BinDetails T with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID
   
	DELETE T FROM INV_DocExtraDetails T with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID 

	DELETE T FROM INV_DocExtraDetails T with(nolock)
	join @TblDeleteRows a on t.REFID=a.ID 
	where t.type=10
	
	--to delete stock codes
	if exists(select PrefValue from COM_DocumentPreferences with(nolock)
	where CostCenterID=@CostCenterID and PrefName='DumpStockCodes' and PrefValue='true')    
	BEGIN
		set @tablename=''
		select @tablename=b.TableName from ADM_GlobalPreferences a WITH(NOLOCK) 
		join ADM_Features b WITH(NOLOCK) on a.Value=b.FeatureID
		where a.Name='POSItemCodeDimension'
		if(@tablename<>'')
		BEGIN
			set @SQL='delete T FROM '+@tablename+' T with(nolock)
			join Inv_DocDetails b with(nolock) on T.InvDocDetailsID =b.InvDocDetailsID
			WHERE b.COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND b.DOCID='+CONVERT(NVARCHAR,@DocID)
				
			exec(@SQL)
		END	
	END


	if exists(select [InvDocDetailsID] from [INV_SerialStockProduct] T with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID)
	BEGIN	
	
		if(@VoucherType=1)
		BEGIN
			if exists(select [SerialNumber]  from [INV_SerialStockProduct] t with(nolock)
			 join @TblDeleteRows a on t.RefInvDocDetailsID=a.ID)
			BEGIN			
				RAISERROR('-508',16,1)
			END	
		END
		ELSE if(@VoucherType=-1)
		BEGIN		
			 UPDATE [INV_SerialStockProduct]      
			 SET [StatusID]=157      
			 ,IsAvailable=1 
			  from ( select [SerialNumber] sno ,SerialGUID sguid,[RefInvDocDetailsID] refinvID,[ProductID] PID from [INV_SerialStockProduct]  t with(nolock)    
			 join @TblDeleteRows a on t.InvDocDetailsID=a.ID) as t
			  where [ProductID]=PID and [SerialNumber]=sno and SerialGUID=sguid and [InvDocDetailsID]=refinvID
		END
		
		DELETE T FROM  [INV_SerialStockProduct]  T with(nolock)
		join @TblDeleteRows a on t.InvDocDetailsID=a.ID	 
	END	
	
	DELETE T FROM COM_DocFlow T with(nolock) 
	WHERE T.DocID=@DocID
	
	DELETE T FROM COM_Billwise T with(nolock) 
	WHERE T.DocNo=@VoucherNo
	
	DELETE T FROM COM_LCBills T with(nolock) 
	WHERE T.DocNo=@VoucherNo
	
	DELETE T FROM Com_BillwiseNonAcc T with(nolock) 
	WHERE T.DocNo=@VoucherNo

	DELETE T FROM COM_ChequeReturn T with(nolock) 
	WHERE T.DocNo=@VoucherNo
	
	update a 
	set a.IsNewReference=1,a.RefDocNo=null,a.RefDocSeqNo=null,a.RefDocDate=null,a.RefDocDueDate=null
	from COM_Billwise a WITH(NOLOCK)
	WHERE a.RefDocNo=@VoucherNo
	
	DELETE T FROM COM_Notes T with(nolock) 
	WHERE T.FeatureID=@CostCenterID AND T.FeaturePK=@DocID

	DELETE T FROM COM_DocQtyAdjustments T with(nolock)
	WHERE T.DocID=@DocID
	
	DELETE T FROM  COM_Files T with(nolock) 
	WHERE T.FeatureID=@CostCenterID AND T.FeaturePK=@DocID
	
	DELETE T FROM INV_TempInfo T with(nolock)
	join @TblDeleteRows a on t.InvDocDetailsID=a.ID	 
	
	DELETE T FROM COM_DocDenominations T with(nolock) 
	WHERE T.DOCID=@DocID
	
	DELETE T FROM [COM_DocID] T with(nolock) WHERE T.ID=@DocID

	DELETE T FROM [INV_DocDetails] T with(nolock) 
	WHERE T.CostCenterID=@CostCenterID AND T.DocID=@DocID
	
	DELETE T FROM com_approvals T with(nolock) 
	WHERE T.CCID=@CostCenterID AND T.CCNODEID=@DocID
	
	IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='CRM_Activities')
	BEGIN
		SET @SQL='DELETE T FROM CRM_Activities T WITH(NOLOCK) 
		WHERE T.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND T.NodeID ='+CONVERT(NVARCHAR,@DocID)
		EXEC sp_executesql @SQL
	END
	
	update T
	set T.PostedVoucherNo=null,T.StatusID=1
	FROM com_schevents T WITH(NOLOCK)  
	where T.PostedVoucherNo=@VoucherNo
	
	IF (@VoucherType=1 and exists(select Batchid from @TblDeleteRows where BatchID>1))
	BEGIN
		select @bi=0,@bcnt=COUNT(id) from @TblDeleteRows
		while(@bi<@bcnt)		
		BEGIN  		
			set @bi=@bi+1
			set @BatchID=1
			SELECT  @BatchID=BatchID,@InvDocDetailsID=Id from @TblDeleteRows where idid=@bi
			
			if(@BatchID>1)
			BEGIN
				select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
				where Name='AllowNegativebatches' and costcenterid=16  
				if(@ConsolidatedBatches is null or @ConsolidatedBatches ='' or @ConsolidatedBatches ='false')
				BEGIN
					select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
					where Name='ConsolidatedBatches' and costcenterid=16  
					if(@ConsolidatedBatches is null and @ConsolidatedBatches ='false')
					begin     
						set @Tot=isnull((SELECT sum(BD.ReleaseQuantity)    
						FROM [INV_DocDetails] AS BD WITH(NOLOCK)                 
						where BD.vouchertype=1 and BD.IsQtyIgnored=0  and BD.batchid=@BatchID and BD.[InvDocDetailsID]=@InvDocDetailsID),0)  

						set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
						FROM [INV_DocDetails] AS BD  with(nolock)                  
						where BD.vouchertype=-1 and BD.statusid in(369,371,441) and BD.IsQtyIgnored=0  and BD.batchid=@BatchID and BD.RefInvDocDetailsID=@InvDocDetailsID),0)   
					end  
					else  
					begin  
						set @WHERE=''
						if exists(select value from @TblPref where  Name='LW Batches' and Value='true')
							 and exists(select value from @TblPref where  Name='EnableLocationWise' and Value='true')
						BEGIN				
							select @NID=Loc 	from @TblDeleteRows where idid=@bi  
							set @WHERE =@WHERE+' and dcCCNID2='+CONVERT(nvarchar,@NID)        
						END

						if exists(select value from @TblPref where  Name='DW Batches' and Value='true')
						and exists(select value from @TblPref where  Name='EnableDivisionWise' and Value='true')
						BEGIN		
							select @NID=DIV from @TblDeleteRows where idid=@bi		 
							set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@NID)       
						END
						
						set @PrefValue=''      
						select @PrefValue= isnull(Value,'') from @TblPref where Name='Maintain Dimensionwise Batches'        

						if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)        
						begin 	
							select @NID=DIM from @TblDeleteRows where idid=@bi		 		 
							set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,(convert(INT,@PrefValue)-50000))+'='+CONVERT(nvarchar,@NID)        
						end 
							  
						set @sql='set @Tot=(SELECT isnull(sum(BD.ReleaseQuantity),0)  
						FROM [INV_DocDetails] AS BD  WITH(NOLOCK)
						join COM_DocCCData c with(nolock) on BD.InvDocDetailsID=c.InvDocDetailsID 
						where vouchertype=1  and statusid=369 and IsQtyIgnored=0 '+@WHERE+' and batchid='+convert(nvarchar,@BatchID)+')  

						set @Tot= @Tot-(SELECT isnull(sum(BD.UOMConvertedQty),0)
						FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
						join COM_DocCCData c with(nolock) on BD.InvDocDetailsID=c.InvDocDetailsID  
						where BD.vouchertype=-1 and BD.statusid in(369,371,441) and BD.IsQtyIgnored=0 '+@WHERE+' and BD.batchid='+convert(nvarchar,@BatchID)+')'
						EXEC sp_executesql @sql,N'@Tot float OUTPUT',@Tot output	
				
					end  
				
					if(@Tot<-0.001)   
					begin  
						RAISERROR('-502',16,1)      
					end 
					
					if exists(select PrefValue from COM_DocumentPreferences with(nolock)
					where CostCenterID=@CostCenterID and PrefName='SameBatchtoall' and PrefValue='true')
					BEGIN
						IF NOT exists(SELECT BatchID FROM INV_DocDetails WITH(NOLOCK) WHERE BatchID=@BatchID and DocID<>@DocID)
						BEGIN
							EXEC @return_value = dbo.spINV_DeleteBatch
							@BatchID = @BatchID,
							@UserID = 1,
							@RoleID = 1,
							@LangID = @LangID
						END
					END
				END	 
			END 
		END
	END  
	
	IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='CRM_Cases')
	BEGIN
		delete from @caseTab
		
		SET @SQL='select CaseID FROM CRM_Cases with(nolock) where SvcContractID='+CONVERT(NVARCHAR,@DocID)  
		INSERT INTO @caseTab(CaseID)
		EXEC sp_executesql @SQL
		
		select @iUNIQ=MIN(id),@UNIQUECNT=MAX(id) FROM @caseTab
		
		WHILE(@iUNIQ <= @UNIQUECNT)
		BEGIN
			SELECT @CaseID=CaseID FROM @caseTab WHERE id=@iUNIQ
			--SELECT @CaseID
			SET @SQL='exec spCRM_DeleteCase @CASEID='+CONVERT(NVARCHAR,@CaseID)+',@USERID='+CONVERT(NVARCHAR,@UserID)+',@LangID='+CONVERT(NVARCHAR,@LangID)+',@RoleID='+CONVERT(NVARCHAR,@RoleID)
			EXEC sp_executesql @SQL	
			SET @iUNIQ=@iUNIQ+1
		END
	END
		
		if (@DocumentType=39)
	    BEGIN
		 if exists(select a.VoucherType from COM_PosPayModes a WITH(NOLOCK)
		 join COM_PosPayModes b WITH(NOLOCK) on a.VoucherNodeID=b.VoucherNodeID
		 where b.VoucherType=-1 and a.DOCID=@DocID)
		 BEGIN
				RAISERROR('-525',16,1)  
		 END
		 
		     if exists(select a.VoucherType from COM_PosPayModes a WITH(NOLOCK)
				where DOCID=@DocID and VoucherNodeID>0)
			  BEGIN
					delete from @caseTab
					INSERT INTO @caseTab(CaseID)      
					SELECT VoucherNodeID FROM COM_PosPayModes with(nolock)
					where DOCID=@DocID and VoucherNodeID>0
					
					
					delete a from COM_PosPayModes a WITH(NOLOCK) where a.DOCID=@DocID
		
					
					select @iUNIQ=MIN(id),@UNIQUECNT=MAX(id) FROM @caseTab        
				    
				    select @PrefValue=Value FROM ADM_GlobalPreferences with(nolock) WHERE Name='PosCoupons'    
					set @Dimesion=0
					if(@PrefValue is not null and @PrefValue<>'' and ISNUMERIC(@PrefValue)=1)
					begin						
						begin try
							select @Dimesion=convert(INT,@PrefValue)
						end try
						begin catch
							set @Dimesion=0
						end catch
					END
				           
					WHILE(@iUNIQ <= @UNIQUECNT and @Dimesion>50000)        
					BEGIN      
					  SELECT @CaseID=CaseID FROM @caseTab WHERE id=@iUNIQ
					  
					  EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @Dimesion,
						@NodeID = @CaseID,
						@RoleID=1,
						@UserID = 1,
						@LangID = @LangID
						
				
					  set @iUNIQ=@iUNIQ+1
				    END   
			  END
		END
		
		set @PrefValue=''
		select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
		where CostCenterID=@CostCenterID and PrefName='BackTrack'
	
		select @bi=0,@bcnt=COUNT(id) from @TblDeleteRows
		while(@bi<@bcnt)		
		BEGIN  		
			set @bi=@bi+1			
			set @InvDocDetailsID=0
			SELECT  @BatchID=CostCenterID,@InvDocDetailsID=a.linkinv from @TblDeleteRows a
			join INV_DocDetails b with(nolock) on a.linkinv=b.InvDocDetailsID
			where idid=@bi
			
			if(@InvDocDetailsID is not null and @InvDocDetailsID>0)
			BEGIN
				if(@PrefValue='true')
				BEGIN
					SELECT @Tot=isnull(sum(a.Quantity),0) FROM INV_DocDetails a WITH(NOLOCK)    
					WHERE  a.LinkedInvDocDetailsID=@InvDocDetailsID and a.Costcenterid=@CostCenterID

					update a    
					set a.LinkedFieldValue=Quantity-@Tot
					FROM INV_DocDetails a WITH(NOLOCK)
					where a.InvDocDetailsID=@InvDocDetailsID
				END
				
				delete from @caseTab
				
				insert into @caseTab(CaseID,fldName)
				select SrcDoc,Fld from COM_DocLinkCloseDetails WITH(NOLOCK)
				where CostCenterID=@CostCenterID and linkedfrom=@BatchID
				
				
				select @iUNIQ=min(id) ,@UNIQUECNT=max(id) from @caseTab
				while(@iUNIQ<=@UNIQUECNT)
				BEGIN
					SELECT @DELETECCID=CaseID,@tablename=fldName from @caseTab where id=@iUNIQ
					
					if(@tablename like 'dcalpha%')
					BEGIN
						set @SQL='SELECT @LockCCValues='+@tablename+' from COM_DocTextData WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)				
						exec sp_executesql @SQL,N'@LockCCValues nvarchar(max) output',@LockCCValues output
						
						set @SQL='SELECT @Tot=isnull(a.Quantity,0),@DocumentType=a.LinkStatusID from INV_DocDetails a WITH(NOLOCK)
							join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID 
							where a.costcenterid='+CONVERT(nvarchar,@DELETECCID)+' and '+@tablename+'='''+@LockCCValues+''''
								
						exec sp_executesql @SQL,N'@Tot float output,@DocumentType int OUTPUT',@Tot output,@DocumentType OUTPUT
						
						if(@DocumentType=445)
						BEGIN
							set @dt=0
							set @SQL='SELECT @dt=isnull(sum(a.Quantity),0) from INV_DocDetails a WITH(NOLOCK)
								join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID 
								where a.statusid<>376 and  a.costcenterid='+convert(nvarchar,@CostCenterID)+' and '+@tablename+'='''+@LockCCValues+''''
										
							exec sp_executesql @SQL,N'@dt float output',@dt output
								select @DocumentType,@Tot,@dt,@LockCCValues
							if(@Tot>@dt and @LockCCValues is not null and @LockCCValues<>'')
							BEGIN
								set @SQL='update a
								set a.LinkStatusID=443
								from INV_DocDetails a WITH(NOLOCK)
								join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
								 where '+@tablename+'='''+@LockCCValues+''''
								
								EXEC sp_executesql @SQL
							END
						END	
					END
					set @iUNIQ=@iUNIQ+1
				END
			END	
		END
		
		delete a from COM_PosPayModes a WITH(NOLOCK) where a.DOCID=@DocID
		
	IF(@DocumentType=220) -- Bid Open
	BEGIN
		SET @SQL='DELETE FROM COM_BiddingDocs WHERE BODocID='+CONVERT(NVARCHAR,@DocID)
		EXEC(@SQL)
	END


COMMIT TRANSACTION         
--ROLLBACK TRANSACTION         
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID  
RETURN 1
END TRY
BEGIN CATCH 	

	if(@return_value=-999)
		return -999
	--Return exception info [Message,Number,ProcedureName,LineNumber] 	
	IF ERROR_NUMBER()=50000
	BEGIN
		if(ERROR_MESSAGE()=-127)
		begin
			set @VoucherNo=(select top 1 VoucherNo from [INV_DocDetails] WITH(NOLOCK) where LinkedInvDocDetailsID in (SELECT InvDocDetailsID FROM [INV_DocDetails] WITH(NOLOCK)
			WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber))
			
			SELECT ErrorMessage+' '+@VoucherNo as ErrorMessage,ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		end
		else if(ERROR_MESSAGE()=-502)
		begin			
			SELECT ErrorMessage+' '+convert(nvarchar,@bi) as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		end
		else if(ERROR_MESSAGE()=-566)
		begin			
			SELECT ErrorMessage+' '+@VoucherNo as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		end
		else if(ERROR_MESSAGE()=-577)
		begin	
			SELECT ErrorMessage+' '+@DocFinalSettlement as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		end
		else
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
delete t from COM_SchEvents t  WITH(NOLOCK) Where CostCenterID=@CostCenterID and NodeID=@DocID and StatusID=1 and FilterXML like '<XML><FilePath>%'

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
