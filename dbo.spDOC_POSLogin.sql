USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_POSLogin]
	@RegNodeID [bigint],
	@ShiftID [bigint],
	@day [datetime],
	@mode [int],
	@DenomXML [nvarchar](max),
	@JVXML [nvarchar](max),
	@detailsXMl [nvarchar](max),
	@IP [nvarchar](max),
	@CompanyGUID [nvarchar](200),
	@UserName [nvarchar](200),
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON; 
	declare @ID bigint,@XML xml,@CloseID bigint,@i int,@Cnt int,@CurrentDay float,@Dt float,@IsUC int,@IsSC bit,@IsDC bit,@SQL NVARCHAR(MAX),@stat int
	
	set @ID=0
	set @Dt=convert(float,getdate())

	if(@mode=100)--Create Session
	BEGIN
		CREATE TABLE #DOCTAB(ID INT IDENTITY(1,1),InvDocDetailsID bigint)
		DECLARE @DocumentID INT
		SELECT @DocumentID=[Value] FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='UserWiseRegisters'
		IF (@DocumentID IS NOT NULL AND @DocumentID<>'' AND @DocumentID > 0)
		BEGIN
			SET @SQL='SELECT IDD.InvDocDetailsID FROM INV_DocDetails IDD WITH(NOLOCK) 
			JOIN COM_DocCCData CCD WITH(NOLOCK) ON CCD.InvDocDetailsID=IDD.InvDocDetailsID
			WHERE IDD.DocDate='+CONVERT(NVARCHAR,convert(float,@day))+' AND IDD.CostCenterID='+CONVERT(NVARCHAR,@DocumentID)+' 
			AND CCD.UserID IN ('+CONVERT(NVARCHAR,@UserID)
			
			IF EXISTS (SELECT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
						WHERE ParentCostCenterID=7 AND CostCenterID=7 AND ParentNodeID=@UserID)
				SET @SQL=@SQL+(SELECT DISTINCT ','+CONVERT(NVARCHAR,NodeID) 
								FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
								WHERE ParentCostCenterID=7 AND CostCenterID=7 AND ParentNodeID=@UserID
								ORDER BY 1 FOR XML PATH (''))+') '
			ELSE
				SET @SQL=@SQL+') '
				
			SELECT @DocumentID=[Value] FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='Registers'
			IF (@DocumentID IS NOT NULL AND @DocumentID<>'' AND @DocumentID > 50000)
				SET @SQL=@SQL+' AND CCD.dcCCNID'+CONVERT(NVARCHAR,(@DocumentID-50000))+'='+CONVERT(NVARCHAR,@RegNodeID)
			
			SELECT @DocumentID=[Value] FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='PosShifts'
			IF (@DocumentID IS NOT NULL AND @DocumentID<>'' AND @DocumentID > 50000)
				SET @SQL=@SQL+' AND CCD.dcCCNID'+CONVERT(NVARCHAR,(@DocumentID-50000))+'='+CONVERT(NVARCHAR,@ShiftID)
			
			SET @SQL=@SQL+@detailsXMl
			PRINT (@SQL)
			
			INSERT INTO #DOCTAB
			EXEC (@SQL)
			
			IF NOT EXISTS (SELECT * FROM #DOCTAB)
			BEGIN
				set @ID=-9
				COMMIT TRANSACTION
				RETURN @ID
			END
		END
		
		declare @UserLogged nvarchar(100),@NewID bigint

		select top 1 @ID=posloginhistoryid,@IsUC=IsUserClose,@IsSC=IsShiftClose,@IsDC=IsDayClose,@UserLogged=UserName from [POS_loginHistory] with(nolock)
		where RegisterNodeID=@RegNodeID
		order by posloginhistoryid desc

		if @ID is not null and @IsUC=0
		begin
			if @UserLogged=@UserName 
			begin
				set @ID=@ID
				select '0' IsOpening
			end
			else
			begin
				set @ID=-10
				select @UserLogged UserName
			end
			
		end
		else
		begin
			--select count(PrefName) from COM_DocumentPreferences WITH(NOLOCK)
			--where (PrefName='PosJVOn' and PrefValue='2') or (PrefName='PosPostings' and PrefValue='true'))=2
			if exists(select ShiftNodeID from POS_loginHistory WITH(NOLOCK)
				where [RegisterNodeID]=@RegNodeID and [ShiftNodeID]=@ShiftID and [Day]=convert(float,@day) and IsShiftClose=1)
			BEGIN
				set @ID=-11
			END
			ELSE
			BEGIN					
				INSERT INTO POS_loginHistory([RegisterNodeID],[ShiftNodeID],[UserName],[Day]
				,[IsShiftClose],[IsDayClose],[LoginDate],Status,IPAddress)VALUES
				(@RegNodeID,@ShiftID,@UserName,convert(float,@day),0,0,convert(float,getdate()),'Open',@IP)
				SET @NewID=@@IDENTITY
				if @IsUC=2
				begin
					update POS_loginHistory set CloseID=@ID where posloginhistoryid=@NewID
					select '0' IsOpening
				end
				else
				begin
					update POS_loginHistory set CloseID=@NewID where posloginhistoryid=@NewID
					select '1' IsOpening
				end
				set @ID=@NewID
				
				IF(@detailsXMl IS NOT NULL AND @detailsXMl<>'')
				BEGIN
					SET @SQL='update POS_loginHistory SET '+Substring(Ltrim(REPLACE(@detailsXMl,'AND CCD.dc',',')),2,LEN(@detailsXMl))+' WHERE posloginhistoryid='+CONVERT(NVARCHAR,@ID)
					EXEC (@SQL)
				END
			END	
		end
		
		SET @SQL='SELECT 1'
		IF EXISTS (SELECT * FROM #DOCTAB)
		BEGIN
			
			SELECT @DocumentID=[Value] FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='EPOS'--,SmartCard
			IF (@DocumentID IS NOT NULL AND @DocumentID<>'' AND @DocumentID > 0)
			BEGIN
				SET @SQL=@SQL+',(SELECT STUFF((SELECT DISTINCT '',''+CONVERT(NVARCHAR,CCD.dcCCNID'+CONVERT(NVARCHAR,(@DocumentID-50000))+') 
				FROM #DOCTAB DT
				JOIN COM_DocCCData CCD WITH(NOLOCK) ON CCD.InvDocDetailsID=DT.InvDocDetailsID 
				ORDER BY 1 FOR XML PATH ('''')),1,1,'''')) EPOSDim' 
			END
			
			SELECT @DocumentID=[Value] FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='SmartCard'--,SmartCard
			IF (@DocumentID IS NOT NULL AND @DocumentID<>'' AND @DocumentID > 0)
			BEGIN
				SET @SQL=@SQL+',(SELECT STUFF((SELECT DISTINCT '',''+CONVERT(NVARCHAR,CCD.dcCCNID'+CONVERT(NVARCHAR,(@DocumentID-50000))+') 
				FROM #DOCTAB DT
				JOIN COM_DocCCData CCD WITH(NOLOCK) ON CCD.InvDocDetailsID=DT.InvDocDetailsID 
				ORDER BY 1 FOR XML PATH ('''')),1,1,'''')) SmartCardDim' 
			END
		end
		EXEC (@SQL)
		DROP TABLE #DOCTAB
		
	END
	else if @mode=101
	begin
		select @ID=CloseID,@IsUC=IsUserClose,@UserLogged=UserName from [POS_loginHistory] with(nolock)
		where CloseID<@DenomXML and UserName=@UserName and IsUserClose=1 
		order by posloginhistoryid
		
		if @ID>0
			IF EXISTS (SELECT PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName='DonotConsiderOpeningInPaymode' AND PrefValue='True' and CostCenterID=40994)
			BEGIN
				select CurrencyID,Notes Denom,NotesTender Tender,1 Type  from COM_DocDenominations with(nolock) 
				where PosCloseID=@ID and Notes>0 AND ACCDocDetailsID=0
				union all
				select CurrencyID,Change Denom,ChangeTender Tender,2 Type from COM_DocDenominations with(nolock)
				where PosCloseID=@ID and Change>0 AND ACCDocDetailsID=0
				order by Type,Denom desc
			END
			ELSE
			BEGIN
				select CurrencyID,Notes Denom,NotesTender Tender,1 Type  from COM_DocDenominations with(nolock) 
				where PosCloseID=@ID and Notes>0 AND ACCDocDetailsID IS NULL
				union all
				select CurrencyID,Change Denom,ChangeTender Tender,2 Type from COM_DocDenominations with(nolock)
				where PosCloseID=@ID and Change>0 AND ACCDocDetailsID IS NULL
				order by Type,Denom desc
			END
		else
			select 1 NoData where 1!=1
	end
	else if @mode=104
	begin
		declare @tab table(shiftid bigint)
		insert into @tab
		select distinct ShiftNodeID from [POS_loginHistory] with(nolock)
		where RegisterNodeID=@RegNodeID and Day=CONVERT(float,@day)
		
		if(select COUNT(*) from [POS_loginHistory]  a with(nolock)
		join @tab b on a.ShiftNodeID=b.shiftid
		where a.IsShiftClose=1 and RegisterNodeID=@RegNodeID and Day=CONVERT(float,@day))<>(select COUNT(*) from @tab)
		BEGIN
			set @ID=-999
		END
		ELSE
		BEGIN
			set @ID=1
		END
	end
	else if @mode=102
	begin
		declare @RegTable nvarchar(50),@ShiftTable nvarchar(50),@CallFromReport bit,@Select nvarchar(max),@Join nvarchar(max)
		set @CallFromReport=0
		if(@ShiftID=1)
			set @CallFromReport=1
		
		Select @RegNodeID=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='Registers' and Value is not null and ISNUMERIC(Value)=1
		select @RegTable=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@RegNodeID
		
		Select @ShiftID=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='PosShifts' and Value is not null and ISNUMERIC(Value)=1
		if(@ShiftID>50000)
			select @ShiftTable=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@ShiftID
		
		select @XML=ReportDefnXML from adm_revenuReports with(nolock) where ReportID=196
		select @Select=X.value('Select[1]','nvarchar(max)'),@Join=X.value('From[1]','nvarchar(max)')
		from @XML.nodes('PactRevenURpts/PactRevenURptDef/Query') as Data(X)
		
		DECLARE @TABDetails TABLE (ID INT IDENTITY(1,1),ColumnName NVARCHAR(MAX),TableJoin NVARCHAR(MAX))
		
		INSERT INTO @TABDetails
		SELECT ',CC'+CONVERT(NVARCHAR,(F.FeatureID-50000))+'.Name ['+SC.Name+'Name],CC'+CONVERT(NVARCHAR,(F.FeatureID-50000))+'.Code ['+SC.Name+'Code]'
		,' inner join '+F.TableName+' CC'+CONVERT(NVARCHAR,(F.FeatureID-50000))+' with(nolock) on CC'+CONVERT(NVARCHAR,(F.FeatureID-50000))+'.NodeID=ISNULL(H.CCNID'+CONVERT(NVARCHAR,(F.FeatureID-50000))+',1) ' 
		FROM ADM_Features F WITH(NOLOCK)
		JOIN sys.columns SC WITH(NOLOCK) ON F.FeatureID=50000+CONVERT(INT,REPLACE(SC.Name,'CCNID',''))
		WHERE SC.Name like 'CCNID%' and object_id=object_id('POS_loginHistory')
		AND F.FeatureID<>@RegNodeID AND F.FeatureID<>ISNULL(@ShiftID,0)
		
		set @SQL='select H.POSLoginHistoryID,convert(datetime,[Day]) Day,R.NodeID RegisterID,H.ShiftNodeID,R.Code RegisterCode,R.Name RegisterName,H.UserName,H.IPAddress,H.Status,convert(datetime,H.LoginDate) LoginDate,convert(datetime,H.LogoutTime) LogoutTime'
		
		if @ShiftTable is not null
			set @SQL=@SQL+',S.Name Shift'
		
		SELECT @i=1,@Cnt=COUNT(*) FROM @TABDetails
		WHILE @i<=@Cnt
		BEGIN
			SELECT @SQL=@SQL+ColumnName FROM @TABDetails WHERE ID=@i
			SET @i=@i+1
		END
		
		if @Select is not null and @Select!=''
			set @SQL=@SQL+@Select
		
		set @SQL=@SQL+' from (select RegisterNodeID,max(POSLoginHistoryID) POSLoginHistoryID from POS_loginHistory with(nolock) group by RegisterNodeID) AS T
		inner join POS_loginHistory H with(nolock) on H.POSLoginHistoryID=T.POSLoginHistoryID'
		
		if @ShiftTable is not null
			set @SQL=@SQL+' inner join '+@ShiftTable+' S with(nolock) on S.NodeID=H.ShiftNodeID'
		
		SELECT @i=1,@Cnt=COUNT(*) FROM @TABDetails
		WHILE @i<=@Cnt
		BEGIN
			SELECT @SQL=@SQL+TableJoin FROM @TABDetails WHERE ID=@i
			SET @i=@i+1
		END
		
		set @SQL=@SQL+' right join '+@RegTable+' R with(nolock) on R.NodeID=H.RegisterNodeID'
		
		if @Select is not null and @Select!=''
			set @SQL=@SQL+@Join
		set @SQL=@SQL+' where R.NodeID>0 and R.IsGroup=0'
		
		declare @DimensionList nvarchar(max)
		Select @DimensionList=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='Dimension List' and Value is not null
		if (@UserID<>1 AND @DimensionList is not null AND @DimensionList<>'')
		begin
			
			declare @Dimension table(CostCenterID INT)  
			insert into @Dimension  
			exec SPSplitString @DimensionList,','
			
			
			IF EXISTS (SELECT * FROM @Dimension WHERE CostCenterID=@RegNodeID) AND EXISTS (SELECT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK) WHERE ParentCostCenterID=7 AND ParentNodeID=@UserID AND CostCenterID=@RegNodeID)
				SET @SQL=@SQL+' AND R.NodeID IN('+(SELECT STUFF((SELECT DISTINCT ','+CONVERT(NVARCHAR,NodeID) 
								FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
								WHERE ParentCostCenterID=7 AND CostCenterID=@RegNodeID AND ParentNodeID=@UserID
								ORDER BY 1 FOR XML PATH ('')),1,1,''))+') '
			
			IF EXISTS (SELECT * FROM @Dimension WHERE CostCenterID=@ShiftID) AND @ShiftTable is not null AND EXISTS (SELECT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK) WHERE ParentCostCenterID=7 AND ParentNodeID=@UserID AND CostCenterID=@ShiftID)
				SET @SQL=@SQL+' AND S.NodeID IN('+(SELECT STUFF((SELECT DISTINCT ','+CONVERT(NVARCHAR,NodeID) 
								FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
								WHERE ParentCostCenterID=7 AND CostCenterID=@ShiftID AND ParentNodeID=@UserID
								ORDER BY 1 FOR XML PATH ('')),1,1,''))+') '
								
			IF EXISTS (SELECT * FROM @Dimension WHERE CostCenterID=7) AND EXISTS (SELECT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK) WHERE ParentCostCenterID=7 AND CostCenterID=7 AND ParentNodeID=@UserID)
				SET @SQL=@SQL+' AND H.UserName IN ('''+@UserName+(SELECT DISTINCT ''','''+UserName
								FROM COM_CostCenterCostCenterMap CCM WITH(NOLOCK) 
								JOIN ADM_Users U WITH(NOLOCK) ON U.UserID=CCM.NodeID
								WHERE CCM.ParentCostCenterID=7 AND CCM.CostCenterID=7 AND CCM.ParentNodeID=@UserID
								ORDER BY 1 FOR XML PATH (''))+''') '
		end
		--select row_number() over (order by CostCenterID) rowno,CostCenterID,NodeID into #TblMap
		--from COM_CostCenterCostCenterMap CC with(nolock)
		--inner join (select ColumnCostCenterID from adm_costcenterdef with(nolock) where CostcenterID=@RegNodeID and IsColumnInUse=1 and SysColumnName like 'CCNID%') as T
		--on T.ColumnCostCenterID=CC.CostCenterID
		--where ParentCostCenterID=7 and ParentNodeID=2
		--order by CostCenterID,NodeID
 

		--select @i=1,@Cnt=count(*) from #TblMap
		--while @i<=@cnt
		--begin
		--	select CostCenterID from #TblMap where ID=@i
		--	--if exists (select NodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=7 and ParentNodeID=@UserID and CostCenterID=
		--	set @i=@i+1
		--end
		--drop table #TblMap

		--For Register Assign Check
		/*	select CostCenterID,NodeID into #TblMap  from COM_CostCenterCostCenterMap CC with(nolock)
		inner join (select ColumnCostCenterID from adm_costcenterdef with(nolock) where CostcenterID=@RegNodeID and IsColumnInUse=1 and SysColumnName like 'CCNID%') as T
		on T.ColumnCostCenterID=CC.CostCenterID
		where ParentCostCenterID=7 and ParentNodeID=2
		order by CostCenterID,NodeID
		
		set @DenomXML=''
		select @DenomXML=@DenomXML+' and REG_CC.CCNID'+convert(nvarchar,CostCenterID-50000)+' in ('+ccwhere+')' from
		(
			select CostCenterID,STUFF((select ','+convert(nvarchar,TB.NodeID) from #TblMap TB with(nolock) where TB.CostCenterID=T.CostCenterID FOR XML PATH('')),1,1,'') ccwhere 
			from #TblMap T group by CostCenterID
		) as T
		drop table #TblMap
		if @DenomXML is not null and @DenomXML!=''
			set @SQL=@SQL+@DenomXML
		*/
		
		
		--if @CallFromReport=1	
		--	set @SQL=@SQL+' order by Day Asc,RegisterCode'
		--else
			set @SQL=@SQL+' order by POSLoginHistoryID desc,RegisterCode'
		print(@SQL)
		exec(@SQL)
		
		if exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK)
		where PrefName='PosPostings' and PrefValue='true' and CostCenterID=40994)
		BEGIN			
			select PrefName,PrefValue from COM_DocumentPreferences WITH(NOLOCK)
			where PrefName in('PosPostings','POSFields','POSJVFields','PosJVOn') and CostCenterID=40994
			UNION
			select 'ShiftCCID',CONVERT(nvarchar,@ShiftID)
			
			declare @prefvalue nvarchar(max)
			select @prefvalue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)
			where PrefName ='POSJVFields' and CostCenterID=40994

			declare @tbl table(col nvarchar(100))  
			insert into @tbl  
			exec SPSplitString @prefvalue,','
		
			select a.SysColumnName,b.DebitAccount,b.CreditAccount,d.IsBillwise drbillwise,c.IsBillwise crbillwise,a.SectionID from ADM_CostCenterDef a WITH(NOLOCK)
			join ADM_DocumentDef b WITH(NOLOCK) on a.CostCenterColID=b.CostCenterColID
			join ACC_Accounts d WITH(NOLOCK) on b.DebitAccount=d.AccountID
			join ACC_Accounts c WITH(NOLOCK) on b.CreditAccount=c.AccountID
			where a.SysColumnName in(select col from @tbl)
			and a.CostCenterID=40994
				
		END
		
	end
	else if @mode=103
	begin
		set @XML=@DenomXML
		select @DenomXML=X.value('Registers[1]','nvarchar(max)')
		from @XML.nodes('/XML') as Data(X)
		
		declare @iDay float
		declare @table table(ID int identity(1,1),RegID bigint)  
		insert into @table  
		exec SPSplitString @DenomXML,','
		select @i=1,@Cnt=count(*) from @table
		set @mode=@ShiftID
		set @iDay=convert(float,@day)
		while(@i<=@Cnt)
		begin
			select @ID=null,@CurrentDay=null,@RegNodeID=RegID from @table where ID=@i
			
			select @ID=posloginhistoryid,@CurrentDay=Day,@IsDC=IsDayClose,@IsSC=IsShiftClose,@IsUC=IsUserClose from [POS_loginHistory] with(nolock)
			where RegisterNodeID=@RegNodeID
			order by posloginhistoryid
			
			if @mode=1
			begin
				if(@ID is not null and @CurrentDay<=@iDay and @IsDC=0)
					update [POS_loginHistory]
					set [IsShiftClose]=1,[IsDayClose]=1,IsUserClose=1,Status='Day Close',LogoutTime=@Dt
					where posloginhistoryid=@ID	

				if @ID is null or @CurrentDay<@iDay
				begin
					INSERT INTO POS_loginHistory([RegisterNodeID],[ShiftNodeID],[UserName],[Day]
					,[IsShiftClose],[IsDayClose],IsUserClose,[LoginDate],Status,LogoutTime,IPAddress)
					VALUES(@RegNodeID,1,@UserName,@iDay,1,1,1,@Dt,'Day Close',@Dt,@IP)
					SET @NewID=@@IDENTITY
					update POS_loginHistory set CloseID=@NewID where posloginhistoryid=@NewID
				end
			end
			else if @mode=2
			begin
				if(@ID is not null and @CurrentDay<=@iDay and @IsDC=0)
					update [POS_loginHistory]
					set [IsShiftClose]=1,IsUserClose=1,Status='Shift Close',LogoutTime=@Dt
					where posloginhistoryid=@ID	
			end
			else if @mode=3
			begin
				if(@ID is not null and @CurrentDay<=@iDay and @IsUC!=1)
					update [POS_loginHistory]
					set IsUserClose=1,Status='User Close',LogoutTime=@Dt
					where posloginhistoryid=@ID	
			end

			set @i=@i+1
		end
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
		WHERE ErrorNumber=100 AND LanguageID=@LangID  
		--select * from POS_loginHistory
		set @ID=1
	end
	else if(@mode=0)--User Exit
	BEGIN		
		select @ID=posloginhistoryid,@IsUC=IsUserClose from [POS_loginHistory] with(nolock)
		where RegisterNodeID=@RegNodeID
		order by posloginhistoryid
		
		if @IsUC=0
		begin
			update [POS_loginHistory]
			set [IsUserClose]=2,Status='User Exit',LogoutTime=@Dt
			where posloginhistoryid=@ID
		end
	END
	else
	begin
		set @XML=@DenomXML
		
		select @ID=posloginhistoryid,@CloseID=CloseID from [POS_loginHistory] with(nolock)
		where RegisterNodeID=@RegNodeID
		order by posloginhistoryid
			
		if(@mode=1)--Day Close
		begin
			update [POS_loginHistory]
			set [IsShiftClose]=1,[IsDayClose]=1,IsUserClose=1,Status='Day Close',LogoutTime=@Dt,DetailsXML=@detailsXMl
			where posloginhistoryid=@ID	
		end 
		else if(@mode=2)--Shift Close
		begin		
			update [POS_loginHistory]
			set [IsShiftClose]=1,IsUserClose=1,Status='Shift Close',LogoutTime=@Dt,DetailsXML=@detailsXMl
			where posloginhistoryid=@ID
			
			--if (select count(PrefName) from COM_DocumentPreferences WITH(NOLOCK)			
			--where  CostCenterID=40994 and ((PrefName='PosJVOn' and PrefValue='2') or (PrefName='PosPostings' and PrefValue='true')))=2
			--BEGIN
				Select @ShiftID=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='PosShifts' and Value is not null and ISNUMERIC(Value)=1
				if(@ShiftID>50000)
					select @ShiftTable=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@ShiftID
				
				select @stat=Statusid from com_status WITH(NOLOCK) 
				where Costcenterid=@ShiftID and status='In Active'
				
				set @SQL='select NodeID from '+@ShiftTable+' WITH(NOLOCK)
				where IsGroup=0 and statusid<>'+convert(nvarchar(max),@stat)
				
				declare @tabshifts table(shiftid bigint)
				insert into @tabshifts
				exec(@SQL)
				
				if(select COUNT(*) from [POS_loginHistory]  a with(nolock)
				join @tabshifts b on a.ShiftNodeID=b.shiftid
				where a.IsShiftClose=1 and RegisterNodeID=@RegNodeID and Day=CONVERT(float,@day))=(select COUNT(*) from @tabshifts)
					set @ID=-100
			--END
		end
		else if(@mode=3)--User Close
		begin		
			update [POS_loginHistory]
			set [IsUserClose]=1,Status='User Close',LogoutTime=@Dt
			where posloginhistoryid=@ID
		end
		if(@XML is not null and CONVERT(nvarchar(max),@XML)<>'')
		begin
			INSERT INTO COM_DocDenominations(DOCID,[CurrencyID],[Notes],[NotesTender],[Change],[ChangeTender],AccDocDetailsID,PosCloseID)
			  select 0,X.value('@CurrencyID','BIGINT'),X.value('@Notes','float'),X.value('@NotesTender','float')
			  ,X.value('@Change','float'),X.value('@ChangeTender','float'),null,@CloseID
			  FROM @XML.nodes('/XML') as Data(X) where X.value('@IsDenom','BIT')=1
		end
		
		if(@mode in(1,2) and @JVXML<>'')--Day Close
		BEGIN
			declare @JVCCID int,@Prefix nvarchar(200)
			set @JVCCID=0
			select @JVCCID=CONVERT(int,PrefValue) from COM_DocumentPreferences WITH(NOLOCK)
			where PrefName='PosJV' and ISNUMERIC(PrefValue)=1 and CostCenterID=40994
			
			if(@JVCCID>40000)
			BEGIN
			
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @JVXML,@day,@JVCCID,@Prefix   output

				EXEC @i = [dbo].[spDOC_SetTempAccDocument]  
					@CostCenterID = @JVCCID,  
					@DocID = 0,  
					@DocPrefix =@Prefix,  
					@DocNumber =1,     
					@DocDate =  @day,  
					@DueDate = NULL,  
					@BillNo = NULL,  
					@InvDocXML = @JVXML,  
					@NotesXML = N'',  
					@AttachmentsXML = N'',  
					@ActivityXML  = N'', 
					@IsImport = 0,  
					@LocationID = 0,  
					@DivisionID = 0,  
					@WID = 0,  
					@RoleID = @RoleID,  
					@RefCCID = 259,
					@RefNodeid = 0 ,
					@CompanyGUID = @CompanyGUID,  
					@UserName = @UserName,  
					@UserID = @UserID,  
					@LangID = @LangID 
			END
			ELSE
				RAISERROR('-555',16,1)    
		END
		
	end	

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SET NOCOUNT OFF;              
RETURN @ID
END TRY              
BEGIN CATCH     
           
  --Return exception info [Message,Number,ProcedureName,LineNumber]                
  IF ERROR_NUMBER()=50000              
  BEGIN              
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID              
  END              
  ELSE              
  BEGIN              
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine              
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID              
  END              
ROLLBACK TRANSACTION
SET NOCOUNT OFF                
RETURN -999                 
END CATCH   
GO
