storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  # WARNING: TLS is disabled for local development only.
  # Production MUST have tls_disable = "0" with proper cert/key paths configured.
  tls_disable = "1"
}

ui = true
disable_mlock = true
