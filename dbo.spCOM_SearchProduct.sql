USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SearchProduct]
	@ColName [nvarchar](100),
	@Value [nvarchar](max),
	@ProductIDs [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
        
BEGIN TRY        
SET NOCOUNT ON;      
	declare @CCID bigint,@table nvarchar(100),@sql nvarchar(max),@prKey nvarchar(50),@NodeID bigint,@temp nvarchar(max)
	declare @NameCOl nvarchar(50)
	 
	
	select @CCID=ColumnCostCenterID from ADM_CostCenterDef where SysColumnName=@ColName and CostCenterID=3
	if(@CCID is not null and @CCID>0)
	begin
		if(@CCID=2)
		begin
			set @prKey='AccountID'
			set @NameCOl='AccountName'
		end
		else if(@CCID=11)
		begin
			set @prKey='UOMID'
			set @NameCOl='UnitName'
		end
		else if(@CCID>50000)
		begin
			set @prKey='NodeID'
			set @NameCOl='Name'
		end
			 
		select  @table=TableName from ADM_Features where FeatureID=@CCID
		
		set @sql='select @NodeID='+@prKey+' from '+@table +' where '+@NameCOl+@Value
		set @temp=' @NodeID bigint OUTPUT'
		exec sp_executesql @sql,@temp,@NodeID output
		set @Value='='+convert(nvarchar,@NodeID)
		
	end 
	
	
	set @sql='select a.productid from INV_Product a with(nolock)
	join INV_ProductExtended E with(nolock) on E.ProductID=a.ProductID
	join COM_CCCCData C with(nolock) on C.NodeID=a.ProductID  AND C.CostCenterID = 3 
	where '+@ColName+@Value
    exec(@sql)
 
       
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
