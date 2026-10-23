# TEST datasets

TEST-BASE contains stable non-personal masters. TEST-S is a deterministic synthetic operational dataset.

Deployment and data lifecycle are independent. Use the manual workflow **Manage Supabase TEST dataset**:
- `KEEP`: no data changes.
- `RESET + BASELINE`: removes only registered TEST-S entities and rebuilds TEST-S v1.1.
- `RESET + NOTIFICATIONS`: rebuilds BASELINE and adds exactly one known pending SMTP notification.

The existing Administrador TEST identity is not registered as a TEST-S entity and therefore survives resets.
Never use name prefixes as a deletion criterion.

## TEST-ACCESS: permanent login identities
TEST-ACCESS is independent from TEST-S. Its Personas, roles and Auth accounts survive RESET so the same credentials can be used after every dataset rebuild in both `/develop/` and `/test/` (both use Supabase TEST).

Synthetic accounts: `club.test@yebenes.test`, `coach.test@yebenes.test`, `coach-player.test@yebenes.test`, `tutor.test@yebenes.test`, `player-adult.test@yebenes.test`, `player-minor.test@yebenes.test`, and `multiprofile.test@yebenes.test`. The existing Administrador TEST is not changed.

All TEST-ACCESS accounts use the same password stored only in the GitHub repository secret `TEST_APP_USER_PASSWORD`. The bootstrap also requires `SUPABASE_TEST_SERVICE_ROLE_KEY`; neither secret value belongs in Git, documentation or chat. The workflow is manual and TEST-only.

Before first run, create these GitHub repository secrets:
- `TEST_APP_USER_PASSWORD`
- `SUPABASE_TEST_SERVICE_ROLE_KEY`

Existing secrets reused: `SUPABASE_TEST_DB_URL`, `SUPABASE_TEST_PROJECT_REF`.

Run `Bootstrap Supabase TEST access users` once after the files are merged to `develop`. Re-running is idempotent: it finds users by email, updates the shared password and relinks the deterministic Persona.

## TEST-ACCESS operational matrix (TEST-S v1)

After `RESET -> BASELINE`, the permanent TEST-ACCESS logins are connected to deterministic TEST-S operational cases. Personas/Auth/roles remain permanent; seasonal operational relations are rebuilt by TEST-S.

| Login | Profiles | Operational TEST-S case |
|---|---|---|
| `club.test@yebenes.test` | Club | Club-only administration account |
| `coach.test@yebenes.test` | Coach | Operational coach with season, team assignments and availability |
| `coach-player.test@yebenes.test` | Coach + Player | Senior A player and operational coach |
| `tutor.test@yebenes.test` | Tutor/Family | Active representative of `Jugador Menor TEST Acceso` |
| `player-adult.test@yebenes.test` | Player | Adult Senior B player with active inscription/team |
| `player-minor.test@yebenes.test` | Player | Minor Cadete A player with active inscription/team |
| `multiprofile.test@yebenes.test` | Club + Coach + Player | Senior A player and operational coach, plus Club profile |

All TEST-ACCESS Auth users use the password stored in GitHub secret `TEST_APP_USER_PASSWORD`. Never write that password into the repository.

### Test protocol
Every multi-session test should name: Session/Device A login + selected profile + screen/entity; Session/Device B login + selected profile + exact action; expected silent refresh in A.
