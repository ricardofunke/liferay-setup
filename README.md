The directories bellow are created in the first run of "setup-liferay.sh" script.
Here are some explanations about them:

- bundles: Download Liferay Bundles here
- licenses: Put your Liferay Dev Licenses here
- patches: For future use, when we add a new feature to cache the downloaded patches
- patching-tool: Download the latests patching-tools here, the script will detect the latest version automatically
- tickets: Is where the script will install Liferay for you

See the script usage by typing:

./setup-liferay.sh --help

Before using setup-liferay.sh, put your Liferay username and password in the default.properties file, then
run "./crypt-decrypt enc" to encrypt your password. It's important to choose another password for the encryption

