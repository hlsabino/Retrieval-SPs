USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SuspendAccDocument]
	@CostCenterID [int],
	@DocID [int],
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@Remarks [nvarchar](max),
	@LockWhere [nvarchar](max) = '',
	@SuspendAll [bit] = 0,
	@sysinfo [nvarchar](max) = '',
	@AP [varchar](10) = '',
	@UserID [int] = 0,
	@UserName [nvarchar](100),
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
  --Declaration Section    
  DECLARE @HasAccess bit,@VoucherNo nvarchar(200),@PrefValue NVARCHAR(500),@NodeID INT,@WID INT,@level INT
  DECLARE @sql nvarchar(max),@tablename nvarchar(200),@CurrentNo INT,@DocDate datetime,@DocType int
  	declare @ModDate float
  	DECLARE	@return_value int
			set @ModDate=convert(float,getdate())
	--SP Required Parameters Check
	IF(@CostCenterID<40000)
	BEGIN
		RAISERROR('-100',16,1)
	END


	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,141)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	IF (@DocID IS NOT NULL and @DocID>0)
		SELECT @VoucherNo=VoucherNo,@DocType=Documenttype,@DocPrefix=DocPrefix,@DocNumber=DocNumber,@DocDate=CONVERT(datetime,DocDate),@WID=WorkflowID   FROM [ACC_DocDetails] WITH(nolock)
		WHERE CostCenterID=@CostCenterID AND @DocID=DocID
	ELSE
		SELECT @VoucherNo=VoucherNo,@DocType=Documenttype,@DocID=DocID,@DocDate=CONVERT(datetime,DocDate),@WID=WorkflowID   FROM [ACC_DocDetails] WITH(nolock)
		WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber
	
	IF @DocID IS NULL
	BEGIN
		COMMIT TRANSACTION         
		SET NOCOUNT OFF;  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=109 AND LanguageID=@LangID  
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
  
      set @sql ='if exists (select a.AccDocDetailsID FROM  [COM_DocCCData] a with(nolock)  
      join [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID  
      WHERE b.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND b.docid='+convert(nvarchar,@DocID)+' and a.dcccnid'+convert(nvarchar,(@LockCC-50000))+' in('+@LockCCValues+'))  
      RAISERROR(''-125'',16,1)  '  
      exec(@sql)  
     END  
   END      
  END  
  
  if(dbo.fnCOM_HasAccess(@RoleID,43,193)=0 and @LockWhere <>'')
  BEGIN
	  set @sql ='if exists (select a.CostCenterID from Acc_DocDetails a WITH(NOLOCK)
			join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
			join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1
			where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
			RAISERROR(''-125'',16,1)  '  
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
 declare @IsLineWisePDC bit,@CrossDimension bit ,@PrePayment INT
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
	END
		declare @AccDocID INT,@DELETECCID INT,@delcnt int,@deli int,@DeleteDOcid INT
		DECLARE @DELDocID INT
		declare @ttdel table(id int identity(1,1),docid INT,CCID INT)
		insert into @ttdel
		SELECT distinct b.DocID,b.COSTCENTERID FROM  [ACC_DocDetails] a WITH(NOLOCK)
		join  [ACC_DocDetails] b WITH(NOLOCK) on a.AccDocDetailsID=b.RefNodeid 
		WHERE a.DocID =@DocID and b.RefCCID=400
		
		select @deli=0,@delcnt=COUNT(docid) from @ttdel
		while(@deli<@delcnt)
		BEGIN
			set @deli=@deli+1
			select @DeleteDOcid=docid,@DELETECCID=CCID from @ttdel where id=@deli
				    
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
		DELETE FROM @ttdel
		insert into @ttdel
		SELECT distinct b.DocID,b.COSTCENTERID FROM  [ACC_DocDetails] a WITH(NOLOCK)
		join  [INV_DocDetails] b WITH(NOLOCK) on a.AccDocDetailsID=b.RefNodeid 
		WHERE a.DocID =@DocID and b.RefCCID=400
		
		select @deli=min(id),@delcnt=max(id) from @ttdel
		while(@deli<=@delcnt)
		BEGIN
			
			select @DeleteDOcid=docid,@DELETECCID=CCID from @ttdel where id=@deli
				    
			 EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
			 @CostCenterID = @DELETECCID,  
			 @DocPrefix = '',  
			 @DocNumber = '',
			 @DocID=@DeleteDOcid,
			 @UserID = @UserID,  
			 @UserName = @UserName,  
			 @LangID = @LangID,  
			 @RoleID= @RoleID
			 
			 set @deli=@deli+1
		END
 
	if exists (SELECT a.ACCDocDetailsID from ACC_DocDetails a 	 WITH(nolock) 
	 join ACC_DocDetails B WITH(nolock) on a.ACCDocDetailsID =b.RefNodeid and b.RefCCID=400  
	 where a.CostCenterid=@CostCenterID and a.DocID =@DocID )
	 begin
		if exists(select ACCDocDetailsID from ACC_DocDetails WITH(nolock) where DocID =@DocID and StatusID=369)
			RAISERROR('-370',16,1)  
		else
			RAISERROR('-371',16,1)  
	 end
	 
		
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(nolock)
		where CostCenterID=@CostCenterID and PrefName='DocumentLinkDimension'
		
		if(@PrefValue is not null and @PrefValue<>'')
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
				set @sql='select @NodeID=NodeID from '+@tablename+' WITH(nolock) where Name='''+@VoucherNo+''''
				print @sql
				EXEC sp_executesql @sql,N'@NodeID INT OUTPUT',@NodeID output
				 
				if(@NodeID>1)
				begin
					if exists(SELECT PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='Inactiveonsuspend' and prefvalue='true')
					BEGIN
						select @sql=tablename from adm_features WITH(NOLOCK) where featureid=@Dimesion
						set @sql='update '+@sql+' set statusid=1004 where NODEID='+CONVERT(NVARCHAR,@NodeID)
						EXEC(@sql)
					END
					ELSE
					BEGIN
						SET @sql='UPDATE COM_DocCCData 
						SET dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'=1'
						+' WHERE AccDocDetailsID IN (SELECT AccDocDetailsID FROM [ACC_DocDetails] WITH(nolock) 
						WHERE COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND DOCID='+CONVERT(NVARCHAR,@DocID)+')'
						EXEC(@sql)
						EXEC	@return_value = [dbo].[spCOM_DeleteCostCenter]
							@CostCenterID = @Dimesion,
							@NodeID = @NodeID,
							@RoleID=1,
							@UserID = 1,
							@LangID = @LangID
					END		
				end
			end
		end	
		
		set @tablename=''
		select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=11
		if(@tablename<>'')
		exec @tablename @CostCenterID,@DocID,'',@UserID,@LangID
		
		DELETE FROM COM_Billwise 
		WHERE DocNo=@VoucherNo

		update COM_Billwise 
		set IsNewReference=1,RefDocNo=null,RefDocSeqNo=null,RefDocDate=null,RefDocDueDate=null
		WHERE RefDocNo=@VoucherNo

	 
		update [ACC_DocDetails] 
		set StatusID=376,CancelledRemarks=@Remarks,ModifiedBy=@UserName,ModifiedDate=@ModDate
		WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber
		
		DELETE FROM COM_SchEvents WHERE StatusID=1 AND 
		ScheduleID IN (SELECT DISTINCT ScheduleID FROM COM_CCSchedules with(nolock) WHERE CostCenterID=@CostCenterID AND NodeID=@DocID)
		
		UPDATE S SET StatusID=3 FROM COM_Schedules S with(nolock) 
		INNER JOIN COM_CCSchedules CC with(nolock) ON S.ScheduleID=CC.ScheduleID
		WHERE CC.CostCenterID=@CostCenterID AND CC.NodeID=@DocID 
	
		--Post Notification On Suspend Doc
		EXEC spCOM_SetNotifEvent 376,@CostCenterID,@DocID,'GUID',@UserName,@UserID,@RoleID
		
		--Audit Trail
		IF (SELECT CONVERT(BIT,PrefValue) FROM COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID and PrefName='AuditTrial')=1
		BEGIN
		
			 EXEC @return_value = [spDOC_SaveHistory]      
				@DocID =@DocID ,
				@HistoryStatus='Suspend',
				@Ininv =0,
				@ReviseReason ='',
				@LangID =@LangID,
				@UserName=@UserName,
				@ModDate=@ModDate,
				@CCID=@CostCenterID,
				@sysinfo=@sysinfo,
				@AP=@AP
		END	
		
		if exists(select * from COM_Approvals WITH(NOLOCK) where CCID=@COSTCENTERID and CCNODEID=@DOCID)
		BEGIN
			SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and UserID =@UserID
			order by LevelID desc
			
			if(@level is null)  
				SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and RoleID =@RoleID
				order by LevelID desc
				
			if(@level is null)       
				SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID
				order by LevelID desc
				
			if(@level is null)  
				SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
				order by LevelID desc
			if(@level is null)  
				set @level=1
				
			INSERT INTO COM_Approvals    
							(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
				VALUES(@COSTCENTERID,@DOCID,376,CONVERT(FLOAT,getdate()),@Remarks,@UserID,''    
						,newid(),@UserName,CONVERT(FLOAT,getdate()),@level,0)
		END	

COMMIT TRANSACTION         
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=109 AND LanguageID=@LangID  
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
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
