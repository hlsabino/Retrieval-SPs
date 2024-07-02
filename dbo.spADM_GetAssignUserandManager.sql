USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetAssignUserandManager]
	@CostcenterID [int],
	@NodeID [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	declare @sql nvarchar(max)
	set @CostcenterID=@CostcenterID-50000
	set @sql='select u.Email1,u.username
	from inv_docdetails a WITH(NOLOCK)
	join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
	join INV_DocExtraDetails c WITH(NOLOCK) on c.invdocdetailsid=a.invdocdetailsid
	join ADM_Users U WITH(NOLOCK) on c.RefID=U.UserID
	where a.documenttype=45 and b.dcccnid'+convert(nvarchar(max),@CostcenterID)+'='+convert(nvarchar(max),@NodeID)+' and type=8


	select UM.Email1
	from inv_docdetails a WITH(NOLOCK)
	join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
	join INV_DocExtraDetails c WITH(NOLOCK) on c.invdocdetailsid=a.invdocdetailsid
	join ADM_Users U WITH(NOLOCK) on c.RefID=U.UserID
	join COM_CostCenterCostCenterMap M WITH(NOLOCK) on M.nodeid=U.UserID
	join ADM_Users UM WITH(NOLOCK) on UM.UserID=M.ParentNodeID
	where a.documenttype=45 and b.dcccnid'+convert(nvarchar(max),@CostcenterID)+'='+convert(nvarchar(max),@NodeID)+' and type=8
	and m.CostCenterID=-7  and m.PARENTcostcenterid=7'
	exec(@sql)		
END			
GO
