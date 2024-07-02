USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetLinkStatus]
	@STATUSID [int] = 0,
	@REMARKS [nvarchar](max),
	@DATE [datetime],
	@DOCID [bigint],
	@COSTCENTERID [bigint],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@ROLEID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
    
	--Declaration Section    
	DECLARE @Dt FLOAT,@temp nvarchar(max),@VoucherNo nvarchar(200),@Level INT,@LinkDimension nvarchar(50),@LinkDimensionCCID int,@DimesionNodeID bigint

	UPDATE INV_DocDetails    
	SET LinkStatusID=@STATUSID,LinkStatusRemarks=@REMARKS
	WHERE CostCenterID=@CostCenterID AND DOCID=@DOCID
	
	set @VoucherNo=(select top 1 VoucherNo FROM  [INV_DocDetails] a WITH(NOLOCK)
	WHERE a.CostCenterID=@CostCenterID AND DOCID=@DOCID)
	
	
	SELECT @LinkDimension=PrefValue FROM COM_DocumentPreferences with(nolock)
	WHERE CostCenterID=@CostCenterID and PrefName IN ('DocumentLinkDimension')
	
	if @LinkDimension is not null and @LinkDimension<>'' and isnumeric(@LinkDimension)=1
		set @LinkDimensionCCID=convert(bigint,@LinkDimension)	
	else
		set @LinkDimensionCCID=0
	
	if(@LinkDimensionCCID>50000)
	begin
		select @LinkDimension=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@LinkDimensionCCID
		set @temp='select @NodeID=NodeID from '+@LinkDimension+' WITH(NOLOCK) where Name='''+@VoucherNo+''''				
		EXEC sp_executesql @temp,N'@NodeID bigint OUTPUT',@DimesionNodeID output

		if @DimesionNodeID is not null and @DimesionNodeID>0
		begin
			set @temp='update '+@LinkDimension+' set statusID=(SELECT STATUSID FROM COM_STATUS WITH(NOLOCK) WHERE COSTCENTERID='+CONVERT(NVARCHAR,@LinkDimensionCCID)
			
			if @STATUSID=445
				set @temp=@temp+' and status=''In Active'''
			else
				set @temp=@temp+' and status=''Active'''
			set @temp=@temp+') where NodeID='+Convert(nvarchar,@DimesionNodeID)
				
			--print @temp
			EXEC(@temp)
		end		
	end
	
    
   
COMMIT TRANSACTION  
SET NOCOUNT OFF;    
 select @temp=ResourceData from COM_Status S WITH(NOLOCK)
 join COM_LanguageResources R WITH(NOLOCK) on R.ResourceID=S.ResourceID and R.LanguageID=@LangID
 where S.StatusID=@StatusID
 
SELECT   @temp status,ErrorMessage + '   ' + isnull(@VoucherNo,'voucherempty') +' ['+@temp+']'  as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=105 AND LanguageID=@LangID    
RETURN  1    
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
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH    
GO
