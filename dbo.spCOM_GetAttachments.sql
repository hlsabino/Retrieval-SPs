USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetAttachments]
	@CostCenterID [bigint] = 0,
	@NodeID [bigint] = 0,
	@UserID [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @AttahmentDimTable NVARCHAR(50), @SQL nvarchar(Max)
SELECT @AttahmentDimTable=TableName From ADM_GlobalPreferences GP WITH(NOLOCK)
JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=GP.Value
 WHERE GP.Name='AttahmentDimType'
if 'True'=(select Value from com_costcenterpreferences with(nolock) where CostCenterID=@CostCenterID and Name='UserWiseAttachments')
begin
	declare @I int,@CNT int,@UID int
	declare @TblFileUsr as Table(ID int identity(1,1),UserID int)
	
	insert into @TblFileUsr(UserID) 
	Values(@UserID)
	
	set @I=1
	set @CNT=1
	while(@I<=@CNT)
	begin
		select @UID=UserID from @TblFileUsr WHERE ID=@I
		
		insert into @TblFileUsr(UserID)
		
		select NodeID 
		from COM_CostCenterCostCenterMap C WITH(NOLOCK)		
		left join @TblFileUsr T on T.UserID=C.NodeID
		where parentcostcenterid=7 and parentnodeid=@UID and costcenterid=7 and T.UserID is null
		
		set @I=@I+1
		select @CNT=count(*) from @TblFileUsr
	end
	
	select CONVERT(DATETIME,ValidTill) ValidTill,CONVERT(DATETIME,IssueDate) IssDate,CONVERT(DATETIME,f.ModifiedDate) ModifiedDate,CONVERT(DATETIME,f.CreatedDate) CreatedDate,F.* 
	from @TblFileUsr T
	inner join ADM_Users U with(nolock) on U.UserID=T.UserID
	inner join COM_Files F with(nolock) on F.CreatedBy=U.UserName
	where FeatureID=@CostCenterID and  FeaturePK=@NodeID  ORDER BY CONVERT(DATETIME,F.CreatedDate) DESC
end
else
begin

	IF(@AttahmentDimTable IS NOT NULL AND @AttahmentDimTable<>'')
	BEGIN
	
		SET @SQL='SELECT CONVERT(DATETIME,F.ValidTill) ValidTill,CONVERT(DATETIME,F.IssueDate) IssDate,CONVERT(DATETIME,F.ModifiedDate) ModifiedDate,CONVERT(DATETIME,F.CreatedDate) CreatedDate,T.Name TypeName,* 
		FROM  COM_Files F WITH(NOLOCK)
		LEFT JOIN '+CONVERT(NVARCHAR,@AttahmentDimTable)+' T ON T.NodeID=F.Type
		WHERE FeatureID='+CONVERT(NVARCHAR,@CostCenterID)+' and  FeaturePK='+CONVERT(NVARCHAR,@NodeID)+'   ORDER BY CONVERT(DATETIME,F.CreatedDate) DESC'
		EXEC(@SQL)
	END
	ELSE
		SELECT CONVERT(DATETIME,ValidTill) ValidTill,CONVERT(DATETIME,IssueDate) IssDate,CONVERT(DATETIME,ModifiedDate) ModifiedDate,CONVERT(DATETIME,CreatedDate) CreatedDate,* FROM  COM_Files WITH(NOLOCK)
		WHERE FeatureID=@CostCenterID and  FeaturePK=@NodeID  ORDER BY CONVERT(DATETIME,CreatedDate) DESC
end

GO
