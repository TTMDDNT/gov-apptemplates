# Creating environment configurations

Store environment-specific JSON settings under:

  .config/[AuthProfileName]/[EnvironmentName].json

- The folder name is the auth profile label from the Power Platform VS Code extension.
- The file name is the environment name.

## Example:
- File: `.config/Contoso-Auth/Prod.json`
- Import command (PowerShell):
  
  ```
  pac solution import --path ".\\releases\\MySolution.zip" --settings-file ".\\.config\\Contoso-Auth\\Prod.json"
  ```
- Deploy-Solution in Util.ps1 accepts a -Settings parameter where you can pass in this information:
  ```
  Deploy-Solution "$baseFolder\$module" -Managed -AutoConfirm -Settings "$tenantName\$envName.json"
  ```

## Using the settings template:
- Copy the repository's `settings-template.json` into your tenant/env path and save it as the environment file.
- Fill in the connection reference IDs and any environment-specific values. The template already contains the expected connection reference keys; only supply the IDs/values.

## Security:
- These settings can be sensitive. Add `/.config/` to `.gitignore` (the project already ignores this folder).


