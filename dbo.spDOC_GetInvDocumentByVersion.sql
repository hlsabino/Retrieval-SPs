USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetInvDocumentByVersion]
	@CostCenterID [int],
	@DocID [int],
	@Version [int],
	@MaxID [int],
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit,@VoucherNo NVARCHAR(100),@DocDate float,@ModifiedDate float
		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@HIstory bit,@canEdit bit


		SELECT @VoucherNo=VoucherNo,@DocDate=DocDate  FROM [Inv_DocDetails] WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID
		
		if(@Version =-1)
		BEGIN				
			SELECT @ModifiedDate=ModifiedDate,@Version=versionno FROM  [INV_DocDetails_History] D WITH(NOLOCK) 
			WHERE INVDocDetailsHistoryID=@MaxID
	
		END
		ELSE
		BEGIN
			SELECT @ModifiedDate=max(ModifiedDate) FROM  [INV_DocDetails_History] D WITH(NOLOCK) 
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version
		END	
			 
           
			--GETTING DOCUMENT DETAILS
			SELECT a.InvDocDetailsID AS DocDetailsID,a.[AccDocDetailsID],a.VoucherNO
						   ,a.[DocID]
						   ,a.[CostCenterID]						   
						   ,a.[DocumentType]
						   ,a.[VersionNo]
						   ,a.[DocAbbr]
						   ,a.[DocPrefix]
						   ,a.[DocNumber]
						   ,CONVERT(DATETIME,a.[DocDate]) AS DocDate
						   ,CONVERT(DATETIME,a.[DueDate]) AS DueDate
						   ,a.[StatusID]
						   ,a.[BillNo]
							,CONVERT(DATETIME,a.BILLDATE) AS BILLDATE
						   ,a.[LinkedInvDocDetailsID]
						   ,a.LinkedFieldName
						   ,a.LinkedFieldValue
						   ,a.[CommonNarration]
								,a.lineNarration
						   ,a.[DebitAccount]
						   ,a.[CreditAccount]
						   ,a.[DocSeqNo]
						   ,a.[ProductID],p.ProductTypeID
						   ,a.[Quantity]
						   ,a.Unit,p.productCode,p.productname
						   ,a.[HoldQuantity], [ReserveQuantity]
						   ,a.[ReleaseQuantity]
						   ,a.[IsQtyIgnored]
						   ,a.[IsQtyFreeOffer]
						   ,a.[Rate]
						   ,a.[AverageRate]
						   ,a.[Gross]
						   ,a.[StockValue]
						   ,a.[CurrencyID]
						   ,a.[ExchangeRate]
						   ,a.[CompanyGUID]
						   ,a.[GUID]
						   ,CONVERT(DATETIME,A.[CreatedDate]) AS CreatedDate
						   ,A.[ModifiedBy]
						   ,CONVERT(DATETIME,A.[ModifiedDate]) AS ModifiedDate
						   ,a.[CreatedDate]
							,UOMConversion
							,UOMConvertedQty,grossfc, DynamicInvDocDetailsID,vouchertype,
							RefCCID,RefNodeid ,RefNo
			  FROM  [INV_DocDetails_History] a WITH(NOLOCK)
				join dbo.INV_Product p WITH(NOLOCK) on  a.ProductID=p.ProductID
				WHERE a.CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version and a.ModifiedDate=@ModifiedDate
				order by DocSeqNo
		
			--GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS
			SELECT A.* FROM  [COM_DocCCData_History] A WITH(NOLOCK)
			join [INV_DocDetails_History] D WITH(NOLOCK) on A.InvDocDetailsID=D.InvDocDetailsID		and A.ModifiedDate=D.ModifiedDate	
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version and A.ModifiedDate=@ModifiedDate
			order by DocSeqNo
		 
			--GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS
			SELECT A.* FROM [COM_DocNumData_History] A WITH(NOLOCK)
			join [INV_DocDetails_History] D WITH(NOLOCK) on A.InvDocDetailsID=D.InvDocDetailsID	and A.ModifiedDate=D.ModifiedDate		
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version and A.ModifiedDate=@ModifiedDate
			order by DocSeqNo

			--GETTING DOCUMENT EXTRA TEXT FEILD DETAILS
			SELECT A.* FROM [COM_DocTextData_History] A WITH(NOLOCK)
			join [INV_DocDetails_History] D WITH(NOLOCK) on A.InvDocDetailsID=D.InvDocDetailsID		and A.ModifiedDate=D.ModifiedDate	
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version and A.ModifiedDate=@ModifiedDate
			order by DocSeqNo

			--GETTING DOCUMENT QtyAdjustments DETAILS
			SELECT A.* FROM [COM_DocQtyAdjustmentsHISTORY] A WITH(NOLOCK)
			WHERE  A.ModifiedDate=@ModifiedDate
			AND A.DOCID IN (SELECT DOCID FROM INV_DocDetails_History WITH(NOLOCK) 
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version)
			UNION
			SELECT A.* FROM [COM_DocQtyAdjustmentsHISTORY] A WITH(NOLOCK) 
			WHERE A.InvDocDetailsID=0  and A.ModifiedDate=@ModifiedDate
			 AND A.DOCID IN (SELECT DOCID FROM INV_DocDetails_History WITH(NOLOCK) 
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version)
			
			 

			

			
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
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
