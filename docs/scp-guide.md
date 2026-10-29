# Service control policies

SCPs set the *maximum* permissions in an account; IAM still has to grant access. They are all deny-lists here (the AWS-managed `FullAWSAccess` stays attached), which keeps them additive and easy to reason about.

| Policy | Attached to | Why |
|---|---|---|
| [`deny-leave-organization`](../policies/scp/deny-leave-organization.json) | Root | An account that leaves the org also leaves every guardrail and the org trail. |
| [`protect-security-services`](../policies/scp/protect-security-services.json) | Root | CloudTrail, Config, GuardDuty, Security Hub, and Access Analyzer can only be changed by the `LandingZoneAdmin` pipeline role. |
| [`region-restriction`](../policies/scp/region-restriction.json.tftpl) | Root | Data residency and a smaller attack surface. Global services (IAM, STS, Route 53, CloudFront, …) are exempt via `NotAction`. Rendered by Terraform from `allowed_regions`. |
| [`deny-root-user`](../policies/scp/deny-root-user.json) | Every OU | Root credentials are break-glass only; MFA on root is still checked by Config. |
| [`data-protection-baseline`](../policies/scp/data-protection-baseline.json) | Workload OUs | Keeps S3 public access block and EBS default encryption on, blocks unencrypted RDS, and stops IAM users / access keys (people use Identity Center). |
| [`sandbox-guardrails`](../policies/scp/sandbox-guardrails.json) | Sandbox OU | No reservations or long-term commitments, small instance types only, no private connectivity into the rest of the estate. |

## Rollout practice

1. Write the policy and test it in the **Sandbox** OU first, or in a dedicated `SCP-Test` OU with one account.
2. Use CloudTrail (`errorCode = AccessDenied` with `errorMessage` mentioning "service control policy") to confirm nothing legitimate breaks.
3. Promote to non-prod OUs, then prod. Never attach a new deny straight to the root.
4. Exempt the pipeline role by ARN pattern (`LandingZoneAdmin`), never by tag; tags are writable by the principals you are trying to restrict.

The management account is never affected by SCPs, so keep workloads out of it entirely.
