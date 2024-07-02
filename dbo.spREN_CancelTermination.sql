USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_CancelTermination]
	@ContractID [int],
	@SCostCenterID [int],
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY        
SET NOCOUNT ON;  
	
	DECLARE @Dt float,@XML xml,@CNT INT,@I INT,@return_value int,@AUDITSTATUS NVARCHAR(50),@ServiceUnitDims INT,@ServiceTypeVal INT,@pendset bit
	DECLARE @OldStatus int, @DELETEDOCID INT , @DELETECCID INT , @DELETEISACC BIT,@AuditTrial BIT,@IsAccDoc BIT,@ServiceType nvarchar(max),@EndDate datetime 
	DECLARE @CostCenterID int,@PendingVchrs nvarchar(max),@DDXML nvarchar(max),@TermDate float,@STATUSID INT,@DocCC nvarchar(max),@TerminationPostingDate datetime

	set @DocCC=''
	select @DocCC =@DocCC +','+a.name from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData' and a.name like 'dcCCNID%'
		
	SET @Dt=convert(float,getdate())
	declare @tabvchrs table(vno nvarchar(200))
	select @OldStatus=STATUSID,@TermDate=TerminationDate,@pendset=PendFinalSettl
	,@EndDate=convert(datetime,EndDate),@TerminationPostingDate=convert(datetime,TerminationPostingDate) from REN_CONTRACT WITH(NOLOCK) WHERE ContractID = @ContractID  
	
	
	
	set @ServiceUnitDims=0
	select  @ServiceType = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 and  Name = 'ServiceUnitTypes'
	select  @ServiceUnitDims = Value from COM_CostCenterPreferences   WITH(nolock) 
	 where CostCenterID=95 and  Name = 'ServiceUnitDims' and Value<>'' and isnumeric(Value)=1
	
	set @ServiceTypeVal=0
	if(@ServiceUnitDims>0 )
	BEGIN
		set @DDXML='select @ServiceTypeVal=CCNID'+convert(nvarchar(50),(@ServiceUnitDims-50000))+' from COM_ccccdata u with(nolock) 
		where u.NodeID='+CONVERT(NVARCHAR(MAX),@ContractID)+' and CostCenterID=95'
		exec sp_executesql @DDXML, N'@ServiceTypeVal INT output', @ServiceTypeVal OUTPUT
	END
	
	declare @tble table(NIDs INT)  
	insert into @tble				
	exec SPSplitString @ServiceType,','  
		
	IF not (@ServiceTypeVal>0 and exists(select * from @tble where NIDs=@ServiceTypeVal)) and (@SCostCenterID=95 and @OldStatus=428)
	BEGIN
		set @DDXML='if exists(SELECT C2.ContractID FROM REN_Contract C1 with(nolock)
		JOIN REN_Contract C2 with(nolock) ON C2.UnitID=C1.UnitID AND C2.SNO > C1.SNO'
		
		if(@ServiceUnitDims>0 and @ServiceType is not null and @ServiceType<>'')
					set @DDXML =@DDXML+' join COM_ccccdata u with(nolock) on u.NodeID=C2.contractid and u.CostCenterID=95 and u.CCNID'+convert(nvarchar(max),(@ServiceUnitDims-50000))+' not in('+@ServiceType+')'
			
		
		set @DDXML=@DDXML+' WHERE C1.ContractID='+CONVERT(NVARCHAR(MAX),@ContractID)
		
		--if(@ServiceUnitDims>0 and @ServiceType is not null and @ServiceType<>'')
		--	set @DDXML=@DDXML+' AND u.NodeID IS NOT NULL '
			
		set @DDXML=@DDXML+' AND C1.EndDate BETWEEN C2.StartDate AND C2.EndDate and c2.statusid<>451 )
		RAISERROR(''-520'',16,1)'	
		exec(@DDXML)
	END
	
	IF(@SCostCenterID=104 and @OldStatus=428)
	BEGIN
		set @DDXML='if exists(SELECT C2.ContractID FROM REN_Contract C1 with(nolock)
		LEFT JOIN REN_Contract C2 with(nolock) ON C2.PropertyID=C1.PropertyID AND C2.SNO > C1.SNO
		WHERE C1.ContractID='+CONVERT(NVARCHAR(MAX),@ContractID)+' AND C2.ContractID IS NOT NULL
		C2.CostCenterID=95 AND C1.CostCenterID=95 AND C1.EndDate BETWEEN C2.StartDate AND C2.EndDate )
		RAISERROR(''-520'',16,1)'	
		exec(@DDXML)
	END
	
	
	if exists(select * from com_costcenterpreferences
	where costcenterid=95 and name = 'FinalSettlement' and value='true')
	BEGIN
		UPDATE REN_CONTRACT
		SET PendFinalSettl=1,FinalSettlXML=null
		WHERE ContractID = @ContractID  or RefContractID=@ContractID
	END
	ELSE
	BEGIN
		SET @STATUSID=426
		IF((select RenewRefID from REN_CONTRACT WITH(NOLOCK) WHERE ContractID=@ContractID)>0)
			SET @STATUSID=427
	
	
		if(@OldStatus in(450,478))
			SET @AUDITSTATUS= 'Cancelrefund'
		else if(@OldStatus in(480,481))
			SET @AUDITSTATUS= 'CancelClose'
		else if(@OldStatus = 477)
			SET @AUDITSTATUS= 'CancelFullRefund'	  
		else	
			SET @AUDITSTATUS= 'CancelTERMINATE'  
		
		if(@OldStatus in(450,478,480,481))
			UPDATE REN_CONTRACT
			SET STATUSID = @STATUSID ,VacancyDate =NULL , RefundDate = NULL  ,wfAction=null,PendFinalSettl=null,FinalSettlXML=null  
			WHERE ContractID = @ContractID  or RefContractID=@ContractID
		else
			UPDATE REN_CONTRACT  
			SET STATUSID = @STATUSID ,TerminationDate =NULL , Reason = NULL  ,wfAction=null,PendFinalSettl=null,FinalSettlXML=null
			WHERE ContractID = @ContractID  or RefContractID=@ContractID
	END
	
	if(@pendset is null or @pendset=0)
	BEGIN
		update b
		set statusid=1
		from REN_ContractDocMapping DM WITH(NOLOCK)
		join COM_CCSchedules a WITH(NOLOCK) on DM.CostCenterID=a.CostCenterID
		join COM_SchEvents b WITH(NOLOCK) on a.ScheduleID=b.ScheduleID
		where a.NodeID=DM.DocID and DM.ContractID = @ContractID and b.statusid=3
		and (DM.TYPE = 1 OR DM.TYPE IS NULL) and (DM.isaccdoc = 0 OR DM.IsAccDoc  IS NULL )


		delete from [REN_TerminationParticulars]
		where contractID=@ContractID
		
			
		SET @AuditTrial=0      
		SELECT @AuditTrial= CONVERT(BIT,VALUE)  FROM [COM_COSTCENTERPreferences] WITH(NOLOCK)     
		WHERE CostCenterID=@SCostCenterID  AND NAME='AllowAudit'   
	  
	  
		IF (@AuditTrial=1 AND (@SCostCenterID=95 OR @SCostCenterID=104))    
		BEGIN
			--INSERT INTO HISTROY
			EXEC [spCOM_SaveHistory]  
				@CostCenterID =@SCostCenterID,    
				@NodeID =@ContractID,
				@HistoryStatus =@AUDITSTATUS,
				@UserName=@UserName,
				@DT=@DT       
		END       
  END
