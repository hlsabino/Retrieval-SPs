﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetQuickViewDetails]
	@TypeID [int] = 1,
	@CostCenterID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON  
  
   --Declaration Section  
   DECLARE @HasAccess bit,@FEATUREID int  
  
  IF @TypeID=1
  BEGIN
		--Groups
		SELECT GID,GroupName FROM COM_Groups WITH(NOLOCK)
		Group By GID,GroupName
		HAVING GroupName IS NOT NULL
		ORDER BY GroupName
		   
		--Roles
		SELECT RoleID, Name FROM ADM_PRoles WITH(NOLOCK)
		WHERE StatusID=434
		ORDER BY Name

		--Getting All Users
		SELECT UserID,UserName FROM ADM_Users WITH(NOLOCK)
		WHERE StatusID=1
		ORDER BY UserName 
		
		--Getting Documents List
		SELECT CostCenterID,DocumentName,IsInventory FROM ADM_DocumentTypes WITH(NOLOCK)
		ORDER BY DocumentName
		
		--Getting Dimensions List
		--SELECT FEATUREID,Name FROM ADM_FEATURES WITH(NOLOCK) WHERE 
		--FEATUREID NOT IN (1) and isenabled=1  and ALLOWCUSTOMIZATION=1 --(ALLOWCUSTOMIZATION=1  OR FEATUREID BETWEEN 40000 AND 50000)
		--ORDER BY NAME
		SELECT FEATUREID,CL.RESOURCEDATA Name FROM ADM_FEATURES ADF WITH(NOLOCK),COM_LANGUAGERESOURCES CL WITH(NOLOCK) WHERE ADF.RESOURCEID=CL.RESOURCEID AND 
		CL.LanguageID=@LangID AND ADF.FEATUREID NOT IN (1) and ADF.isenabled=1  and ADF.ALLOWCUSTOMIZATION=1 --(ALLOWCUSTOMIZATION=1  OR FEATUREID BETWEEN 40000 AND 50000)
		ORDER BY NAME
	END
	ELSE IF @TypeID=2
	BEGIN
		SELECT QID,QName FROM ADM_QuickViewDefn WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID
		GROUP BY  QID,QName
	    IF(@CostCenterID>50000)
	    BEGIN
			SELECT A.COSTCENTERCOLID,A.USERCOLUMNNAME,A.SYSCOLUMNNAME
			FROM ADM_COSTCENTERDEF A WITH(NOLOCK)
			WHERE A.CostCenterID=@CostCenterID and A.IsColumnInUse=1 AND A.SYSCOLUMNNAME<>'Balance' 
			AND NOT (7=@CostCenterID AND (A.SYSCOLUMNNAME LIKE '%Password' OR A.SYSCOLUMNNAME='HistoryStatus'))
			union all
			SELECT CostCenterColID,'Address_'+UserColumnName,SysColumnName
			FROM ADM_CostCenterDef WITH(NOLOCK) 		
			WHERE  IsColumnInUse=1 and CostCenterID=110 and ColumnCostCenterID=0-- and IsColumnUserDefined=0
			UNION ALL
			SELECT A.COSTCENTERCOLID,A.USERCOLUMNNAME,A.SYSCOLUMNNAME
			FROM ADM_COSTCENTERDEF A WITH(NOLOCK)
			WHERE CostCenterID=404 AND SysColumnName IN ('ModifiedBy','ModifiedDate')
		END	
		ELSE
		BEGIN
			SELECT A.COSTCENTERCOLID,A.USERCOLUMNNAME,A.SYSCOLUMNNAME
			FROM ADM_COSTCENTERDEF A WITH(NOLOCK)
			WHERE A.CostCenterID=@CostCenterID and A.IsColumnInUse=1 AND A.SYSCOLUMNNAME<>'Balance' 
			AND NOT (7=@CostCenterID AND (A.SYSCOLUMNNAME LIKE '%Password' OR A.SYSCOLUMNNAME='HistoryStatus'))
			union all
			SELECT CostCenterColID,'Address_'+UserColumnName,SysColumnName
			FROM ADM_CostCenterDef WITH(NOLOCK) 		
			WHERE  IsColumnInUse=1 and CostCenterID=110 and ColumnCostCenterID=0-- and IsColumnUserDefined=0
			UNION ALL
			SELECT A.COSTCENTERCOLID,A.USERCOLUMNNAME,A.SYSCOLUMNNAME
			FROM ADM_COSTCENTERDEF A WITH(NOLOCK)
			WHERE CostCenterID=3 AND 2=@CostCenterID AND SysColumnName IN ('CreatedDate','ModifiedDate')
		END
	END
	ELSE IF @TypeID=3
	BEGIN
		--Views List
		SELECT * FROM ADM_QuickViewDefn WITH(NOLOCK) WHERE QID=@CostCenterID
	   
	    --Selected Fields
		SELECT Q.COSTCENTERCOLID,Q.COSTCENTERID,A.USERCOLUMNNAME,A.SYSCOLUMNNAME 
		from ADM_QuickViewDefn Q WITH(NOLOCK)   
		INNER JOIN ADM_COSTCENTERDEF A WITH(NOLOCK) ON A.COSTCENTERCOLID=Q.COSTCENTERCOLID  
		where QID=@CostCenterID AND A.IsColumnInUse=1  
		order by Q.ColumnOrder
		
		--Show In
		SELECT DISTINCT ShowCCID FROM ADM_QuickViewDefnUserMap WITH(NOLOCK) WHERE QID=@CostCenterID AND ShowCCID!=0
		
		--Roles
		SELECT UserID,RoleID,GroupID FROM ADM_QuickViewDefnUserMap WITH(NOLOCK) WHERE QID=@CostCenterID
	END	
	
	 --  SELECT  'NEW' 'LINK/DELINK',A.COSTCENTERCOLID,A.USERCOLUMNNAME,A.SYSCOLUMNNAME FROM ADM_COSTCENTERDEF A WITH(NOLOCK)  
	 --  WHERE  A.COSTCENTERCOLID NOT IN (SELECT COSTCENTERCOLID FROM ADM_QuickViewDef WHERE CostCenterID=@CostCenterID)   
	 --  AND A.CostCenterID=@CostCenterID  and A.IsColumnInUse=1
	  
		--SELECT 'EDIT' 'LINK/DELINK',Q.COSTCENTERCOLID, Q.COSTCENTERID,A.USERCOLUMNNAME,A.SYSCOLUMNNAME from ADM_QuickViewDef Q WITH(NOLOCK)   
		--LEFT JOIN ADM_COSTCENTERDEF A ON A.COSTCENTERCOLID=Q.COSTCENTERCOLID  
		--where Q.CostCenterID=@CostCenterID AND Q.UserID = @UserID AND IsUserDefined=0  and A.IsColumnInUse=1  
		--order by Q.ColumnOrder
   
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
