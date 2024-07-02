USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetLead]
	@LeadID [int] = 0,
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
	select *,convert(datetime,createddate) as CvtDate,convert(datetime,date) as CDate,dbo.fnGet_GetAssignedListForFeatures(CONVERT(nvarchar(300),86),@LeadID) AssignedTo  
	,(SELECT MAX(convert(datetime,createddate)) FROM CRM_Assignment WITH(NOLOCK) WHERE CCID=86 AND CCNodeID=@LeadID) AssignedDate
	from CRM_Leads with(nolock) where LeadID=@LeadID

	select * from CRM_Leads with(nolock) where IsGroup=1

	SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=86

	select  FirstName,
       MiddleName,
       LastName,
       SalutationID,
       JobTitle,
       CC.Company,
       LD.StatusID,
       Phone1,
       Phone2,
       Email1,
       Fax,
       Department,
       RoleLookUpID,
       Address1,
       Address2,
       Address3,
       City,
       [State],
       Zip,
       Country,
       Gender,
       PreferredID,
       PreferredName,
       IsEmailOn,
       IsBulkEmailOn,
       IsMailOn,
       IsPhoneOn,
       IsFaxOn,
       IsVisible,convert(datetime,Birthday) Birthday,convert(datetime,Anniversary) Anniversary ,Lo.Name Salutation
       from CRM_Contacts CC with(nolock)
	   join CRM_Leads LD with(nolock) ON CC.FeaturePK=LD.LeadID
       LEFT JOIN Com_lookup Lo with(nolock) on Lo.NodeID=CC.SalutationID and LookUpType=20
       where CC.FeaturePK=@LeadID and CC.Featureid=86  
	 
	SELECT * FROM  CRM_LeadsExtended WITH(NOLOCK) 
	WHERE LeadID=@LeadID

	SELECT ConvertFromLeadID FROM CRM_Opportunities WITH(nolock) WHERE ConvertFromLeadID=@LEADID
	SELECT ConvertFromLeadID FROM CRM_Customer WITH(nolock) WHERE ConvertFromLeadID=@LEADID
	SELECT ConvertFromLeadID FROM COM_Contacts WITH(nolock) WHERE ConvertFromLeadID=@LEADID
		
	IF(EXISTS(SELECT * FROM CRM_Activities WITH(nolock) WHERE CostCenterID=86 AND NodeID=@LeadID))
		EXEC spCRM_GetFeatureByActvities @LeadID,86,'',@UserID,@LangID  
	ELSE
		SELECT 1 WHERE 1<>1
			 
	--Getting Notes
	SELECT NoteID, Note,FeatureID,FeaturePK,CompanyGUID,[GUID],CreatedBy,convert(datetime,CreatedDate) CreatedDate,ModifiedBy, ModifiedDate, CostCenterID
	FROM COM_Notes WITH(NOLOCK) 
	WHERE FeatureID=86 and  FeaturePK=@LeadID

	--Getting Files
	EXEC [spCOM_GetAttachments] 86,@LeadID,@UserID
	
	--Getting CostCenterMap
	SELECT * FROM  COM_CCCCData WITH(NOLOCK) 
	WHERE NodeID=@LeadID and CostCenterID=86
	
	--Getting ProductMap for leads
	Select P.ProductName as ProductName,P.ProductCode, U.UnitName as UOM,U.UnitName,L.CostCenterID,L.Description,L.CRMProduct,L.ProductMapID,L.CCNodeID,L.ProductID,L.UOMID,L.CurrencyID,CUR.Name CurrName,L.Remarks,L.Quantity,
	L.LDAlpha1,L.LDAlpha2,L.LDAlpha3,L.LDAlpha4,L.LDAlpha5,L.LDAlpha6,L.LDAlpha7,L.LDAlpha8,L.LDAlpha9,L.LDAlpha10,L.LDAlpha11,L.LDAlpha12,L.LDAlpha13,L.LDAlpha14,L.LDAlpha15,L.LDAlpha16,L.LDAlpha17,L.LDAlpha18,L.LDAlpha19,L.LDAlpha20
	,L.Alpha1,L.Alpha2,L.Alpha3,L.Alpha4,L.Alpha5,L.Alpha6,L.Alpha7,L.Alpha8,L.Alpha9,L.Alpha10,L.Alpha11,L.Alpha12,L.Alpha13,L.Alpha14,L.Alpha15,L.Alpha16,L.Alpha17
	,L.Alpha18,L.Alpha19,L.Alpha20,L.Alpha21,L.Alpha22,L.Alpha23,L.Alpha24,L.Alpha25,L.Alpha26,L.Alpha27,L.Alpha28,L.Alpha29,L.Alpha30,L.Alpha31
	,L.Alpha32,L.Alpha33,L.Alpha34,L.Alpha35,L.Alpha36,L.Alpha37,L.Alpha38,L.Alpha39,L.Alpha40,L.Alpha41,L.Alpha42
	,L.Alpha43,L.Alpha44,L.Alpha45,L.Alpha46,L.Alpha47,L.Alpha48,L.Alpha49,L.Alpha50,
	L.CCNID1 as CCNID1_Key ,L.CCNID2 as CCNID2_Key ,L.CCNID3 as CCNID3_Key ,L.CCNID4 as CCNID4_Key ,L.CCNID5 as CCNID5_Key ,L.CCNID6 as CCNID6_Key ,L.CCNID7 as CCNID7_Key ,L.CCNID8 as CCNID8_Key ,L.CCNID9 as CCNID9_Key ,L.CCNID10 as CCNID10_Key ,L.CCNID11 as CCNID11_Key ,L.CCNID12 as CCNID12_Key ,L.CCNID13 as CCNID13_Key ,L.CCNID14 as CCNID14_Key ,L.CCNID15 as CCNID15_Key ,L.CCNID16 as CCNID16_Key ,
	L.CCNID17 as CCNID17_Key ,L.CCNID18 as CCNID18_Key ,L.CCNID19 as CCNID19_Key ,L.CCNID20 as CCNID20_Key ,L.CCNID21 as CCNID21_Key ,L.CCNID22 as CCNID22_Key ,L.CCNID23 as CCNID23_Key ,L.CCNID24 as CCNID24_Key ,L.CCNID25 as CCNID25_Key ,L.CCNID26 as CCNID26_Key ,L.CCNID27 as CCNID27_Key ,L.CCNID28 as CCNID28_Key ,L.CCNID29 as CCNID29_Key ,L.CCNID30 as CCNID30_Key ,
	L.CCNID31 as CCNID31_Key ,L.CCNID32 as CCNID32_Key ,L.CCNID33 as CCNID33_Key ,L.CCNID34 as CCNID34_Key ,L.CCNID35 as CCNID35_Key ,L.CCNID36 as CCNID36_Key ,L.CCNID37 as CCNID37_Key ,L.CCNID38 as CCNID38_Key ,L.CCNID39 as CCNID39_Key ,L.CCNID40 as CCNID40_Key ,L.CCNID41 as CCNID41_Key ,
	L.CCNID42 as CCNID42_Key,L.CCNID43 as CCNID43_Key ,L.CCNID44 as CCNID44_Key ,L.CCNID45 as CCNID45_Key ,L.CCNID46 as CCNID46_Key ,L.CCNID47 as CCNID47_Key ,L.CCNID48 as CCNID48_Key ,L.CCNID49 as CCNID49_Key ,L.CCNID50 as CCNID50_Key ,
	NID1.NAME as CCNID1,NID2.NAME as CCNID2,NID3.NAME as CCNID3,NID4.NAME as CCNID4,NID5.NAME as CCNID5,NID6.NAME as CCNID6,NID7.NAME as CCNID7,NID8.NAME as CCNID8,NID9.NAME as CCNID9,NID10.NAME as CCNID10,
	NID11.NAME as CCNID11,NID12.NAME as CCNID12,NID13.NAME as CCNID13,NID14.NAME as CCNID14,NID15.NAME as CCNID15,NID16.NAME as CCNID16,NID17.NAME as CCNID17,NID18.NAME as CCNID18,NID19.NAME as CCNID19,NID20.NAME as CCNID20,
	NID21.NAME as CCNID21,NID22.NAME as CCNID22,NID23.NAME as CCNID23,NID24.NAME as CCNID24,NID25.NAME as CCNID25,NID26.NAME as CCNID26,NID27.NAME as CCNID27,NID28.NAME as CCNID28,NID29.NAME as CCNID29,NID30.NAME as CCNID30,
	NID31.NAME as CCNID31,NID32.NAME as CCNID32,NID33.NAME as CCNID33,NID34.NAME as CCNID34,NID35.NAME as CCNID35,NID36.NAME as CCNID36,NID37.NAME as CCNID37,NID38.NAME as CCNID38,NID39.NAME as CCNID39,NID40.NAME as CCNID40,
	NID41.NAME as CCNID41,NID42.NAME as CCNID42,NID43.NAME as CCNID43,NID44.NAME as CCNID44,NID45.NAME as CCNID45,NID46.NAME as CCNID46,NID47.NAME as CCNID47,NID48.NAME as CCNID48,NID49.NAME as CCNID49,NID50.NAME as CCNID50 
	from CRM_ProductMapping L WITH(nolock)
	Left JOIN INV_Product P WITH(nolock) on P.ProductID = L.ProductID
	Left Join COM_UOM U WITH(nolock) on U.UOMID = L.UOMID
	Left Join COM_Currency CUR WITH(nolock) on CUR.CurrencyID = L.CurrencyID
	LEFT JOIN COM_DIVISION NID1 WITH(nolock) on L.CCNID1=NID1.NODEID
	LEFT JOIN COM_Location NID2 WITH(nolock) on L.CCNID2=NID2.NODEID
	LEFT JOIN COM_Branch NID3 WITH(nolock) on L.CCNID3=NID3.NODEID
	LEFT JOIN COM_Department NID4 WITH(nolock) on L.CCNID4=NID4.NODEID
	LEFT JOIN COM_Salesman NID5 WITH(nolock) on L.CCNID5=NID5.NODEID
	LEFT JOIN COM_Category NID6 WITH(nolock) on L.CCNID6=NID6.NODEID
	LEFT JOIN COM_Area NID7 WITH(nolock) on L.CCNID7=NID7.NODEID
	LEFT JOIN COM_Teritory NID8 WITH(nolock) on L.CCNID8=NID8.NODEID
	LEFT JOIN COM_CC50009 NID9 WITH(nolock) on L.CCNID9=NID9.NODEID
	LEFT JOIN COM_CC50010 NID10 WITH(nolock) on L.CCNID10=NID10.NODEID
	LEFT JOIN COM_CC50011 NID11 WITH(nolock) on L.CCNID11=NID11.NODEID
	LEFT JOIN COM_CC50012 NID12 WITH(nolock) on L.CCNID12=NID12.NODEID
	LEFT JOIN COM_CC50013 NID13 WITH(nolock) on L.CCNID13=NID13.NODEID
	LEFT JOIN COM_CC50014 NID14 WITH(nolock) on L.CCNID14=NID14.NODEID
	LEFT JOIN COM_CC50015 NID15 WITH(nolock) on L.CCNID15=NID15.NODEID
	LEFT JOIN COM_CC50016 NID16 WITH(nolock) on L.CCNID16=NID16.NODEID
	LEFT JOIN COM_CC50017 NID17 WITH(nolock) on L.CCNID17=NID17.NODEID
	LEFT JOIN COM_CC50018 NID18 WITH(nolock) on L.CCNID18=NID18.NODEID
	LEFT JOIN COM_CC50019 NID19 WITH(nolock) on L.CCNID19=NID19.NODEID 
	LEFT JOIN COM_CC50020 NID20 WITH(nolock) ON L.CCNID20=NID20.NODEID
	LEFT JOIN COM_CC50021 NID21 WITH(nolock) ON L.CCNID21=NID21.NODEID
	LEFT JOIN COM_CC50022 NID22 WITH(nolock) ON L.CCNID22=NID22.NODEID
	LEFT JOIN COM_CC50023 NID23 WITH(nolock) ON L.CCNID23=NID23.NODEID
	LEFT JOIN COM_CC50024 NID24 WITH(nolock) ON L.CCNID24=NID24.NODEID
	LEFT JOIN COM_CC50025 NID25 WITH(nolock) ON L.CCNID25=NID25.NODEID
	LEFT JOIN COM_CC50026 NID26 WITH(nolock) ON L.CCNID26=NID26.NODEID
	LEFT JOIN COM_CC50027 NID27 WITH(nolock) ON L.CCNID27=NID27.NODEID
	LEFT JOIN COM_CC50028 NID28 WITH(nolock) ON L.CCNID28=NID28.NODEID
	LEFT JOIN COM_CC50029 NID29 WITH(nolock) ON L.CCNID29=NID29.NODEID 
	LEFT JOIN COM_CC50030 NID30 WITH(nolock) ON L.CCNID30=NID30.NODEID
	LEFT JOIN COM_CC50031 NID31 WITH(nolock) ON L.CCNID31=NID31.NODEID
	LEFT JOIN COM_CC50032 NID32 WITH(nolock) ON L.CCNID32=NID32.NODEID
	LEFT JOIN COM_CC50033 NID33 WITH(nolock) ON L.CCNID33=NID33.NODEID
	LEFT JOIN COM_CC50034 NID34 WITH(nolock) ON L.CCNID34=NID34.NODEID
	LEFT JOIN COM_CC50035 NID35 WITH(nolock) ON L.CCNID35=NID35.NODEID
	LEFT JOIN COM_CC50036 NID36 WITH(nolock) ON L.CCNID36=NID36.NODEID
	LEFT JOIN COM_CC50037 NID37 WITH(nolock) ON L.CCNID37=NID37.NODEID
	LEFT JOIN COM_CC50038 NID38 WITH(nolock) ON L.CCNID38=NID38.NODEID
	LEFT JOIN COM_CC50039 NID39 WITH(nolock) ON L.CCNID39=NID39.NODEID 
	LEFT JOIN COM_CC50040 NID40 WITH(nolock) ON L.CCNID40=NID40.NODEID
	LEFT JOIN COM_CC50041 NID41 WITH(nolock) ON L.CCNID41=NID41.NODEID
	LEFT JOIN COM_CC50042 NID42 WITH(nolock) ON L.CCNID42=NID42.NODEID
	LEFT JOIN COM_CC50043 NID43 WITH(nolock) ON L.CCNID43=NID43.NODEID
	LEFT JOIN COM_CC50044 NID44 WITH(nolock) ON L.CCNID44=NID44.NODEID
	LEFT JOIN COM_CC50045 NID45 WITH(nolock) ON L.CCNID45=NID45.NODEID
	LEFT JOIN COM_CC50046 NID46 WITH(nolock) ON L.CCNID46=NID46.NODEID
	LEFT JOIN COM_CC50047 NID47 WITH(nolock) ON L.CCNID47=NID47.NODEID
	LEFT JOIN COM_CC50048 NID48 WITH(nolock) ON L.CCNID48=NID48.NODEID
	LEFT JOIN COM_CC50049 NID49 WITH(nolock) ON L.CCNID49=NID49.NODEID 
	LEFT JOIN COM_CC50050 NID50 WITH(nolock) ON L.CCNID50=NID50.NODEID
	where L.CCNodeID =  @LeadID and CostCenterID=86
		
	--Getting CostCenterMap
	SELECT L.*,CONVERT(DATETIME,[Date]) CDate,(SELECT TOP 1 [GUID]+'.'+FileExtension FROM COM_Files WITH(NOLOCK) WHERE FeatureID=7 AND IsProductImage=1 AND FileDescription='USERPHOTO' AND  FeaturePK=(select top 1 userid from adm_users with(nolock) where username=L.CreatedBy) ) Imagefilepath
	FROM  CRM_Feedback L WITH(NOLOCK) WHERE L.CCNodeID=@LeadID and CCID=86
		
	SELECT isnull(ConvertFromLeadID,0) ConvertFromLeadID 
	FROM ACC_ACCOUNTs WITH(nolock) WHERE ConvertFromLeadID=@LEADID

	--Getting Contacts 
	EXEC [spCom_GetFeatureWiseContacts] 86,@LeadID,2,1,1
	
	--Getting CostCenterMap
	SELECT CRM_LeadCVRDetails.*,convert(datetime,date)d,P.ProductName PRODUCT,P.PRODUCTID 
	FROM  CRM_LeadCVRDetails WITH(NOLOCK) 
	Left JOIN INV_Product P  WITH(nolock) on P.ProductID = CRM_LeadCVRDetails.PRODUCT
	WHERE CRM_LeadCVRDetails.CCNodeID=@LeadID and CRM_LeadCVRDetails.CCID=86
	
	--Getting Contacts 
	EXEC [spCom_GetFeatureWiseContacts] 86,@LeadID,1,1,1
	
	--Getting History 
	EXEC [spCRM_GetAssignedList] 86,@LeadID,1,1,1
	
	--Getting CRMHistory 
	EXEC [spCRM_GetHistoryList] 86,@LeadID,1,1


	
		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM CRM_Leads WITH(NOLOCK) where LeadID=@LeadID
		if(@WID is not null and @WID>0)  
		BEGIN  
			SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID

			if(@Userlevel is null)  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID

			if(@Userlevel is null)       
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID

			if(@Userlevel is null)  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
			
			if(@Userlevel is null )  	
				SELECT @Type=[type] FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID


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
			print '@Userlevel'
		
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
			--else if(@Userlevel is not null and  @Level is not null and @Level=@Userlevel and @StatusID=1001)  
			--begin
			--	set @canApprove=1  
			--end
			else  
				set @canApprove= 0   
		end  		
		else  
			set @canApprove= 0   

		IF @WID is not null and @WID>0
		begin

			
			select @canEdit canEdit,@canApprove canApprove

			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U 
			with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=86
			AND CCNodeID=@LeadID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
		end 
		
COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
