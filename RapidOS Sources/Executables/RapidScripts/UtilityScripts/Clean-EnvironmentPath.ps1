# ------------------------------------------------------------------------- #
# Modified https://gist.github.com/zbalkan/7f7232c70d0a085c8921a8ccaa9a444b #
#                                                                           #
# This script is designed to clean the 'Path' environment variable          #
# by removing non-existent directories. This helps improve system           #
# performance by reducing the time needed to search for executable          #
# files, prevents potential errors caused by invalid paths,                 #
# optimizes the environment variable space, and makes the 'Path'            #
# variable cleaner and easier to manage.                                    #
# ------------------------------------------------------------------------- #

# Define the environments to clean: Machine (system-wide) and User (user-specific)
$environments = @([EnvironmentVariableTarget]::Machine, [EnvironmentVariableTarget]::User)

foreach ($e in $environments) {
    # Get the current 'Path' environment variable and filter out any empty entries
    $path = [System.Collections.Generic.List[string]]::new(
        ([Environment]::GetEnvironmentVariable('Path', $e)).Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    )

    # Filter the list, keeping only the paths that exist
    $validPaths = $path | Where-Object { Test-Path -Path $_ }

    # Remove non-existent paths and update the 'Path' variable if any paths were removed
    if ($path.Count -ne $validPaths.Count) {
        Write-Host "Cleaning up non-existent paths from Env:Path in $e" -ForegroundColor Yellow
        $newPath = [System.String]::Join(';', $validPaths) + ';'
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, $e)
    } else {
        Write-Host "Nothing to clean in $e" -ForegroundColor Green
    }
}