USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPCRM_GetFeedbackDetails]
	@CostCenterID [int],
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON;

		SELECT  C.CostCenterColID,R.ResourceData,R.RESOURCEDATA UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
		C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(F.IsVisible,1) IsVisible,C.ColumnCCListViewTypeID,      
		C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName , C.RowNo,C.ColumnNo, 
		C.ColumnSpan,C.TextFormat,C.Iscolumninuse,C.UIWidth Width,isnull(C.Filter,0) as Filter,Cformula,LocalReference,LinkData
		,c.dependancy,c.dependanton
        ,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=C.ColumnCostCenterID and  syscolumnname='ccnid'+convert(nvarchar,(c.dependanton-50000))) as filterinuse
		FROM ADM_CostCenterDef C WITH(NOLOCK)      
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
		LEFT JOIN CRM_FollowUpCustomization F with(nolock) ON F.CCCOLID =C.CostCenterColID 
		WHERE C.CostCenterID = @CostCenterID and C.IsColumnUserDefined=1 and C.IsVisible=1
		AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)      
		ORDER BY ISNULL(C.SectionID,0),C.SectionSeqNumber--C.CostCenterColID  

		SELECT F.CCCOLID AS CostCenterColID,F.NAME AS USERCOLUMNNAME,D.SYSCOLUMNNAME,D.UserColumnType, F.IsVisible
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN CRM_FollowUpCustomization F with(nolock) ON F.CCCOLID =D.CostCenterColID 
		WHERE CostCenterID=@CostCenterID AND IsColumnInUse=1 AND ISCOLUMNUSERDEFINED=1
		ORDER BY D.ColumnNo
		
	     IF((SELECT ISNULL(COUNT(*),0) FROM ADM_GlobalPreferences with(nolock) WHERE NAME= 'CRM-Products')>0)
		 BEGIN
			 DECLARE @SQL NVARCHAR(300),@TableNm Nvarchar(300) 
			 SELECT @TableNm=TableName FROM ADM_FEATURES with(nolock) WHERE FEATUREID IN 
			 (SELECT VALUE FROM   ADM_GlobalPreferences with(nolock) WHERE NAME= 'CRM-Products')
			 IF(@TableNm<>'')
			 BEGIN
				 SET @SQL=' SELECT NODEID NODEID,NAME CRMProduct FROM '+@TableNm +' with(nolock) WHERE ISGROUP=0'
				 EXEC(@SQL)
			 END
			 ELSE
				SELECT 0 WHERE 1<>1
		 END
		 ELSE
			SELECT 0 WHERE 1<>1
		 
		if(@CostCenterID<>118) 
			SELECT NAME,CASE WHEN VALUE='0' THEN 'FALSE' ELSE VALUE END AS VALUE FROM COM_COSTCENTERPREFERENCES C  with(nolock)
			WHERE COSTCENTERID=86 AND NAME='IsProductReadonly'
		else if(@CostCenterID=118)
			SELECT NAME DBText,Value FROM COM_COSTCENTERPREFERENCES C  with(nolock)
			WHERE COSTCENTERID=88
		 
			
		SELECT INV_PRODUCT.ProductID, INV_PRODUCT.PRODUCTCODE,INV_PRODUCT.PRODUCTNAME FROM INV_PRODUCT with(nolock)
		WHERE ProductID IN (SELECT VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE  NAME='DefaultProduct' AND  COSTCENTERID=86 )
		 
		select * from com_lookup with(nolock) where lookuptype =20
		
		SELECT CostCenterColId,resourceid, sectionseqnumber,UserColumnName,SysColumnName, SysTableName,UIWidth,IsVisible,IsMandatory,IsEditable 
		FROM ADM_COSTCENTERDEF with(nolock) 
		WHERE CostCenterID=95 and costcentercolid in (26000,25999,25998,26001,26002,26003,26672,26673,26674,26004,26005,26006,26007,26008,26009,26010,26011,26675,26676,26677,26678)
		order by sectionseqnumber,SysTableName
		
		if(@CostCenterID=118)
		begin
			declare @fieldname nvarchar(100), @tablename nvarchar(100), @SQL1 nvarchar(max)
			select @fieldname= SysColumnName,@tablename=SysTableName from ADM_CostCenterDef C with(nolock)  
			where C.IsColumnInUse=1 AND CostCenterColID in 
			(select value from COM_CostCenterPreferences with(nolock) 
			where CostCenterID=88 and  Name='EventDimensionField')
			set @SQL1= 'select '+@fieldname+',NodeID from '+@tablename+' where isnumeric('+@fieldname+')=1'
			IF LEN(@SQL1)>0 
				exec(@SQL1)
			ELSE
				SELECT 1 WHERE 1<>1
 		end
		
		IF (@CostCenterID=118 OR @CostCenterID=123 OR @CostCenterID=124 OR @CostCenterID=121 OR @CostCenterID=125
		OR @CostCenterID=126 OR @CostCenterID=127 OR @CostCenterID=120 OR @CostCenterID=119) --FOR CAMPAIGN TABS ONLY
		BEGIN
			 SELECT COM_TabGridCustomize.SYSCOLUMNNAME,Visible,ADM_CostCenterDef.CostCenterColID, COM_TabGridCustomize.USERCOLUMNNAME,WIDTH, GRIDORDER 
			 FROM COM_TabGridCustomize WITH(NOLOCK)
			 LEFT JOIN ADM_CostCenterDef WITH(NOLOCK) ON CostCenterID=COM_TabGridCustomize.ChildCostCenter AND
			 ADM_CostCenterDef.SysColumnName=COM_TabGridCustomize.SysColumnName
			 WHERE ParentCostCenter=88	
			 AND ChildCostCenter=@CostCenterID
			 ORDER BY GRIDORDER 
			 
			 SELECT D.SysColumnName,  D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
			D.RowNo, D.ColumnNo, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType, D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
			,'Main' TabName  
			FROM ADM_COSTCENTERDEF D with(nolock) 
			LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID     
			WHERE D.CostCenterID=@CostCenterID  AND IsColumnInUse=1  order by d.sectionseqnumber       
		END
		
		IF @CostCenterID=114
		BEGIN
			DECLARE @HasAccess BIT,@DocViewID bigint                            
			DECLARE @code nvarchar(200),@no bigint,@GridviewID bigint                   
			if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and UserID=@UserID)                      
			begin                      
				set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and  UserID=@UserID)                      
			end                      
			else if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and RoleID=@RoleID)
			begin                      
				set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and  RoleID=@RoleID)
			end                      
			else if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and GroupID in (select GID from COM_Groups with(nolock) where UserID=@UserID or RoleID=@RoleID))
			begin                      
				set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and GroupID in (select GID from COM_Groups with(nolock) where UserID=@UserID or RoleID=@RoleID))
			end
			
			if(@DocViewID is not null and @DocViewID>0)                      
			begin                      
				SELECT [DocumentViewDefID],c.SysColumnName                      
				 ,[DocumentViewID],[DocumentTypeID],d.[CostCenterID],d.[CostCenterColID],[ViewName]                      
				 ,d.[IsEditable],[IsReadonly]  ,[NumFieldEditOptionID]                      
				 ,d.[IsVisible],[TabOptionID] ,[CompoundRuleID]  ,[FailureMessage]  ,[ActionOptionID]                      
				 ,[Mode]   ,[Expression],Tabid,d.IsMandatory
				FROM [ADM_DocumentViewDef] d  WITH(NOLOCK)                  
				left join ADM_CostCenterDef c WITH(NOLOCK)  on c.CostCenterColID=d.CostCenterColID where DocumentViewID=@DocViewID                      
			end                      
			else                      
			begin                      
				SELECT [DocumentViewDefID],c.SysColumnName                      
				 ,[DocumentViewID] ,[DocumentTypeID] ,d.[CostCenterID],d.[CostCenterColID],[ViewName]                      
				 ,d.[IsEditable]  ,[IsReadonly] ,[NumFieldEditOptionID]   ,d.[IsVisible]                      
				 ,[TabOptionID]   ,[CompoundRuleID]      ,[FailureMessage]  ,[ActionOptionID]   ,[Mode]                      
				 ,[Expression] ,Tabid,d.IsMandatory                     
				FROM [ADM_DocumentViewDef] d WITH(NOLOCK)                      
				left join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=d.CostCenterColID where 1=2 --not to return any row just structure                      
			end         
		 
			SELECT  C.CostCenterColID,R.ResourceData,R.RESOURCEDATA UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
			C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,
			isnull(C.IsVisible,1) IsVisible,C.ColumnCCListViewTypeID,      
			C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName , C.RowNo,C.ColumnNo, 
			C.ColumnSpan,C.TextFormat,C.Iscolumninuse,C.UIWidth Width,isnull(C.Filter,0) as Filter,Cformula,LocalReference,LinkData
			,c.dependancy,c.dependanton
			,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=C.ColumnCostCenterID and  syscolumnname='ccnid'+convert(nvarchar,(c.dependanton-50000))) as filterinuse
			FROM ADM_CostCenterDef C WITH(NOLOCK)      
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID   
			WHERE C.CostCenterID = 114 and C.IsColumnUserDefined=0  
			  AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0    
			ORDER BY C.SectionID,C.SectionSeqNumber
		END
		
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
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
