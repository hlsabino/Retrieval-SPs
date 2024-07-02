USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_CopyParentData]
	@FromID [bigint],
	@ToIDs [nvarchar](max),
	@ccid [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
	
		declare @cols nvarchar(max),@sql nvarchar(Max),@table nvarchar(200),@primcol nvarchar(50)
		
		if(@ccid=92)
		BEGIN
			set @table='REN_Property'
			set @primcol='NodeID'
		END	
		else if(@ccid=93)
		BEGIN
			set @table='REN_Units'
			set @primcol='UnitID'
		END	
		
		set @cols=''
		
		select @cols=@cols+','+syscolumnname+'=a.'+syscolumnname FROM  adm_costcenterdef a WITH(NOLOCK)
		join sys.columns s on a.syscolumnname=s.name 
		left join COM_DocumentBatchLinkDetails b WITH(NOLOCK) on  a.CostCenterColID=b.CostCenterColIDBase
		and  b.[CostCenterID]=@ccid and b.batchColid=0 and b.LinkDimCCID=@ccid 
		where s.object_id=object_id(@table) and a.[CostCenterID]=@ccid and syscolumnname not in('Code','Name','IsGroup','Group','StatusID','CreatedBy','ModifiedBy','ParentID')
		and b.CostCenterColIDBase is null and(iscolumnuserdefined=0 or  iscolumninuse=1)
		and systablename=@table
		
		set @cols=substring(@cols,2,len(@cols))
		
		set @sql='update b
			set '+@cols+'
			from '+@table+' a,'+@table+' b
			where a.'+@primcol+'='+convert(nvarchar(max),@FromID)+' and b.'+@primcol+' in('+@ToIDs+')'
			print @sql
			exec(@sql)
			
			
			
			
		if(@ccid=92)		
			set @table='REN_PropertyExtended'
		else if(@ccid=93)
			set @table='REN_UnitsExtended'
		
		set @cols=''
		
		select @cols=@cols+','+syscolumnname+'=a.'+syscolumnname FROM  adm_costcenterdef a WITH(NOLOCK)
		join sys.columns s on a.syscolumnname=s.name 
		left join COM_DocumentBatchLinkDetails b WITH(NOLOCK) on  a.CostCenterColID=b.CostCenterColIDBase
		and  b.[CostCenterID]=@ccid and b.batchColid=0 and b.LinkDimCCID=@ccid 
		where s.object_id=object_id(@table) and a.[CostCenterID]=@ccid and syscolumnname not in('Code','Name','IsGroup','Group','StatusID','CreatedBy','ModifiedBy','ParentID')
		and b.CostCenterColIDBase is null and(iscolumnuserdefined=0 or  iscolumninuse=1)
		and systablename=@table
		
		set @cols=substring(@cols,2,len(@cols))
		
		set @sql='update b
			set '+@cols+'
			from '+@table+' a,'+@table+' b
			where a.'+@primcol+'='+convert(nvarchar(max),@FromID)+' and b.'+@primcol+' in('+@ToIDs+')'
			print @sql
			exec(@sql)	
			
			
		set @table='COM_CCCCData'
		
		set @cols=''
		
		select @cols=@cols+','+syscolumnname+'=a.'+syscolumnname FROM  adm_costcenterdef a WITH(NOLOCK)
		join sys.columns s on a.syscolumnname=s.name 
		left join COM_DocumentBatchLinkDetails b WITH(NOLOCK) on  a.CostCenterColID=b.CostCenterColIDBase
		and  b.[CostCenterID]=@ccid and b.batchColid=0 and b.LinkDimCCID=@ccid 
		where s.object_id=object_id(@table) and a.[CostCenterID]=@ccid and syscolumnname not in('Code','Name','IsGroup','Group','StatusID','CreatedBy','ModifiedBy','ParentID')
		and b.CostCenterColIDBase is null and(iscolumnuserdefined=0 or  iscolumninuse=1)
		and systablename=@table
		
		set @cols=substring(@cols,2,len(@cols))
		
		set @sql='update b
			set '+@cols+'
			from '+@table+' a,'+@table+' b
			where a.CostCenterID='+convert(nvarchar(max),@ccid)+' and b.CostCenterID='+convert(nvarchar(max),@ccid)+' and  a.NodeID='+convert(nvarchar(max),@FromID)+' and b.NodeID in('+@ToIDs+')'
			print @sql
			exec(@sql)		
		
		set @table=''	
		select @table=value from com_costcenterpreferences
		where name='CopyGroupTabs' and costcenterid=@ccid
		declare @tabid bigint
		select @tabid= CCTabID from adm_costcentertab
		where costcenterid=@ccid and CCTabName='Particulars'
		declare @tabids table(TabID int)  
		insert into @tabids  
		exec SPSplitString @table,';'  
		if exists(select * from @tabids where TabID= @tabid)
		BEGIN
			set @cols=''
			select @cols=@cols+','+name FROM  sys.columns s 
			where s.object_id=object_id('ren_particulars') and name not in('PropertyID','UnitID')
			if(@ccid=93)
			BEGIN
				set @sql=' delete from ren_particulars
				where UnitID in('+@ToIDs+')
				insert into ren_particulars(UnitID,PropertyID'+@cols
				
				set @cols=''
				select @cols=@cols+',a.'+name FROM  sys.columns s 
				where s.object_id=object_id('ren_particulars') and name not in('PropertyID','UnitID')

				set @sql=@sql+')
				select b.UnitID,b.PropertyID'+@cols+' from ren_particulars a,REN_Units b 
				where a.UnitID='+convert(nvarchar(max),@FromID)+' and b.UnitID in('+@ToIDs+')'			
			END
			ELSE if(@ccid=92)
			BEGIN
				set @sql=' delete from ren_particulars
				where UnitID=0  and  PropertyID in('+@ToIDs+')
				insert into ren_particulars(UnitID,PropertyID'+@cols
				
				set @cols=''
				select @cols=@cols+',a.'+name FROM  sys.columns s 
				where s.object_id=object_id('ren_particulars') and name not in('PropertyID','UnitID')

				set @sql=@sql+')
				select 0,b.NodeID'+@cols+' from ren_particulars a,REN_Property b 
				where a.UnitID=0  and a.PropertyID='+convert(nvarchar(max),@FromID)+' and b.NodeID in('+@ToIDs+')'			

			END	
			exec(@sql)
		END
		
	
COMMIT TRANSACTION
SET NOCOUNT OFF;    
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=100 AND LanguageID=@LangID  
return 1
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
 
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=2627  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-116 AND LanguageID=@LangID  
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
