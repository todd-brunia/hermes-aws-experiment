# Future integrations

## Telegram

The initial container is for interactive CLI experiments. When you have a Telegram account, use Telegram's BotFather to create a bot, then follow the current [Hermes messaging-platform guide](https://hermes-agent.nousresearch.com/docs/user-guide/messaging-platforms). Store the bot token privately, allow only your own numeric user ID, and configure the gateway through `sudo docker exec -it hermes hermes setup`.

For unattended use, change the final container command in `user-data.sh.tftpl` from `sleep infinity` to `gateway run` and arrange secure, repeatable Telegram secret delivery before reprovisioning. Review the plan: this user-data change replaces the server and erases the root disk. Telegram polling does not require opening an inbound server port. Preserve configuration outside the disposable server if you need repeatable Telegram setup. Do not enable a public dashboard or API server as part of this change.

## AWS Bedrock

Hermes has a native `bedrock` provider using the boto3 credential chain. Adding it requires reviewing model availability, costs, an exact-model or inference-profile IAM policy, and safe credential delivery to the container. This stack intentionally prevents ordinary container access to host instance credentials. Do not simply raise the metadata hop limit or copy permanent AWS access keys into Hermes. Choose a deliberate workload credential mechanism and a narrowly scoped runtime role before enabling Bedrock.

## GitHub and ai-delivery-orchestrator

Add these as separate integrations after the AWS/OpenAI experiment works. Use narrowly scoped installation credentials or roles. This repository does not grant Hermes access to source repositories, CI credentials, orchestration APIs, or the AWS management account.

## GitHub deployment workflows

CI validates configuration only. A later deployment workflow can use GitHub OIDC, a dedicated role scoped to this stack, and a protected deployment environment. Forks need their own AWS trust configuration. Avoid static AWS keys in GitHub and never let untrusted pull requests mutate cloud infrastructure.
