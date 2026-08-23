# Contributing to Edge AI

## Before opening a change

1. Do not use real student identities, photographs, camera URLs, credentials or attendance exports in issues, tests or commits.
2. Keep authorization decisions in the backend even when the Flutter UI also hides a feature.
3. Preserve the rule that unknown faces are never sent to Gemini for identification.
4. Update documentation and tests when behavior, routes, infrastructure or data models change.

## Local checks

```powershell
flutter pub get
flutter analyze
flutter test

Push-Location backend
npm ci
npm test
npm audit --omit=dev
Pop-Location

Push-Location ai_service
dart pub get
dart analyze
dart test
Pop-Location
```

Validate CloudFormation when AWS CLI credentials are available:

```powershell
aws cloudformation validate-template --template-body file://infra/aws/template.yaml
```

## Pull requests

- Keep a pull request focused on one behavior or infrastructure concern.
- Explain user-visible behavior, security/privacy impact and verification performed.
- Include screenshots for material UI changes, using synthetic data only.
- Never commit generated APKs, deployment ZIPs, local cloud configuration or secrets.
- Use clear commit subjects such as `feat: add document deletion` or `fix: preserve PDF scope in chat history`.
