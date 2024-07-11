USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetOpportunity]
	@OpportunityID [int] = 0,
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

		SELECT Name,Value,CostCenterID from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=89 
		UNION ALL
		SELECT Name,Value,CostCenterID from  COM_CostCenterPreferences with(nolock) 
		WHERE CostCenterID=86 AND Name in ('LinkDimension','CreateDocuments')

		SELECT O.OpportunityID,O.ContactID,L.SelectedModeID CustomerID, O.Mode, O.SelectedModeID, O.DetailsContactID, O.Code, Convert(datetime,O.Date) as Date, O.StatusID, O.LeadID, O.CampaignID, O.Subject, O.Company, O.EstimatedRevenue, 
		  O.CurrencyID, Convert(datetime,O.EstimatedCloseDate) as EstimatedCloseDate , O.ProbabilityLookUpID, O.RatingLookUpID, Convert(datetime, O.CloseDate)as CloseDate, O.ReasonLookUpID, O.Description, 
		  O.CCOpportunityID,L.CCLeadID,
		  O.Depth, O.ParentID, O.lft, O.rgt, O.IsGroup, O.CompanyGUID, O.GUID, O.CreatedBy, O.CreatedDate, O.ModifiedBy, O.ModifiedDate ,
		  L.Mode LeadMode,O.WorkFlowID,O.WorkFlowLevel
		FROM CRM_Opportunities O with(nolock) 
		LEFT JOIN CRM_Leads L with(nolock) ON L.LeadID=O.LeadID where  O.OpportunityID=@OpportunityID
	                     
		select * from CRM_Opportunities with(nolock) where IsGroup=1

		select * from ADM_Features with(nolock) where IsEnabled=1 and featureID between 40001 and 40050
		
	 	IF(EXISTS(SELECT * FROM CRM_Activities with(nolock) WHERE CostCenterID=89 AND NodeID=@OpportunityID))
			EXEC spCRM_GetFeatureByActvities @OpportunityID,89,'',@UserID,@LangID  
		ELSE
			SELECT 1 WHERE 1<>1

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
      from CRM_ProductMapping L with(nolock)
		Left JOIN INV_Product P with(nolock) on P.ProductID = L.ProductID
		Left Join COM_UOM U with(nolock) on U.UOMID = L.UOMID
		Left Join COM_Currency CUR with(nolock) on CUR.CurrencyID = L.CurrencyID
		LEFT JOIN COM_DIVISION NID1 with(nolock) on L.CCNID1=NID1.NODEID
		LEFT JOIN COM_Location NID2 with(nolock) on L.CCNID2=NID2.NODEID
		LEFT JOIN COM_Branch NID3 with(nolock) on L.CCNID3=NID3.NODEID
		LEFT JOIN COM_Department NID4 with(nolock) on L.CCNID4=NID4.NODEID
		LEFT JOIN COM_Salesman NID5 with(nolock) on L.CCNID5=NID5.NODEID
		LEFT JOIN COM_Category NID6 with(nolock) on L.CCNID6=NID6.NODEID
		LEFT JOIN COM_Area NID7 with(nolock) on L.CCNID7=NID7.NODEID
		LEFT JOIN COM_Teritory NID8 with(nolock) on L.CCNID8=NID8.NODEID
		LEFT JOIN COM_CC50009 NID9 with(nolock) on L.CCNID9=NID9.NODEID
		LEFT JOIN COM_CC50010 NID10 with(nolock) on L.CCNID10=NID10.NODEID
		LEFT JOIN COM_CC50011 NID11 with(nolock) on L.CCNID11=NID11.NODEID
		LEFT JOIN COM_CC50012 NID12 with(nolock) on L.CCNID12=NID12.NODEID
		LEFT JOIN COM_CC50013 NID13 with(nolock) on L.CCNID13=NID13.NODEID
		LEFT JOIN COM_CC50014 NID14 with(nolock) on L.CCNID14=NID14.NODEID
		LEFT JOIN COM_CC50015 NID15 with(nolock) on L.CCNID15=NID15.NODEID
		LEFT JOIN COM_CC50016 NID16 with(nolock) on L.CCNID16=NID16.NODEID
		LEFT JOIN COM_CC50017 NID17 with(nolock) on L.CCNID17=NID17.NODEID
		LEFT JOIN COM_CC50018 NID18 with(nolock) on L.CCNID18=NID18.NODEID
		LEFT JOIN COM_CC50019 NID19 with(nolock) on L.CCNID19=NID19.NODEID 
		LEFT JOIN COM_CC50020 NID20 with(nolock) ON L.CCNID20=NID20.NODEID
		LEFT JOIN COM_CC50021 NID21 ON L.CCNID21=NID21.NODEID
		LEFT JOIN COM_CC50022 NID22 ON L.CCNID22=NID22.NODEID
		LEFT JOIN COM_CC50023 NID23 ON L.CCNID23=NID23.NODEID
		LEFT JOIN COM_CC50024 NID24 ON L.CCNID24=NID24.NODEID
		LEFT JOIN COM_CC50025 NID25 ON L.CCNID25=NID25.NODEID
		LEFT JOIN COM_CC50026 NID26 ON L.CCNID26=NID26.NODEID
		LEFT JOIN COM_CC50027 NID27 ON L.CCNID27=NID27.NODEID
		LEFT JOIN COM_CC50028 NID28 ON L.CCNID28=NID28.NODEID
		LEFT JOIN COM_CC50029 NID29 ON L.CCNID29=NID29.NODEID 
		LEFT JOIN COM_CC50030 NID30 ON L.CCNID30=NID30.NODEID
		LEFT JOIN COM_CC50031 NID31 ON L.CCNID31=NID31.NODEID
		LEFT JOIN COM_CC50032 NID32 ON L.CCNID32=NID32.NODEID
		LEFT JOIN COM_CC50033 NID33 ON L.CCNID33=NID33.NODEID
		LEFT JOIN COM_CC50034 NID34 ON L.CCNID34=NID34.NODEID
		LEFT JOIN COM_CC50035 NID35 ON L.CCNID35=NID35.NODEID
		LEFT JOIN COM_CC50036 NID36 ON L.CCNID36=NID36.NODEID
		LEFT JOIN COM_CC50037 NID37 ON L.CCNID37=NID37.NODEID
		LEFT JOIN COM_CC50038 NID38 ON L.CCNID38=NID38.NODEID
		LEFT JOIN COM_CC50039 NID39 ON L.CCNID39=NID39.NODEID 
		LEFT JOIN COM_CC50040 NID40 ON L.CCNID40=NID40.NODEID
		LEFT JOIN COM_CC50041 NID41 ON L.CCNID41=NID41.NODEID
		LEFT JOIN COM_CC50042 NID42 ON L.CCNID42=NID42.NODEID
		LEFT JOIN COM_CC50043 NID43 ON L.CCNID43=NID43.NODEID
		LEFT JOIN COM_CC50044 NID44 ON L.CCNID44=NID44.NODEID
		LEFT JOIN COM_CC50045 NID45 ON L.CCNID45=NID45.NODEID
		LEFT JOIN COM_CC50046 NID46 ON L.CCNID46=NID46.NODEID
		LEFT JOIN COM_CC50047 NID47 ON L.CCNID47=NID47.NODEID
		LEFT JOIN COM_CC50048 NID48 ON L.CCNID48=NID48.NODEID
		LEFT JOIN COM_CC50049 NID49 ON L.CCNID49=NID49.NODEID 
		LEFT JOIN COM_CC50050 NID50 ON L.CCNID50=NID50.NODEID
		where L.CCNodeID =  @OpportunityID and CostCenterID=89

		select costcenterid from INV_DocDetails with(nolock) where DocID=(select top(1) DocID from CRM_OpportunityDocMap with(nolock) where OpportunityID=@OpportunityID)

		SELECT     I.DocID, I.CostCenterID, I.VoucherNo, CONVERT(DATETIME, I.DocDate) AS DocDate, D.DocumentName, I.DocPrefix, I.DocNumber,I.Gross as Amount,C.Name,S.Status
		FROM INV_DocDetails AS I with(nolock) 
		INNER JOIN ADM_DocumentTypes AS D with(nolock) ON I.CostCenterID = D.CostCenterID 
		INNER JOIN COM_Currency As C with(nolock) On I.CurrencyID=C.CurrencyID 
		INNER JOIN COM_Status As S with(nolock) ON I.StatusID=S.StatusID
		WHERE D.CostCenterID=(select costcenterid from INV_DocDetails with(nolock) where DocID=(select top(1) DocID from CRM_OpportunityDocMap with(nolock) where OpportunityID=@OpportunityID))
		GROUP BY I.DocDate, I.VoucherNo, D.DocumentName, I.DocPrefix, I.DocNumber, I.DocID, I.CostCenterID,I.Gross,C.Name,S.Status
				
		--Getting data from Opportunities extended table
		SELECT * FROM  CRM_OpportunitiesExtended WITH(NOLOCK) 
		WHERE OpportunityID=@OpportunityID
		
		--Getting Notes
		SELECT * FROM  COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=89 and  FeaturePK=@OpportunityID

		--Getting Files
		EXEC [spCOM_GetAttachments] 89,@OpportunityID,@UserID
		
			--Getting CostCenterMap
		SELECT * FROM  COM_CCCCData WITH(NOLOCK) 
		WHERE NodeID=@OpportunityID and CostCenterID=89
		
		SELECT L.*,CONVERT(DATETIME,[Date]) CDate,(SELECT TOP 1 [GUID]+'.'+FileExtension FROM COM_Files WITH(NOLOCK) WHERE FeatureID=7 AND IsProductImage=1 AND FileDescription='USERPHOTO' AND  FeaturePK=(select top 1 userid from adm_users with(nolock) where username=L.CreatedBy) ) Imagefilepath
		FROM  CRM_Feedback L WITH(NOLOCK) WHERE L.CCNodeID=@OpportunityID and CCID=89
		
		select  FirstName,
           MiddleName,
           LastName,
           SalutationID,
           JobTitle,
           Company,
           StatusID,
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
           State,
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
           IsVisible,convert(datetime,Birthday)  as Birthday,convert(datetime,Anniversary)  as Anniversary ,Lo.Name Salutation
           from CRM_Contacts with(nolock) LEFT JOIN Com_lookup Lo with(nolock) on Lo.NodeID=CRM_Contacts.SalutationID and LookUpType=20
           where FeaturePK=@OpportunityID and Featureid=89  
           
           	--Getting Contacts
		EXEC [spCom_GetFeatureWiseContacts] 89,@OpportunityID,1,1,1
			--Getting Contacts
		EXEC [spCom_GetFeatureWiseContacts] 89,@OpportunityID,2,1,1
		
		SELECT isnull(NodeID,0) FROM COM_CostCenterCostCenterMap with(nolock) WHERE  CostCenterID=83 AND ParentCostCenterID=89 AND PARENTNODEID=@OpportunityID
		SELECT isnull(NodeID,0) FROM COM_CostCenterCostCenterMap with(nolock) WHERE  CostCenterID=2 AND ParentCostCenterID=89 AND PARENTNODEID=@OpportunityID


	Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM CRM_Opportunities WITH(NOLOCK) where OpportunityID=@OpportunityID
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
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=89
			AND CCNodeID=@OpportunityID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
		end 


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
