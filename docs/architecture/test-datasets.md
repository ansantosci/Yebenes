# Synthetic datasets for TEST and DEMO

TEST-BASE contains stable non-personal masters. TEST-S is a deterministic synthetic operational dataset.

Deployment and data lifecycle are independent. Use the manual workflow **Manage Supabase TEST dataset**:
- `KEEP`: no data changes.
- `RESET + BASELINE`: removes only registered TEST-S entities and rebuilds TEST-S v1.1.
- `RESET + NOTIFICATIONS`: rebuilds BASELINE and adds exactly one known pending SMTP notification.

The existing Administrador TEST identity is not registered as a TEST-S entity and therefore survives resets.
Never use name prefixes as a deletion criterion.

## DEMO S

DEMO-S is a separate, presentation-ready synthetic dataset. It is intentionally **not** part of the release pipeline and is only operated through the manual workflow `Manage Supabase DEMO dataset`.

- The core DEMO-S baseline never creates Supabase Auth users and never assigns `auth_user_id` to its generated Personas.
- Existing DEMO identities and their data are neither selected nor updated by the seed.
- Each generated row is registered in `private.demo_dataset_entities`; a refresh deletes only those registered rows and then rebuilds them deterministically.
- The dataset adds two synthetic players and one synthetic family per active team, with representative data, inscription states, documents and RRMM cases suitable for a demonstration.
- First rehearse `RESET_AND_LOAD` in TEST from `develop` or `test`. Run it in DEMO only from `main` after writing `MANAGE_DEMO_DATA` as explicit confirmation.

This protects the existing DEMO identities even when the demonstration dataset is refreshed. It is not a mechanism for production data or anonymization.

## DEMO-ACCESS: permanent demo login identities

DEMO-ACCESS mirrors TEST-ACCESS without changing the existing DEMO administrator, club or family accounts. It creates exactly six controlled synthetic identities with `@demo.invalid` addresses: club, coach, coach-player, tutor, adult-player and multiprofile. No synthetic administrator is created. The minor demo case belongs exclusively to the tutor/family flow and has no login.

- The six login Personas, roles, documents and player/coach facets are outside `DEMO-S` and survive a refresh; the tutor-only minor fixture has no authentication account.
- Their Auth users are created only by the manual **Bootstrap Supabase DEMO synthetic access users** workflow, from `main`, after typing `BOOTSTRAP_DEMO_ACCESS`.
- The workflow uses `DEMO_APP_USER_PASSWORD`, `SUPABASE_DEMO_SERVICE_ROLE_KEY`, `SUPABASE_DEMO_PROJECT_REF` and `SUPABASE_DEMO_DB_URL`. Secret values must never enter Git, documentation or chat.
- It refuses to overwrite an account with the same address if that account belongs to a different controlled origin.
- When DEMO-ACCESS exists, `RESET_AND_LOAD` attaches its player-, tutor- and coach-capable identities to a deterministic operational DEMO-S matrix: three login-player inscriptions, one tutor-only minor inscription/representation and three coach season/team assignments.
- Existing DEMO users are neither selected nor updated by this process.

The first use sequence is: deploy migration `050`, run the DEMO-ACCESS bootstrap workflow, then run `Manage Supabase DEMO dataset -> RESET_AND_LOAD` from `main` with `MANAGE_DEMO_DATA`. Re-running either workflow is idempotent.

## TEST-ACCESS: permanent login identities
TEST-ACCESS is independent from TEST-S. Its Personas, roles and Auth accounts survive RESET so the same credentials can be used after every dataset rebuild in both `/develop/` and `/test/` (both use Supabase TEST).

Synthetic accounts: `club.test@yebenes.test`, `coach.test@yebenes.test`, `coach-player.test@yebenes.test`, `tutor.test@yebenes.test`, `player-adult.test@yebenes.test`, and `multiprofile.test@yebenes.test`. The existing Administrador TEST is not changed. Minors are exercised through their tutor/family, never through their own login.

All TEST-ACCESS accounts use the same password stored only in the GitHub repository secret `TEST_APP_USER_PASSWORD`. The bootstrap also requires `SUPABASE_TEST_SERVICE_ROLE_KEY`; neither secret value belongs in Git, documentation or chat. The workflow is manual and TEST-only.

Before first run, create these GitHub repository secrets:
- `TEST_APP_USER_PASSWORD`
- `SUPABASE_TEST_SERVICE_ROLE_KEY`

Existing secrets reused: `SUPABASE_TEST_DB_URL`, `SUPABASE_TEST_PROJECT_REF`.

Run `Bootstrap Supabase TEST access users` once after the files are merged to `develop`. Re-running is idempotent: it finds users by email, updates the shared password, relinks the deterministic Persona and removes only explicitly retired synthetic accounts.

## TEST-ACCESS operational matrix (TEST-S v1)

After `RESET -> BASELINE`, the permanent TEST-ACCESS logins are connected to deterministic TEST-S operational cases. Personas/Auth/roles remain permanent; seasonal operational relations are rebuilt by TEST-S.

| Login | Profiles | Operational TEST-S case |
|---|---|---|
| `club.test@yebenes.test` | Club | Club-only administration account |
| `coach.test@yebenes.test` | Coach | Operational coach with season, team assignments and availability |
| `coach-player.test@yebenes.test` | Coach + Player | Senior A player and operational coach |
| `tutor.test@yebenes.test` | Tutor/Family | Active representative of `Jugador Menor TEST Acceso` |
| `player-adult.test@yebenes.test` | Player | Adult Senior B player with active inscription/team |
| `multiprofile.test@yebenes.test` | Club + Coach + Player | Senior A player and operational coach, plus Club profile |

All TEST-ACCESS Auth users use the password stored in GitHub secret `TEST_APP_USER_PASSWORD`. Never write that password into the repository.

### Test protocol
Every multi-session test should name: Session/Device A login + selected profile + screen/entity; Session/Device B login + selected profile + exact action; expected silent refresh in A.

### TEST-S v1.1 reset hardening
- TEST-ACCESS Personas, Auth links, roles and permanent `jugadores`/`entrenadores` facets are not owned by TEST-S and must survive RESET.
- TEST-S may attach season-scoped operational rows to those permanent facets (inscriptions, coach season, assignments, availability, etc.).
- Before rebuilding coach operational rows, BASELINE normalizes the selected TEST-ACCESS coaches for the active season to avoid natural-key collisions from previous/manual TEST state.
- `private.test_dataset_entities` deliberately excludes permanent TEST-ACCESS `jugadores` and `entrenadores`; only TEST-S-owned rows are registered for cleanup.
