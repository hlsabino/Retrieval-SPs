USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetDimBasedEMailTemplates]
	@CostCenterID [int],
	@DocID [int],
	@RoleID [int],
	@UserID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @IsInventory bit,@EmailBasedOn NVARCHAR(MAX),@IsEmailBasedOnDim BIT,@IsEmailBasedOnField BIT
DECLARE @TblDim AS TABLE(ID INT,NotifType int)
DECLARE @TblField AS TABLE(TXT NVARCHAR(MAX),NotifType int)

SET @IsEmailBasedOnDim=0
SET @IsEmailBasedOnField=0

select @IsInventory=IsInventory from adm_documentTypes with(nolock) WHERE CostCenterID=@CostCenterID
select @EmailBasedOn=PrefValue FROM COM_DocumentPreferences with(nolock) WHERE CostCenterID=@CostCenterID AND PrefName='EmailBasedOnDimension'
if @EmailBasedOn IS NOT NULL AND @EmailBasedOn!=''
begin
	if isnumeric(@EmailBasedOn)=1 and convert(int,@EmailBasedOn)>50000
	begin
		set @IsEmailBasedOnDim=1
		set @EmailBasedOn='dcCCNID'+convert(nvarchar,(convert(int,@EmailBasedOn)-50000))
		if(@IsInventory=1)
			set @EmailBasedOn='select distinct '+@EmailBasedOn+',1 FROM INV_DocDetails D with(nolock) inner join com_DocCCData dcc with(nolock) on dcc.invdocdetailsID=D.invdocdetailsID'
		else
			set @EmailBasedOn='select distinct '+@EmailBasedOn+',1 FROM ACC_DocDetails D with(nolock) inner join com_DocCCData dcc with(nolock) on dcc.accdocdetailsID=D.accdocdetailsID'
		
		set @EmailBasedOn=@EmailBasedOn+' where D.CostCenterID='+convert(nvarchar,@CostCenterID)+' and D.DocID='+convert(nvarchar,@DocID)

		INSERT INTO @TblDim
		EXEC(@EmailBasedOn)
	end
end
select ISNULL(@EmailBasedOn,'') as EmailBasedOn	
SELECT distinct N.TemplateID
FROM COM_NotifTemplate N WITH(NOLOCK)
INNER JOIN COM_NotifTemplateAction NA WITH(NOLOCK) ON NA.TemplateID=N.TemplateID 
WHERE N.TemplateType=1 AND CostCenterID=@CostCenterID AND StatusID=383
AND N.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)
	WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))
AND (@IsEmailBasedOnDim=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblDim T ON T.ID=A.BasedOnDimension and (T.NotifType=0 or T.NotifType=1)))

GO
