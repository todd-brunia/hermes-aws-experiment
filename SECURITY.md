# Experimental security boundary

Hermes can execute commands and read its own configuration, including its OpenAI credential. Treat prompts, downloaded skills, tool outputs, and chat-platform users as inputs to an agent with that authority. Use a dedicated OpenAI project, a dedicated AWS member account, and limited experimental data.

There are no inbound ports, SSH keys, Docker socket mounts, or Bedrock/GitHub credentials. The optional dashboard publishes only on host loopback and requires a generated login, reached through an authenticated Session Manager tunnel. IMDSv2 is required with hop limit 1 to block ordinary bridged-container access to instance credentials; this is defense in depth rather than a complete container escape boundary. Only the host fetches the SSM key. The container has outbound internet access and can use or disclose the key it receives. Operators with host administrator access can read it.

The official image's entrypoint starts as root and drops privileges for Hermes. The bind mount is owned by its runtime UID 10000. `no-new-privileges`, process/memory limits, and log rotation bound some behavior, but this is not a hardened multi-tenant sandbox. Do not mount host credentials or add the runtime user to the host Docker group.

All private account emails, real account configuration, Terraform state/plans, and keys stay outside Git. Terraform account state includes the account email. Root disk encryption protects storage at rest; it does not hide secrets from administrators or the agent. Destroy removes the root disk; backup and restore are deliberate future additions.

CI is credential free, read only, and uses pinned Actions. Cloud changes run under your workstation's AWS identity. Never run unreviewed fork changes with an AWS administrator session.

Report suspected credential disclosure privately to the affected credential owner and revoke the key. Public issues should contain sanitized reproduction details only.
