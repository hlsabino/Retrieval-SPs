USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetDocumentsList]
	@UserID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY          
SET NOCOUNT ON;        

		declare @name nvarchar(500)
           
     
 --Getting all Documents        
 SELECT D.DocumentTypeID,D.IsUserDefined,case when Isinventory=1 then 'True' else 'False' end Isinventory,D.CostCenterID,D.DocumentType,D.DocumentAbbr,D.DocumentName,
 D.IsUserDefined,L.ResourceData    ,D.ConvertAs ConvertAs , D.Bounce Bounce     
 ,ISNULL(M.FeatureActionRoleMapID,0) [HasAccess]
 FROM ADM_DocumentTypes D WITH(NOLOCK)        
 INNER JOIN ADM_RibbonView R WITH(NOLOCK) ON R.FeatureID=D.CostCenterID        
 LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID         
 inner JOIN ADM_FeatureActionRoleMap M WITH(NOLOCK) ON M.FeatureActionID=R.FeatureActionID AND M.RoleID=@RoleID  
 union all
 select 95,0,'False',95,95,'','Sales Contract',0,'Sales Contract',0,0,1
 ORDER BY D.DocumentName,D.DocumentType,D.IsUserDefined Asc   
 
			declare @value nvarchar(50),@cc int,@colid bigint
			declare @tab table(ccid bigint,name nvarchar(500))
			if (exists(select name from adm_globalpreferences
			where name='EnableLocationWise' and value='True') and exists(select name from adm_globalpreferences
			where name='Location AverageRate' and value='True') )
			begin
				select @name=name from ADM_Features WITH(NOLOCK) where FeatureID=50002
				insert into @tab
				values(50002,@name)
				
			end
			if (exists(select name from adm_globalpreferences
			where name='EnableDivisionWise' and value='True') and exists(select name from adm_globalpreferences
			where name='Division AverageRate' and value='True') )
			begin
				select @name=name from ADM_Features WITH(NOLOCK) where FeatureID=50001
				insert into @tab
				values(50001,@name)
				
			end

			select @value=value from adm_globalpreferences WITH(NOLOCK)
			where name='Maintain Dimensionwise AverageRate' 

			if(@value is not null and @value<>'')
			begin
				set @cc=CONVERT(int,@value) 
				 
				select @name=name from ADM_Features WITH(NOLOCK) where FeatureID=@cc
				insert into @tab
				values(@cc,@name)
				 
			end        
			
			select * from @tab
     
		select CurrencyID,Name from COM_Currency With(nolock)
		
		select CostCenterIDBase, CostCenterIDLinked,SelectionType,GridViewID 
		from Com_CopyDocumentDetails WITH(NOLOCK) 
		group by CostCenterIDBase, CostCenterIDLinked,SelectionType,GridViewID
		
		  SELECT  C.CostCenterColID,R.ResourceData,C.CostCenterID,SysColumnName
   FROM ADM_CostCenterDef C WITH(NOLOCK)    
   join ADM_DocumentTypes D WITH(NOLOCK)    on C.CostCenterID=D.CostCenterID
  LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=1    
  WHERE D.IsInventory=1 and C.CostCenterID between 40000 and 50000
   AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND   
  SysColumnName like 'dcNum%' or SysColumnName in ('Quantity','Rate','Gross')
  -- (C.SysColumnName NOT LIKE '%dcCalcNum%')  AND (C.SysColumnName NOT LIKE '%dcExchRT%') AND (C.SysColumnName NOT LIKE '%dcCurrID%') AND (C.SysColumnName <> 'UOMConversion')   AND (C.SysColumnName <> 'UOMConvertedQty')          
  --ORDER BY C.RowNo,C.ColumnNo   
	
	select FeatureID,Name from ADM_Features
	where FeatureID>50000 and IsEnabled=1	
	
	
	SELECT D.DocumentTypeID,D.IsUserDefined,Isinventory,D.CostCenterID,D.DocumentType,D.DocumentAbbr,D.DocumentName,D.IsUserDefined,L.ResourceData    ,D.ConvertAs ConvertAs , D.Bounce Bounce     
	
	FROM ADM_DocumentTypes D WITH(NOLOCK)        
	INNER JOIN ADM_RibbonView R WITH(NOLOCK) ON R.FeatureID=D.CostCenterID        
	LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID         
	ORDER BY D.DocumentType,D.IsUserDefined Asc   

	--To get linked document list
	 select CostCenterIDBase ,[CostCenterIDLinked],  Name SourceDocumentName
	   from COM_DocumentLinkDef a   WITH(NOLOCK)  
	 left  join ADM_Features  b  WITH(NOLOCK) on a.CostCenterIDBase=b.FeatureID    
	 order by costcenteridbase 	
 
 
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
