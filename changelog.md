# Changelog

All notable changes to this project will be documented in this file.

## registry.buildpiper.in/s3-uploader

| Tag       | Features                                                                                   | Fixes                | Improvements                                                                                   | Notes                                                                                            |
| --------- | ------------------------------------------------------------------------------------------ | -------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
|           | - Base image: `amazon/aws-cli`.                                                            | None in this release | - Added `shadow-utils` package to support custom user creation.                                | - `buildpiper` user is now used instead of `root`, enhancing container security.                 |
|           | - Created non-root user: `buildpiper`.                                                     |                      | - Working directory set to `/home/buildpiper`.                                                 | - Ownership of relevant directories (`/opt/buildpiper`, `/home/buildpiper`) properly configured. |
|           | - Entrypoint set to `build.sh`.                                                            |                      | - Script and shell-function files are now owned by `buildpiper`, ensuring correct permissions. |                                                                                                  |
|           | - Directory: `/opt/buildpiper/shell-functions` created and populated using `COPY --chown`. |                      |                                                                                                |                                                                                                  |

| Tag       | Features                                                         | Fixes                | Improvements                                  | Notes             |
| --------- | ---------------------------------------------------------------- | -------------------- | --------------------------------------------- | ----------------- |
|            | - Base image: `amazon/aws-cli`.                                  | None in this release | - Initial version with basic S3 upload logic. | - Uses root user. |
|           | - Installed `jq`.                                                |                      |                                               |                   |
|           | - Adds shell functions under `/opt/buildpiper/shell-functions/`. |                      |                                               |                   |
|           | - Entrypoint defined as `build.sh`.                              |                      |                                               |                   |

---

