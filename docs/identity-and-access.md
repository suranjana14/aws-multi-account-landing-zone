# Identity and access

## Workforce users: IAM Identity Center
- Users and groups are mastered in the corporate identity provider and provisioned with SCIM. Joiners, movers, and leavers are handled in one place.
- Access = **group × permission set × account**, defined in `modules/identity-center` and reviewed in pull requests.
- Session lengths are short for privileged sets (`PlatformAdmin` 1 h) and longer for read-only.
- No IAM users for people. The `data-protection-baseline` SCP blocks `iam:CreateUser` and `iam:CreateAccessKey` in workload OUs.

## Break-glass
- One IAM user per account is allowed for break-glass, with a hardware MFA token stored offline. The account password policy in `modules/security-baseline` (14+ chars, 24-password history, 90-day rotation) applies to it.
- Root user: MFA on, no access keys, contact details set to a distribution list. Usage raises a CloudTrail metric (`RootAccountUsage`) and a Security Hub finding.

## Workloads
- CI/CD reaches accounts through OIDC federation (GitHub Actions or another CI) into scoped deploy roles. No stored access keys.
- Applications use IAM roles (EC2 instance profiles, ECS task roles, EKS IRSA / Pod Identity).
- IAM Access Analyzer (account analyzer in every account) flags resources shared outside the organization.