--------------------------Cancel  POSTINGS --------------------------  
      
IF(@pendset is null or @pendset=0) and (@SCostCenterID  = 95 OR @SCostCenterID  = 104)  
BEGIN    
      
    DECLARE  @tblXML TABLE(ID int identity(1,1),DOCID INT,COSTCENTERID int,IsAccDoc bit,Stat int)
	
	if(@OldStatus in(450,478,480,481))
	BEGIN
		INSERT INTO @tblXML       
		select DocID,COSTCENTERID,IsAccDoc,0 from [REN_ContractDocMapping] WITH(NOLOCK) 
		where  [ContractID]=@ContractID and [Type]=101 and ContractCCID=@SCostCenterID
		ORDER BY DocID DESC
	END
	ELSE
	BEGIN
		if exists(select Value from COM_CostCenterPreferences WITH(NOLOCK) where Name='CancelIncomeonTerminate' and Value='true')
		BEGIN
			update b
			set statusid=369
			FROM REN_CONTRACTDOCMAPPING a WITH(NOLOCK)
			join acc_docdetails b WITH(NOLOCK) on a.docid=b.docid
			where doctype=5 and contractid=@ContractID
			and b.statusid=376
		END
		
		if exists(select Value from COM_CostCenterPreferences WITH(NOLOCK) where costcenterid=95 and Name='PostIncomeMonthEnd' and Value='true')
		BEGIN
			update b
			set docdate=case when month(@EndDate)=month(convert(datetime,b.docdate)) and  year(@EndDate)=year(convert(datetime,b.docdate)) then convert(float,@EndDate)
			else convert(float,dateadd(d,-1,dateadd(m,datediff(m,0,convert(datetime,b.docdate))+1,0))) end
			 from REN_CONTRACTDOCMAPPING a
			join acc_docdetails b on a.docid=b.docid		
			where  a.contractid=@ContractID and a.doctype=5 
			and month(b.docdate)=month(@TerminationPostingDate) and year(b.docdate)=year(@TerminationPostingDate)
		END
		
		INSERT INTO @tblXML       
		select DocID,COSTCENTERID,IsAccDoc,0 from [REN_ContractDocMapping]  WITH(NOLOCK)
		where  [ContractID]=@ContractID and [Type]<0 and ContractCCID=@SCostCenterID
		ORDER BY DocID DESC
	END
	
	--insert into @tblXML
	--select DocID,CCID,0,0 from COM_DocFlow WITH(NOLOCK)
	--where RefCCID=95 and RefNodeID=@ContractID
	
	
	set @I=0
	select @CNT=max(ID) from @tblXML
	WHILE(@I <  @CNT)      
	BEGIN                
		SET @I = @I+1  
		set @DELETEDOCID=0
		set @DELETECCID=0
		SELECT @DELETEDOCID = DOCID,@IsAccDoc=IsAccDoc FROM @tblXML WHERE ID = @I      
        
        if(@IsAccDoc=1) 
        BEGIN
			SELECT @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails  WITH(NOLOCK)        
			WHERE DOCID = @DELETEDOCID      
			IF @DELETECCID IS NOT NULL and @DELETECCID>0 AND @DELETEDOCID IS NOT NULL and @DELETEDOCID>0
			BEGIN
			
				EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]        
				@CostCenterID = @DELETECCID,        
				@DocPrefix = '',        
				@DocNumber = '',   
				@DOCID = @DELETEDOCID,
				@SysInfo =@SysInfo, 
				@AP =@AP, 
				@UserID = 1,        
				@UserName = N'ADMIN',        
				@LangID = 1,
				@RoleID = 1
			END
		END	
		ELSE
		BEGIN
			SELECT  @DELETECCID = COSTCENTERID FROM dbo.INV_DocDetails WITH(NOLOCK)         
			WHERE DOCID = @DELETEDOCID      
			IF @DELETECCID IS NOT NULL and @DELETECCID>0 AND @DELETEDOCID IS NOT NULL and @DELETEDOCID>0
			BEGIN
			
				EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]        
				@CostCenterID = @DELETECCID,        
				@DocPrefix = '',        
				@DocNumber = '', 
				@DOCID = @DELETEDOCID, 
				@SysInfo =@SysInfo, 
				@AP =@AP,       
				@UserID = 1,        
				@UserName = N'ADMIN',        
				@LangID = 1,
				@RoleID =1
			END
		END       
    END
     
     
    DELETE from COM_DocFlow 
	where RefCCID=95 and RefNodeID=@ContractID and ccid=1000
     
     
    if(@OldStatus = 450)
	BEGIN
	  DELETE from [REN_ContractDocMapping] 
	  where  [ContractID]=@ContractID and [Type]=101 and ContractCCID=@SCostCenterID   
	END
	ELSE
	BEGIN
	
		DELETE from [REN_ContractDocMapping] 
		where  [ContractID]=@ContractID and [Type]<0 and ContractCCID=@SCostCenterID
	    
		INSERT INTO @tblXML       
		select b.DocID,b.COSTCENTERID,IsAccDoc,StatusID from [REN_ContractDocMapping] a WITH(NOLOCK)
		join [ACC_DocDetails] b WITH(NOLOCK) on a.DocID=b.DocID 
		where  [ContractID]=@ContractID and [Type]>0 and ContractCCID=@SCostCenterID and IsAccDoc=1
		and b.StatusID in(376,452)	and documenttype in (14,19)
		
		select @I=min(ID),@CNT=max(ID) from @tblXML
		WHILE(@I < = @CNT)      
		BEGIN              
			SELECT @DELETEDOCID = DOCID,@CostCenterID=COSTCENTERID,@OldStatus=Stat FROM @tblXML WHERE ID = @I      
			
			update [ACC_DocDetails] 
			set StatusID=370,CancelledRemarks=NULL
			WHERE CostCenterID=@CostCenterID AND DOCID=@DELETEDOCID
			
			if(@OldStatus=376 and exists (select accountid from acc_accounts WITH(NOLOCK)
						where accountid =(select CreditAccount from [ACC_DocDetails] WITH(nolock)   where CostCenterID=@CostCenterID AND DOCID=@DELETEDOCID)
						and isbillwise=1))
			BEGIN
			set @DDXML='INSERT INTO [COM_Billwise]    
		 ([DocNo]    
		 ,[DocDate]    
		 ,[DocDueDate]    
		   ,[DocSeqNo]    
		   ,[AccountID]    
		   ,[AdjAmount]    
		   ,[AdjCurrID]    
		   ,[AdjExchRT]    
		   ,[DocType]    
		   ,[IsNewReference]    
		   ,[RefDocNo]    
		   ,[RefDocSeqNo]    
		 ,[RefDocDate]    
		 ,[RefDocDueDate]    
		   ,[Narration]    
		   ,[IsDocPDC]'+@DocCC+' , AmountFC)    
		 select VoucherNo    
		   , DocDate    
		   , DueDate    
		   , [DocSeqNo]    
		   , CreditAccount    
		   , Amount    
		   , [CurrencyID]    
		   , [ExchangeRate]
		   , [DocumentType]    
		   , 1    
		   , NULL    
		   ,NULL    
		   , NULL    
		   ,NULL    
		   , ''    
		   , 1'+@DocCC +', [AmountFC] 
		 from [ACC_DocDetails] a  WITH(NOLOCK)   
		 join [COM_DocCCData] d  WITH(NOLOCK)  on d.AccDocDetailsID=a.AccDocDetailsID 
		 where a.CostCenterID='+convert(nvarchar(max),@CostCenterID)+' AND a.DOCID='+convert(nvarchar(max),@DELETEDOCID)
			END
			SET @I = @I+1  
		END
		
		
		set @PendingVchrs=''
		
		select @PendingVchrs=@PendingVchrs+dbo.[fnDoc_GetPendingVouchers](VoucherNo) from ACC_DocDetails WITH(NOLOCK)
		where RefCCID=@SCostCenterID and RefNodeid=@ContractID and StatusID=429
		
		insert into @tabvchrs
		exec SPSplitString @PendingVchrs,','
		
		update ACC_DocDetails 
		set StatusID=370
		where StatusID=452 and VoucherNo in(select vno from @tabvchrs)
	END     
END 
   
COMMIT TRANSACTION       
     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;
RETURN @ContractID        
END TRY        
BEGIN CATCH   
 if(@return_value is null or  @return_value<>-999)     
 BEGIN          
IF ERROR_NUMBER()=50000    
 BEGIN    
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END     
 ROLLBACK TRANSACTION      
 END  
 SET NOCOUNT OFF        
 RETURN -999         
    
    
END CATCH   
  
GO
