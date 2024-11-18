# Overview

This repository contains the material of the "Kubenet: Mastering Kubernetes for Network Automation" workshop held at [AutoCon2](https://networkautomation.forum/autocon2) on 19. November 2024.

# running the workshop

## Using the Google Cloud VM instance provided
During the workshop we'll provide a flyer containing the connection details in order to connect to the VM instance.

### Using a regular terminal/SSH client
Refering towards the handed out flyer for connection credentials. In case you did not receive a flyer, pop your hand up, someone will be there to assist you shortly.
```bash
export ID=<number>
ssh kubenet@$ID.ac2.kubenet.dev
```
Once connected, use the following command to enter the devcontainer
`devcontainer exec --workspace-folder /home/kubenet/ac2-kubenet-workshop zsh`
or
`devcontainer exec --workspace-folder /home/kubenet/ac2-kubenet-workshop bash`

### Using VS Code
Make sure to install [VS Code](https://code.visualstudio.com/download)
Install the following extensions:
- [Remote SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
- [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## Using codespaces -- during/post event
Use  [codespaces](https://codespaces.new/kubenet-dev/ac2-kubenet-workshop) to create your environment.
Note: This will utilize your personal GitHub Codespaces credits.

