USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[fnGet_GetAssignedDims]
	@UserID [int],
	@RoleID [int],
	@where [nvarchar](max) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	declare @Dimensions nvarchar(max),@i int,@cnt int,@dimid int
	declare @TblUserDims table(id int identity(1,1),Dimension int)
	set @where=''
	if(@UserID!=1 and @RoleID!=1)
	begin
		set @Dimensions=(select value from ADM_GlobalPreferences with(nolock) where name='Dimension List')
		if(@Dimensions is not null and @Dimensions!='')
		begin
			insert into @TblUserDims(Dimension)
			exec SPSplitString @Dimensions,','
			
			set @i=0
			select @cnt=count(id) from @TblUserDims
			while(@i<@cnt)
			BEGIN
				set @i=@i+1
				select @dimid=Dimension from @TblUserDims where id=@i
				if(@dimid>50000)
				BEGIN
					set @Dimensions=''
					select @Dimensions=@Dimensions+convert(nvarchar(max),NodeID)+','  from COM_CostCenterCostCenterMap  with(nolock) 
					where ParentCostCenterID=7 and CostCenterID=@dimid and ParentNodeID=@UserID
					
					if(@Dimensions<>'')
						set @where=@where+' and DcCCNID'+convert(nvarchar(max),(@dimid-50000))+' in ('+substring(@Dimensions,0,len(@Dimensions))+')'
				END
			END
		end
	end
END
	
	
 	 
GO
