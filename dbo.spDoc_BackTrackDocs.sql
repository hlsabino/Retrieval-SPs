USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_BackTrackDocs]
	@InvDocDetailsID [bigint],
	@LinkInvDocDetID [bigint] = 0,
	@CCIDS [nvarchar](max),
	@QtyFin [float],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

		DECLARE @CC AS TABLE(CCID INT)
		INSERT INTO @CC(CCID)
		exec SPSplitString @CCIDS,','  
	 
		DECLARE @I INT,@CNT INT
		DECLARE @Tbl AS TABLE(ID INT NOT NULL IDENTITY(1,1), DetailsID BIGINT,CostCenterID int)
		 
		INSERT INTO @Tbl(DetailsID,CostCenterID)
		SELECT InvDocDetailsID,CostCenterID
		FROM INV_DocDetails INV with(nolock) 
		where InvDocDetailsID=@LinkInvDocDetID
		
			
		set @I=0
		WHILE(1=1)
		BEGIN
			SET @CNT=(SELECT Count(*) FROM @Tbl)
			INSERT INTO @Tbl(DetailsID,CostCenterID)
			SELECT Link.InvDocDetailsID,Link.CostCenterID
			FROM INV_DocDetails INV with(nolock) 
			join INV_DocDetails Link on INV.LINKEDInvDocDetailsID=Link.InvDocDetailsID
			INNER JOIN @Tbl T ON INV.InvDocDetailsID=T.DetailsID AND ID>@I
			where INV.LINKEDInvDocDetailsID is not null and INV.LINKEDInvDocDetailsID>0
			
			
			if exists(select DetailsID from @Tbl a
			join @CC b on a.CostCenterID=b.CCID where ID>@CNT )
			BEGIN
				update  a 
				set LinkedFieldValue=Quantity-@QtyFin
				from INV_DocDetails a
				join @Tbl T ON a.LINKEDInvDocDetailsID=T.DetailsID
				join @Tbl TI ON a.InvDocDetailsID=TI.DetailsID
				join @CC b on t.CostCenterID=b.CCID	
				where t.ID>@CNT
				
				insert into INV_DocExtraDetails(InvDocDetailsID,[RefID],[Type],[Quantity])
				select a.InvDocDetailsID,@InvDocDetailsID,10,@QtyFin from INV_DocDetails a
				join @Tbl T ON a.LINKEDInvDocDetailsID=T.DetailsID
				join @Tbl TI ON a.InvDocDetailsID=TI.DetailsID
				join @CC b on t.CostCenterID=b.CCID	
				where t.ID>@CNT
			END
			
			IF @CNT=(SELECT Count(*) FROM @Tbl)
				BREAK
			SET @I=@CNT
		END
		
		
		
COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  











GO
