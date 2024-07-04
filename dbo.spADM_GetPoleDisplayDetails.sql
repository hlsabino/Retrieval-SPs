USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetPoleDisplayDetails]
	@PoleID [bigint] = 0,
	@DocID [bigint] = 0,
	@UserID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY   
SET NOCOUNT ON  
   
   if(@PoleID=0)
   begin
		select CostCenterID,DocumentName from adm_documenttypes with(nolock) order by DocumentName
		
		select * from ADM_PoleDisplay with(nolock)
		
		declare @CCID bigint,@TableName nvarchar(100),@Sql nvarchar(max)
	    set @CCID=(select Value from ADM_GlobalPreferences with(nolock) where Name='Registers')
		if(@CCID is not null and @CCID<>'')
		begin
			set  @TableName=(Select TableName from Adm_Features with(nolock) where FeatureID=@CCID)
			set @Sql='select *,'+convert(nvarchar(10),@CCID)+' as [CostCenterID] from '+@TableName
			
		--	print @Sql
			exec (@Sql)
		end
		
   end
   else
   begin
		Select -1 as COSTCENTERID,-1 as COSTCENTERCOLID,'TEXT FIELD' as CCFIELDNAME,'TEXT FIELD' as SysColumnName,-1 as ColumnCostCenterID,'TEXT' as  ColumnDataType
		union
		Select -2 as COSTCENTERID,-2 as COSTCENTERCOLID,'Net Total' as CCFIELDNAME,'Net Total' as SysColumnName,-2 as ColumnCostCenterID,'FLOAT' as  ColumnDataType
		union
		SELECT CDF.COSTCENTERID COSTCENTERID, CDF.COSTCENTERCOLID, R.RESOURCEDATA  CCFIELDNAME,CDF.SysColumnName,CDF.ColumnCostCenterID ,CDF.ColumnDataType FROM ADM_COSTCENTERDEF CDF with(nolock)
		JOIN COM_LANGUAGERESOURCES R with(nolock) ON CDF.RESOURCEID = R.RESOURCEID  AND R.LANGUAGEID = @LangID 
		WHERE (CDF.IsColumnUserDefined=0  or CDF.IsColumnInUse=1) and CDF.CostCenterID=@DocID  and CDF.IsColumnInUse=1
		
		select * from  ADM_PoleDisplay with(nolock) where PoleID=@PoleID
		
		select * from ADM_PoleDisplayRegisters with(nolock) where PoleID=@PoleID
		
		
		select * from ADM_PoleDisplay with(nolock) where DocumentID=@DocID
		
		 SELECT DocPrintLayoutID,Name
		FROM ADM_DocPrintLayouts WITH(NOLOCK)
		WHERE DocumentID=@DocID-- AND DocType=@DocType
			AND (
				@RoleID=1 
				OR 
					DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK)
						where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))
				)
		ORDER BY [Name] ASC
   end
	  
SET NOCOUNT OFF;  
RETURN @PoleID  
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
