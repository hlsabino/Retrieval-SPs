USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetReleaseJobDetails]
	@VoucherNo [nvarchar](max),
	@DocID [int],
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN 
	
	select a.InvDocDetailsID,Isnull(SUM(T.Quantity),0) Used from INV_DOCDETAILS a WITH(NOLOCK)
	left join INV_DocExtraDetails T WITH(NOLOCK) on t.InvDocDetailsID=a.InvDocDetailsID and t.type=15
	where docid=@DocID 
	group by a.InvDocDetailsID
END
GO
