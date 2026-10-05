# Dev Container Setup

The dev container includes Azure CLI, Bicep, GitHub CLI, Git, PowerShell, Python virtual-environment support, and the VS Code Azure extensions.

## Persistent authentication

Azure CLI state is stored outside this repository at `~/code/container-configuration/personal/.azure` and mounted at `/home/vscode/.azure`.

GitHub CLI state is stored outside this repository at `~/code/container-configuration/personal/.github` and mounted at `/home/vscode/.config/gh`.

These directories are created when the container is initialized. Do not add credentials, tokens, subscription IDs, or personal configuration to this repository.

## First run

1. Authenticate with Azure if required:

   ```sh
   az login
   az account show
   az account set --subscription "<subscription-name-or-id>"
   ```

2. Authenticate with GitHub when using `gh`, pull requests, Actions, releases, or HTTPS Git remotes:

   ```sh
   gh auth login
   gh auth status
   ```

   GitHub authentication is not required to run local checks or Azure CLI commands.

3. Run the relevant demo's offline verification before deploying:

   ```sh
   cd 26-action-groups-that-reach-someone
   ./scripts/verify.sh
   ```

The container startup output reports the Azure CLI, Bicep, GitHub CLI, PowerShell, and their authentication state. Missing Azure or GitHub authentication does not block container creation.