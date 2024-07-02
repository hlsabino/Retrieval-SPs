USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetAccDocument]
	@CostCenterID [int],
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@IsPrevNext [int],
	@DocID [int],
	@LockWhere [nvarchar](max) = '',
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit,@VoucherNo NVARCHAR(500),@canEdit bit,@UserWise bit,@DimensionWise bit,@OffLineStatus int,@AssignWise bit,@oppdc int
		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@Stat nvarchar(200),@IsLineWisePDC bit,@LockedBY nvarchar(max),@guid nvarchar(max)
		declare @PrefValue nvarchar(50),@Dimesion int,@sql nvarchar(max),@isPrinted bit,@Type int,@escDays int,@tabName nvarchar(100)
		Declare @docPref table(name nvarchar(100),value nvarchar(100))
		DECLARE @DAllowLockData BIT,@AllowLockData BIT,@IsLock bit,@DocDate float,@CreatedDate datetime,@DLockCC int,@LockCCValues nvarchar(max),@dim INT,@DisRej bit
		
		--SP Required Parameters Check
		IF (@CostCenterID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END


		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		insert into @docPref
		SELECT Name,Value FROM ADM_GlobalPreferences WITH(NOLOCK)  
		WHERE Name in('DimensionwiseDocuments','enableChequeReturnHistory','ShowAttachmentExtraFieldsInDocuments')
		

		if(@DocID>0)
		BEGIN			
			SELECT @VoucherNo=VoucherNo,@DocPrefix=DocPrefix,@DocDate=DocDate ,@DocNumber=DocNumber
			,@oppdc=OpPdcStatus,@WID=WorkflowID,@Level=WorkFlowLevel,@StatusID=StatusID,@CreatedDate=CONVERT(float,CreatedDate) FROM [ACC_DocDetails] WITH(NOLOCK) 
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID		
		END
		ELSE
		BEGIN
			SET @UserWise=dbo.fnCOM_HasAccess(@RoleID,43,137) 
			IF(@UserWise=0)
				SET @UserWise=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,137)
			SET @DimensionWise=dbo.fnCOM_HasAccess(@RoleID,43,145) 
			SET @AssignWise=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,221) 

			if(@DimensionWise=1)
			BEGIN
		   
			SELECT @PrefValue=Value FROM @docPref  WHERE Name='DimensionwiseDocuments'  

			if(@PrefValue is not null and @PrefValue<>'')    
			begin    		
				set @Dimesion=0    
				begin try    
					select @Dimesion=convert(INT,@PrefValue)    
				end try    
				begin catch    
					set @Dimesion=0    
				end catch 		
			END
			
			if(@Dimesion>50000)
			BEGIN
				set @sql='select @DimensionWise=IsColumninUse from ADM_CostCenterDef with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and SysColumnName=''dcccnid'+Convert(nvarchar,(@Dimesion-50000))+''''
				print @sql
				EXEC sp_executesql @sql,N'@DimensionWise BIT OUTPUT',@DimensionWise output
			END
		
		END
		
		IF (@UserWise=1  or @DimensionWise=1)
		BEGIN  
			set @sql='if exists(SELECT DocID FROM [ACC_DocDetails] a WITH(NOLOCK)   
			join COM_DocCCData b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID'
	
			if(@DimensionWise=1 and @Dimesion>50000)
			BEGIN
				
				set @sql=@sql+' JOIN  COM_CostCenterCostCenterMap CCM WITH(NOLOCK) ON  parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				and CCM.costcenterid='+convert(nvarchar,@Dimesion)  

				select @tabName=TableName from adm_features WITH(NOLOCK) where FeatureID=@Dimesion
				
				 set @sql=@sql+' join '+@tabName+' DCCMj with(nolock) on  CCM.NodeID= DCCMj.NodeID 
								 join '+@tabName+' DCG   with(nolock) on  DCG.lft between   DCCMj.lft and  DCCMj.rgt and DCG.NodeID=b.DcccNID'+convert(nvarchar,(@Dimesion-50000))
			END  
			
			set @sql=@sql+' WHERE a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND DocPrefix='''+@DocPrefix+''' AND convert(INT,DocNumber)'
			if(@IsPrevNext=0)
				set @sql=@sql+' = '
			else  if(@IsPrevNext=1) 
				set @sql=@sql+' <= '
			else  if(@IsPrevNext=2) 
				set @sql=@sql+' >= '
					
			set @sql=@sql+@DocNumber
			
			if(@AssignWise=1)		
				set @sql=@sql+' and a.Docid in (SELECT NodeID FROM ADM_Assign WITH(NOLOCK) 
					WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND UserID='+convert(nvarchar,@UserID)+')'

			if(@UserWise=1)		
				set @sql=@sql+' and a.CreatedBy in (select username from ADM_Users with(nolock)  
				where UserID='+convert(nvarchar,@UserID)+' or  UserID in (select NodeID from COM_CostCenterCostCenterMap with(nolock)  
				where parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				and costcenterid=7))  '
		
			set @sql=@sql+') BEGIN  
				SELECT @DocNumber=DocNumber FROM [ACC_DocDetails] a WITH(NOLOCK) 
				join COM_DocCCData b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID '
	
			if(@DimensionWise=1 and @Dimesion>50000)
			BEGIN
				
				set @sql=@sql+' JOIN  COM_CostCenterCostCenterMap CCM WITH(NOLOCK) ON  parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				and CCM.costcenterid='+convert(nvarchar,@Dimesion)  
				
				 set @sql=@sql+' join '+@tabName+' DCCMj with(nolock) on  CCM.NodeID= DCCMj.NodeID 
								 join '+@tabName+' DCG   with(nolock) on  DCG.lft between   DCCMj.lft and  DCCMj.rgt and DCG.NodeID=b.DcccNID'+convert(nvarchar,(@Dimesion-50000))
			END 
			 
			set @sql=@sql+' WHERE a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND DocPrefix='''+@DocPrefix+''' AND convert(INT,DocNumber)' 
			if(@IsPrevNext=0)
				set @sql=@sql+' = '
			else  if(@IsPrevNext=1) 
				set @sql=@sql+' <= '
			else  if(@IsPrevNext=2) 
				set @sql=@sql+' >= '	
			set @sql=@sql+@DocNumber
			
			if(@AssignWise=1)		
				set @sql=@sql+' and a.Docid in (SELECT NodeID FROM ADM_Assign WITH(NOLOCK) 
					WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND UserID='+convert(nvarchar,@UserID)+')'


			if(@UserWise=1)	
				 set @sql=@sql+'  and a.CreatedBy in (select username from ADM_Users with(nolock)  
				 where UserID='+convert(nvarchar,@UserID)+' or  UserID in (select NodeID from COM_CostCenterCostCenterMap with(nolock) 
				 where parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				 and costcenterid=7))  '
	
			set @sql=@sql+' ORDER BY convert(INT,DocNumber)       '
			if(@IsPrevNext=2) 
				set @sql=@sql+' desc '	
			set @sql=@sql+' END  
				ELSE  
				begin     
				  set @DocNumber=''notexists''
				end '
			print @sql
			EXEC sp_executesql @sql,N'@DocNumber nvarchar(200) OUTPUT',@DocNumber output
   
			if(@DocNumber='notexists')
			BEGIN
				SET NOCOUNT OFF;  
				RETURN 1  
			END 
    
		END

		 
		set @DocID=0 
		SELECT @VoucherNo=VoucherNo,@DocID=DocID,@DocDate=DocDate,@oppdc=OpPdcStatus,@WID=WorkflowID,@Level=WorkFlowLevel,@StatusID=StatusID,@CreatedDate=CONVERT(float,CreatedDate) FROM [ACC_DocDetails] WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber
			
		if(@DocID is null or @DocID=0)
		begin     
			SET NOCOUNT OFF;  
			RETURN 1  
		end 			
	END
	
	if(@VoucherNo is null)
	begin     
		SET NOCOUNT OFF;  
		RETURN 1  
	end
	insert into @docPref
	SELECT PrefName,PrefValue  FROM [COM_DocumentPreferences]  WITH(NOLOCK) 
	WHERE CostCenterID=@CostCenterID AND PrefName in('AuditTrial','Activities','LineWisePDC','UseasCrossDimension'
	,'Lock Data Between','Notes','NonAccDocs','Attachments','UseAsLC','EnableRevision','UseAsTR','LockCostCenters','LockCostCenterNodes')
	
			set @IsLineWisePDC=0
			select @IsLineWisePDC=isnull(Value,0) from @docPref
			where Name='LineWisePDC'   	

    select @LockedBY=LockedBY,@OffLineStatus=OffLineStatus,@guid=guid from COM_DocID WITH(NOLOCK) where DocNo=@VoucherNo and ID=@DocID  

			--GETTING DOCUMENT DETAILS
			SELECT A.[AccDocDetailsID] AS DocDetailsID,A.VoucherNO
					  ,A.[InvDocDetailsID]
					  ,A.[DocID]
					  ,A.[CostCenterID]					  
					  ,A.[DocumentType]
					  ,A.[VersionNo]
					  ,A.[DocAbbr]
					  ,A.[DocPrefix]
					  ,A.[DocNumber]
					  ,CONVERT(DATETIME, A.[DocDate]) AS DocDate
					  ,CONVERT(DATETIME, A.[DueDate]) AS DueDate
					  ,A.[ChequeBankName]
					  ,A.[ChequeNumber]
					  ,CONVERT(DATETIME,A.[ChequeDate]) AS ChequeDate
					  ,CONVERT(DATETIME,A.[ChequeMaturityDate]) AS ChequeMaturityDate
					  ,A.[StatusID]
					  ,A.[BillNo]
						,CONVERT(DATETIME,A.BILLDATE) AS BILLDATE
					  ,A.[LinkedAccDocDetailsID]
					  ,A.[CommonNarration]
						,A.LineNarration
					  ,A.[DocSeqNo]
					  ,A.[DebitAccount]
					  ,A.[CreditAccount]					  
					  ,A.[Amount]
					  ,A.IsNegative
					  ,A.[CurrencyID]
					  ,A.[ExchangeRate]					  
					  ,@guid [GUID]
					  ,A.[Description]
					  ,A.[CreatedBy]
					  ,CONVERT(DATETIME,A.[CreatedDate]) AS CreatedDate
					  ,A.[ModifiedBy]
					  ,CONVERT(DATETIME,A.[ModifiedDate]) AS ModifiedDate
					 ,amountfc,A.BILLDATE IsReplce,convert(datetime,a.ActDocDate) ActDocDate
					  ,db.IsBillwise DBIsBillwise ,cr.IsBillwise CrIsBillwise
					  ,db.AccountCode DBAccountCode,cr.AccountCode CrAccountCode
					  ,db.AccountName DBAccountName,cr.AccountName CrAccountName
					  ,RefCCID,RefNodeid,BankAccountID
					  ,ChequeBookNo,A.WorkflowID
					  ,CONVERT(DATETIME,A.ClearanceDate) AS ClearanceDate
					  ,BRS_Status,A.WorkFlowLevel,@oppdc oppdc
				  FROM [ACC_DocDetails] A   WITH(NOLOCK) 
				  join ACC_Accounts db  WITH(NOLOCK) on A.[DebitAccount]=db.AccountID
				  join ACC_Accounts cr  WITH(NOLOCK) on A.[CreditAccount]=cr.AccountID
				  WHERE A.CostCenterID=@CostCenterID AND docid=@DocID and 
				  (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0)
				 order by  DocSeqNo
		
		
			--GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS
			SELECT A.* FROM  [COM_DocCCData] A WITH(NOLOCK)  
			join [ACC_DocDetails] B WITH(NOLOCK) on  A.AccDocDetailsID =B.AccDocDetailsID
			WHERE CostCenterID=@CostCenterID AND docid=@DocID  and 
				  (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0)
			order by DocSeqNo
		 
			--GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS
			SELECT A.*   FROM [COM_DocNumData] A WITH(NOLOCK)  
			join [ACC_DocDetails] B WITH(NOLOCK) on  A.AccDocDetailsID =B.AccDocDetailsID
			WHERE CostCenterID=@CostCenterID AND docid=@DocID 
			order by DocSeqNo

			--GETTING DOCUMENT EXTRA TEXT FEILD DETAILS
			SELECT A.*  FROM [COM_DocTextData] A WITH(NOLOCK)  
			join [ACC_DocDetails] B WITH(NOLOCK) on  A.AccDocDetailsID =B.AccDocDetailsID
			WHERE CostCenterID=@CostCenterID AND docid=@DocID 
			order by DocSeqNo

			--GETTING BillWise
			if(@IsLineWisePDC=1 or exists(	select Value from @docPref
			where Name='UseasCrossDimension' and Value='true'))
				SELECT B.RefNodeid,RefStatusID,[DocNo],A.[DocSeqNo],[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT]
				,[IsNewReference],[RefDocNo],[RefDocSeqNo],convert(datetime,RefDocDate) RefDocDate,convert(datetime,RefDocDueDate) RefDocDueDate,[RefBillWiseID]
				,[Narration],A.[AmountFC],IsDocPDC,[DiscAccountID],[DiscAmount],[DiscCurrID],[DiscExchRT] FROM COM_Billwise a WITH(NOLOCK)	
				join [ACC_DocDetails] B WITH(NOLOCK) on  A.[DocNo] =B.VoucherNo
				join [ACC_DocDetails] C WITH(NOLOCK) on  B.RefNodeid =C.AccDocDetailsID
				WHERE C.docid=@DocID
			ELSE
				SELECT [DocNo],RefStatusID,A.[DocSeqNo],[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT]
				,[IsNewReference],[RefDocNo],[RefDocSeqNo],convert(datetime,RefDocDate) RefDocDate,convert(datetime,RefDocDueDate) RefDocDueDate,[RefBillWiseID]
				,[Narration],A.[AmountFC],IsDocPDC,[DiscAccountID],[DiscAmount],[DiscCurrID],[DiscExchRT] FROM COM_Billwise a WITH(NOLOCK)			
				WHERE [DocNo]=@VoucherNo
			
			if(@IsLineWisePDC=1)
			BEGIN 			
				select b.AccDocDetailsID,a.StatusID,a.VoucherNo FROM [ACC_DocDetails] a WITH(NOLOCK)   
				join [ACC_DocDetails] b WITH(NOLOCK) on a.RefNodeid=b.AccDocDetailsID
				where  b.DocID=@DocID
			END
			ELSE
				SELECT 1 WHERE 1<>1

			
		if(@WID is not null and @WID>0)  
		BEGIN  
			SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID and LevelID>=@Level
			order by LevelID desc

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID and LevelID>=@Level
				order by LevelID desc

			if(@Userlevel is null )       
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID and LevelID>=@Level
				order by LevelID desc

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID>=@Level
				order by LevelID desc
			
			if(@Userlevel is null )	
					SELECT @Type=type FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID
		end  
     
  
		if(@StatusID<>369)  
		begin    
			if(@Userlevel is not null and  @Level is not null and @Userlevel>@level)  
			begin
				if(@Type=1 or @Level+1=@Userlevel)
					set @canApprove=1   
				ELSE
				BEGIN
					if exists(select EscDays from [COM_WorkFlow] a WITH(NOLOCK) 
						join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID
						where b.CostCenterID=@CostCenterID  and a.LevelID=b.LevelID and  IsEnabled=1 and ApprovalMandatory=1 and a.workflowid=@WID and a.LevelID<@Userlevel and a.LevelID>@Level)
						set @canApprove=0
					ELSE
					BEGIN
						select @escDays=isnull(sum(escdays),0) from (select max(escdays) escdays from [COM_WorkFlow] a WITH(NOLOCK) 
						join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID
						where b.CostCenterID=@CostCenterID  and a.LevelID=b.LevelID and  IsEnabled=1 and a.workflowid=@WID and a.LevelID<@Userlevel and a.LevelID>@Level
						group by a.LevelID) as t
						 
						set @CreatedDate=dateadd("d",@escDays,@CreatedDate)
						
						select @escDays=isnull(sum(escdays),0) from (select max(eschours) escdays from [COM_WorkFlow] a WITH(NOLOCK) 
						join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID
						where b.CostCenterID=@CostCenterID  and a.LevelID=b.LevelID and  IsEnabled=1 and a.workflowid=@WID and a.LevelID<@Userlevel and a.LevelID>@Level
						group by a.LevelID) as t
						
						set @CreatedDate=dateadd("HH",@escDays,@CreatedDate)
						
						if (@CreatedDate<getdate())
							set @canApprove=1   
						ELSE
							set @canApprove=0
					END
				END	
			end   
			else  
				set @canApprove= 0   
		end  
		else  
			set @canApprove= 0
			
			set @canEdit=1  
     
  
			if((@StatusID=369 or @StatusID=441 or @StatusID=371) and @WID>0)   
			begin  
				if(@Userlevel is null )  
				BEGIN
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]   WITH(NOLOCK)   
					where WorkFlowID=@WID and  UserID =@UserID and LevelID<@Level
					order by LevelID
					
					if(@Userlevel is null )  
						SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]  WITH(NOLOCK)    
						where WorkFlowID=@WID and  RoleID =@RoleID and LevelID<@Level
						order by LevelID

					if(@Userlevel is null )       
						SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
						JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
						where g.UserID=@UserID and WorkFlowID=@WID and LevelID<@Level
						order by LevelID

					if(@Userlevel is null )  
						SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
						JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
						where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID<@Level
						order by LevelID
				END
				
				if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
				begin  
					set @canEdit=0   
				end    
			end   
     

			if(@Userlevel is null and @WID>0 )  
			BEGIN
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]   WITH(NOLOCK)   
					where WorkFlowID=@WID and  UserID =@UserID
					order by LevelID
					
					if(@Userlevel is null )  
						SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]  WITH(NOLOCK)    
						where WorkFlowID=@WID and  RoleID =@RoleID
						order by LevelID

					if(@Userlevel is null )       
						SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
						JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
						where g.UserID=@UserID and WorkFlowID=@WID
						order by LevelID

					if(@Userlevel is null )  
						SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
						JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
						where g.RoleID =@RoleID and WorkFlowID=@WID
						order by LevelID
			END
			
			--Getting Status
			if(@oppdc is not null and @oppdc>0 and @StatusID=369)
				SELECT @Stat=R.ResourceData from COM_Status S WITH(NOLOCK)  
				JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID     
				where StatusID=@oppdc
			else
				SELECT @Stat=R.ResourceData from COM_Status S WITH(NOLOCK)  
				JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID     
				where StatusID=@StatusID
			
			if exists(select DocID from INV_DocDetails_History_ATUser	WITH(NOLOCK) where DocID=@DocID and ActionTypeID=2 and ActionType='Print')
				set @isPrinted=1
			ELSE
				set @isPrinted=0
			
			set @HasAccess=0	
			if(@StatusID=429 and not exists(select DocNo FROM COM_ChequeReturn WITH(NOLOCK)
			WHERE RefDocNo=@VoucherNo))
					set @HasAccess=1
			
		SELECT @AllowLockData=Value FROM ADM_GlobalPreferences WITH(NOLOCK)  
		WHERE Name='Lock Data Between'
		
		SELECT @DAllowLockData=Value FROM @docPref
		WHERE Name='Lock Data Between'
		
		set @DLockCC=0	
		SELECT @DLockCC=CONVERT(INT,Value) FROM @docPref 
		where Name='LockCostCenters' and isnumeric(Value)=1
		
		declare @tble table(NIDs INT)  
		
		if(@DAllowLockData=1 and @DLockCC>50000)
		BEGIN
			SELECT @LockCCValues=Value FROM @docPref WHERE Name='LockCostCenterNodes'
			
			insert into @tble				
			exec SPSplitString @LockCCValues,',' 
			
			set @sql ='select @dim=dcCCNID'+CONVERT(NVARCHAR,(@DLockCC-50000))+' from Acc_DocDetails a WITH(NOLOCK)
					join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
				   where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)
							   
				   EXEC sp_executesql @sql,N'@dim INT OUTPUT',@dim output
		END	
		IF exists(select * from ADM_LockedDates WITH(NOLOCK) where isEnable=1 
		and ((@AllowLockData=1 and @DocDate between FromDate and ToDate and CostCenterID=0)
		or (@DAllowLockData=1 and @DocDate between FromDate and ToDate and CostCenterID=@CostCenterID and @DLockCC=0)
		or (@DAllowLockData=1 and @DocDate between FromDate and ToDate and CostCenterID=@CostCenterID and @DLockCC>50000
		and exists(select NIDs From @tble where NIDs=@dim))))
			set @IsLock=1	
		ELSE
			set @IsLock=0
		
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
							set @IsLock=1 '

			  END
			  ELSE
			  BEGIN
				  set @sql ='if exists (select a.CostCenterID from Acc_DocDetails a WITH(NOLOCK)
						join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
						join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1
						where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
							set @IsLock=1 ' 
			  END				
						 
			  EXEC sp_executesql @sql,N'@IsLock BIT OUTPUT',@IsLock output
		  END 
		
		
		select @canApprove canapprove,@canEdit CanEdit,@Stat 'Status',@isPrinted IsPrinted,@HasAccess 'CanRedeposit',@IsLock IsLock,@Userlevel userlevel,@level Wlevel,@Type WType,@LockedBY LockedBY,@OffLineStatus OffLineStatus,@DisRej DisableReject--6
			
			
		IF exists (SELECT Value  FROM @docPref 
		WHERE Name='Notes' and Value='true')
		BEGIN
			--GETTING NOTES
			SELECT [NoteID],[Note],[CostCenterID],CreatedBy,Convert(DateTime,CreatedDate) CreatedDate,ModifiedBy,CONVERT(DATETIME,ModifiedDate) ModifiedDate FROM COM_Notes WITH(NOLOCK)      
			WHERE FeatureID=@CostCenterID AND FeaturePK=@DocID 
		END
		ELSE
			SELECT 1 WHERE 1<>1

		IF exists (SELECT Value  FROM @docPref  
		WHERE Name='Attachments' and Value='true')
		BEGIN
			--GETTING ATTACHMENTS BASED ON GLOBALPREFERENCE
			IF exists (SELECT Value  FROM @docPref  WHERE Name='ShowAttachmentExtraFieldsInDocuments' and Value='true')
				EXEC [spCOM_GetAttachments] @CostCenterID,@DocID,@UserID
			ELSE
			BEGIN
				--GETTING ATTACHMENTS
				SELECT [FileID],[FilePath],[ActualFileName],[RelativeFileName],[FileExtension],[IsProductImage],AllowInPrint,RowSeqNo,ColName,IsDefaultImage
					,[FileDescription],[CostCenterID],GUID,CreatedBy,CONVERT(DATETIME,CreatedDate) CreatedDate,CONVERT(DATETIME,ValidTill) ValidTill,status FROM  COM_Files WITH(NOLOCK) 
				WHERE FeatureID=@CostCenterID AND FeaturePK=@DocID
			END
		END
		ELSE
			SELECT 1 WHERE 1<>1

        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='Activities' and Value='true')
		BEGIN 
			SET @SQL='IF(EXISTS(SELECT CostCenterID FROM CRM_Activities WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND NodeID=@DocID))
				EXEC spCRM_GetFeatureByActvities @DocID,@CostCenterID,'''','+CONVERT(NVARCHAR,@UserID)+','+CONVERT(NVARCHAR,@LangID)+'  
			ELSE
				SELECT 1 WHERE 1<>1 '
			EXEC sp_executesql @SQL,N'@CostCenterID INT,@DocID INT',@CostCenterID,@DocID
		END	
		ELSE
			SELECT 1 WHERE 1<>1
			
        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='EnableRevision' and Value='true')
		BEGIN 		 
		 	select distinct Versionno from [Acc_DocDetails_History] WITH(NOLOCK) 
			where DocID=@DocID
		END	
		ELSE
			SELECT 1 WHERE 1<>1

	 
        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='enableChequeReturnHistory' and Value='true')
		BEGIN 	 
			if(@IsLineWisePDC=1 or exists(	select Value from @docPref
			where Name='UseasCrossDimension' and Value='true'))
				SELECT [DocNo],c.[DocSeqNo],[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT]
				,[IsNewReference],[RefDocNo],[RefDocSeqNo],convert(datetime,RefDocDate) RefDocDate,convert(datetime,RefDocDueDate) RefDocDueDate
				,[Narration],a.[AmountFC],IsDocPDC,A.[DocNo] PdcDoc
				FROM COM_ChequeReturn A WITH(NOLOCK)
				join [ACC_DocDetails] B WITH(NOLOCK) on  A.[DocNo] =B.VoucherNo
				join [ACC_DocDetails] C WITH(NOLOCK) on  B.RefNodeid =C.AccDocDetailsID
				WHERE C.docid=@DocID
			ELSE
				SELECT [DocNo],[DocSeqNo],[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT]
				,[IsNewReference],[RefDocNo],[RefDocSeqNo],convert(datetime,RefDocDate) RefDocDate,convert(datetime,RefDocDueDate) RefDocDueDate
				,[Narration],[AmountFC],IsDocPDC FROM COM_ChequeReturn WITH(NOLOCK)
				WHERE DocNo=@VoucherNo
		END
		ELSE
			SELECT 1 WHERE 1<>1
		
		
		if exists (select a.name from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where a.name='BatchID' and b.name='Acc_DocDetails')
		BEGIN
			set @sql='select a.BatchID,b.BatchNUmber,a.AccDocDetailsID from ACC_DocDetails a  WITH(NOLOCK)
			join inv_batches b with(nolock) on a.BatchID=b.BatchID
			 WHERE A.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND docid='+convert(nvarchar,@DocID)	 
			print @sql
			exec(@sql)
		END 
		ELSE
			SELECT 1 WHERE 1<>1
			
		select * from COM_DocDenominations WITH(NOLOCK)
		WHERE DOCID=@DocID

		--Workflow Details
		SELECT @WID=WorkflowID FROM [Inv_DocDetails] WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND DocID=@DocID		
		IF @WID is not null and @WID>0
		begin
			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=@CostCenterID AND CCNodeID=@DocID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		else
		begin
			select 1 WF where 1!=1
			select 1 WFL where 1!=1
		end
		
		 IF exists (SELECT Value  FROM @docPref  
		WHERE Name='NonAccDocs' and Value<>'')
		BEGIN 	 
			SELECT * FROM COM_BillWiseNonAcc WITH(NOLOCK)
			WHERE DocNo=@VoucherNo
		END
		ELSE
			SELECT 1 WHERE 1<>1
		
			
		--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA    
		IF exists (SELECT Value  FROM @docPref WHERE Name='AuditTrial' and Value='true')
		BEGIN        
			INSERT INTO INV_DocDetails_History_ATUser(DocType,DocID,VoucherNo,ActionType,ActionTypeID,UserID,CreatedBy,CreatedDate)  
			VALUES(@CostCenterID,@DocID,@VoucherNo,'View',1,@UserID,@UserName,CONVERT(FLOAT,GETDATE()))        
		END

		--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA
		IF exists (SELECT Value  FROM @docPref WHERE Name='AuditTrial' and Value='true')
		BEGIN 
			INSERT INTO ACC_DocDetails_History_ATUser(DocType,DocID,VoucherNo,ActionType,ActionTypeID,UserID,CreatedBy,CreatedDate)
			VALUES(@CostCenterID,@DocID,@VoucherNo,'View',1,@UserID,@UserName,CONVERT(FLOAT,GETDATE()))
		END
	 
			
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
