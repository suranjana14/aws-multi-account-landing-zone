# Account and OU layout

```
Root  [deny-leave-organization, protect-security-services, region-restriction]
├── Security          [deny-root-user]
│   ├── log-archive        central S3 bucket: CloudTrail, Config, VPC flow logs (KMS, versioned, deny-delete)
│   └── security           delegated admin: GuardDuty, Security Hub, Access Analyzer (org), findings → SNS
├── Infrastructure    [deny-root-user]
│   ├── network            Transit Gateway hub shared via RAM, centralized egress VPC
│   └── shared-services    CI runners, artifact registries, DNS
├── Workloads-Prod    [deny-root-user, data-protection-baseline]
│   └── <app>-prod
├── Workloads-NonProd [deny-root-user, data-protection-baseline]
│   └── <app>-dev, <app>-staging
├── Sandbox           [deny-root-user, sandbox-guardrails]
│   └── <engineer>-sandbox   budget alarm, no TGW attachment
└── Suspended         (closed/quarantined accounts, deny-all can be attached)
```

## Why separate accounts

- **Blast radius.** An account is the strongest isolation boundary AWS offers. A compromised dev role cannot touch prod data.
- **Audit independence.** Logs live in an account the workload teams cannot write to or delete from, which is what auditors ask for first.
- **Billing and quotas.** Cost per environment and team without tagging discipline, and service quotas that do not compete.
- **Least privilege by default.** Guardrails attach to an OU, so a new account inherits them the moment it is moved in.

## How a new workload account is vended

1. Add an entry to `accounts` in the `organization` module (name, email alias, OU). Open a PR.
2. After merge, the pipeline creates the account in the right OU; SCPs apply immediately.
3. The pipeline applies `modules/security-baseline` in the new account (password policy, S3/EBS defaults, Config recorder → log archive, Access Analyzer). GuardDuty and Security Hub enroll it automatically through the delegated admin.
4. Identity Center assignments give the team's group its permission set in the new account.
5. The team attaches its VPC to the shared Transit Gateway (already visible through RAM).
