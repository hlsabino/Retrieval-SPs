USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetFeaturesList]
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  
   
   
	DECLARE @SQL NVARCHAR(MAX),@HasAccess BIT

	SET @SQL='SELECT FeatureID, Name, 0 SortOrd   FROM ADM_Features F with(nolock)
	WHERE (FeatureID IN (2,3,7,11,16,40,45,51,55,56,61,65,70,72,73,74,75,76,77,80,83,86,92,93,94,95,99,101,114,151,153,251,252,253,254,255) or FeatureID between  40000 and 50000 or (IsEnabled=1  and FeatureID>50000))
	and ( FeatureID=70 or '+CONVERT(NVARCHAR,@RoleID)+'=1 or '+CONVERT(NVARCHAR,@UserID)+'=1 or FeatureID IN( select FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
			inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
			where FAR.RoleID='+CONVERT(NVARCHAR,@RoleID)+' and (FA.FeatureActionTypeID=2 or FA.FeatureActionTypeID=3) 
			))'
	print (@SQL)
	IF (dbo.fnCOM_HasAccess(@RoleID,2,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,2,3)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 2,''Account Dimension wise Cr/Dr Limits''  , 0 SortOrd 
		UNION  
		SELECT 2,''Account Report Template'', 0 SortOrd '
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,2,16)=1 OR dbo.fnCOM_HasAccess(@RoleID,2,18)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 2,''Account Contacts''  , 0 SortOrd '
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,2,32)=1 OR dbo.fnCOM_HasAccess(@RoleID,2,34)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 2,''Account Address''  , 0 SortOrd '
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,3,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,3,3)=1)
	BEGIN 
		SET @SQL=@SQL+' UNION  
		SELECT 3,''Product With Vehicle''  , 0 SortOrd 
		UNION  
		SELECT 3,''Product With Services(One-One)''  , 0 SortOrd 
		UNION  
		SELECT 3,''Product With Services(Many-One)''  , 0 SortOrd 
		UNION  
		SELECT 3,''Services to Dimension''  , 0 SortOrd 
		UNION
		SELECT 3,''Substitute Products''  , 0 SortOrd 
		UNION 
		SELECT 3,''Products With Multiple UOM''  , 0 SortOrd 
		UNION 
		SELECT 3,''Products With Multiple UOM Barcode'', 0 SortOrd 
		UNION 
		SELECT 3,''Products With Vendor Multiple Barcode''  , 0 SortOrd 
		UNION 
		SELECT 3,''Products Wise Bins'' , 0 SortOrd 
		UNION 
		SELECT 3,''Products With Substitutes'' , 0 SortOrd 
		UNION 
		SELECT 3,''Kit Products'', 0 SortOrd
		UNION 
		SELECT 3,''Product QC'' , 0 SortOrd'   
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,40,1)=1 OR dbo.fnCOM_HasAccess(@RoleID,40,3)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 40,''Dimension Wise Price Chart'', 0 SortOrd'
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,51,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,51,3)=1)
	BEGIN
		SET @SQL=@SQL+' union   
		SELECT 51,''Customer With Vehicle'', 0 SortOrd'   
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,76,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,76,3)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 76,''Bill Of Materials With Multiple Stage''  , 0 SortOrd'
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,83,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,83,3)=1)
	BEGIN  
		SET @SQL=@SQL+' UNION
		SELECT 83,''CRM Customer With Address'' , 0 SortOrd   
		UNION 
		SELECT 83,''CRM Customer With Contacts'', 0 SortOrd '   
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,92,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,92,3)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 92,''Property Particulars''  , 0 SortOrd'
	END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,93,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,93,3)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 93,''Unit Particulars''  , 0 SortOrd'
		IF (dbo.fnCOM_HasAccess(@RoleID,93,8)=1 OR dbo.fnCOM_HasAccess(@RoleID,93,10)=1)
		BEGIN
			SET @SQL=@SQL+' UNION  
			SELECT 93,''Unit Rates''  , 0 SortOrd'
		END
	END
	
	IF ((dbo.fnCOM_HasAccess(@RoleID,92,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,92,3)=1) AND (dbo.fnCOM_HasAccess(@RoleID,93,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,93,3)=1))
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 92,''Particulars Import''  , 0 SortOrd'
	END
	
	--IF (dbo.fnCOM_HasAccess(@RoleID,115,2)=1 OR dbo.fnCOM_HasAccess(@RoleID,115,3)=1)
	--BEGIN
		SET @SQL=@SQL+' UNION 
		SELECT 115,''Leads With Products'', 0 SortOrd '  
	--END
	
	IF (dbo.fnCOM_HasAccess(@RoleID,151,1)=1 OR dbo.fnCOM_HasAccess(@RoleID,151,3)=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 151,''Schemes & Discounts BasedOn Unique Dimension'', 0 SortOrd '  
	END
	
	IF EXISTS (SELECT FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
		inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
		where FA.name='Move'and FAR.RoleID=@RoleID)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 8,''Dimension Move''  , 0 SortOrd'
	END
	
	IF EXISTS (SELECT FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
	inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
	where FA.FeatureID between  40000 and 50000 AND FA.name='Edit'and FAR.RoleID=1)
	BEGIN
		SET @SQL=@SQL+' UNION  
		SELECT 400,''Document Edit''  , 0 SortOrd'
	END
	
	SET @SQL=@SQL+' UNION  
	SELECT 110,''Payroll Employee_Address''  , 0 SortOrd'
	
	SET @SQL=@SQL+' UNION  
	SELECT 50051,''Payroll Employee_Appraisal''  , 0 SortOrd'
	
	SET @SQL=@SQL+' UNION  
		SELECT 2,''Account Contacts''  , 0 SortOrd '
		
	DECLARE @JobDimension BIGINT
	SELECT @JobDimension=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=76 AND Name='JobDimension'
	SET @SQL=@SQL+' UNION  
		SELECT '+CONVERT(NVARCHAR,@JobDimension)+',''Job Output''  , 0 SortOrd ' 
			
	SET @SQL=@SQL+' UNION
	select 44, l.LookupName+'' (Lookup)'' as Name, 1 SortOrd  from com_lookuptypes L with(nolock)
	inner join adm_featureaction FA with(nolock) on FA.FeatureActionTypeID=(NodeID*5)+100
	inner join adm_featureactionrolemap FAR with(nolock) on FA.FeatureActionID=FAR.FeatureActionID
	where FA.FeatureID=44 and FAR.RoleID='+CONVERT(NVARCHAR,@RoleID)+'
	order by SortOrd,Name'
	--print(@SQL)
	EXEC(@SQL)
	
	select Value as CostCenterID from com_Costcenterpreferences with(nolock) where costcenterid=3 and name='LinkedProductDimension'  

	SELECT FeatureID,Name  FROM ADM_Features with(nolock)
	WHERE IsEnabled=1 
      
     
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
