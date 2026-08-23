# Edge AI feature scope

This scope is based on all ten slides in `detection_sysn12.pptx` and the revised client direction: remove the offline/local inference requirement, do not train a custom model, and prioritize identity, location, exit/return, absence, and accurate timestamps using AWS plus Google Gemini.

## Implemented working scope

| Client need | Edge AI behavior | Cloud implementation |
|---|---|---|
| Secure educator access | Staff sign in before viewing biometric or attendance data | Amazon Cognito; API Gateway JWT authorization |
| Student self-service | Students sign up, verify email, create their own face profile, and see only their attendance | Cognito self-signup, identity-bound `/me` APIs, and Lambda role checks |
| Guided in-app photos | Front camera requests front, left, right, up, and down poses and rejects blur, darkness, occlusion, multiple faces, and incorrect angles | Flutter Camera plus Rekognition `DetectFaces` pose/quality validation |
| Student enrollment | Staff enter a name/roll number and select 5–10 face photographs | Flutter image picker; Lambda validation; Rekognition face collection |
| No custom model training | Enrollment updates the managed identity index; it does not fine-tune a model | Rekognition `IndexFaces` and `AssociateFaces` |
| Continuous frame scanning | Android camera samples and uploads a frame every three seconds | Flutter camera; authenticated API Gateway endpoint |
| Changeable RTSP camera | Staff securely save or replace a LAN RTSP address, preview the stream, and start/stop monitoring | Android VLC RTSP/TCP client and secure credential storage |
| Event visual context | After a matched attendance transition, Gemini records clothing, carried objects, posture, and coarse scene position | Multimodal Gemini call in Lambda with two-minute cooldown and restricted schema |
| Multiple people in one frame | Each detected face is cropped and matched separately | Rekognition `DetectFaces` plus Lambda/Sharp crops and `SearchUsersByImage` |
| Accurate event timestamps | Arrival, movement, exit, and return use server-generated UTC timestamps | Lambda and DynamoDB |
| Location tracking | Automatic mode derives left/center/right from each face position; fixed camera modes identify entrance or exit | Rekognition bounding boxes and DynamoDB session state |
| Left and returned detection | Exit-zone sightings become `LEFT`; a later non-exit match becomes `RETURNED` | State transition logic with unit tests |
| Presence and absence | The live dashboard derives absent students from the enrolled roster and current sightings | DynamoDB roster/session query |
| Per-student history | Staff can open a chronological movement/attendance timeline | DynamoDB timeline records and Flutter timeline screen |
| Live dashboard | Present, absent, left, returned, and last known location refresh every five seconds | Flutter polling of protected API |
| Natural-language questions | Staff ask questions grounded only in authorized session data | Gemini 3.6 Flash invoked server-side by Lambda |
| Data minimization | Raw enrollment photos and scanned frames are processed in memory and not retained | Lambda passes bytes directly to Rekognition |
| Assistant memory | Follow-up questions use the latest 20 messages; complete chat history can be reopened from the app | Cognito-scoped DynamoDB chat and message records |
| PDF knowledge/RAG | Upload a PDF, wait for background indexing, select it in AI, and ask concise grounded questions with page citations | Private S3, Textract, SNS, DynamoDB, `gemini-embedding-001`, and `gemini-3.6-flash` |
| Infrastructure as code | Repeatable backend deployment and local app configuration | AWS CloudFormation and PowerShell deployment scripts |

## Deck features not included in this revised MVP

These appeared in the original offline-first proposal but are outside the client’s revised movement/attendance scope or require separate validation:

- Focused/distracted/inactive engagement classification, gaze, posture, and micro-expression inference.
- Engagement heatmaps, per-student focus scores, and inactivity alerts.
- Automatic PDF reports and Learning Management System integration.
- Multi-camera handoff and 3D spatial tracking.
- Fully offline operation and a local Flask/SQLite/Python inference stack.
- Emotion-aware curriculum recommendations.

The deck’s stated results—98.3% face accuracy, 94.7% engagement accuracy, under-120 ms latency, 50+ classroom deployments, 200 daily educators, 99.6% uptime, and a 38% engagement improvement—are presented without project test evidence in the deck. They must not be represented as achieved Edge AI results until a consented field evaluation produces supporting measurements.

## Production acceptance work

- Pilot with consented participants across actual lighting, camera heights, occlusion, and classroom density; measure false accept and false reject rates.
- Add manual correction, withdrawal/deletion, session creation/closure, roles, audit logging, and a documented biometric retention policy.
- Enable staff MFA and use a dedicated non-root AWS administrative role.
- Add RTSP ingestion through a controlled gateway or Kinesis Video Streams if fixed classroom cameras replace the Android scanner.
- Define institutional alerting and reporting requirements before implementing behavioral analytics.
