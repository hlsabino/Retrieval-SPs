USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetCasesScreenDetails]
	@CaseID [int] = 0,
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON
	
	DECLARE @SQL NVARCHAR(300),@TableNm Nvarchar(300)
	
	Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
	
	create table #tblUsers(username nvarchar(100))
	insert into #tblUsers
	exec [spADM_GetUserNamebyOwner] @UserID 
		  
	create table #Fin(ServiceTypeID int,Technician int) 
	create Table #temp (id int identity(1,1), ServiceTypeID int, Technicians nvarchar(500) )
	create table #tempTech (TechID int)
	declare @Tech nvarchar(200), @i int, @cnt int, @ID int
	insert into #temp 
	select ServiceTypeID,Technicians from crm_serviceTypes with(nolock) where Technicians is not null 
	select @i=1,@cnt=COUNT(*) from #temp WITH(NOLOCK)

	while @i<=@cnt
	begin
		select @ID=ServiceTypeID, @Tech=Technicians from #temp WITH(NOLOCK) where id=@i
		
		truncate table #tempTech 
		insert into #tempTech  
		EXEC SPSplitString @Tech,',' 
		
		insert into #Fin 
		select @ID,TechID from #tempTech WITH(NOLOCK)
		
		set @i=@i+1
	end
	
	drop table #temp 
	drop table #tempTech
			
	select ServiceTypeID, ServiceName, Technicians from CRM_ServiceTypes with(nolock) 
	SELECT ServiceReasonID,Reason,ServiceTypeID FROM CRM_ServiceReasons WITH(NOLOCK)
	
	IF((SELECT ISNULL(COUNT(*),0) FROM ADM_FEATURES with(nolock) WHERE FeatureID in
	 (select value from COM_CostCenterPreferences with(nolock) where CostCenterID=82 and name='ServiceTypeLinkDimension'))>0)
	BEGIN
		 SELECT @TableNm=TableName FROM  ADM_FEATURES with(nolock) WHERE FeatureID in
		(select value from COM_CostCenterPreferences with(nolock) where CostCenterID=82 and name='ServiceTypeLinkDimension')
		 SET @SQL=' SELECT NODEID,NAME Technician, f.ServiceTypeID FROM '+@TableNm +' t WITH(NOLOCK) 
		   join #Fin f WITH(NOLOCK) on f.Technician=t.NodeID  '
		  print (@SQL)
		 EXEC(@SQL)
	END
	ELSE
		SELECT NULL
		
	drop table #Fin		
	
	SELECT UserID,UserName FROM  ADM_Users WITH(NOLOCK) WHERE StatusID=1
	
	IF @CaseID>0
	BEGIN
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM CRM_Cases WITH(NOLOCK) where CaseID=@CaseID
		
		if(@WID is not null and @WID>0)  
		BEGIN  
			SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID

			if(@Userlevel is null )       
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
			
			if(@Userlevel is null )  	
				SELECT @Type=[type] FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID
		end 
     
		set @canEdit=1  
       
		if(@StatusID =1002)  
		begin  
			if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=0   
			end    
		end
		ELSE if(@StatusID=1003)
		BEGIN
		    if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=1
			end
			ELSE
				set @canEdit=0
		END
     
  
		if(@StatusID=1001 or @StatusID=1002)  
		begin    
			if(@Userlevel is not null and  @Level is not null and @Userlevel>@level)  
			begin
				if(@Type=1 or @Level+1=@Userlevel)
					set @canApprove=1   
				ELSE
				BEGIN
					if exists(select EscDays FROM [COM_WorkFlow]
					where workflowid=@WID and ApprovalMandatory=1 and LevelID<@Userlevel and LevelID>@Level)
						set @canApprove=0
					ELSE
					BEGIN	
						select @escDays=sum(escdays) from (select max(escdays) escdays from [COM_WorkFlow] WITH(NOLOCK) 
						where workflowid=@WID and LevelID<@Userlevel and LevelID>@Level
						group by LevelID) as t
						 
						set @CreatedDate=dateadd("d",@escDays,@CreatedDate)
						
						select @escDays=sum(escdays) from (select max(eschours) escdays from [COM_WorkFlow] WITH(NOLOCK) 
						where workflowid=@WID and LevelID<@Userlevel and LevelID>@Level
						group by LevelID) as t
						
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
			
		SELECT c.*,ProductName,VoucherNo,convert(datetime,WaiveDate) as WaiveDate1,convert(datetime,c.CreatedDate) as CreatedDate1,convert(datetime,c.CloseDate) CloseDate1,
		convert(datetime,AssignedDate) as ADate,convert(datetime,c.CreateDate) as CDAte,
		 dbo.fnGet_GetAssignedListForFeatures(73,c.CaseID) as AssignedUser,A.AccountName as Customer
		 ,@canEdit canEdit,@canApprove canApprove,@Userlevel userlevel
		FROM CRM_Cases c WITH(NOLOCK)
		left join Acc_accounts A WITH(NOLOCK) on c.customerid=A.Accountid
		LEFT JOIN ADM_USERS U WITH(NOLOCK) ON U.USERID=C.ASSIGNEDTO
		LEFT JOIN INV_Product p WITH(NOLOCK) ON c.ProductID=p.ProductID
		LEFT JOIN INV_DocDetails d WITH(NOLOCK) ON c.SvcContractID=d.DocID
		where CaseID=@CaseID
		
		set @SQL='SELECT *,R.Reason, T.Name NODEID_Key FROM CRM_CaseSvcTypeMap WITH(NOLOCK) 
		LEFT JOIN CRM_ServiceReasons R with(nolock) ON R.ServiceReasonID=CRM_CaseSvcTypeMap.ServiceReasonID 
		left join '+@TableNm+' t with(nolock) on t.NodeID=CRM_CaseSvcTypeMap.Techincian
		where caseid='+Convert(nvarchar,@CaseID)
		print (@SQL)
		exec (@SQL)
		
		SELECT * FROM CRM_CasesExtended WITH(NOLOCK) where CaseID=@CaseID

		IF(EXISTS(SELECT * FROM CRM_Activities WITH(NOLOCK) WHERE CostCenterID=73 AND NodeID=@CaseID))
			EXEC spCRM_GetFeatureByActvities @CaseID,73,'',@UserID,@LangID  
		ELSE
			SELECT 1 WHERE 1<>1
			
		SELECT * FROM COM_CCCCData WITH(NOLOCK) WHERE NodeID=@CaseID and CostCenterID=73
		
		
		--Select P.ProductName as ProductName,P.ProductCode, U.UnitName as UOM,U.UnitName,L.CostCenterID,L.Description,L.CRMProduct,L.ProductMapID,L.CCNodeID,L.ProductID,L.UOMID,L.CurrencyID,CUR.Name CurrName,L.Remarks,L.Quantity,
		--L.LDAlpha1,L.LDAlpha2,L.LDAlpha3,L.LDAlpha4,L.LDAlpha5,L.LDAlpha6,L.LDAlpha7,L.LDAlpha8,L.LDAlpha9,L.LDAlpha10,L.LDAlpha11,L.LDAlpha12,L.LDAlpha13,L.LDAlpha14,L.LDAlpha15,L.LDAlpha16,L.LDAlpha17,L.LDAlpha18,L.LDAlpha19,L.LDAlpha20
		--,L.Alpha1,L.Alpha2,L.Alpha3,L.Alpha4,L.Alpha5,L.Alpha6,L.Alpha7,L.Alpha8,L.Alpha9,L.Alpha10,L.Alpha11,L.Alpha12,L.Alpha13,L.Alpha14,L.Alpha15,L.Alpha16,L.Alpha17
		--,L.Alpha18,L.Alpha19,L.Alpha20,L.Alpha21,L.Alpha22,L.Alpha23,L.Alpha24,L.Alpha25,L.Alpha26,L.Alpha27,L.Alpha28,L.Alpha29,L.Alpha30,L.Alpha31
		--,L.Alpha32,L.Alpha33,L.Alpha34,L.Alpha35,L.Alpha36,L.Alpha37,L.Alpha38,L.Alpha39,L.Alpha40,L.Alpha41,L.Alpha42
		--,L.Alpha43,L.Alpha44,L.Alpha45,L.Alpha46,L.Alpha47,L.Alpha48,L.Alpha49,L.Alpha50,
		--L.CCNID1 as CCNID1_Key ,L.CCNID2 as CCNID2_Key ,L.CCNID3 as CCNID3_Key ,L.CCNID4 as CCNID4_Key ,L.CCNID5 as CCNID5_Key ,L.CCNID6 as CCNID6_Key ,L.CCNID7 as CCNID7_Key ,L.CCNID8 as CCNID8_Key ,L.CCNID9 as CCNID9_Key ,L.CCNID10 as CCNID10_Key ,L.CCNID11 as CCNID11_Key ,L.CCNID12 as CCNID12_Key ,L.CCNID13 as CCNID13_Key ,L.CCNID14 as CCNID14_Key ,L.CCNID15 as CCNID15_Key ,L.CCNID16 as CCNID16_Key ,
		--L.CCNID17 as CCNID17_Key ,L.CCNID18 as CCNID18_Key ,L.CCNID19 as CCNID19_Key ,L.CCNID20 as CCNID20_Key ,L.CCNID21 as CCNID21_Key ,L.CCNID22 as CCNID22_Key ,L.CCNID23 as CCNID23_Key ,L.CCNID24 as CCNID24_Key ,L.CCNID25 as CCNID25_Key ,L.CCNID26 as CCNID26_Key ,L.CCNID27 as CCNID27_Key ,L.CCNID28 as CCNID28_Key ,L.CCNID29 as CCNID29_Key ,L.CCNID30 as CCNID30_Key ,
		--L.CCNID31 as CCNID31_Key ,L.CCNID32 as CCNID32_Key ,L.CCNID33 as CCNID33_Key ,L.CCNID34 as CCNID34_Key ,L.CCNID35 as CCNID35_Key ,L.CCNID36 as CCNID36_Key ,L.CCNID37 as CCNID37_Key ,L.CCNID38 as CCNID38_Key ,L.CCNID39 as CCNID39_Key ,L.CCNID40 as CCNID40_Key ,L.CCNID41 as CCNID41_Key ,
		--L.CCNID42 as CCNID42_Key,L.CCNID43 as CCNID43_Key ,L.CCNID44 as CCNID44_Key ,L.CCNID45 as CCNID45_Key ,L.CCNID46 as CCNID46_Key ,L.CCNID47 as CCNID47_Key ,L.CCNID48 as CCNID48_Key ,L.CCNID49 as CCNID49_Key ,L.CCNID50 as CCNID50_Key ,
		--NID1.NAME as CCNID1,NID2.NAME as CCNID2,NID3.NAME as CCNID3,NID4.NAME as CCNID4,NID5.NAME as CCNID5,NID6.NAME as CCNID6,NID7.NAME as CCNID7,NID8.NAME as CCNID8,NID9.NAME as CCNID9,NID10.NAME as CCNID10,
		--NID11.NAME as CCNID11,NID12.NAME as CCNID12,NID13.NAME as CCNID13,NID14.NAME as CCNID14,NID15.NAME as CCNID15,NID16.NAME as CCNID16,NID17.NAME as CCNID17,NID18.NAME as CCNID18,NID19.NAME as CCNID19,NID20.NAME as CCNID20,
		--NID21.NAME as CCNID21,NID22.NAME as CCNID22,NID23.NAME as CCNID23,NID24.NAME as CCNID24,NID25.NAME as CCNID25,NID26.NAME as CCNID26,NID27.NAME as CCNID27,NID28.NAME as CCNID28,NID29.NAME as CCNID29,NID30.NAME as CCNID30,
		--NID31.NAME as CCNID31,NID32.NAME as CCNID32,NID33.NAME as CCNID33,NID34.NAME as CCNID34,NID35.NAME as CCNID35,NID36.NAME as CCNID36,NID37.NAME as CCNID37,NID38.NAME as CCNID38,NID39.NAME as CCNID39,NID40.NAME as CCNID40,
		--NID41.NAME as CCNID41,NID42.NAME as CCNID42,NID43.NAME as CCNID43,NID44.NAME as CCNID44,NID45.NAME as CCNID45,NID46.NAME as CCNID46,NID47.NAME as CCNID47,NID48.NAME as CCNID48,NID49.NAME as CCNID49,NID50.NAME as CCNID50 
		--from CRM_ProductMapping L with(nolock)
		--Left JOIN INV_Product P with(nolock) on P.ProductID = L.ProductID
		--Left Join COM_UOM U with(nolock) on U.UOMID = L.UOMID
		--Left Join COM_Currency CUR with(nolock) on CUR.CurrencyID = L.CurrencyID
		--LEFT JOIN COM_DIVISION NID1 on L.CCNID1=NID1.NODEID
		--LEFT JOIN COM_Location NID2 on L.CCNID2=NID2.NODEID
		--LEFT JOIN COM_Branch NID3 on L.CCNID3=NID3.NODEID
		--LEFT JOIN COM_Department NID4 on L.CCNID4=NID4.NODEID
		--LEFT JOIN COM_Salesman NID5 on L.CCNID5=NID5.NODEID
		--LEFT JOIN COM_Category NID6 on L.CCNID6=NID6.NODEID
		--LEFT JOIN COM_Area NID7 on L.CCNID7=NID7.NODEID
		--LEFT JOIN COM_Teritory NID8 on L.CCNID8=NID8.NODEID
		--LEFT JOIN COM_CC50009 NID9 on L.CCNID9=NID9.NODEID
		--LEFT JOIN COM_CC50010 NID10 on L.CCNID10=NID10.NODEID
		--LEFT JOIN COM_CC50011 NID11 on L.CCNID11=NID11.NODEID
		--LEFT JOIN COM_CC50012 NID12 on L.CCNID12=NID12.NODEID
		--LEFT JOIN COM_CC50013 NID13 on L.CCNID13=NID13.NODEID
		--LEFT JOIN COM_CC50014 NID14 on L.CCNID14=NID14.NODEID
		--LEFT JOIN COM_CC50015 NID15 on L.CCNID15=NID15.NODEID
		--LEFT JOIN COM_CC50016 NID16 on L.CCNID16=NID16.NODEID
		--LEFT JOIN COM_CC50017 NID17 on L.CCNID17=NID17.NODEID
		--LEFT JOIN COM_CC50018 NID18 on L.CCNID18=NID18.NODEID
		--LEFT JOIN COM_CC50019 NID19 on L.CCNID19=NID19.NODEID 
		--LEFT JOIN COM_CC50020 NID20 ON L.CCNID20=NID20.NODEID
		--LEFT JOIN COM_CC50021 NID21 ON L.CCNID21=NID21.NODEID
		--LEFT JOIN COM_CC50022 NID22 ON L.CCNID22=NID22.NODEID
		--LEFT JOIN COM_CC50023 NID23 ON L.CCNID23=NID23.NODEID
		--LEFT JOIN COM_CC50024 NID24 ON L.CCNID24=NID24.NODEID
		--LEFT JOIN COM_CC50025 NID25 ON L.CCNID25=NID25.NODEID
		--LEFT JOIN COM_CC50026 NID26 ON L.CCNID26=NID26.NODEID
		--LEFT JOIN COM_CC50027 NID27 ON L.CCNID27=NID27.NODEID
		--LEFT JOIN COM_CC50028 NID28 ON L.CCNID28=NID28.NODEID
		--LEFT JOIN COM_CC50029 NID29 ON L.CCNID29=NID29.NODEID 
		--LEFT JOIN COM_CC50030 NID30 ON L.CCNID30=NID30.NODEID
		--LEFT JOIN COM_CC50031 NID31 ON L.CCNID31=NID31.NODEID
		--LEFT JOIN COM_CC50032 NID32 ON L.CCNID32=NID32.NODEID
		--LEFT JOIN COM_CC50033 NID33 ON L.CCNID33=NID33.NODEID
		--LEFT JOIN COM_CC50034 NID34 ON L.CCNID34=NID34.NODEID
		--LEFT JOIN COM_CC50035 NID35 ON L.CCNID35=NID35.NODEID
		--LEFT JOIN COM_CC50036 NID36 ON L.CCNID36=NID36.NODEID
		--LEFT JOIN COM_CC50037 NID37 ON L.CCNID37=NID37.NODEID
		--LEFT JOIN COM_CC50038 NID38 ON L.CCNID38=NID38.NODEID
		--LEFT JOIN COM_CC50039 NID39 ON L.CCNID39=NID39.NODEID 
		--LEFT JOIN COM_CC50040 NID40 ON L.CCNID40=NID40.NODEID
		--LEFT JOIN COM_CC50041 NID41 ON L.CCNID41=NID41.NODEID
		--LEFT JOIN COM_CC50042 NID42 ON L.CCNID42=NID42.NODEID
		--LEFT JOIN COM_CC50043 NID43 ON L.CCNID43=NID43.NODEID
		--LEFT JOIN COM_CC50044 NID44 ON L.CCNID44=NID44.NODEID
		--LEFT JOIN COM_CC50045 NID45 ON L.CCNID45=NID45.NODEID
		--LEFT JOIN COM_CC50046 NID46 ON L.CCNID46=NID46.NODEID
		--LEFT JOIN COM_CC50047 NID47 ON L.CCNID47=NID47.NODEID
		--LEFT JOIN COM_CC50048 NID48 ON L.CCNID48=NID48.NODEID
		--LEFT JOIN COM_CC50049 NID49 ON L.CCNID49=NID49.NODEID 
		--LEFT JOIN COM_CC50050 NID50 ON L.CCNID50=NID50.NODEID
		--where L.CCNodeID =  @CaseID and CostCenterID=73
		--CC FIELDS
		DECLARE @K INT,@RC INT,@STRKEY NVARCHAR(MAX),@STRNAME NVARCHAR(MAX),@COLNAME NVARCHAR(MAX),@KEYNAME NVARCHAR(MAX),@LDCOLNAME NVARCHAR(MAX),@ALPHACOLNAME NVARCHAR(MAX)
		DECLARE @JOINCOND NVARCHAR(MAX),@JOINWHR NVARCHAR(MAX),@strSql nvarchar(max),@CINDEX INT
		SET @strSql=''
		DECLARE @CCTAB TABLE (ID INT IDENTITY(1,1),COLUMNNAME NVARCHAR(100),COLINDEX INT,KEYNAME NVARCHAR(MAX),ALIASNAME NVARCHAR(MAX),JOINCOND NVARCHAR(MAX))
		DECLARE @LDTAB TABLE (ID INT IDENTITY(1,1),COLUMNNAME NVARCHAR(100),COLINDEX INT,KEYNAME NVARCHAR(MAX),ALIASNAME NVARCHAR(MAX))
		DECLARE @TXTTAB TABLE (ID INT IDENTITY(1,1),COLUMNNAME NVARCHAR(100),COLINDEX INT,KEYNAME NVARCHAR(MAX),ALIASNAME NVARCHAR(MAX))
		
		INSERT INTO @CCTAB  
				SELECT C.NAME,REPLACE(C.NAME,'CCNID',''),'','','' FROM SYS.COLUMNS C WHERE C.OBJECT_ID=OBJECT_ID('CRM_ProductMapping') AND NAME LIKE 'CCNID%' ORDER BY COLUMN_ID
		
		UPDATE @CCTAB SET ALIASNAME=' NID'+CONVERT(NVARCHAR,COLINDEX)+'.NAME AS CCNID'+CONVERT(NVARCHAR,COLINDEX)+'',KEYNAME=' L.CCNID'+CONVERT(NVARCHAR,COLINDEX)+' AS CCNID'+CONVERT(NVARCHAR,COLINDEX)+'_Key'
		
		SET @K=1
		SELECT @RC=COUNT(*) FROM @CCTAB
		WHILE(@K<=@RC)
		BEGIN
			SELECT @CINDEX=COLINDEX FROM @CCTAB WHERE ID=@K
			PRINT LEN(@CINDEX)
			IF(@K>8 AND @K<=9)
			BEGIN
				UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_CC5000'+ CONVERT(VARCHAR,@K) +' NID'+ CONVERT(VARCHAR,@K) +' on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
			END
			ELSE IF(@K>9)
			BEGIN
				IF(LEN(@CINDEX)=2)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_CC500'+ CONVERT(VARCHAR,@K) +' NID'+ CONVERT(VARCHAR,@K) +' on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(LEN(@CINDEX)=4)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_CC5'+ CONVERT(VARCHAR,@CINDEX) +' NID'+ CONVERT(VARCHAR,@CINDEX) +' on L.CCNID'+ CONVERT(VARCHAR,@CINDEX) +'=NID'+ CONVERT(VARCHAR,@CINDEX) +'.NODEID' WHERE ID=@K
				
			END
			ELSE
			BEGIN
				IF(@K=1)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_DIVISION NID'+ CONVERT(VARCHAR,@K)+' on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(@K=2)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_LOCATION NID'+ CONVERT(VARCHAR,@K)+'  on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(@K=3)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_Branch NID'+ CONVERT(VARCHAR,@K)+'   on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(@K=4)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_Department NID'+ CONVERT(VARCHAR,@K)+'  on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(@K=5)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_Salesman NID'+ CONVERT(VARCHAR,@K)+'  on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(@K=6)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_Category NID'+ CONVERT(VARCHAR,@K)+'  on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(@K=7)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_Area NID'+ CONVERT(VARCHAR,@K)+'  on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
				ELSE IF(@K=8)
					UPDATE @CCTAB SET JOINCOND=' LEFT JOIN COM_Teritory NID'+ CONVERT(VARCHAR,@K)+'  on L.CCNID'+ CONVERT(VARCHAR,@K) +'=NID'+ CONVERT(VARCHAR,@K) +'.NODEID' WHERE ID=@K
			END
		SET @K=@K+1
		END
		
		SET @STRNAME=''
		SET @STRKEY=''
		SET @JOINWHR=''
		SET @K=1
		SELECT @RC=COUNT(*) FROM @CCTAB
		WHILE(@K<=@RC)
		BEGIN
			SELECT @COLNAME=ALIASNAME,@KEYNAME=KEYNAME,@JOINCOND=JOINCOND FROM @CCTAB WHERE ID=@K
		
			IF(@K=1)
			BEGIN
				SET @STRNAME=@COLNAME
				SET @STRKEY=@KEYNAME
				SET @JOINWHR=@JOINCOND				
			END
			ELSE
			BEGIN
				SET @STRNAME=@STRNAME+','+@COLNAME
				SET @STRKEY=@STRKEY+','+@KEYNAME
				SET @JOINWHR=@JOINWHR+' '+@JOINCOND
			END
		SET @K=@K+1
		END
		--PRINT @STRNAME
		--PRINT @STRKEY
		--PRINT @JOINWHR
		
		--LDALPHA FIELDS		
		INSERT INTO @LDTAB  
		SELECT C.NAME,REPLACE(C.NAME,'LDAlpha',''),'','' FROM SYS.COLUMNS C WHERE C.OBJECT_ID=OBJECT_ID('CRM_ProductMapping') AND NAME LIKE 'LDAlpha%'
		UPDATE @LDTAB SET ALIASNAME=' L.LDAlpha'+CONVERT(NVARCHAR,COLINDEX) 
		
		SET @LDCOLNAME=''
		SET @K=1
		SELECT @RC=COUNT(*) FROM @LDTAB
		WHILE(@K<=@RC)
		BEGIN
			SELECT @COLNAME=ALIASNAME FROM @LDTAB WHERE ID=@K
			IF(@K=1)
			BEGIN
				SET @LDCOLNAME=@COLNAME
			END
			ELSE
			BEGIN
				SET @LDCOLNAME=@LDCOLNAME+','+@COLNAME
			END
		SET @K=@K+1
		END
		PRINT @LDCOLNAME

		--ALPHA FIELDS		
		INSERT INTO @TXTTAB  
		SELECT C.NAME,REPLACE(C.NAME,'Alpha',''),'','' FROM SYS.COLUMNS C WHERE C.OBJECT_ID=OBJECT_ID('CRM_ProductMapping') AND NAME LIKE 'Alpha%'
		UPDATE @TXTTAB SET ALIASNAME=' L.Alpha'+CONVERT(NVARCHAR,COLINDEX) 
		
		SET @ALPHACOLNAME=''
			SET @K=1
		SELECT @RC=COUNT(*) FROM @TXTTAB
		WHILE(@K<=@RC)
		BEGIN
			SELECT @COLNAME=ALIASNAME FROM @TXTTAB WHERE ID=@K
			IF(@K=1)
			BEGIN
				SET @ALPHACOLNAME=@COLNAME
			END
			ELSE
			BEGIN
				SET @ALPHACOLNAME=@ALPHACOLNAME+','+@COLNAME
			END
		SET @K=@K+1
		END
		--PRINT @ALPHACOLNAME
		
		IF(@LDCOLNAME<>'')
			SET @LDCOLNAME=@LDCOLNAME+','
		IF(@ALPHACOLNAME<>'')
			SET @ALPHACOLNAME=@ALPHACOLNAME+','
		IF(@STRKEY<>'')
			SET @STRKEY=@STRKEY+','
			
		set @strSql='
		Select P.ProductName as ProductName,P.ProductCode, U.UnitName as UOM,U.UnitName,L.CostCenterID,L.Description,L.CRMProduct,L.ProductMapID,L.CCNodeID,L.ProductID,L.UOMID,L.CurrencyID,CUR.Name CurrName,L.Remarks,L.Quantity,
		'+ @LDCOLNAME+'
		'+ @ALPHACOLNAME +''+ @STRKEY+''+ @STRNAME +'
		from CRM_ProductMapping L with(nolock)
		Left JOIN INV_Product P with(nolock) on P.ProductID = L.ProductID
		Left Join COM_UOM U with(nolock) on U.UOMID = L.UOMID
		Left Join COM_Currency CUR with(nolock) on CUR.CurrencyID = L.CurrencyID
		'+ @JOINWHR+'
		where L.CCNodeID = '+ convert(varchar, @CaseID) +' and CostCenterID=73'
		print (@strSql)
		exec(@strSql)
	
		--Getting Notes
		SELECT NoteID, Note, FeatureID, FeaturePK, CompanyGUID, [GUID], CreatedBy, convert(datetime,CreatedDate) CreatedDate,ModifiedBy, ModifiedDate, CostCenterID
		FROM COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=73 and  FeaturePK=@CaseID

		--Getting Files
		EXEC [spCOM_GetAttachments] 73,@CaseID,@UserID
			
		SELECT L.*,CONVERT(DATETIME,[Date]) CDate,(SELECT TOP 1 [GUID]+'.'+FileExtension FROM COM_Files WITH(NOLOCK) WHERE FeatureID=7 AND IsProductImage=1 AND FileDescription='USERPHOTO' AND  FeaturePK=(select top 1 userid from adm_users with(nolock) where username=L.CreatedBy) ) Imagefilepath
		FROM  CRM_Feedback L WITH(NOLOCK) WHERE L.CCNodeID=@CaseID and CCID=73
			
		select CON.*,C1.Name as SalutationName,C1.NodeID as Salutation , C2.Name as Role,S.Status ,crm.CustomerID CustomerID, acc.AccountName Customer 
		from com_contacts CON WITH(NOLOCK) 
		left join com_lookup C1 WITH(NOLOCK) on CON.SalutationID=C1.NodeID and C1.lookuptype =20  
		left join com_lookup C2 WITH(NOLOCK) on CON.RoleLookUpID=C1.NodeID
		left join Com_Status S WITH(NOLOCK) on CON.StatusID=S.StatusID
		left join com_lookup Sal WITH(NOLOCK) on  Sal.nodeid = CON.SalutationID
		left join CRM_Cases crm WITH(NOLOCK) on CON.featurepk = crm.CaseID 
		left join acc_accounts acc WITH(NOLOCK) on crm.CustomerID = acc.accountid 
		where CON.featureid=73 and CON.featurepk=@CaseID
		
		
		IF @WID is not null and @WID>0
		begin
			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=73 AND CCNodeID=@CaseID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
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
