USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetSerialNumberScreenDetails]
	@ProductID [int],
	@DocDetID [int],
	@DocID [int],
	@DivisionID [int],
	@LocationID [int],
	@Dimwhere [nvarchar](max),
	@Srnos [bit],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
	   
		Declare @SQL nvarchar(Max)
		--Getting  Status.  
		SELECT S.StatusID,R.ResourceData AS Status,Status as ActualStatus
		FROM COM_Status S WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID
		WHERE CostCenterID = 42  

		--GETTING SerialStock
		set @SQL='SELECT a.[SerialProductID]
      ,a.[InvDocDetailsID]
      ,a.[ProductID]
      ,a.[SerialNumber]
      ,a.[StockCode]
      ,a.[Quantity]
      ,case when b.InvDocDetailsID is null then 157 else a.[StatusID] END as StatusID
      ,a.[SerialGUID]
      ,case when b.InvDocDetailsID is null then 1 else a.[IsAvailable] END as [IsAvailable]
      ,a.[IsIssue]     
      ,a.[RefInvDocDetailsID]
      ,a.[Narration]
      ,a.[CompanyGUID]
      ,a.[GUID]
      ,a.[Description]
      ,a.[CreatedBy]
      ,a.[CreatedDate]
      ,a.[ModifiedBy]
      ,a.[ModifiedDate]
		FROM INV_SerialStockProduct a WITH(NOLOCK)
		join Inv_docdetails i WITH(NOLOCK) on a.InvDocDetailsID=i.InvDocDetailsID
		left join INV_SerialStockProduct b WITH(NOLOCK) on a.SerialNumber=b.SerialNumber and a.InvDocDetailsID=b.RefInvDocDetailsID
	   join COM_DocCCData D WITH(NOLOCK) on a.InvDocDetailsID=D.InvDocDetailsID
		WHERE a.ProductID='+convert(nvarchar,@ProductID) +' and i.IsQtyIgnored=0  and (b.InvDocDetailsID is null and
		(a.RefInvDocDetailsID is null or a.RefInvDocDetailsID =0))'
		
		if(@LocationID is not null and @LocationID>0)
			set @SQL=@SQL+' and D.dcccnid2='+CONVERT(nvarchar,@LocationID)
		if(@DivisionID is not null and @DivisionID>0)
			set @SQL=@SQL+' and D.dcccnid1='+CONVERT(nvarchar,@DivisionID)
 
		 set @SQL=@SQL+@Dimwhere
		 set @SQL=@SQL+' or a.InvDocDetailsID = '+convert(nvarchar,@DocDetID) +' order by a.IsAvailable'
		 
		 print @SQL
		 exec(@SQL)
		
		if(@Srnos=1)
		BEGIN
			set @SQL=' select a.InvDocDetailsID,SerialNumber,a.ProductID from INV_SerialStockProduct a WITH(NOLOCK)
			join COM_DocCCData D WITH(NOLOCK) on a.InvDocDetailsID=D.InvDocDetailsID 
			join Inv_docdetails e WITH(NOLOCK) on a.InvDocDetailsID=e.InvDocDetailsID
			 where (a.[RefInvDocDetailsID] is null or a.[RefInvDocDetailsID]=0) and a.ProductID='+CONVERT(nvarchar,@ProductID)
			if(@LocationID is not null and @LocationID>0)
				set @SQL=@SQL+' and D.dcccnid2='+CONVERT(nvarchar,@LocationID)
			if(@DivisionID is not null and @DivisionID>0)
				set @SQL=@SQL+' and D.dcccnid1='+CONVERT(nvarchar,@DivisionID)
			set @SQL=@SQL+@Dimwhere	
			set @SQL=@SQL+' and e.docid<>'+CONVERT(nvarchar,@DocID)
			print @SQL
			exec(@SQL)	
		END
		ELSE
			SELECT 1 WHERE 1<>1
			
		DECLARE @SerialNumber NVARCHAR(50)
		SELECT @SerialNumber=SerialNumber FROM INV_Product WITH(NOLOCK) WHERE [ProductID]=@ProductID
		IF(@SerialNumber IS NOT NULL AND @SerialNumber<>'')
		BEGIN
			DECLARE @DSerialNumber NVARCHAR(50),@I INT=0,@NUM INT=0
			SELECT @DSerialNumber=a.[SerialNumber]
			FROM INV_SerialStockProduct a WITH(NOLOCK)
			WHERE a.[SerialProductID]= (SELECT MAX([SerialProductID])
			FROM INV_SerialStockProduct WITH(NOLOCK) WHERE [ProductID]=@ProductID) 
			
			WHILE LEN(@DSerialNumber)>@I
			BEGIN
				IF ISNUMERIC(SUBSTRING(@DSerialNumber,LEN(@DSerialNumber)-@I,@I+1))=1
				BEGIN
					SET @NUM=CONVERT(INT,SUBSTRING(@DSerialNumber,LEN(@DSerialNumber)-@I,@I+1))
					SET @I=@I+1
				END
				ELSE
					SET @I=LEN(@DSerialNumber)
			END

			SELECT CASE WHEN (@NUM=0 OR @DSerialNumber='')  THEN @SerialNumber ELSE REPLACE(@DSerialNumber,@NUM,'')+CONVERT(NVARCHAR(50),@NUM+1) END SerialNumber
		END
		ELSE
			SELECT 1 WHERE 1<>1

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
