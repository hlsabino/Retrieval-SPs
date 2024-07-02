USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetLinkDimension]
	@InvDocDetailsID [int],
	@Costcenterid [int],
	@DimCCID [int],
	@DimNodeID [int],
	@BasedOnValue [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    

SET NOCOUNT ON    
		Declare @DocumentLinkDefID INT,@Srccol nvarchar(50),@Descol nvarchar(50),@i int,@ctn int,@isinv bit,@SrcTabName nvarchar(200),@ColID INT
		Declare @sql nvarchar(max),@Val nvarchar(max),@ActVal nvarchar(max),@VendorName nvarchar(max),@tableName nvarchar(200),@dtype nvarchar(50),@Decimal INT
		--
		DECLARE @tmpTableName nvarchar(200)
	
		select @isinv=IsInventory from ADM_DocumentTypes with(nolock) where Costcenterid=@Costcenterid
		
		select @tableName=TableName from ADM_Features WiTh(NOLOCK) where FeatureID= @DimCCID
		--
		SET @tmpTableName=@tableName

		declare @tab table(id INT identity(1,1) PRIMARY KEY,Srccol nvarchar(50),dtype  nvarchar(50),Descol nvarchar(50),tabName nvarchar(200),ColID INT,[Decimal] int)   
		insert into @tab
		SELECT DisTINCT B.SysColumnName BASECOL,B.UserColumnType,L.SysColumnName LINKCOL,B.SysTableName,A.BatchColID,ISNULL(L.[Decimal],-1)    
		FROM COM_DocumentBatchLinkDetails A  with(nolock)
		JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.BatchColID AND B.CostCenterID=A.CostCenterID   
		JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDBase AND L.CostCenterID=A.LinkDimCCID   
		WHERE A.CostCenterID=@Costcenterid and A.LinkDimCCID=@DimCCID and L.SysColumnName is not null and L.SysColumnName!='' and B.SysColumnName is not null and B.SysColumnName!='' and a.BasedOnValue=@BasedOnValue
		
		if not exists (select * from @tab) and @DimCCID=16 and @Costcenterid between 40001 and 49999
		begin
			insert into @tab
			SELECT DisTINCT L.SysColumnName BASECOL,B.UserColumnType,B.SysColumnName LINKCOL,B.SysTableName,A.BatchColID,ISNULL(L.[Decimal],-1)    
			FROM COM_DocumentBatchLinkDetails A  with(nolock)
			JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.BatchColID AND B.CostCenterID=A.LinkDimCCID   
			JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDBase AND L.CostCenterID=A.CostCenterID   
			WHERE A.CostCenterID=@Costcenterid and A.LinkDimCCID=@DimCCID and L.SysColumnName is not null and L.SysColumnName!='' and B.SysColumnName is not null and B.SysColumnName!='' and a.BasedOnValue=@BasedOnValue
		end
		
		
 		set @i=0
		select @ctn=COUNT(id) from @tab
		while(@i<@ctn)
		BEGIN
			set @i=@i+1
			SELECT @Srccol=Srccol,@dtype=dtype,@Descol=Descol,@SrcTabName=tabName,@ColID=ColID,@Decimal=[Decimal] from @tab where id=@i
			
			----
			if(@Descol like 'acAlpha%' and @DimCCID=2)
			BEGIN
				SET @tableName='ACC_AccountsExtended'
			END
			ELSE 
				SET @tableName=@tmpTableName
			----			
			
			if(@ColID=-2)
				set @Srccol='DocPrefix'
			else if(@ColID=-1)
				set @Srccol='DocNumber'
			else if(@ColID=-3)
				set @Srccol='DocSeqNo'
				
			if(@Srccol not in('VoucherNo','RefNO','DimensionImage','ProductImage','AccountImage','TenantImage'))
			BEGIN
				set @sql='select @Val='+@Srccol +' from '
				if(@Costcenterid >50000)			 
					set @sql=@sql+@SrcTabName+' with(nolock) '
				else if(@Costcenterid not between 40000 and 50000)			 
					set @sql=@sql+@SrcTabName+' with(nolock) '
				ELSE if(@Srccol like 'dcnum%')			 
					set @sql=@sql+' COM_DocNumData with(nolock) '			 
				ELSE if(@Srccol like 'dcalpha%')
					set @sql=@sql+' [COM_DocTextData] with(nolock) ' 
				ELSE if(@Srccol like 'dcccnid%')
					set @sql=@sql+' [COM_DocCCData] with(nolock) '
				else if(@isinv=1)
					set @sql=@sql+' INV_DocDetails with(nolock) '
				else if(@isinv=0)
					set @sql=@sql+' Acc_DocDetails with(nolock) '
				
				if(@SrcTabName ='COM_CCCCData' and @Srccol like 'CCNID%')	
					set @sql=@sql+' where costcenterid='+convert(nvarchar,@Costcenterid)+' and [NodeID]='+convert(nvarchar,@InvDocDetailsID)	
				ELSE if(@Costcenterid>50000)
					set @sql=@sql+' where [NodeID]='+convert(nvarchar,@InvDocDetailsID)					
				else if(@Costcenterid=76)
					set @sql=@sql+' where [BOMID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid=92)
					set @sql=@sql+' where [NodeID]='+convert(nvarchar,@InvDocDetailsID)	
				ELSE if(@Costcenterid=72)
				begin
					if @DimCCID>50000
						set @sql=@sql+' where [AssetID]='+convert(nvarchar,@InvDocDetailsID)	
					else
						set @sql=@sql+' where [NodeID]='+convert(nvarchar,@InvDocDetailsID)	
				end
				ELSE if(@Costcenterid=93)
					set @sql=@sql+' where [UnitID]='+convert(nvarchar,@InvDocDetailsID)	
				ELSE if(@Costcenterid=94)
					set @sql=@sql+' where [TenantID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid in(95,104) and @SrcTabName='REN_ContractParticulars' and @Srccol='RentAmount')
					set @sql=@sql+' where Sno=1 and [ContractID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid in(95,104))
				BEGIN
					if(@Srccol like 'alpha%')
						set @sql=@sql+' where [NodeID]='+convert(nvarchar,@InvDocDetailsID)
					ELSE
						set @sql=@sql+' where [ContractID]='+convert(nvarchar,@InvDocDetailsID)
				END	
				ELSE if(@Costcenterid=16)
					set @sql=@sql+' where [BatchID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid=2)
					set @sql=@sql+' where [AccountID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid=3)
					set @sql=@sql+' where [ProductID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid>=50001 and @Costcenterid<=50051)
					set @sql=@sql+' where [NodeID]='+convert(nvarchar,@InvDocDetailsID)	
				ELSE if(@Costcenterid=73)
					set @sql=@sql+' where [CaseID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid=86)
					set @sql=@sql+' where [LeadID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@Costcenterid=89)
					set @sql=@sql+' where [OpportunityID]='+convert(nvarchar,@InvDocDetailsID)
				ELSE if(@isinv=1)	
					set @sql=@sql+' where [InvDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)
				else	
					set @sql=@sql+' where [AccDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)

 				EXEC sp_executesql @sql,N'@Val nvarchar(max) OUTPUT',@Val output
 				
 				if(@Srccol='PropertyID' or @Srccol='UnitID' or @Srccol='TenantID')
 				BEGIN
 					set @sql='select @Val= isnull(CCNodeID,1) from '
 					if @Srccol='PropertyID'
 						set @sql=@sql+'REN_Property WITH(NOLOCK) WHERE [NodeID]='
 					else if @Srccol='UnitID'
 						set @sql=@sql+'REN_Units WITH(NOLOCK) WHERE [UnitID]='
 					else if @Srccol='TenantID'
 						set @sql=@sql+'REN_Tenant WITH(NOLOCK) WHERE [TenantID]='
 					set @sql=@sql+@Val
 					
 					EXEC sp_executesql @sql,N'@Val nvarchar(max) OUTPUT',@Val output
 					
 				END
			END
			
			IF(@Descol='StatusID' AND isnumeric(@Val)=1)
			BEGIN
				SELECT TOP 1 @Val=CONVERT(NVARCHAR,S2.[StatusID]) FROM COM_Status S1 WITH(NOLOCK)
				JOIN COM_Status S2 WITH(NOLOCK) ON S2.[Status]=S1.[Status] AND S2.COSTCENTERID=@DimCCID
				WHERE S1.[StatusID]=@Val
			END
			
			if(@Descol like 'CCNID%' or @Descol = 'productid')
				set @sql='update COM_CCCCDATA  set '+@Descol +' = '+@Val
				+' where CostCenterID ='+convert(nvarchar,@DimCCID)+' and NodeID ='+convert(nvarchar,@DimNodeID)						
			ELSE IF( @Srccol='AccountImage' OR @Srccol='ProductImage' OR @Srccol='DimensionImage' OR @Descol ='DimensionImage')
			BEGIN
				set @sql=''
				DELETE FROM COM_FILES WHERE COSTCENTERID=@DimCCID AND FEATUREPK=@DimNodeID
				
				INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,GUID,CreatedBy,CreatedDate, IsDefaultImage)
				SELECT FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,@DimCCID,@DimCCID,@DimNodeID,GUID,CreatedBy,CreatedDate, IsDefaultImage FROM COM_FILES WITH(NOLOCK)
				WHERE FEATUREID=@Costcenterid AND FEATUREPK=@InvDocDetailsID
			END
			ELSE IF(@Srccol like '%alpha%' and @dtype='ATTACHMENT' and @Costcenterid =50170)
			BEGIN
			--Select @Srccol
				set @sql=''
				DELETE FROM COM_FILES WHERE COSTCENTERID=@DimCCID AND FEATUREPK=@DimNodeID And ColName = @Descol

				INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,GUID,CreatedBy,CreatedDate, IsDefaultImage,ColName)
				SELECT FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,@DimCCID,@DimCCID,@DimNodeID,GUID,CreatedBy,CreatedDate, IsDefaultImage,@Descol FROM COM_FILES WITH(NOLOCK)
				WHERE FEATUREID=@Costcenterid AND FEATUREPK=@InvDocDetailsID And ColName = @Srccol
			END
			ELSE 
			BEGIN
				
				set @Val=replace(@Val,'''','''''')
				if(@Descol like 'acAlpha%' and @DimCCID=72)
					set @sql='update ACC_AssetsExtended  set '+@Descol +' =N'''+@Val+ ''' where AssetID='+convert(nvarchar,@DimNodeID)
				ELSE IF(@DimCCID=72 and @dtype='date' and @Srccol like 'dcalpha%')
				begin
					if isdate(@Val)=1
						set @sql='update ACC_Assets  set '+@Descol +' = convert(float,convert(datetime,N'''+@Val+ ''')) where AssetID='+convert(nvarchar,@DimNodeID)	
					else
					BEGIN
						IF ISNUMERIC(@Val)=1
							set @sql='update '+@tableName+'  set '+@Descol +' = convert(nvarchar,convert(datetime,N'''+@Val+ '''),100) where AssetID='+convert(nvarchar,@DimNodeID)
						ELSE
							set @sql=''
					END
				end
				Else if(@DimCCID=72)
					set @sql='update ACC_Assets  set '+@Descol +' =N'''+@Val+ ''' where AssetID='+convert(nvarchar,@DimNodeID)	
				ELSE IF(@DimCCID=2)
				BEGIN
					if(isnumeric(@Val)=1 and @dtype<>'TEXT')
					BEGIN
						if(@Decimal>0)
							set @sql='update '+@tableName+' set '+@Descol +' =N'''+ ltrim(str(replace(@val,',',''),50,@Decimal))+ ''' where AccountID='+convert(nvarchar,@DimNodeID)
						else
							set @sql='update '+@tableName+' set '+@Descol +' =N'''+ replace(@val,',','')+ ''' where AccountID='+convert(nvarchar,@DimNodeID)	
					END	
					else	
						set @sql='update '+@tableName+'  set '+@Descol +' =N'''+@Val+ ''' where AccountID='+convert(nvarchar,@DimNodeID)						
						
				END
				ELSE IF(@DimCCID=16 and @dtype='date' and @Srccol like 'dcalpha%')
				begin
					if isdate(@Val)=1
						set @sql='update '+@tableName+'  set '+@Descol +' = convert(nvarchar,convert(datetime,N'''+@Val+ ''')) where BatchID='+convert(nvarchar,@DimNodeID)	
					else
					BEGIN
						IF ISNUMERIC(@Val)=1
							set @sql='update '+@tableName+'  set '+@Descol +' = convert(nvarchar,convert(datetime,N'''+@Val+ '''),100) where BatchID='+convert(nvarchar,@DimNodeID)
						ELSE
							set @sql=''
					END
				end
				Else if(@DimCCID=16)
					set @sql='update '+@tableName+'  set '+@Descol +' =N'''+@Val+ ''' where BatchID='+convert(nvarchar,@DimNodeID)
				
				ELSE IF(@dtype='date' and @Descol like '%alpha%')
				BEGIN
					IF(@DimCCID=2)
					BEGIN
						IF isdate(@Val)=1
							set @sql='update '+@tableName+'  set '+@Descol +' = convert(nvarchar,convert(datetime,N'''+@Val+ '''),100) where AccountID='+convert(nvarchar,@DimNodeID)
						else IF isnumeric(@Val)=1
							set @sql='update '+@tableName+'  set '+@Descol +' = convert(nvarchar,convert(datetime,'+@Val+'),100) where AccountID='+convert(nvarchar,@DimNodeID)
						ELSE
							set @sql=''
					END
					ELSE
					BEGIN
						IF isdate(@Val)=1
							set @sql='update '+@tableName+'  set '+@Descol +' = convert(nvarchar,convert(datetime,N'''+@Val+ '''),100) where NodeID='+convert(nvarchar,@DimNodeID)
						else IF isnumeric(@Val)=1
							set @sql='update '+@tableName+'  set '+@Descol +' = convert(nvarchar,convert(datetime,'+@Val+'),100) where NodeID='+convert(nvarchar,@DimNodeID)
						ELSE
							set @sql=''
					END
				END
				ELSE IF(@Srccol='StatusID' AND @Descol like '%alpha%' AND isnumeric(@Val)=1)
				BEGIN
					SELECT @Val=S1.[Status] FROM COM_Status S1 WITH(NOLOCK) WHERE CONVERT(NVARCHAR,S1.[StatusID])=@Val
					set @sql='update '+@tableName+'  set '+@Descol +' =N'''+@Val+ ''' where NodeID='+convert(nvarchar,@DimNodeID)
				END
				ELSE
				BEGIN
					if(isnumeric(@Val)=1 and @dtype<>'TEXT' and  @Decimal is not null and @Decimal>=0)
						set @sql='update '+@tableName+' set '+@Descol +' =N'''+ ltrim(str(replace(@val,',',''),50,@Decimal))+ ''' where NodeID='+convert(nvarchar,@DimNodeID)
					else	
						set @sql='update '+@tableName+'  set '+@Descol +' =N'''+@Val+ ''' where NodeID='+convert(nvarchar,@DimNodeID)
				END
			END
			print @sql
			EXEC ( @sql)
		END
        
    
COMMIT TRANSACTION    
SET NOCOUNT OFF;
GO
