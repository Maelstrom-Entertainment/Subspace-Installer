# Subspace-Installer

The Subspace Installer will ensure the server has the required prerequisites in order to install Subspace and setup Github authentication.

- Prerequisites
  1. [Authenticate Github user](#authenticate-github-user)
  2. [Download scripts on target machine](#download-scripts-on-target-machine)
  3. [Run installer scripts](#run-installer-scripts)

## Prerequisites

### Authenticate Github User

You will be asked to authenticate as a Github User that belongs to the Maelstrom Entertainment organization on Github. This is required in order to ensure that you are part of the organization and have access to the required repo's for the next step.

In order to generate a token, you will need to create a [Fine Grained Personal Access Token](https://github.com/settings/personal-access-tokens/new) in your Github Settings -> Developer Settings area. Ensure `Read-Only` access on the `Contents` section of `Repository Settings` is the only access granted.

### Download scripts on target machine

Navigate to a folder meant to contain the Subspace app (ie - `/opt/var/Subspace`) and run:

```bash
# Executes the script in the current context
source <(curl -sSfL https://raw.githubusercontent.com/Maelstrom-Entertainment/Subspace-Installer/main/installer.sh)
```

After you successfully run that command, you should have full access to the `subspace` command while in the folder, and can use that command to start populating your Subspace projects.

### Run Installer Scripts

You should now have access to the subspace command while inside this folder. You can begin with:

```bash
subspace install
```

or, if you already know which projects you want to install:

```bash
subspace install -p "Github Repo Name" "Github Repo Name" # etc
```