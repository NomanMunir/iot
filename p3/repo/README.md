# Part 3 Repository Content

This folder contains the application manifests used in Part 3.

## Instructions
The configurations in `../confs/application.yaml` have been set to use the updated repository:
`https://github.com/NomanMunir/Inception-of-Things.git`

ARGO CD will look for the manifests in the path: `p3/repo/app`.

1. Ensure you push the entire project `42_IoT` (including `p3/repo/app`) to the above GitHub repository.
2. Verify that Argo CD in your K3d cluster syncs the application.
