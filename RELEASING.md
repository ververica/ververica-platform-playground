# Releasing

## Branches and Tags

Branch/Tag | Description
---|---
`master` branch | Code for the *next* release.
`release-X.Y` branch | Code for the *vX.Y* release series.

### Creating a release branch

We have to create a new release branch manually from the `master` branch.

When a new release branch was created, some configuration files have to be adapted on `master`:
- Add a [mergify rule](.mergify.yml) for backporting to the previous version, analogous to the existing ones.
