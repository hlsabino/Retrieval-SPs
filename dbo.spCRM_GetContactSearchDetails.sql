USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetContactSearchDetails]
	@CCWhere [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit

		--SP Required Parameters Check
		 
		declare @SQL nvarchar(max)
		
		set @SQL='SELECT Distinct c.FirstName as Fname,c.*,L.Name TITLE, dept.NodeID, dept.Name  as Dept , L.Name as Salutation 
		,cus.CustomerName,cus.CustomerID 
		,cccus.CCNID1 CytomedDivisionID, div.Name CytomedDivision,
		cccus.CCNID8 TerritoryID, Territory.Name Territory,
		cccus.CCNID26 CountryID, Country.Name Country1,
		cccus.CCNID27 CityID, City.Name City1
		FROM  COM_Contacts c WITH(NOLOCK) 
		left join crm_customer cus on cus.CustomerID=c.FeaturePK and c.Featureid=83
		LEFT JOIN COM_Lookup L ON L.NODEID=c.SalutationID
		left JOIN COM_CCCCDATA CC ON CC.costcenterid=65 and cc.NodeID=C.contactid
		left join COM_CCCCDATA cccus ON cccus.costcenterid=83 and cccus.NodeID=C.FeaturePK
		left join COM_Division div on cccus.ccnid1=div.nodeid
		left join COM_Teritory Territory on cccus.ccnid8=Territory.nodeid
		left join COM_CC50026 Country on cccus.ccnid26=Country.nodeid
		left join COM_CC50027 City on cccus.ccnid27=City.nodeid
		left join com_cc50029 dept on cc.ccnid29=dept.nodeid and cc.costcenterid=65 '+ @CCWhere
		print (@SQL)
		exec(@SQL)
		
		 
 
		  

SET NOCOUNT OFF;
return 1
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
