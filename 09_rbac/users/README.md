# README

The script `generate_role_for_user.sh` will generate a config file for a user to
access a specified namespace in K8s. While the user does not need more than the
generated config file (in `$USER-config/$USER.config`), the script also
generates certificates for the user (also saved in `$USER-config/`), gets
them signed by k8s and generates and applies a Role and a RoleBinding.

For now, the script reads the user from env variable `$USER`, all other settings
must be specified at the top of the script as variables.
