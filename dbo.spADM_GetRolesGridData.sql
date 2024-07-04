USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetRolesGridData]
	@RoleID [int] = 0,
	@UserID [int],
	@LoginRoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
            
BEGIN TRY            
SET NOCOUNT ON;           
	--Declaration Section          
	DECLARE @HasAccess BIT

	--User access check           
	SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,6,2)          

	IF @HasAccess=0          
	BEGIN          
		RAISERROR('-105',16,1)          
	END
  
	declare @JLen INT 
	select @JLen=len(Value) from com_costcenterpreferences WITH(NOLOCK) where CostCenterID=76 and name='JobDimension' 

	--Get Role Information.          
	IF (@RoleID =  0 )        
	BEGIN        
		SELECT Name,Description,GUID,STATUSID,ExtraXML,RoleType FROM ADM_PRoles WITH(NOLOCK)        
		WHERE STATUSID = 1 AND IsRoleDeleted = 0         
		--SET @RoleID = 1      
	END        
	ELSE        
	BEGIN        
		SELECT Name,Description,GUID,STATUSID,ExtraXML,RoleType FROM ADM_PRoles WITH(NOLOCK)        
		WHERE  ROLEID = @RoleID AND IsRoleDeleted = 0          
	END     
 
	select DISTINCT(FA.FeatureActionID) FeatureActionID,TabID,T.ResourceData TabName, GroupID,
	G.ResourceData GroupName, 
	case when(R.screenname is null or R.screenname='') then A.Name else R.screenname END DrpName, 
	R.FeatureID, FA.Name  Feature,  (R.RIBBONVIEWID),
	case when EXISTS (SELECT FeatureActionID FROM ADM_FeatureActionRoleMap WITH(NOLOCK) WHERE RoleID=@LoginRoleID and FeatureActionID=FA.FeatureActionID) then 1  else 0 end isEdit
	from ADM_RibbonView R WITH(NOLOCK)
	JOIN ADM_FEATURES A WITH(NOLOCK) ON R.FEATUREID=A.FEATUREID
	join adm_featureaction  FA WITH(NOLOCK) on A.FeatureID=FA.FeatureID  
	LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=R.TabResourceID AND T.LanguageID=1          
	LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=R.GroupResourceID AND G.LanguageID=1          
	LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=R.DrpResourceID AND D.LanguageID=1          
	WHERE   FA.FEATUREID<>50 
	--FeatureActionID (R.RibbonViewID NOT IN (29,30,50004,77,80,81,82,108,109,1010,157,158,187,202,203,523,612,674,1009,616,552,553,554,214,227,228,229,230,1012,236,992,993,1004) 
	AND (R.FeatureActionID NOT IN (1695,770,35,85,1744,771,1888,3737,460,461,6464,1745,773,1619,2081,2082,3459,3458,4812,2068,1972,2001,2593,2064,1991,3452,608,609,3738,563,564,2873)
	--AND (R.FeatureActionID NOT IN (1695,770,35,85,1744,771,1888,3737,460,461,6464,1745,773,1619,2081,2082,3459,3458,4812,2068,1972,2001,2593,2064,1991,3452,608,609,3738,563,564,3754,2873)
	and R.RibbonViewID NOT IN (select ribbonviewid from ADM_RibbonView with(nolock) where TabID=9 and groupid=50 and featureactionname='Document Resave')) 
	and R.RibbonViewID NOT IN ( select ribbonviewid from adm_ribbonview WITH(NOLOCK) where tabid=4 and GroupID=32 and DrpName='Jobs' and @JLen=0 ) 
	and FA.FEATUREACTIONID <> (6604)
	and (@UserID=1 or FA.FeatureActionID IN (SELECT FeatureActionID FROM ADM_FeatureActionRoleMap WITH(NOLOCK) WHERE RoleID=@LoginRoleID OR RoleID=@RoleID))
	GROUP BY TABID, TABNAME, GROUPID, GroupName, R.RIBBONVIEWID , R.FeatureID,FA.FeatureActionID, 
	FA.Name, T.ResourceData,G.ResourceData ,A.Name ,R.screenname
	union all
	select DISTINCT(FA.FeatureActionID) ,tabid,T.ResourceData tabname, groupid,
	G.ResourceData groupname, 
	A.Name, 
	R.FeatureID,  FA.Name,  (R.RibbonViewID) ,1 
	from ADM_RibbonView R WITH(NOLOCK)
	LEFT JOIN ADM_FEATURES A WITH(NOLOCK) ON R.FEATUREID=A.FEATUREID 
	left join adm_featureaction FA WITH(NOLOCK) on A.FeatureID=FA.FeatureID  AND FA.FEATUREACTIONID=R.FEATUREACTIONID
	LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=R.TabResourceID AND T.LanguageID=1          
	LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=R.GroupResourceID AND G.LanguageID=1          
	LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=R.DrpResourceID AND D.LanguageID=1          
	WHERE   FA.FEATUREID= 50  
	GROUP BY TABID, TABNAME, GROUPID, GroupName, R.RIBBONVIEWID , R.FeatureID,FA.FeatureActionID, 
	FA.Name, T.ResourceData,G.ResourceData ,A.Name  
	union all
	SELECT distinct A.FeatureActionID,16 TabID,'Company' ,300,'Company',ADM_Features.name,a.FeatureID, a.Name, 4000 ,1     
	FROM ADM_FeatureAction A WITH(NOLOCK)             
	LEFT JOIN ADM_FeatureActionRoleMap AR WITH(NOLOCK) ON AR.FeatureActionRoleMapID=A.FeatureActionID            
	LEFT JOIN ADM_PRoles R WITH(NOLOCK) ON R.RoleID=AR.RoleID            
	LEFT JOIN ADM_Features WITH(NOLOCK) ON ADM_Features.FEATUREID=A.FEATUREID         
	where a.featureid in (4 ,157) and FeatureActionTypeID<>30 
	ORDER BY R.TabID, R.GroupID,R.RIBBONVIEWID,R.FeatureID,   FA.FEATUREACTIONID --,DrpName,Feature
 
-- --REPORTS
--select DISTINCT(FA.FeatureActionID) ,tabid,T.ResourceData tabname, groupid,
--G.ResourceData groupname, 
--A.Name, 
--R.FeatureID,  FA.Name,  (R.RIBBONVIEWID)
--from ADM_RibbonView R
--LEFT JOIN ADM_FEATURES A ON R.FEATUREID=A.FEATUREID 
--left join adm_featureaction  FA on A.FeatureID=FA.FeatureID  AND FA.FEATUREACTIONID=R.FEATUREACTIONID
--LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=R.TabResourceID AND T.LanguageID=1          
--LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=R.GroupResourceID AND G.LanguageID=1          
--LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=R.DrpResourceID AND D.LanguageID=1          
--WHERE   FA.FEATUREID= 50   AND R.TABID IN (2,3)
--GROUP BY TABID, TABNAME, GROUPID, GroupName, R.RIBBONVIEWID , R.FeatureID,FA.FeatureActionID, 
-- FA.Name, T.ResourceData,G.ResourceData ,A.Name 
--ORDER BY R.TabID, R.GroupID,FA.FEATUREACTIONID,R.RIBBONVIEWID,R.FeatureID    

	select CostCenterID,DocumentType from adm_documenttypes with(nolock)
           
  SELECT [Name],[Value]            
  FROM ADM_GlobalPreferences WITH(NOLOCK)          
      
  -- Getting FeatureActionID For a Particular Role      
  SELECT FeatureActionID,Description,Status FROM dbo.ADM_FeatureActionRoleMap WITH(NOLOCK)
  WHERE RoleID = @RoleID     
  
-- Getting Location Mapped with Role  
  SELECT * FROM  COM_CostCenterCostCenterMap   WITH(NOLOCK)
  WHERE PARENTCOSTCENTERID = 6 AND COSTCENTERID = 50002 AND ParentNodeID = @RoleID   

-- Getting Location - Divisions Mapped with Role
SELECT CCMAP.ParentNodeId,CCMAP.CostCenterId,ADM_Features.NAME AS CostCenterName,CCMAP.NodeID 
 ,CASE WHEN COSTCENTERID = 50001 THEN COM_DIVISION.NAME ELSE COM_LOCATION.NAME END AS Value
FROM  COM_CostCenterCostCenterMap  CCMAP WITH(NOLOCK)
LEFT JOIN ADM_Features WITH(NOLOCK) ON CCMAP.COSTCENTERID = ADM_Features.FEATUREID 
LEFT JOIN COM_LOCATION WITH(NOLOCK) ON CCMAP.NODEID = COM_LOCATION.NODEID
LEFT JOIN COM_DIVISION WITH(NOLOCK) ON CCMAP.NODEID = COM_DIVISION.NODEID
WHERE CCMAP.PARENTCOSTCENTERID = 6   AND CCMAP.ParentNodeID = @RoleID  
  
-- Getting Types of Accounts & Products
select AccountType as Type, AccountTypeID as FeatureTypeID, 2 as FeatureID 
from acc_accounttypes WITH(NOLOCK)
union
select ProductType as Type, ProductTypeID as FeatureTypeID, 3 as FeatureID from INV_ProductTypes WITH(NOLOCK)

--select @RoleID
select FeatureID,FeatureTypeID from ADM_FeatureTypeValues WITH(NOLOCK) where roleid=@RoleID
          
SET NOCOUNT OFF;             
RETURN 1          
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
SET NOCOUNT OFF            
RETURN -999             
END CATCH
GO
