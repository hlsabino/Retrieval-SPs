USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetReportData]
	@Type [int] = 0,
	@Param1 [int],
	@strXML [nvarchar](max) = NULL,
	@RoleID [int] = -153
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
	declare @UserID int,@SQL nvarchar(max)
	
	IF @Type=0
	BEGIN
		select r.ReportID,ReportName, ReportTypeName, StatusID, ParentID,GroupName From ADM_RevenUReports r with(nolock)  
		left join (select ReportID, ReportName GroupName from ADM_RevenUReports with(nolock) where IsGroup=1) as g on g.ReportID=r.ParentID
		where IsGroup=1 order by ReportName
	END
	ELSE IF @Type=1
	BEGIN
		select ReportID,ReportName From ADM_RevenUReports with(nolock) 
		where StaticReportType=@Param1 AND ReportID>0 AND IsGroup=0
		order by ReportName
	END
	ELSE IF @Type=2
	BEGIN
		select ReportDefnXML From ADM_RevenUReports with(nolock) 
		where ReportID=@Param1
	END
	ELSE IF @Type=3
	BEGIN
		set @UserID=@Param1
		
		select CostCenterID,DocumentName,DocumentAbbr From ADM_DocumentTypes with(nolock) 
		where IsInventory=1 --and DocumentType not between 51 and 90
		and (@RoleID=1 or @UserID=1 or CostCenterID IN( select FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
			inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
			where FAR.RoleID=@RoleID and (FA.FeatureActionTypeID=1 or FA.FeatureActionTypeID=2) and FA.FeatureID between 40000 and 50000
			))
		Order By DocumentName
	END
	ELSE IF @Type=4
	BEGIN
		select FileID,FileDescription,GUID From COM_Files with(nolock) 
		where CostCenterID=50 and FeaturePK=@Param1
		Order By FileDescription
	END
	ELSE IF @Type=5
	BEGIN
	BEGIN TRANSACTION
		declare @XML xml
		
		set @XML=@strXML
		INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
	   FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
	   GUID,CreatedBy,CreatedDate)  
	   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
	   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),50,50,@Param1,
	   X.value('@GUID','NVARCHAR(50)'),X.value('@UserName','NVARCHAR(50)'),convert(float,getdate())  
	   FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
	   WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
	  
	   --If Action is MODIFY then update Attachments  
	   UPDATE COM_Files  
	   SET FilePath=X.value('@FilePath','NVARCHAR(500)'),  
		ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
		RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),  
		FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
		FileDescription=X.value('@FileDescription','NVARCHAR(500)'),  
		IsProductImage=X.value('@IsProductImage','bit'),        
		GUID=X.value('@GUID','NVARCHAR(50)'),  
		ModifiedBy=X.value('@UserName','NVARCHAR(50)'),  
		ModifiedDate=convert(float,getdate())  
	   FROM COM_Files C   
	   INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X)    
	   ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID  
	   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
	COMMIT TRANSACTION 
	END
	ELSE IF @Type=6
	BEGIN
	BEGIN TRANSACTION
		DELETE From COM_Files where CostCenterID=50 and FileID=@Param1
	COMMIT TRANSACTION
	END
	ELSE IF @Type=7
	BEGIN
		select StatusID,[Status] from COM_Status with(nolock) where CostCenterID=400 and StatusID IN (371,372,376,441)
	END
	ELSE IF @Type=8
	BEGIN
		set @UserID=@Param1
		if @RoleID=-153
			SELECT @RoleID=RoleID FROM ADM_UserRoleMap WITH(nolock) WHERE UserID=@UserID
		
		IF(@RoleID=-1)
		BEGIN
			DECLARE @NRoleID NVARCHAR(MAX)

			SELECT @NRoleID=RoleID FROM ADM_UserRoleMap WITH(nolock) WHERE UserID=@UserID

			SET @SQL='insert into #TblUsrWF
			select *,null,null from (
				--Horizontal
				select WorkFlowID,max(LevelID) LevelID,1 TYPE
				from
				(
					select WorkFlowID,LevelID from com_workflow w with(nolock)
					where (UserID='+CONVERT(NVARCHAR,@UserID)+' or RoleID IN (-1,'+ @NRoleID +')) and w.Type=1
					union all
					select WorkFlowID,LevelID from [COM_WorkFlow] w WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.UserID='+CONVERT(NVARCHAR,@UserID)+' or g.RoleID IN (-1,'+ @NRoleID +') and w.Type=1
				) as H
				group by WorkFlowID
				UNION ALL
				--Vertical
				select WorkFlowID,LevelID,2 TYPE
				from
				(
					select WorkFlowID,LevelID,TYPE from com_workflow w with(nolock)
					where (UserID='+CONVERT(NVARCHAR,@UserID)+' or RoleID IN (-1,'+ @NRoleID +')) and w.Type=2
					union all
					select WorkFlowID,LevelID,TYPE from [COM_WorkFlow] w WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.UserID='+CONVERT(NVARCHAR,@UserID)+' or g.RoleID IN (-1,'+ @NRoleID +') and w.Type=2
				) as V
				group by WorkFlowID,LevelID
			) as T'
			--PRINT @SQL
			EXEC(@SQL)	
		END
		ELSE
		BEGIN
			insert into #TblUsrWF
			select *,null,null from (
				--Horizontal
				select WorkFlowID,max(LevelID) LevelID,1 TYPE
				from
				(
					select WorkFlowID,LevelID from com_workflow w with(nolock)
					where (UserID=@UserID or RoleID=@RoleID) and w.Type=1
					union all
					select WorkFlowID,LevelID from [COM_WorkFlow] w WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.UserID=@UserID or g.RoleID =@RoleID and w.Type=1
				) as H
				group by WorkFlowID
				UNION ALL
				--Vertical
				select WorkFlowID,LevelID,2 TYPE
				from
				(
					select WorkFlowID,LevelID,TYPE from com_workflow w with(nolock)
					where (UserID=@UserID or RoleID=@RoleID) and w.Type=2
					union all
					select WorkFlowID,LevelID,TYPE from [COM_WorkFlow] w WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.UserID=@UserID or g.RoleID =@RoleID and w.Type=2
				) as V
				group by WorkFlowID,LevelID
			) as T
		END
		
		DECLARE @SPInvoice cursor, @nStatusOuter int,@WID int,@Userlevel int,@escDays float,@escHrs float,@dt datetime,@TempUserlevel int
		SET @SPInvoice = cursor for 
		select WID,LevelID from #TblUsrWF where TYPE=2
		
		OPEN @SPInvoice 
		SET @nStatusOuter = @@FETCH_STATUS
		
		FETCH NEXT FROM @SPInvoice Into @WID,@Userlevel
		SET @nStatusOuter = @@FETCH_STATUS
		
		WHILE(@nStatusOuter <> -1)
		BEGIN
			set @TempUserlevel=isnull((select max(a.LevelID) from [COM_WorkFlow] a WITH(NOLOCK) 
			--join COM_WorkFlowDef b on a.WorkFlowID=b.WorkFlowID
			where   a.workflowid=@WID and a.LevelID<@Userlevel and ApprovalMandatory=1 --and a.LevelID>@Level
			),0)
			
			select @escDays=isnull(sum(escdays),0) from (select max(escdays) escdays from [COM_WorkFlow] a WITH(NOLOCK) 
			where   a.workflowid=@WID and a.LevelID<@Userlevel and a.LevelID>@TempUserlevel --and ApprovalMandatory=0 --and a.LevelID>@Level
			group by a.LevelID) as t
			
			--set @dt=dateadd("d",-@escDays,getdate())

			select @escHrs=isnull(sum(escdays),0) from (select max(eschours) escdays from [COM_WorkFlow] a WITH(NOLOCK) 
			where a.workflowid=@WID and a.LevelID<@Userlevel and a.LevelID>@TempUserlevel --and a.LevelID>@Level
			group by a.LevelID) as t
			
			set @escHrs=@escHrs/24
			--set @dt=dateadd("HH",-@escHrs,@dt),convert(float,@dt)

			if (@escDays>0 or @escHrs>0) and @TempUserlevel<@Userlevel
				update #TblUsrWF set CtWef=@escDays+@escHrs,LvWef=@TempUserlevel where WID=@WID and LevelID=@Userlevel
	
			FETCH NEXT FROM @SPInvoice Into @WID,@Userlevel
			SET @nStatusOuter = @@FETCH_STATUS
		END
		CLOSE @SPInvoice
		DEALLOCATE @SPInvoice
	END
	ELSE IF @Type=9
	BEGIN
		SET @XML=@strXML
		declare @UID nvarchar(20),@ShowMyQueue int,@UserName nvarchar(100)
		SELECT @ShowMyQueue=X.value('@ShowMyQueue','int'),@UID=X.value('@UID','nvarchar(20)') FROM @XML.nodes('/XML') as Data(X)    

		if exists(select value from ADM_GlobalPreferences with(nolock) where Name='CanApproveFunction' and Value='True')
			set @SQL='dbo.[fnExt_CanApprove](INV.InvDocDetailsID,INV.CostCenterID,INV.WorkflowID,INV.WorkFlowLevel,INV.StatusID,INV.CreatedDate,'+convert(nvarchar,@UID)+','+convert(nvarchar,@RoleID)+')'
		else
			set @SQL='dbo.[fnRPT_CanApprove](INV.CostCenterID,INV.WorkflowID,INV.WorkFlowLevel,INV.StatusID,INV.CreatedDate,'+convert(nvarchar,@UID)+','+convert(nvarchar,@RoleID)+')'

		--(WF.CtWef is not null and INV.WorkFlowLevel>=WF.LvWef and INV.CreatedDate+WF.CtWef<=convert(float,getdate())) condition added for vertical->non mandatory->Escape Days,Hrs Exists
		if @ShowMyQueue=1
		begin
			select @UserName=UserName from adm_users with(nolock) where UserID=@UID
			if @Param1='1'
				select 'WF.WID=INV.WorkflowID and (INV.CreatedBy='''+@UserName+''' or WF.LevelID>INV.WorkFlowLevel) and (INV.StatusID=371 or INV.StatusID=372 or INV.StatusID=441) AND (INV.CreatedBy='''+@UserName+''' or ( WF.Type=1 or (INV.WorkFlowLevel+1=WF.LevelID and INV.StatusID!=372))  or (WF.CtWef is not null and INV.WorkFlowLevel>=WF.LvWef and INV.CreatedDate+WF.CtWef<=convert(float,getdate())))' Qry
			else
				select '(INV.StatusID=371 or INV.StatusID=372 or INV.StatusID=441) and (INV.CreatedBy='''+@UserName+''' or '+@SQL+'=1)' Qry
		end
		else
		begin
			if @Param1='1'
				select 'WF.WID=INV.WorkflowID and WF.LevelID>INV.WorkFlowLevel and (INV.StatusID=371 or INV.StatusID=372 or INV.StatusID=441) AND (WF.Type=1 or (INV.WorkFlowLevel+1=WF.LevelID and INV.StatusID!=372)  or (WF.CtWef is not null and INV.WorkFlowLevel>=WF.LvWef and INV.CreatedDate+WF.CtWef<=convert(float,getdate())))' Qry
			else
				select '(INV.StatusID=371 or INV.StatusID=372 or INV.StatusID=441) and ('+@SQL+'=1)' Qry
		end
	END
	ELSE IF @Type=10
	BEGIN
		SET @XML=@strXML
		select @UserName=UserName from adm_users with(nolock) where convert(nvarchar(max),UserID)=@strXML
		select '(INV.StatusID=371 or INV.StatusID=372 or INV.StatusID=441) AND INV.CreatedBy='''+@UserName+'''' Qry
	END
	ELSE IF @Type=11
	BEGIN
		set @UserID=@Param1
		set @SQL=(SELECT  VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=3 AND NAME ='ProductCopyReports')
		if @SQL is not null and @SQL!=''
		begin
			SET @SQL='DECLARE @UserID INT,@RoleID INT
declare @TblRID as table(RID INT)
SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
SET @RoleID='+CONVERT(NVARCHAR,@RoleID)+'
insert into @TblRID
SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0 and (M.ActionType=1 or M.ActionType=0)
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
union
SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1 and (M.ActionType=1 or M.ActionType=0)
inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
  
SELECT ReportID,ReportName,ReportDefnXML
FROM ADM_RevenUReports AS R with(nolock)    
WHERE ReportID>0 and ReportID IN ('+@SQL+') AND (@RoleID=1 OR ReportID IN 
	(
		select RID from @TblRID
		union
		select G.ReportID
		from @TblRID T
		inner join ADM_RevenUReports C with(nolock) ON T.RID=C.ReportID
		inner join ADM_RevenUReports G with(nolock) ON C.lft between G.lft and G.rgt
		group by G.ReportID
	)
)
order by ReportName'
		exec(@SQL)
		end
		else
		begin
			select 1 copyreports where 1!=1
		end		
	END
	ELSE IF @Type=12
	BEGIN
		declare @FinalQry nvarchar(max)
		select @XML=ReportDefnXML from adm_revenuReports with(nolock) where ReportID=@Param1
--select @XML
		select X.value('Identity[1]/Sequence[1]','int') Sequence		
		,X.value('Identity[1]/ID[1]','nvarchar(max)') ID
		,X.value('Identity[1]/Caption[1]','nvarchar(max)') Caption
		,X.value('Identity[1]/Type[1]','nvarchar(max)') DType
		,X.value('HeaderAppearance[1]/Visibility[1]','int') Visible		
		,X.value('Identity[1]/Field[1]','nvarchar(max)') Field	
		,X.value('Identity[1]/SelectedField[1]','nvarchar(max)') SelectedField 
		,X.value('Width[1]','nvarchar(max)') Width
		,X.value('Format[1]/Decimals[1]','nvarchar(max)') Decimals
		into #TblFields
		from @XML.nodes('PactRevenURpts/PactRevenURptDef/Columns/ColumnDef') as Data(X)
		order by Sequence
		
		select T.*
			,F.SysTableName,F.SysColumnName,F.ColumnCostCenterID
			,F.IsForeignKey IsFK,F.ParentCostCenterID,F.ParentCostCenterSysName,F.ParentCostCenterColSysName
			,SF.CostCenterID SFCostCenterID,SF.SysTableName SFSysTableName,SF.SysColumnName SFSysColumnName
			,SF.IsForeignKey SSFIsFK,SF.ParentCostCenterSysName SSFParentCostCenterSysName,SF.ParentCostCenterColSysName SSFParentCostCenterColSysName,SSF.SysColumnName SSFSysColumnName
		from #TblFields T
		left join ADM_CostCenterDef F with(nolock) on F.CostCenterColID=abs(T.Field)
		left join ADM_CostCenterDef SF with(nolock) on SF.CostCenterColID=T.SelectedField
		left join ADM_CostCenterDef SSF with(nolock) on SSF.CostCenterColID=SF.ParentCCDefaultColID
		order by T.Sequence
		
		drop table #TblFields
	END
	ELSE IF @Type=13
	BEGIN
		IF @strXML='GET_ALL_REPORTS'
			set @strXML=''
		else
			set @strXML=' and ReportName like ''%'+@strXML+'%'''
		SET @SQL='DECLARE @UserID INT,@RoleID INT
