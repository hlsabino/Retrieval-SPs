USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCostCenterSelectionBoxData]
	@CostCenterID [int],
	@ColumnName [nvarchar](500),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY    
SET NOCOUNT ON    
    
   --Declaration Section    
   Declare @Table nvarchar(max),@SQL nvarchar(max)
      
   --Check for manadatory paramters    
   if(@CostCenterID=0)    
   BEGIN    
     RAISERROR('-100',16,1)    
   END    
    
     
   --Getting TableName of CostCenter    
   SET @Table=(SELECT  TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID)    
   
  if(@CostCenterID=2)
      set  @SQL='select distinct '+ @ColumnName+' from ACC_AccountsExtended  WITH(NOLOCK) '       
  else if(@CostCenterID=3)
	 set  @SQL='select distinct '+ @ColumnName+' from  INV_ProductExtended WITH(NOLOCK) ' 
	else if(@CostCenterID in(103,129))
	 set  @SQL='select distinct '+ @ColumnName+' from  REN_QuotationExtended WITH(NOLOCK) ' 
	  else if(@CostCenterID in(95,104))
	 set  @SQL='select distinct '+ @ColumnName+' from  REN_ContractExtended WITH(NOLOCK) ' 	 
  else if(@CostCenterID>40000 and @CostCenterID<50000)
  begin
	if(@ColumnName like 'dcAlpha%')
	BEGIN
		set  @SQL='select distinct d.'+ @ColumnName+' from  COM_DocTextData d WITH(NOLOCK) '       
		if exists(select IsInventory from ADM_DocumentTypes WITH(NOLOCK) where CostCenterID=@CostCenterID and IsInventory=1)
		  set  @SQL=@SQL+' join INV_DocDetails i WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID
			 where i.CostCenterID='+CONVERT(nvarchar,@CostCenterID)
		else
			set  @SQL=@SQL+' join ACC_DocDetails a WITH(NOLOCK) on a.AccDocDetailsID=d.AccDocDetailsID
			 where a.CostCenterID='+CONVERT(nvarchar,@CostCenterID)
	END
	ELSE
	BEGIN
			set  @SQL='select distinct '+ @ColumnName+' from  '       
		if exists(select IsInventory from ADM_DocumentTypes WITH(NOLOCK) where CostCenterID=@CostCenterID and IsInventory=1)
		  set  @SQL=@SQL+'  INV_DocDetails WITH(NOLOCK) where CostCenterID='+CONVERT(nvarchar,@CostCenterID)
		else
			set  @SQL=@SQL+'  ACC_DocDetails WITH(NOLOCK) where CostCenterID='+CONVERT(nvarchar,@CostCenterID)

	END	 
  end	 
  else if(@CostCenterID>50000)
	set  @SQL='select distinct '+ @ColumnName+' from '+@Table +'  WITH(NOLOCK) '    
 
   Exec(@SQL)    
    
   
     
    
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
