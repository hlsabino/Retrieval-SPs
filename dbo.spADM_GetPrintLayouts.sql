USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetPrintLayouts]
	@Type [int],
	@DocumentID [int],
	@DocType [int],
	@LayoutList [nvarchar](max) = NULL,
	@RoleID [int],
	@UserID [int],
	@DocID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
	DECLARE @LocationID INT,@IsLocWise BIT,@IsBasedOn bit

	IF @Type=0
	BEGIN
		--Getting Print Layouts
		SELECT DocPrintLayoutID,Name,IsDefault 
		FROM ADM_DocPrintLayouts WITH(NOLOCK)
		WHERE DocumentID=@DocumentID AND DocType=@DocType
			AND (
				@RoleID=1 
				OR 
					DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK)
						where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))
				)
		ORDER BY [Name] ASC
	END
	ELSE IF @Type=1 or @Type=4--Location Wise Print Layout List
	BEGIN
		SET @LocationID=CONVERT(INT,@LayoutList)
		if((select Value from ADM_GlobalPreferences with(nolock) where Name='EnableLocationWise')='True' 
			and (select Value from com_costcenterpreferences WITH(NOLOCK) where CostCenterID=50002 and Name='IgnoreLWVPT')='False')
			set @IsLocWise=1
		else
			set @IsLocWise=0
			
		declare @PrefValue nvarchar(max)
		declare @TblBasedOn as Table(ID int)
		set @IsBasedOn=0

		if (@DocumentID = 95 or @DocumentID = 103 or @DocumentID = 129)
		begin
		   select @PrefValue=Value from COM_CostCenterPreferences with(nolock) where CostCenterID=@DocumentID and Name='VPTBasedOnDimension'
		   if @DocID!=0 and @PrefValue is not null and @PrefValue!='' and isnumeric(@PrefValue)=1
			begin
				set @IsBasedOn=1
				if @DocumentID = 95
				begin
					 if @PrefValue = 93
						set @PrefValue='select distinct UnitID from REN_Contract T with(nolock) where T.ContractID='+convert(nvarchar,@DocID)
				     else if @PrefValue = 92
						set @PrefValue='select distinct PropertyID from REN_Contract T with(nolock) where T.ContractID='+convert(nvarchar,@DocID)
					else
						set @PrefValue='select distinct CC.CCNID'+convert(nvarchar,convert(int,@PrefValue)-50000)+' from REN_Contract T with(nolock) join COM_CCCCDATA CC with(nolock) on CC.NodeID=T.ContractID where T.ContractID='+convert(nvarchar,@DocID)
				end
				else if @DocumentID = 103 or @DocumentID = 129
				begin
					 if @PrefValue = 93
						set @PrefValue='select distinct UnitID from REN_Quotation Q with(nolock)  where Q.QuotationID='+convert(nvarchar,@DocID)
				     else if @PrefValue = 92
						set @PrefValue='select distinct PropertyID from REN_Quotation Q with(nolock)  where Q.QuotationID='+convert(nvarchar,@DocID)
					else
						set @PrefValue='select distinct CC.CCNID'+convert(nvarchar,convert(int,@PrefValue)-50000)+' from REN_Quotation Q with(nolock) join COM_CCCCDATA CC with(nolock) on CC.NodeID=Q.QuotationID where Q.QuotationID='+convert(nvarchar,@DocID)
				end
				insert into @TblBasedOn
				exec(@PrefValue)
			end
		end
		else
		begin
		    select @PrefValue=PrefValue from com_documentpreferences with(nolock) where CostCenterID=@DocumentID and prefName='VPTBasedOn'
			if @DocID!=0 and @PrefValue is not null and @PrefValue!='' and isnumeric(@PrefValue)=1 and convert(int,@PrefValue) > 50000
			begin
				set @IsBasedOn=1
				if exists (select IsInventory from ADM_DocumentTypes with(nolock) where CostCenterID=@DocumentID and IsInventory=1)
					set @PrefValue='select distinct DCC.dcCCNID'+convert(nvarchar,convert(int,@PrefValue)-50000)+' from INV_DocDetails D with(nolock) join COM_DocCCData DCC with(nolock) on DCC.InvDocDetailsID=D.InvDocDetailsID where D.DocID='+convert(nvarchar,@DocID)
				else
					set @PrefValue='select distinct DCC.dcCCNID'+convert(nvarchar,convert(int,@PrefValue)-50000)+' from ACC_DocDetails D with(nolock) join COM_DocCCData DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID where D.DocID='+convert(nvarchar,@DocID)
				insert into @TblBasedOn
				exec(@PrefValue)
			end
		end

			
		if @Type=1
		begin
			SELECT P.*,(select top 1 Copies from COM_DocPrints WITH(NOLOCK) where TemplateID=DocPrintLayoutID and NodeID=@DocID) Copies
			into #T1 FROM ADM_DocPrintLayouts P WITH(NOLOCK)			
			WHERE DocumentID=@DocumentID AND DocType=@DocType
			AND (@IsBasedOn=0
			OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap M WITH(NOLOCK)join @TblBasedOn T on T.ID=M.BasedOn))
			
			AND (@RoleID=1 
				OR 
					(DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK)
						where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))
					AND (@IsLocWise=0 OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK) where CCNID2=@LocationID))
					)
				)
			ORDER BY IsDefault DESC

			IF (@IsBasedOn = 1 AND  @DocumentID = 95 AND (SELECT COUNT(*) FROM #T1) = 0)
			BEGIN

				WITH Layoutswithzero AS (
				 select DocPrintLayoutID from ADM_DocPrintLayoutsMap GROUP BY DocPrintLayoutID HAVING MAX(BasedoN) = 0
				)
				SELECT P.*,(select top 1 Copies from COM_DocPrints WITH(NOLOCK) where TemplateID=P.DocPrintLayoutID and NodeID=@DocID) Copies
				FROM ADM_DocPrintLayouts P WITH(NOLOCK) 
				--LEFT JOIN ADM_DocPrintLayoutsMap M 
				--On P.DocPrintLayoutID = M.DocPrintLayoutID --AND M.DocPrintLayoutID IN (SElECT DocPrintLayoutID FROM Layoutswithzero)
				WHERE P.DocumentID=@DocumentID AND P.DocType=@DocType
				--OR (M.DocPrintLayoutID IS NULL) 
				AND (p.DocPrintLayoutID IN (SElECT DocPrintLayoutID FROM Layoutswithzero))
				ORDER BY IsDefault DESC

			END
			ELSE
			  SELECT * FROM #T1 ORDER BY IsDefault DESC

			SELECT M.MapID,M.DocPrintLayoutID,M.PrintOtherVPT,M.PrintContinue
			FROM ADM_DocPrintLayoutsMap M WITH(NOLOCK)
			WHERE M.PrintOtherVPT IS NOT NULL AND M.DocPrintLayoutID IN (
				SELECT DocPrintLayoutID FROM ADM_DocPrintLayouts WITH(NOLOCK)
				WHERE DocumentID=@DocumentID AND DocType=@DocType
				AND (@IsBasedOn=0 OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap M WITH(NOLOCK)join @TblBasedOn T on T.ID=M.BasedOn))
				AND (@RoleID=1 
					OR 
						(DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK)
							where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))
						AND (@IsLocWise=0 OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK) where CCNID2=@LocationID))
						)
					)
				)
			ORDER BY MapID
		end
		else if @Type=4
		begin
			SELECT *
			FROM ADM_DocPrintLayouts P WITH(NOLOCK)			
			WHERE DocumentID=@DocumentID AND DocType=@DocType
			AND (@IsBasedOn=0 OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap M WITH(NOLOCK)join @TblBasedOn T on T.ID=M.BasedOn))
			AND (@RoleID=1 
				OR 
					(DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK)
						where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))
					AND (@IsLocWise=0 OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK) where CCNID2=@LocationID))
					)
				)
			ORDER BY IsDefault DESC
			
			SELECT M.MapID,M.DocPrintLayoutID,M.PrintOtherVPT
			FROM ADM_DocPrintLayoutsMap M WITH(NOLOCK)
			WHERE M.PrintOtherVPT IS NOT NULL AND M.DocPrintLayoutID IN (
				SELECT DocPrintLayoutID FROM ADM_DocPrintLayouts WITH(NOLOCK)
				WHERE DocumentID=@DocumentID AND DocType=@DocType
				AND (@IsBasedOn=0 OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap M WITH(NOLOCK)join @TblBasedOn T on T.ID=M.BasedOn))
				AND (@RoleID=1 
					OR 
						(DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK)
							where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))
						AND (@IsLocWise=0 OR DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap WITH(NOLOCK) where CCNID2=@LocationID))
						)
					)
				)
				
			ORDER BY MapID
		end
	END
	ELSE IF @Type=2
	BEGIN
		DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1), Layout INT)
		INSERT INTO @Tbl(Layout)
		EXEC SPSplitString @LayoutList,','

		--@LayoutList
		SELECT *,isnull(D.IsInventory,0) IsInventory
		FROM ADM_DocPrintLayouts L WITH(NOLOCK)
		INNER JOIN @Tbl AS T ON T.Layout=L.DocPrintLayoutID
		left join ADM_DocumentTypes D with(nolock) on D.CostCenterID=L.DocumentID
		ORDER BY ID	
	END
	ELSE IF @Type=3
	BEGIN
		if @DocumentID>40000 and @DocumentID<50000
		begin
			set @DocID=CONVERT(INT,@LayoutList)
			
			select COUNT(*) PrintCount from COM_DocPrints with(nolock) 
			where CostCenterID=@DocumentID and NodeID=@DocID
			
		end
	END
	
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