declare @TblRID as table(RID INT)
SET @UserID='+CONVERT(NVARCHAR,@Param1)+'
SET @RoleID='+CONVERT(NVARCHAR,@RoleID)+'
insert into @TblRID
SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0 and (M.ActionType=1 or M.ActionType=0)
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
union
SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1 and (M.ActionType=1 or M.ActionType=0)
inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
  
SELECT ReportID,ReportName,StaticReportType,ParentID
FROM ADM_RevenUReports AS R with(nolock)    
WHERE ReportID>0 and IsGroup=0 '+@strXML+' and (@RoleID=1 OR ReportID IN 
	(
		select RID from @TblRID
		union
		select G.ReportID
		from @TblRID T
		inner join ADM_RevenUReports C with(nolock) ON T.RID=C.ReportID
		inner join ADM_RevenUReports G with(nolock) ON C.lft between G.lft and G.rgt
		group by G.ReportID
	)
)
order by ReportName'
		exec(@SQL)
	END
	ELSE IF @Type=14
	BEGIN
		set @UserID=@Param1
		
		select CostCenterID,DocumentName,DocumentAbbr 
		From ADM_DocumentTypes with(nolock)
		where IsInventory=0 and DocumentType not between 51 and 90
		and (@RoleID=1 or @UserID=1 or CostCenterID IN( select FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
			inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
			where FAR.RoleID=@RoleID and (FA.FeatureActionTypeID=1 or FA.FeatureActionTypeID=2) and FA.FeatureID between 40000 and 50000
			))
		union all
		select CostCenterID,DocumentName,DocumentAbbr 
		From ADM_DocumentTypes with(nolock) 
		inner join (select CostCenterID CCID from com_documentPreferences with(nolock) where PrefName='DonotupdateAccounts' and PrefValue='False') P
		on  P.CCID=CostCenterID
		where IsInventory=1 and DocumentType not between 51 and 90
		and (@RoleID=1 or @UserID=1 or CostCenterID IN( select FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
			inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
			where FAR.RoleID=@RoleID and (FA.FeatureActionTypeID=1 or FA.FeatureActionTypeID=2) and FA.FeatureID between 40000 and 50000
			))
		Order By DocumentName
	END
	ELSE IF @Type=15
	BEGIN
	BEGIN TRANSACTION
		update ADM_RevenUReports set ReportDefnXML=@strXML where ReportID=@Param1
		select 1 Updated
	COMMIT TRANSACTION
	END
	ELSE IF @Type=16
	BEGIN
		set @SQL=@strXML
		declare @table as table(ID int identity(1,1),Txt nvarchar(max))
		insert into @table(Txt)
		exec SPSplitString @strXML,'~'
		
		set @SQL='SELECT distinct BillWiseID'+(select Txt from @table where ID=1)
		set @SQL=@SQL+' FROM COM_Billwise B with(nolock)
		INNER JOIN ACC_DocDetails ACC with(nolock) ON ACC.VoucherNo=B.RefDocNo
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=ACC.AccDocDetailsID '
		if exists (select Txt from @table where ID=1 and Txt like '%txt.dcAlpha%')
			set @SQL=@SQL+' left join COM_DocTextData txt with(nolock) on txt.accdocdetailsid=ACC.accdocdetailsid '
		set @SQL=@SQL+(select Txt from @table where ID=2)+' WHERE B.BillWiseID IN ('+(select Txt from @table where ID=3)+ ') AND DCC.InvDocDetailsID IS NULL and (B.AccountID=ACC.DebitAccount or B.AccountID=ACC.CreditAccount)'
		
		set @SQL=@SQL+'
		union all
		SELECT distinct BillWiseID'+(select Txt from @table where ID=1)
		set @SQL=@SQL+' FROM COM_Billwise B with(nolock)
		INNER JOIN ACC_DocDetails ACC with(nolock) ON ACC.VoucherNo=B.RefDocNo
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=ACC.InvDocDetailsID '
		if exists (select Txt from @table where ID=1 and Txt like '%txt.dcAlpha%')
			set @SQL=@SQL+' left join COM_DocTextData txt with(nolock) on txt.InvDocDetailsID=ACC.InvDocDetailsID '
		set @SQL=@SQL+(select Txt from @table where ID=2)+' WHERE B.BillWiseID IN ('+(select Txt from @table where ID=3)+ ') and (B.AccountID=ACC.DebitAccount or B.AccountID=ACC.CreditAccount)'
		print(@SQL)
		exec(@SQL)
	END
	ELSE IF @Type=17
	BEGIN
	BEGIN TRANSACTION
		if @Param1=1
			update adm_revenureports set ReportDefnXML=replace(ReportDefnXML,'<Commas>2</Commas>','<Commas>1</Commas>') where ReportDefnXML like '%<Commas>2</Commas>%'
		else if @Param1=2
			update adm_revenureports set ReportDefnXML=replace(ReportDefnXML,'<Commas>1</Commas>','<Commas>2</Commas>') where ReportDefnXML like '%<Commas>1</Commas>%'
	COMMIT TRANSACTION
	END
	ELSE IF @Type=18
	BEGIN
		--select ',(select accountname from acc_accounts where AccountID=isnull((select top 1 CreditAccount from inv_docdetails D with(nolock) where D.VoucherNo=B.DocNo and D.DebitAccount=B.AccountID)
	--,(select top 1 DebitAccount from inv_docdetails D with(nolock) where D.VoucherNo=B.DocNo and D.CreditAccount=B.AccountID))) RefAccount'	
	select ',(select accountname from acc_accounts with(nolock) where AccountID=(select top 1 case when D.VoucherType=1 then CreditAccount else DebitAccount end from inv_docdetails D with(nolock) where D.VoucherNo=B.DocNo)) RefAccount' RefAccount
	END
	ELSE IF @Type=19
	BEGIN
		SELECT CostCenterID FROM COM_WorkFlowDef a WITH(nolock) where IsLineWise=1 group by CostCenterID
	END
	ELSE IF @Type=20
	BEGIN
		select [VoucherNo],[AccountID],[Amount],[days]
		,convert(datetime,[DueDate]) as [DueDate]  
		,[Percentage]  
		,[Remarts],Period,BasedOn,convert(datetime,BaseDate) as BaseDate,a.ProfileID,b.ProfileName,a.dimccid,a.dimNodeid  
		from [COM_DocPayTerms] a WITH(NOLOCK)  
		left join Acc_PaymentDiscountProfile b WITH(NOLOCK) on a.ProfileID=b.ProfileID
		where voucherno=@strXML
		
		select PrefName,PrefValue from COM_DocumentPreferences with(nolock) where CostCenterID=41084
			and PrefName in ('ShowPercentPayTerms','DecimalsNetAmount','Paymenttermsbasedon')
	END
	ELSE IF @Type=21
	BEGIN
		Declare @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQueryNoName nvarchar(max),@i int,@CNT int
		,@TableName nvarchar(100),@TabRef nvarchar(3),@CCID int,@PK nvarchar(50)
		declare @CustomTable as table(ID int identity(1,1),CostCenterID int)
		set @i=1
		set @CustomQuery1=''
		set @CustomQueryNoName=', '
		
		insert into @CustomTable(CostCenterID)
		select ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK)
		where CostCenterID=@Param1 and SystableName='COM_CCCCDATA' and ColumnCostCenterID>50000
		
		select @CNT=count(id) from @CustomTable
		while (@i<=	@CNT)
		begin
			select @CCID=CostCenterID from @CustomTable where ID=@i
	 
			select @TableName=TableName,@FeatureName=FeatureID from adm_features WITH(NOLOCK) where FeatureID=@CCID
			set @TabRef='A'+CONVERT(nvarchar,@i)
			set @CCID=@CCID-50000
			if(@CCID>0 and @CCID<=100)
			begin
				set @CustomQuery1=@CustomQuery1+' left join '+@TableName+' '+@TabRef+' WITH(NOLOCK) on '+@TabRef+'.NodeID=CC.CCNID'+CONVERT(nvarchar,@CCID)
				set @CustomQueryNoName=@CustomQueryNoName+' '+@TabRef+'.Name as CCNID'+CONVERT(nvarchar,@CCID)+','
			end
			set @i=@i+1
		end
		if @CustomQuery1 like '%CC.CCNID%'
			set @CustomQuery1=' LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on C.NodeID=CC.NodeID and CC.CostCenterID='+convert(nvarchar,@Param1)+@CustomQuery1
		if len(@CustomQueryNoName)>1
			set @CustomQueryNoName=substring(@CustomQueryNoName,1,len(@CustomQueryNoName)-1)
		select @TableName=TableName,@PK=PrimaryKey from adm_features WITH(NOLOCK) where FeatureID=@Param1
		if @Param1=4
		begin
			select @strXML=CompanyID from PACT2C.dbo.ADM_Company with(nolock) where DbIndex=@strXML
			set @TableName='PACT2C.dbo.'+@TableName
			set @CustomQueryNoName=',CEX.*'
			set @CustomQuery1=' LEFT JOIN PACT2C.dbo.ADM_CompanyExtended CEX WITH(NOLOCK) on CEX.CompanyID=C.CompanyID'
		end
		set @SQL='SELECT C.*'+@CustomQueryNoName+'
		,AD.ContactPerson,AD.Address1,AD.Address2,AD.Address3,AD.City,AD.State,AD.Zip,AD.Country,AD.Phone1,AD.Phone2,AD.Fax,AD.Email1,AD.Email2,AD.URL,AD.AddressName
		,(SELECT TOP 1 GUID+''.''+FileExtension FROM COM_FILES PIMG WITH(NOLOCK) WHERE PIMG.IsProductImage=1 and PIMG.FeaturePK=C.'+@PK+' AND PIMG.FeatureID='+convert(nvarchar,@Param1)+' Order By IsDefaultImage desc) DimensionImage
		,(SELECT TOP 1 GUID+''.''+FileExtension FROM COM_FILES PIMG WITH(NOLOCK) WHERE PIMG.IsProductImage=1 and IsDefaultImage=2 and PIMG.FeaturePK=C.'+@PK+' AND PIMG.FeatureID='+convert(nvarchar,@Param1)+') IMG_2
		,(SELECT TOP 1 GUID+''.''+FileExtension FROM COM_FILES PIMG WITH(NOLOCK) WHERE PIMG.IsProductImage=1 and IsDefaultImage=3 and PIMG.FeaturePK=C.'+@PK+' AND PIMG.FeatureID='+convert(nvarchar,@Param1)+') IMG_3
		,(SELECT TOP 1 GUID+''.''+FileExtension FROM COM_FILES PIMG WITH(NOLOCK) WHERE PIMG.IsProductImage=1 and IsDefaultImage=4 and PIMG.FeaturePK=C.'+@PK+' AND PIMG.FeatureID='+convert(nvarchar,@Param1)+') IMG_4
		,(SELECT TOP 1 GUID+''.''+FileExtension FROM COM_FILES PIMG WITH(NOLOCK) WHERE PIMG.IsProductImage=1 and IsDefaultImage=5 and PIMG.FeaturePK=C.'+@PK+' AND PIMG.FeatureID='+convert(nvarchar,@Param1)+') IMG_5
		FROM '+@TableName+' C WITH(NOLOCK)
		LEFT JOIN COM_Address AD WITH(NOLOCK) ON AD.FeatureID='+convert(nvarchar,@Param1)+' AND AD.FeaturePK=C.'+@PK+' AND AD.AddressTypeID=1
		'+@CustomQuery1+'
		WHERE C.'+@PK+' IN ('+@strXML+')'
		print(@SQL)
		exec(@SQL)
	END

SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1
		END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
