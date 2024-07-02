USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SortCostcenter]
	@CCNodeID [int],
	@CostcenterID [int],
	@ColumnName [nvarchar](200),
	@sOrder [nvarchar](10) = 'ASC',
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  
	--Declaration Section  
	declare @i INT,@cnt INT,@lft INT,@diff INT,@nodeid INT,@isgrp bit  
	declare @tab table(id INT identity(1,1),NodeID INT,ColumnData nvarchar(max),lft INT,rgt INT,isgrp bit)  
	declare @PrimKey nvarchar(200),@TableName nvarchar(200),@sql nvarchar(max)  

	set @PrimKey='NodeID'  
	if(@CostcenterID=2)  
		set @PrimKey='AccountID'  
	else if(@CostcenterID=3)  
		set @PrimKey='ProductID'  
	else if(@CostcenterID=94)  
		set @PrimKey='TenantID' 
	else if(@CostcenterID=93)  
		set @PrimKey='UnitID' 
	else if(@CostcenterID=83)  
		set @PrimKey='CustomerID' 
	else if(@CostcenterID=65)  
		set @PrimKey='ContactID' 
	else if(@CostcenterID=86)  
		set @PrimKey='leadID'
	else if(@CostcenterID=89)  
		set @PrimKey='opportunityID' 
	else if(@CostcenterID=88)  
		set @PrimKey='CampaignID' 
	else if(@CostcenterID=73)  
		set @PrimKey='CaseID' 
	else if(@CostcenterID=76)  
		set @PrimKey='BOMID' 
	else if(@CostcenterID=16)
		set @PrimKey='BatchID' 
	else if(@CostcenterID=200)
		set @PrimKey='ReportID' 
	else if(@CostcenterID=72)
		set @PrimKey='AssetID' 
	else if(@CostcenterID=117)
		set @PrimKey='DashBoardID' 

	select @TableName=tablename from adm_features with(nolock) where featureid=@CostcenterID  
	if(@CostcenterID=16 and @ColumnName like 'Product%')  
		set @sql='select b.'+@PrimKey+',p.'+@ColumnName+',b.lft,b.rgt,b.isgroup from INV_Batches  b with(nolock)
		left join INV_Product p with(nolock) on b.ProductID=p.ProductID
		where b.ParentID='+convert(nvarchar,@CCNodeID)+'  
		order by p.'+@ColumnName + ' '+@sOrder
	else 
		set @sql='select DISTINCT '+@PrimKey+','+@ColumnName+',lft,rgt,isgroup from '+@TableName+' with(nolock) 
		where ParentID='+convert(nvarchar,@CCNodeID)+' and '+@PrimKey+'>0
		order by '+@ColumnName+ ' '+@sOrder
	
  
	print @sql
 
	insert into @tab  
	exec(@sql)  

	set @sql='select @lft=lft from '+@TableName+'  with(nolock)
	where '+@PrimKey+'='+convert(nvarchar,@CCNodeID)  

	exec sp_executesql @sql,N'@lft INT output',@lft output  

	select @i=0,@cnt=count(id) from @tab  
      
	while(@i<@cnt)  
	begin  
		set @i=@i+1  
		select @nodeid=nodeid,@diff=rgt-lft,@isgrp=isgrp from @tab  
		where id=@i  

		set @lft=@lft+1  

		set @sql='update '+@TableName+'  
		set lft='+convert(nvarchar,@lft)+',rgt='+convert(nvarchar,@lft+@diff)+'  
		where '+@PrimKey+'='+convert(nvarchar,@nodeid)  
		print (@sql)
		exec(@sql)  

		set @lft=@lft+@diff  

		if(@isgrp=1)  
			exec [spCOM_SortCostcenter] @nodeid,@CostcenterID,@ColumnName,@sOrder,@UserID,@LangID  
	end  
     
    
    
COMMIT TRANSACTION  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;     
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END  
	ELSE  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
	END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
