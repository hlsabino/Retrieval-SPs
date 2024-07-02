USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetResources]
	@CCID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY            
SET NOCOUNT ON;          
     
  Declare @tab table([ResourceID] INT,[ResourceName] nvarchar(300),ResourceData nvarchar(500),LanguageID int)  
    
  if(@CCID=26)  
  begin  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_GridView g With(NOLOCK) on a.ResourceID=g.ResourceID  
  end  
  ELSE if(@CCID=117)  
  BEGIN  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   whEre FEATURE='dashboard'  
  END 
  ELSE if(@CCID=69)  
  BEGIN  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   whEre FEATURE='Favorites'  
  END   
  else if(@CCID=40095)  
  begin  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_CostCenterDef c With(NOLOCK) on a.ResourceID=c.ResourceID  
   where c.CostCenterID=@CCID and (IsColumnUserDefined=0 or IsColumnInUse=1)   
   union all  
    SELECT [ResourceID],[ResourceName],ResourceData,LanguageID FROM COM_LanguageResources WITH(NOLOCK)  
    WHERE FEATURE='FFS_Static'  
  end  
  else if(@CCID=40054)  
  begin  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_CostCenterDef c With(NOLOCK) on a.ResourceID=c.ResourceID  
   where c.CostCenterID=@CCID and (IsColumnUserDefined=0 or IsColumnInUse=1)   
   union all  
    SELECT [ResourceID],[ResourceName],ResourceData,LanguageID FROM COM_LanguageResources WITH(NOLOCK)  
    WHERE FEATURE='MonthlyPayroll_Static'  
  end  
  else  
  begin     
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_CostCenterDef c With(NOLOCK) on a.ResourceID=c.ResourceID  
   where c.CostCenterID=@CCID and (IsColumnUserDefined=0 or IsColumnInUse=1)    
   union all  
   select a.[ResourceID],[ResourceName]+'_Tab',ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_CostCenterTab c With(NOLOCK) on a.ResourceID=c.ResourceID  
   where c.CostCenterID=@CCID  
  end  
    
  insert into @tab  
  select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
  join COM_CostCenterPreferences c With(NOLOCK) on a.ResourceID=c.ResourceID  
  where c.CostCenterID=@CCID  
  insert into @tab  
  select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
  join COM_documentPreferences c With(NOLOCK) on a.ResourceID=c.ResourceID  
  where c.CostCenterID=@CCID  
  insert into @tab  
  select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
  join COM_Status c With(NOLOCK) on a.ResourceID=c.ResourceID  
  where c.CostCenterID=@CCID  
    
  if(@CCID=2)  
  BEGIN  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ACC_AccountTypes c With(NOLOCK) on a.ResourceID=c.ResourceID     
  END  
  ELSE if(@CCID=3)  
  BEGIN  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join INV_ProductTypes c With(NOLOCK) on a.ResourceID=c.ResourceID     
  END  
    
  ELSE if(@CCID=9)  
  BEGIN  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.DisplayNameResourceID  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.DrpResourceID  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.FeatureActionResourceID  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.GroupResourceID  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.ScreenResourceID  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.TabResourceID  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.ToolTipDescResourceID     
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_RibbonView c With(NOLOCK) on a.ResourceID=c.ToolTipTitleResourceID  
  END  
  ELSE if(@CCID=10)  
  BEGIN  
   insert into @tab  
   select a.[ResourceID],[ResourceName],ResourceData,LanguageID from [COM_LanguageResources] a With(NOLOCK)   
   join ADM_GlobalPreferences c With(NOLOCK) on a.ResourceID=c.ResourceID     
  END  
    
  select * from @tab  
    
  if(@CCID=1)  
  BEGIN  
   select F.FeatureID,case when F.ResourceID IS null then 0 else F.ResourceID end ResourceID,Name [ResourceName],R.ResourceData,R.LanguageID   
   from ADM_Features F With(NOLOCK)  
   left join COM_LanguageResources R With(NOLOCK) on F.ResourceID=R.ResourceID  
   where F.IsEnabled=1  
   or (F.FeatureID>40000 or F.FeatureID<50000)    
   order by name  
  END   
     
     
    
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
--SELECT * FROM ADM_FEATURES WHERE FEATUREID=40034  
GO
