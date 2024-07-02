USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetActivityScreenDetails]
	@COSTCENTERID [bigint] = 0,
	@LocalReference [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
		 
		--Getting Service ticket fields 
		select C.CostCenterColID,R.ResourceData,R.ResourceData as UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,C.RowNo,C.ColumnNo,C.ColumnSpan,
				C.UserDefaultValue,C.UserProbableValues,C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,
				C.IsCostCenterUserDefined
		FROM ADM_CostCenterDef C WITH(NOLOCK) 
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
		where C.CostCenterID=@COSTCENTERID and C.CostCenterColID in (26689,26690) and C.IsColumninUse=1
		UNION 
		select C.CostCenterColID, R.ResourceData,R.ResourceData as UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,C.RowNo,C.ColumnNo,C.ColumnSpan,
				C.UserDefaultValue,C.UserProbableValues,C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,
				C.IsCostCenterUserDefined
		FROM ADM_CostCenterDef C WITH(NOLOCK) 
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
		where C.CostCenterID=@COSTCENTERID and C.LocalReference in (@LocalReference) AND C.IsColumninUse=1
		   and  (SysColumnName LIKE '%Alpha%')
		 
		
		SELECT FEATUREID DocID,NAME DocName FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE ISENABLED=1 AND (FEATUREID IN (86,89,73,83,88,65) OR FEATUREID BETWEEN 40000 AND 50000)
		
		 --Getting Details of All Documents from Adm_CostCenterDef
		 select distinct A.CostCenterID,A.CostCenterColID,A.CostCenterName,C.ResourceData as UserColumnName, A.SysColumnName
		 from ADM_CostCenterDef A WITH(NOLOCK) 
		 join Com_LanguageResources C WITH(NOLOCK) on C.ResourceID=A.ResourceID   AND C.LanguageID=@LangID
		 where  (IsColumnUserDefined=0  or IsColumnInUse=1) and
		  SysColumnName NOT LIKE '%dcCurrID%' and SysColumnName NOT LIKE '%dcExchRT%'  
		  and  SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName NOT LIKE '%dcCalcNum%' 
		  and SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName <> 'UOMConversion'   AND SysColumnName <> 'UOMConvertedQty' 
		  OR  (SysColumnName LIKE '%acAlpha%' and SysColumnName LIKE '%CCNID%' )
		   OR  (SysColumnName LIKE '%opAlpha%' and SysColumnName LIKE '%CCNID%' )
		  and CostCenterID between 40000 and 50000 or (CostCenterID=89 AND IsColumnInUse=1) or(CostCenterID=2 AND IsColumnInUse=1) or (CostCenterID=83 AND IsColumnInUse=1)
		 union
		  select 0 CostCenterID,0 CostCenterColID,'' CostCenterName,''  UserColumnName,'' SysColumnName
		  order by CostCenterID
		 
		  
		 --Getting details of Mapped voucher
		 select * from COM_DocumentLinkDef WITH(NOLOCK) where CostCenterIDBase=@COSTCENTERID

		select dl.DocumentLinkDeFID, dl.CostCenterColIDBase, C.ResourceData  as BUserColumnName,
		 b.SysColumnName as BSysColumnName, dl.CostCenterColIDLinked, l.UserColumnName as LUserColumnName,
		 l.SysColumnName as LSysColumnName,l.Costcenterid,b.Costcenterid BCostcenterid,D.Mode
		 from COM_DocumentLinkDetails dl WITH(NOLOCK) 
		 left join ADM_CostCenterDef b WITH(NOLOCK) on dl.CostCenterColIDBase=b.CostCenterColID
		 left join Com_LanguageResources C WITH(NOLOCK) on C.ResourceID=b.ResourceID   AND C.LanguageID=@LangID
		 left join ADM_CostCenterDef l WITH(NOLOCK) on dl.CostCenterColIDLinked=l.CostCenterColID
		 join COM_DocumentLinkDef D WITH(NOLOCK) on dl.DocumentLinkDeFID=d.DocumentLinkDeFID		 
		where d.CostCenterIDBase=@COSTCENTERID
		
		
		--Getting Costcenter Fields  
		SELECT  C.CostCenterColID,R.ResourceData,R.ResourceData as UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,C.RowNo,C.ColumnNo,C.ColumnSpan,
				C.UserDefaultValue,C.UserProbableValues,C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,
				C.IsCostCenterUserDefined,isnull(C.UIwidth,100) UIWidth,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName,C.SectionSeqNumber,
				DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,
				DD.IsRoundOffEnabled,DD.IsDrAccountDisplayed,DD.IsCrAccountDisplayed,DD.IsDistributionEnabled,DD.DistributionColID,
				DV.IsReadonly,DV.NumFieldEditOptionID,DV.IsVisible,DV.TabOptionID,DV.ActionOptionID,DD.IsCalculate
		FROM ADM_CostCenterDef C WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
		INNER JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
		LEFT JOIN ADM_DocumentViewDef DV WITH(NOLOCK) ON DV.CostCenterColID=C.CostCenterColID 
		WHERE C.CostCenterID  =@COSTCENTERID AND C.SysColumnName LIKE 'dcNum%' and c.IsColumninUse=1
		

		--Getting Costcenter Fields  
		SELECT  C.CostCenterColID
		FROM ADM_CostCenterDef C WITH(NOLOCK)
		WHERE C.CostCenterID =@COSTCENTERID AND C.SysColumnName LIKE 'dcNum%'
		AND C.CostCenterColID NOT IN (SELECT CostCenterColID FROM ADM_DocumentDef WITH(NOLOCK) WHERE CostCenterID=@COSTCENTERID)
		
COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  

GO
