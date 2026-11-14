# Vault policy for the hashcode-visio AppRole: read its own secrets, nothing else.
#
# Apply (see DEPLOY.md, step 4):
#   vault write sys/policies/acl/hashcode-visio policy=<base64 of this file>

path "secret/data/apps/hashcode-visio" {
  capabilities = ["read"]
}
