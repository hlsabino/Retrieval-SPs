USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPCRM_GetActivitiesCustomFields]
	@ParentCCCID [int],
	@NodeID [int],
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON;
	
	DECLARE @DocViewID INT
	--0
	SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
	C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(C.IsVisible,0) IsVisible,C.ColumnCCListViewTypeID,      
	C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName , C.RowNo,C.ColumnNo, C.ColumnSpan,C.TextFormat,C.Iscolumninuse   
	FROM ADM_CostCenterDef C WITH(NOLOCK)      
	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
	WHERE  C.IsVisible=1 AND C.CostCenterID = 144 and C.localreference = @ParentCCCID and C.IsColumnUserDefined=1
	AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)  
	ORDER BY C.SectionID,C.SectionSeqNumber   

	--1 cost center fields
	SELECT CostCenterColID,REPLACE(SysColumnName,'dc','') SysColumnName FROM ADM_COSTCENTERDEF C WITH(NOLOCK)    
	WHERE COSTCENTERID=@ParentCCCID AND (SysColumnName LIKE '%CCNID%' OR SysColumnName LIKE '%DCCCNID%') AND 
	((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) 

	--2
	SELECT CostCenterColIDBase,CostCenterColIDLinked FROM COM_DocumentLinkDetails with(nolock) WHERE   
	DocumentLinkDeFID IN (SELECT DocumentLinkDeFID FROM [COM_DocumentLinkDef]  with(nolock)
	WHERE CostCenterIDLinked=@ParentCCCID AND CostCenterIDBase=144)   

	--3
	if(@ParentCCCID>0)
	BEGIN
		if(@ParentCCCID between 40000 and 50000)
			select prefvalue Value,prefname Name from com_Documentpreferences  WITH(NOLOCK)
			where prefname in ('ActivityAsPopup','ActivityFields')  and costcenterid=@ParentCCCID
		
		else if(@ParentCCCID =95)
			select  Value, Name from com_costcenterpreferences  WITH(NOLOCK)
			where Name in ('ActivityAsPopup','ActivityFields')  and costcenterid=@ParentCCCID
		else
			select Value,Name from com_costcenterpreferences  WITH(NOLOCK)
			where name in ('ActivityAsPopup','DisableDimensionsatActivities','UseActivityQuickAdd')  and costcenterid=@ParentCCCID
	END	
	else
		select '' Value,'' Name
	
	--4
	IF EXISTS(SELECT SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE COSTCENTERID=144 AND IsColumnUserDefined=0 AND IsColumnInUse=1 AND LOCALREFERENCE=@ParentCCCID)
	BEGIN
		SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
		C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(C.IsVisible,0) IsVisible,C.ColumnCCListViewTypeID,      
		C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName,C.RowNo,C.ColumnNo,C.ColumnSpan,C.TextFormat,C.Iscolumninuse  
		,C.ShowInQuickAdd,C.QuickAddOrder  
		,DF.Mode,DF.SpName,DF.Shortcut,DF.IpParams,DF.OpParams,DF.Expression
		FROM ADM_CostCenterDef C WITH(NOLOCK)      
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
		LEFT JOIN ADM_DocFunctions DF WITH(NOLOCK) ON  DF.CostCenterColID=  C.CostCenterColID AND DF.CostCenterID=c.CostCenterID
		WHERE C.CostCenterID = 144 and C.localreference = @ParentCCCID AND C.IsColumnInUse=1 
		--if(@ParentCCCID!=86)
		--begin
			and C.ShowInQuickAdd=1 or (C.ShowInQuickAdd=0 and C.localreference = 86)
		--end
		ORDER BY C.QuickAddOrder
	END
	ELSE
	BEGIN
		SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
		C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(C.IsVisible,0) IsVisible,C.ColumnCCListViewTypeID,      
		C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName,C.RowNo,C.ColumnNo,C.ColumnSpan,C.TextFormat,C.Iscolumninuse  
		,C.ShowInQuickAdd,C.QuickAddOrder 
		,DF.Mode,DF.SpName,DF.Shortcut,DF.IpParams,DF.OpParams,DF.Expression
		FROM ADM_CostCenterDef C WITH(NOLOCK)      
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
		LEFT JOIN ADM_DocFunctions DF WITH(NOLOCK) ON  DF.CostCenterColID=  C.CostCenterColID AND DF.CostCenterID=c.CostCenterID
		WHERE C.CostCenterID = 144 and C.localreference IS NULL AND C.IsColumnInUse=1 
		and C.ShowInQuickAdd=0
		ORDER BY C.SectionID,C.SectionSeqNumber 
	END
	
	--5
	if(@NodeID>0)	
		EXEC spCRM_GetFeatureByActvities @NodeID,@ParentCCCID,'',@UserID,@LangID	
	else
		select '' where 1=1
	
	--6	
    if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=144 and UserID=@UserID)                      
	begin                      
		set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=144 and  UserID=@UserID)                      
	end                      
	else if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=144 and RoleID=@RoleID)
	begin                      
		set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=144 and  RoleID=@RoleID)
	end                      
	else if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=144 and GroupID in (select GID from COM_Groups with(nolock) where UserID=@UserID or RoleID=@RoleID))
	begin                      
		set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=144 and GroupID in (select GID from COM_Groups with(nolock) where UserID=@UserID or RoleID=@RoleID))
	end
	
	if(@DocViewID is not null and @DocViewID>0)                      
   begin                      
    SELECT [DocumentViewDefID],c.SysColumnName                      
     ,[DocumentViewID]                      
     ,[DocumentTypeID]                      
     ,d.[CostCenterID]                      
     ,d.[CostCenterColID]                      
     ,[ViewName]                      
     ,d.[IsEditable]                      
     ,[IsReadonly]                      
     ,[NumFieldEditOptionID]                      
     ,d.[IsVisible]                      
     ,[TabOptionID]                      
     ,[CompoundRuleID]                      
     ,[FailureMessage]                      
     ,[ActionOptionID]                      
     ,[Mode]                      
     ,[Expression],ViewFor ,Tabid,d.IsMandatory
    FROM [ADM_DocumentViewDef] d  with(nolock)                   
   left join ADM_CostCenterDef c with(nolock) on c.CostCenterColID=d.CostCenterColID where DocumentViewID=@DocViewID                      
   end                      
   else                      
   begin                      
   SELECT [DocumentViewDefID],c.SysColumnName                      
     ,[DocumentViewID]                      
     ,[DocumentTypeID]                      
     ,d.[CostCenterID]                      
     ,d.[CostCenterColID]                      
     ,[ViewName]                      
     ,d.[IsEditable]                      
     ,[IsReadonly]                      
     ,[NumFieldEditOptionID]                      
     ,d.[IsVisible]                      
     ,[TabOptionID]                      
     ,[CompoundRuleID]                      
     ,[FailureMessage]                      
     ,[ActionOptionID]                      
     ,[Mode]                      
     ,[Expression],ViewFor ,Tabid,d.IsMandatory                     
    FROM [ADM_DocumentViewDef] d  with(nolock)                     
    left join ADM_CostCenterDef c with(nolock) on c.CostCenterColID=d.CostCenterColID where 1=2 --not to return any row just structure                      
   end 
	
COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
