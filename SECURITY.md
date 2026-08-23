# Security policy

## Reporting a vulnerability

Do not disclose security or privacy vulnerabilities in a public issue. Use the repository's **Security** tab to open a private GitHub Security Advisory with:

- the affected route, screen or infrastructure resource;
- reproduction steps and impact;
- logs or screenshots with credentials, student data and biometric material removed;
- a suggested remediation, if known.

Do not test against students, real biometric data or infrastructure you do not own or have explicit permission to assess.

## Secrets

The following must never be committed:

- `.edge-ai-cloud.json` and `.edge-ai-google.json`;
- Gemini or Google Cloud API keys;
- AWS access keys or temporary credentials;
- Cognito passwords or tokens;
- Android signing keystores and `key.properties`;
- RTSP usernames/passwords;
- real student images, exported face data, PDFs or attendance records.

The repository `.gitignore` excludes the known local secret and build paths. Run a secret scanner before making the repository public and rotate any credential that has ever entered Git history.

## Deployment expectations

- Use least-privilege AWS identities for deployment and operations.
- Enable administrator MFA.
- Restrict student registration to an approved population.
- Configure alarms and review CloudTrail/CloudWatch logs.
- Establish data retention, access-review, correction and deletion procedures.
- Keep dependencies and the Android target SDK supported and patched.
- Obtain informed consent before storing managed face vectors.

## Supported versions

Security fixes are applied to the latest revision on the default branch. This project does not currently promise maintenance for older APKs or cloud stacks.
