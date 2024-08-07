﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_CreateBackup]
	@FileName [nvarchar](max),
	@BackupDB [nvarchar](max)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

		DECLARE @SQL nvarchar(Max)
		SET @SQL=' BACKUP DATABASE '+CONVERT(VARCHAR,@BackupDB)+ '  TO DISK='''+@FileName+'''  WITH FORMAT'
		--SELECT @SQL
		EXEC(@SQL)
		

COMMIT TRANSACTION    
SET NOCOUNT OFF; 
SELECT 1    
RETURN 1
END TRY
BEGIN CATCH  

	SELECT 0
-- SELECT
--        ERROR_NUMBER() AS ErrorNumber,
--        ERROR_SEVERITY() AS ErrorSeverity,
--        ERROR_STATE() AS ErrorState,
--        ERROR_PROCEDURE() AS ErrorProcedure,
--        ERROR_LINE() AS ErrorLine,
--        ERROR_MESSAGE() AS ErrorMessage;
  
		
 ROLLBACK TRANSACTION  
 SET NOCOUNT OFF  
 RETURN -999     
END CATCH   

----spADM_CreateBackup '\\PSDEVSERVER\Docs\Backups\RevenU-30-Nov-2011\RevenU-30-Nov-2011.Bak','PACT2C1000'

GO
