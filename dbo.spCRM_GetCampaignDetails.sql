USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetCampaignDetails]
	@CampaignID [bigint] = 0,
	@ProductId [bigint] = 0,
	@UserId [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON


	select P.ProductCode,P.ProductName,U.BaseId,U.BaseName,U.UOMID,U.UnitName 
	from Inv_Product  P WITH(NOLOCK) 	
	Left Join COM_UOM U WITH(NOLOCK)  on U.UomId =P.UomID
	Where P.ProductId=@ProductId

	create table #tblUsers(username nvarchar(100))
	insert into #tblUsers
	exec [spADM_GetUserNamebyOwner] @UserID 
	
	if(@CampaignID>0)
	BEGIN
		SELECT Code,Name,StatusID,CampaignTypeLookupID,ExpectedResponse,Offer,convert(datetime,ProposedStartDate) as ProposedStartDate, convert(datetime,ProposedEndDate) as ProposedEndDate,convert(datetime,ActualStartDate) as ActualStartDate,
		convert(datetime,ActualEndDate) as ActualEndDate,BudgetAllocated,EstimatedRevenue,VendorLookupID,ParentID,
		Venue, CodePrefix, CodeNumber, IsApproved,ApprovedBy,Convert(datetime,ApprovedDate) ApprovedDate
		FROM CRM_CAMPAIGNS  WITH(NOLOCK) 	
		WHERE CAMPAIGNID= @CampaignID 
		
		SELECT CP.ProductID,P.ProductName,CP.UomID,U.UnitName,CP.UnitPrice 
		FROM CRM_CampaignProducts as CP WITH(NOLOCK)
		Left Join COM_UOM  U WITH(NOLOCK) 	on U.UomId =CP.UomID
		Left Join Inv_Product  P  WITH(NOLOCK) 	on P.ProductId=CP.ProductId
		WHERE CAMPAIGNID= @CampaignID

		--Getting CostCenterMap
		SELECT * FROM  COM_CCCCData WITH(NOLOCK) 
		WHERE NodeID=@CampaignID and CostCenterID=88
    END
	else
		select 1

		SELECT R.*,C.Name as Campaign,L.Name as [Type],R.CampgnRespLookupID as TypeID,Convert(datetime,ReceivedDate) as [Date],
		Cus.CustomerName as Customer,
		LL.Name as Channel,R.ChannelLookupID as ChannelID,A.CustomerName as Vendor,R.VendorLookupID as VendorID
		
		 FROM  CRM_CAMPAIGNRESPONSE as R WITH(NOLOCK) 	
		left join CRM_Campaigns as C WITH(NOLOCK) 	on C.CampaignID =R.CampaignID
		left join com_lookup as L WITH(NOLOCK) 	on L.NodeID = R.CampgnRespLookupID
		left join crm_customer as Cus WITH(NOLOCK) 	on Cus.CustomerID = R.CustomerID
		left join com_lookup as LL WITH(NOLOCK) 	on LL.NodeID = R.ChannelLookupID
		left join CRM_Customer as A WITH(NOLOCK) 	on A.CustomerID = R.VendorLookupID
		 WHERE R.CAMPAIGNID=@CampaignID
		 
		 
		SELECT C.Name as Campaign,A.CampaignID,A.Name,S.Status as [Status],A.StatusID,L.Name as Channel,A.ChannelLookupID,
		L2.CustomerName as Vendor, A.VendorLookupID,L3.Name as Type,A.TypeLookupID,L4.Name as Priority,A.PriorityTypeLookupID,
		A.Description,Convert(datetime,A.StartDate) as StartDate,Convert(datetime,A.EndDate)as EndDate,A.BudgetedAmount,ActualCost,
		CC.Name as Currency,A.CurrencyID
		, A.CompletionRate, A.WorkingHrs, A.CheckList,A.CloseStatus,Convert(datetime,A.CloseDate) as  CloseDate 
		,A.ClosedRemarks
		FROM CRM_CampaignActivities as A WITH(NOLOCK) 	
		left join CRM_Campaigns as C WITH(NOLOCK) 	on C.CampaignID =A.CampaignID
		left join COM_Status as S WITH(NOLOCK) 	on S.StatusID=A.StatusID
		left join com_lookup as L WITH(NOLOCK) 	on L.NodeID = A.ChannelLookupID
		LEFT JOIN CRM_Customer AS L2 WITH(NOLOCK) ON L2.CustomerID=A.VendorLookupID		
		left join com_lookup as L3 WITH(NOLOCK) 	on L3.NodeID = A.TypeLookupID
		left join com_lookup as L4 WITH(NOLOCK) 	on L4.NodeID = A.PriorityTypeLookupID
		left join com_currency as CC WITH(NOLOCK) 	on CC.CurrencyID = A.CurrencyID
		WHERE A.CampaignID=@CampaignID
		select * from com_lookup WITH(NOLOCK) 	where lookuptype=25
		select * from com_lookup WITH(NOLOCK) 	where lookuptype=27
		select * from com_lookup WITH(NOLOCK) 	where lookuptype=28
		select * from com_lookup WITH(NOLOCK) 	where lookuptype=29
		select * from com_lookup WITH(NOLOCK) 	where lookuptype=30

Select D.*,convert(datetime,D.date) d ,Product.ProductName, isnull(D.Quantity,0) Quantity, 
isnull(D.UnitPrice,0) UnitPrice,isnull(D.Value,0) Value
from CRM_CampaignDemoKit D WITH(NOLOCK) 
Left JOIN INV_Product Product WITH(NOLOCK) 	 on Product.ProductID = D.ProductID	
where campaignNodeID=@CampaignID
 
Select P.ProductName as ProductName,P.ProductCode, U.UnitName as UOM,U.UnitName
,L.*,CUR.Name CurrName
		from CRM_ProductMapping L WITH(NOLOCK) 	
		Left JOIN INV_Product P WITH(NOLOCK) 	 on P.ProductID = L.ProductID
		Left Join COM_UOM U WITH(NOLOCK) 	 on U.UOMID = L.UOMID
		Left Join COM_Currency CUR with(nolock) on CUR.CurrencyID = L.CurrencyID
		where L.CCNodeID =  @CampaignID and CostCenterID=88




Select D.*   ,CON.Email1, 
COM_Teritory.Name T,COM_DIVISION.Name D,Country.Name Co,City.Name Ci,
L.NAME AS SalutationName
from CRM_CampaignOrganization D WITH(NOLOCK) 
LEFT JOIN COM_CONTACTS CON ON CON.CONTACTID=D.ContactID
LEFT JOIN COM_LOOKUP L WITH(NOLOCK) 	ON D.SALUTATION=L.NODEID
LEFT JOIN COM_Teritory COM_Teritory WITH(NOLOCK) 	on D.Territory=COM_Teritory.NODEID
LEFT JOIN COM_DIVISION COM_DIVISION WITH(NOLOCK) 	on D.CytomedDivision=COM_DIVISION.NODEID
LEFT JOIN COM_CC50026 Country WITH(NOLOCK) 	ON D.Country=Country.NODEID
LEFT JOIN COM_CC50027 City WITH(NOLOCK) 	ON D.City=City.NODEID 
where CampaignNodeID=@CampaignID

SELECT * FROM [CRM_CampaignsExtended] WITH(NOLOCK) WHERE CAMPAIGNID=@CampaignID

SELECT [CRM_CampaignStaff].*,CON.Email1   FROM [CRM_CampaignStaff] WITH(NOLOCK)
LEFT JOIN COM_CONTACTS CON ON CON.CONTACTID=[CRM_CampaignStaff].CONTACTID
 WHERE CAMPAIGNID=@CampaignID

Select D.*,convert(datetime,D.date) d
from CRM_CampaignApprovals D WITH(NOLOCK) 	
where campaignNodeID=@CampaignID


		--Getting Notes
		SELECT     NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
		ModifiedBy, ModifiedDate, CostCenterID
		FROM         COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=88 and  FeaturePK=@CampaignID
			 
		
		--Getting Files
		SELECT * FROM  COM_Files WITH(NOLOCK) 
		WHERE FeatureID=88 and  FeaturePK=@CampaignID

		--Getting Venue details
		select * from com_lookup where lookuptype=59
		
		Select D.*,CON.Email1, convert(datetime,D.date) d 
from CRM_CampaignSpeakers D
LEFT JOIN COM_CONTACTS CON ON CON.CONTACTID=D.CONTACTID
where campaignNodeID=@CampaignID

SELECT ConvertFromCampaignID FROM CRM_Opportunities WITH(nolock) WHERE ConvertFromCampaignID=@CampaignID
SELECT ConvertFromCampaignID FROM CRM_LEADS WITH(nolock) WHERE ConvertFromCampaignID=@CampaignID

	 IF(EXISTS(SELECT * FROM CRM_Activities WHERE CostCenterID=88 AND NodeID=@CampaignID))
			EXEC spCRM_GetFeatureByActvities @CampaignID,88,'',@UserID,@LangID  
		ELSE
			SELECT 1 WHERE 1<>1
			
Select D.*   ,CON.Email1 ,COM_Teritory.Name T,COM_DIVISION.Name D,Country.Name Co,City.Name Ci,L.NAME AS SalutationName
from CRM_CampaignInvites D WITH(NOLOCK) LEFT JOIN COM_CONTACTS CON ON CON.CONTACTID=D.ContactID LEFT JOIN COM_LOOKUP L WITH(NOLOCK) 	ON D.SALUTATION=L.NODEID
LEFT JOIN COM_Teritory COM_Teritory WITH(NOLOCK) 	on D.Territory=COM_Teritory.NODEID LEFT JOIN COM_DIVISION COM_DIVISION WITH(NOLOCK) 	on D.CytomedDivision=COM_DIVISION.NODEID LEFT JOIN COM_CC50026 Country WITH(NOLOCK) 	ON D.Country=Country.NODEID
LEFT JOIN COM_CC50027 City WITH(NOLOCK) 	ON D.City=City.NODEID 
where CampaignNodeID=@CampaignID


SELECT     L.CampaignID, A.*,  A.StatusID AS ActStatus, A.Subject AS ActSubject, 
                        CONVERT(datetime, A.ActualCloseDate) AS ActualCloseDate, A.ActualCloseTime,CONVERT(datetime, A.StartDate) AS ActStartDate, 
                      CONVERT(datetime, A.EndDate) AS ActEndDate,   S.ScheduleID AS Expr10, S.Name, S.StatusID AS Expr11, S.FreqType, S.FreqInterval, 
                      S.FreqSubdayType, S.FreqSubdayInterval, S.FreqRelativeInterval, S.FreqRecurrenceFactor, CONVERT(datetime, S.StartDate) AS CStartDate, 
                      CONVERT(datetime, S.EndDate) AS CEndDate, CONVERT(datetime, S.StartTime) AS StartTime, CONVERT(datetime, S.EndTime) AS EndTime, 
                      S.Message,case when A.ActivityTypeID=1 then 'AppointmentRegular' 
					             when A.ActivityTypeID=2 then 'TaskRegular' 
							     when A.ActivityTypeID=3 then 'ApptRecurring' 
								 when A.ActivityTypeID=4 then 'TaskRecur' end as Activity ,
		A.CreatedBy as UserName
FROM         CRM_Activities AS A WITH(NOLOCK) 	LEFT OUTER JOIN
                      CRM_Campaigns AS L WITH(NOLOCK) 	ON L.campaignid = A.NodeID AND A.CostCenterID = 128 LEFT OUTER JOIN
                      COM_Schedules AS S WITH(NOLOCK) 	ON S.ScheduleID = A.ScheduleID LEFT OUTER JOIN
                      COM_CCSchedules AS CS WITH(NOLOCK) 	ON CS.ScheduleID = A.ScheduleID
                      
WHERE     (L.CampaignID =  @CampaignID)
and  ((A.Createdby in (select UserName from #tblUsers) 
	or   (@UserID in ( select UserID from CRM_Assignment where CCID=128 and CCNODEID=L.CampaignID    
	 AND IsFromActivity=A.ActivityID and IsTeam=0 ) 
	  or  @UserID in ( select  UserID from COM_GROUPS where   GROUPNAME<>'' AND GID  IN  
	  (select teamnodeid from CRM_Assignment where CCID=128 and CCNODEID=L.CampaignID  and IsFromActivity=A.ActivityID AND ISGROUP=1) ) OR  
	  @UserID in ( select  UserID from ADM_UserRoleMap where ROLEID IN  
	  (select teamnodeid from CRM_Assignment where CCID=128 and CCNODEID=L.CampaignID  and IsFromActivity=A.ActivityID and ISROLE=1) )  
	 or @UserID in            
	 (select userid from crm_teams where isowner=0 and  teamid in            
	 ( select teamnodeid from CRM_Assignment where CCID=128 and CCNODEID=L.CampaignID  and IsFromActivity=A.ActivityID and IsTeam=1)) ) )      )   
	   
	  select isnull(value,0) ccid from COM_CostCenterPreferences where CostCenterID=88 and Name='CheckListDimension'

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
