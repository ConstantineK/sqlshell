#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Write-DataTable {
    <#
        .SYNOPSIS
            Writes data to a SQL Server Table.

        .DESCRIPTION
            Writes a .NET DataTable to a SQL Server table using SQL Bulk Copy.

        .PARAMETER SqlInstance
            The SQL Server instance.

        .PARAMETER SqlCredential
            Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

            $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

            Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

            To connect as a different Windows user, run PowerShell as that user.

        .PARAMETER Database
            The database to import the table into.

        .PARAMETER InputObject
            This is the DataTable (or datarow) to import to SQL Server.

        .PARAMETER Table
            The table name to import data into. You can specify a one, two, or three part table name. If you specify a one or two part name, you must also use -Database.

            If the table does not exist, you can use -AutoCreateTable to automatically create the table with inefficient data types.

        .PARAMETER Schema
            Defaults to dbo if no schema is specified.

        .PARAMETER BatchSize
            The BatchSize for the import defaults to 5000.

        .PARAMETER NotifyAfter
            Sets the option to show the notification after so many rows of import

        .PARAMETER AutoCreateTable
            If this switch is enabled, the table will be created if it does not already exist. The table will be created with sub-optimal data types such as nvarchar(max)

        .PARAMETER NoTableLock
            If this switch is enabled, a table lock (TABLOCK) will not be placed on the destination table. By default, this operation will lock the destination table while running.

        .PARAMETER CheckConstraints
            If this switch is enabled, the SqlBulkCopy option to process check constraints will be enabled.

            Per Microsoft "Check constraints while data is being inserted. By default, constraints are not checked."

        .PARAMETER FireTriggers
            If this switch is enabled, the SqlBulkCopy option to fire insert triggers will be enabled.

            Per Microsoft "When specified, cause the server to fire the insert triggers for the rows being inserted into the Database."

        .PARAMETER KeepIdentity
            If this switch is enabled, the SqlBulkCopy option to preserve source identity values will be enabled.

            Per Microsoft "Preserve source identity values. When not specified, identity values are assigned by the destination."

        .PARAMETER KeepNulls
            If this switch is enabled, the SqlBulkCopy option to preserve NULL values will be enabled.

            Per Microsoft "Preserve null values in the destination table regardless of the settings for default values. When not specified, null values are replaced by default values where applicable."

        .PARAMETER Truncate
            If this switch is enabled, the destination table will be truncated after prompting for confirmation.

        .PARAMETER BulkCopyTimeOut
            Value in seconds for the BulkCopy operations timeout. The default is 30 seconds.

        .PARAMETER RegularUser
            If this switch is enabled, the user connecting will be assumed to be a non-administrative user. By default, the underlying connection assumes that the user has administrative privileges.

            This is particularly important when connecting to a SQL Azure Database.

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .PARAMETER UseDynamicStringLength
            By default, all string columns will be NVARCHAR(MAX).
            If this switch is enabled, all columns will get the length specified by the column's MaxLength property (if specified)

        .NOTES
            Tags: DataTable, Insert


            License: GPL-2.0 https://opensource.org/licenses/GPL-2.0

        .LINK
            https://dbatools.io/Write-DataTable

        .EXAMPLE
            $DataTable = Import-Csv C:\temp\customers.csv | Out-DataTable
            Write-DataTable -SqlInstance sql2014 -InputObject $DataTable -Table mydb.dbo.customers

            Performs a bulk insert of all the data in customers.csv into database mydb, schema dbo, table customers. A progress bar will be shown as rows are inserted. If the destination table does not exist, the import will be halted.

        .EXAMPLE
            $DataTable = Import-Csv C:\temp\customers.csv | Out-DataTable
            $DataTable | Write-DataTable -SqlInstance sql2014 -Table mydb.dbo.customers

            Performs a row by row insert of the data in customers.csv. This is significantly slower than a bulk insert and will not show a progress bar.

            This method is not recommended. Use -InputObject instead.

        .EXAMPLE
            $DataTable = Import-Csv C:\temp\customers.csv | Out-DataTable
            Write-DataTable -SqlInstance sql2014 -InputObject $DataTable -Table mydb.dbo.customers -AutoCreateTable

            Performs a bulk insert of all the data in customers.csv. If mydb.dbo.customers does not exist, it will be created with inefficient but forgiving DataTypes.

        .EXAMPLE
            $DataTable = Import-Csv C:\temp\customers.csv | Out-DataTable
            Write-DataTable -SqlInstance sql2014 -InputObject $DataTable -Table mydb.dbo.customers -Truncate

            Performs a bulk insert of all the data in customers.csv. Prior to importing into mydb.dbo.customers, the user is informed that the table will be truncated and asks for confirmation. The user is prompted again to perform the import.

        .EXAMPLE
            $DataTable = Import-Csv C:\temp\customers.csv | Out-DataTable
            Write-DataTable -SqlInstance sql2014 -InputObject $DataTable -Database mydb -Table customers -KeepNulls

            Performs a bulk insert of all the data in customers.csv into mydb.dbo.customers. Because Schema was not specified, dbo was used. NULL values in the destination table will be preserved.

        .EXAMPLE
            $passwd = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
            $AzureCredential = Mew-Object System.Management.Automation.PSCredential("AzureAccount"),$passwd)
            $DataTable = Import-Csv C:\temp\customers.csv | Out-DataTable
            Write-DataTable -SqlInstance AzureDB.database.windows.net -InputObject $DataTable -Database mydb -Table customers -KeepNulls -Credential $AzureCredential -RegularUser -BulkCopyTimeOut 300

            This performs the same operation as the previous example, but against a SQL Azure Database instance using the required credentials. The -RegularUser switch is needed to prevent trying to get administrative privilege, and we increase the BulkCopyTimeout value to cope with any latency.

        .EXAMPLE
            $process = Get-Process | Out-DataTable
            Write-DataTable -InputObject $process -SqlInstance sql2014 -Database mydb -Table myprocesses -AutoCreateTable

            Creates a table based on the Process object with over 60 columns, converted from PowerShell data types to SQL Server data types. After the table is created a bulk insert is performed to add process information into the table.

            This is an example of the type conversion in action. All process properties are converted, including special types like TimeSpan. Script properties are resolved before the type conversion starts thanks to Out-DataTable.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [ValidateNotNull()]
        $SqlInstance,
        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [Alias("Credential")]
        [PSCredential]$SqlCredential,
        [Parameter(Position = 2)]
        [object]$Database,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("DataTable")]
        [ValidateNotNull()]
        [object]$InputObject,
        [Parameter(Position = 3, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Table,
        [Parameter(Position = 4)]
        [ValidateNotNullOrEmpty()]
        [string]$Schema = 'dbo',
        [ValidateNotNull()]
        [int]$BatchSize = 50000,
        [ValidateNotNull()]
        [int]$NotifyAfter = 5000,
        [switch]$AutoCreateTable,
        [switch]$NoTableLock,
        [switch]$CheckConstraints,
        [switch]$FireTriggers,
        [switch]$KeepIdentity,
        [switch]$KeepNulls,
        [switch]$Truncate,
        [ValidateNotNull()]
        [int]$bulkCopyTimeOut = 5000,
        [switch]$RegularUser,
        [switch][Alias('Silent')]$EnableException,
        [switch]$UseDynamicStringLength
    )

    begin {
        # Null variable to make sure upper-scope variables don't interfere later
        $steppablePipeline = $null

        #region Utility Functions
        function Invoke-BulkCopy {
        <#
            .SYNOPSIS
                Copies a datatable in bulk over to a table.

            .DESCRIPTION
                Copies a datatable in bulk over to a table.

            .PARAMETER DataTable
                The datatable to copy.

            .PARAMETER SqlInstance
                Needs not be specified. The SqlInstance targeted. For message purposes only.

            .PARAMETER Fqtn
                Needs not be specified. The fqtn written to. For message purposes only.

            .PARAMETER BulkCopy
                Needs not be specified. The bulk copy object used to perform the copy operation.
        #>
            [CmdletBinding()]
            param (
                $DataTable,
                [DbaInstance]$SqlInstance = $SqlInstance,
                [string]$Fqtn = $fqtn,
                $BulkCopy = $bulkCopy
            )
            Write-Message -Level Verbose -Message "Importing in bulk to $fqtn"

            $rowCount = $DataTable.Rows.Count
            if ($rowCount -eq 0) {
                $rowCount = 1
            }

            if ($Pscmdlet.ShouldProcess($SqlInstance, "Writing $rowCount rows to $Fqtn")) {
                $bulkCopy.WriteToServer($DataTable)
                if ($rowCount -is [int]) {
                    Write-Progress -id 1 -activity "Inserting $rowCount rows" -status "Complete" -Completed
                }
            }
        }

        function New-Table {
        <#
            .SYNOPSIS
                Creates a table, based upon a DataTable.

            .DESCRIPTION
                Creates a table, based upon a DataTable.

            .PARAMETER DataTable
                The DataTable to base the table structure upon.

            .PARAMETER PStoSQLTypes
                Automatically inherits from parent.

            .PARAMETER SqlInstance
                Automatically inherits from parent.

            .PARAMETER Fqtn
                Automatically inherits from parent.

            .PARAMETER Server
                Automatically inherits from parent.

            .PARAMETER DatabaseName
                Automatically inherits from parent.

            .PARAMETER EnableException
                By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
                This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
                Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

            .PARAMETER UseDynamicStringLength
                Automatically inherits from parent.
        #>
            [CmdletBinding()]
            param (
                $DataTable,
                $PStoSQLTypes = $PStoSQLTypes,
                $SqlInstance = $SqlInstance,
                $Fqtn = $fqtn,
                $Server = $server,
                $DatabaseName = $databaseName,
                [switch]$EnableException
            )

            Write-Message -Level Verbose -Message "Creating table for $fqtn"

            # Get SQL datatypes by best guess on first data row
            $sqlDataTypes = @();
            $columns = $DataTable.Columns

            if ($null -eq $columns) {
                $columns = $DataTable.Table.Columns
            }

            foreach ($column in $columns) {
                $sqlColumnName = $column.ColumnName

                try {
                    $columnValue = $DataTable.Rows[0].$sqlColumnName
                }
                catch {
                    $columnValue = $DataTable.$sqlColumnName
                }

                if ($null -eq $columnValue) {
                    $columnValue = $DataTable.$sqlColumnName
                }

            <#
                PS to SQL type conversion
                If data type exists in hash table, use the corresponding SQL type
                Else, fallback to nvarchar.
                If UseDynamicStringLength is specified, the DataColumn MaxLength is used if specified
            #>
                if ($PStoSQLTypes.Keys -contains $column.DataType) {
                    $sqlDataType = $PStoSQLTypes[$($column.DataType.toString())]
                    if ($UseDynamicStringLength -and $column.MaxLength -gt 0 -and ($column.DataType -in ("String", "System.String"))) {
                        $sqlDataType = $sqlDataType.Replace("(MAX)", "($($column.MaxLength))")
                    }
                }
                else {
                    $sqlDataType = "nvarchar(MAX)"
                }

                $sqlDataTypes += "[$sqlColumnName] $sqlDataType"
            }

            $sql = "BEGIN CREATE TABLE $fqtn ($($sqlDataTypes -join ' NULL,')) END"

            Write-Message -Level Debug -Message $sql

            if ($Pscmdlet.ShouldProcess($SqlInstance, "Creating table $Fqtn")) {
                try {
                    $null = $Server.Databases[$DatabaseName].Query($sql)
                }
                catch {
                    Stop-Function -Message "The following query failed: $sql" -ErrorRecord $_
                    return
                }
            }
        }

        #endregion Utility Functions

        #region Prepare type for bulk copy
        if (-not $Truncate) { $ConfirmPreference = "None" }

        # Getting the total rows copied is a challenge. Use SqlBulkCopyExtension.
        # http://stackoverflow.com/questions/1188384/sqlbulkcopy-row-count-when-complete

        $source = 'namespace System.Data.SqlClient {
            using Reflection;

            public static class SqlBulkCopyExtension
            {
                const String _rowsCopiedFieldName = "_rowsCopied";
                static FieldInfo _rowsCopiedField = null;

                public static int RowsCopiedCount(this SqlBulkCopy bulkCopy)
                {
                    if (_rowsCopiedField == null) _rowsCopiedField = typeof(SqlBulkCopy).GetField(_rowsCopiedFieldName, BindingFlags.NonPublic | BindingFlags.GetField | BindingFlags.Instance);
                    return (int)_rowsCopiedField.GetValue(bulkCopy);
                }
            }
        }'

        Add-Type -ReferencedAssemblies 'System.Data.dll' -TypeDefinition $source -ErrorAction SilentlyContinue
        #endregion Prepare type for bulk copy

        #region Resolve Full Qualified Table Name
        $dotCount = ([regex]::Matches($Table, "\.")).count

        if ($dotCount -lt 2 -and $null -eq $Database) {
            Stop-Function -Message "You must specify a database or fully qualified table name."
            return
        }

        if (Test-Bound -ParameterName Database) {
            $databaseName = "$Database"
        }

        $tableName = $Table
        $schemaName = $Schema

        if ($dotCount -eq 1) {
            $schemaName = $Table.Split(".")[0]
            $tableName = $Table.Split(".")[1]
        }

        if ($dotCount -eq 2) {
            $databaseName = $Table.Split(".")[0]
            $schemaName = $Table.Split(".")[1]
            $tableName = $Table.Split(".")[2]
        }

        if ($databaseName -match "\[.*\]") {
            $databaseName = ($databaseName -replace '\[', '') -replace '\]', ''
        }

        if ($schemaName -match "\[.*\]") {
            $schemaName = ($schemaName -replace '\[', '') -replace '\]', ''
        }

        if ($tableName -match "\[.*\]") {
            $tableName = ($tableName -replace '\[', '') -replace '\]', ''
        }

        $fqtn = "[$databaseName].[$schemaName].[$tableName]"
        Write-Message -Level SomewhatVerbose -Message "FQTN processed: $fqtn"
        #endregion Resolve Full Qualified Table Name

        #region Connect to server and get database
        Write-Message -Message "Attempting to connect to $SqlInstance." -Level Verbose -Target $SqlInstance
        try {
            $server = Connect-SqlInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential -RegularUser:$RegularUser
        }
        catch {
            Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $SqlInstance
            return
        }

        if ($server.ServerType -eq 'SqlAzureDatabase') {
            <#
                For some reasons SMO wants an initial pull when talking to Azure Sql DB
                This will throw and be caught, and then we can continue as normal.
            #>
            try {
                $null = $server.Databases
            }
            catch {
                #do nothing
            }
        }
        $databaseObject = $server.Databases[$databaseName]
        #endregion Connect to server and get database

        #region Prepare database and bulk operations
        if ($null -eq $databaseObject) {
            Stop-Function -Message "$databaseName does not exist." -Target $SqlInstance
            return
        }

        $databaseObject.Tables.Refresh()
        if ($schemaName -notin $databaseObject.Schemas.Name) {
            Stop-Function -Message "Schema does not exist."
            return
        }

        $tableExists = ($tableName -in $databaseObject.Tables.Name) -and ($databaseObject.Tables.Schema -eq $schemaName)

        if ((-not $tableExists) -and (-not $AutoCreateTable)) {
            Stop-Function -Message "Table does not exist and automatic creation of the table has not been selected. Specify the '-AutoCreateTable'-parameter to generate a suitable table."
            return
        }

        $bulkCopyOptions = 0
        $options = "TableLock", "CheckConstraints", "FireTriggers", "KeepIdentity", "KeepNulls", "Default"

        foreach ($option in $options) {
            $optionValue = Get-Variable $option -ValueOnly -ErrorAction SilentlyContinue
            if ($option -eq "TableLock" -and (!$NoTableLock)) {
                $optionValue = $true
            }
            if ($optionValue -eq $true) {
                $bulkCopyOptions += $([Data.SqlClient.SqlBulkCopyOptions]::$option).value__
            }
        }

        if ($Truncate -eq $true) {
            if ($Pscmdlet.ShouldProcess($SqlInstance, "Truncating $fqtn")) {
                try {
                    Write-Message -Level Output -Message "Truncating $fqtn."
                    $null = $server.Databases[$databaseName].Query("TRUNCATE TABLE $fqtn")
                }
                catch {
                    Write-Message -Level Warning -Message "Could not truncate $fqtn. Table may not exist or may have key constraints." -ErrorRecord $_
                }
            }
        }

        $bulkCopy = New-Object Data.SqlClient.SqlBulkCopy("$($server.ConnectionContext.ConnectionString);Database=$databaseName", $bulkCopyOptions)
        $bulkCopy.DestinationTableName = $fqtn
        $bulkCopy.BatchSize = $BatchSize
        $bulkCopy.NotifyAfter = $NotifyAfter
        $bulkCopy.BulkCopyTimeOut = $BulkCopyTimeOut

        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        # Add RowCount output
        $bulkCopy.Add_SqlRowsCopied({
                $script:totalRows = $args[1].RowsCopied
                $percent = [int](($script:totalRows / $rowCount) * 100)
                $timeTaken = [math]::Round($elapsed.Elapsed.TotalSeconds, 1)
                Write-Progress -id 1 -activity "Inserting $rowCount rows." -PercentComplete $percent -Status ([System.String]::Format("Progress: {0} rows ({1}%) in {2} seconds", $script:totalRows, $percent, $timeTaken))
            })

        $PStoSQLTypes = @{
            #PS datatype      = SQL data type
            'System.Int32'     = 'int';
            'System.UInt32'    = 'bigint';
            'System.Int16'     = 'smallint';
            'System.UInt16'    = 'int';
            'System.Int64'     = 'bigint';
            'System.UInt64'    = 'decimal(20,0)';
            'System.Decimal'   = 'decimal(20,5)';
            'System.Single'    = 'bigint';
            'System.Double'    = 'float';
            'System.Byte'      = 'tinyint';
            'System.SByte'     = 'smallint';
            'System.TimeSpan'  = 'nvarchar(30)';
            'System.String'    = 'nvarchar(MAX)';
            'System.Char'      = 'nvarchar(1)'
            'System.DateTime'  = 'datetime2';
            'System.Boolean'   = 'bit';
            'System.Guid'      = 'uniqueidentifier';
            'Int32'            = 'int';
            'UInt32'           = 'bigint';
            'Int16'            = 'smallint';
            'UInt16'           = 'int';
            'Int64'            = 'bigint';
            'UInt64'           = 'decimal(20,0)';
            'Decimal'          = 'decimal(20,5)';
            'Single'           = 'bigint';
            'Double'           = 'float';
            'Byte'             = 'tinyint';
            'SByte'            = 'smallint';
            'TimeSpan'         = 'nvarchar(30)';
            'String'           = 'nvarchar(MAX)';
            'Char'             = 'nvarchar(1)'
            'DateTime'         = 'datetime2';
            'Boolean'          = 'bit';
            'Bool'             = 'bit';
            'Guid'             = 'uniqueidentifier';
            'int'              = 'int';
            'long'             = 'bigint';
        }

        $validTypes = @([System.Data.DataSet], [System.Data.DataTable], [System.Data.DataRow], [System.Data.DataRow[]])
        #endregion Prepare database and bulk operations

        #region ConvertTo-DataTable wrapper
        try {
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('ConvertTo-DataTable', [System.Management.Automation.CommandTypes]::Function)
            $splatCDDT = @{
                TimeSpanType   = (Get-ConfigValue -FullName 'commands.write-dbadatatable.timespantype' -Fallback 'TotalMilliseconds')
                SizeType       = (Get-ConfigValue -FullName 'commands.write-dbadatatable.sizetype' -Fallback 'Int64')
                IgnoreNull     = (Get-ConfigValue -FullName 'commands.write-dbadatatable.ignorenull' -Fallback $false)
                Raw            = (Get-ConfigValue -FullName 'commands.write-dbadatatable.raw' -Fallback $false)
            }
            $scriptCmd = { & $wrappedCmd @splatCDDT }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline()
            $steppablePipeline.Begin($true)
        }
        catch {
            Stop-Function -Message "Failed to initialize "
        }
        #endregion ConvertTo-DataTable wrapper
    }
    process {
        if (Test-FunctionInterrupt) { return }

        if ($null -ne $InputObject) { $inputType = $InputObject.GetType() }
        else { $inputType = $null }

        if ($inputType -eq [System.Data.DataSet]) {
            $inputData = $InputObject.Tables
            $inputType = [System.Data.DataTable[]]
        }
        else {
            $inputData = $InputObject
        }

        #region Scenario 1: Single valid table
        if ($inputType -in $validTypes) {
            if (-not $tableExists) {
                try {
                    New-Table -DataTable $InputObject -EnableException
                    $tableExists = $true
                }
                catch {
                    Stop-Function -Message "Failed to create table $fqtn" -ErrorRecord $_ -Target $SqlInstance
                    return
                }
            }

            try { Invoke-BulkCopy -DataTable $InputObject }
            catch {
                Stop-Function -Message "Failed to bulk import to $fqtn" -ErrorRecord $_ -Target $SqlInstance
            }
            return
        }
        #endregion Scenario 1: Single valid table

        foreach ($object in $inputData) {
            #region Scenario 2: Multiple valid tables
            if ($object.GetType() -in $validTypes) {
                if (-not $tableExists) {
                    try {
                        New-Table -DataTable $object -EnableException
                        $tableExists = $true
                    }
                    catch {
                        Stop-Function -Message "Failed to create table $fqtn" -ErrorRecord $_ -Target $SqlInstance
                        return
                    }
                }

                try { Invoke-BulkCopy -DataTable $object }
                catch {
                    Stop-Function -Message "Failed to bulk import to $fqtn" -ErrorRecord $_ -Target $SqlInstance -Continue
                }
                continue
            }
            #endregion Scenario 2: Multiple valid tables

            #region Scenario 3: Invalid data types
            else {
                $null = $steppablePipeline.Process($object)
                continue
            }
            #endregion Scenario 3: Invalid data types
        }
    }
    end {
        #region ConvertTo-DataTable wrapper
        if ($null -ne $steppablePipeline) {
            $dataTable = $steppablePipeline.End()

            if (-not $tableExists) {
                try {
                    New-Table -DataTable $dataTable[0] -EnableException
                    $tableExists = $true
                }
                catch {
                    Stop-Function -Message "Failed to create table $fqtn" -ErrorRecord $_ -Target $SqlInstance
                    return
                }
            }

            try { Invoke-BulkCopy -DataTable $dataTable[0] }
            catch {
                Stop-Function -Message "Failed to bulk import to $fqtn" -ErrorRecord $_ -Target $SqlInstance
            }
        }
        #endregion ConvertTo-DataTable wrapper

        if ($bulkCopy) {
            $bulkCopy.Close()
            $bulkCopy.Dispose()
        }
    }
}
