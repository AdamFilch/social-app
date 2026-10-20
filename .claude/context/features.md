# buttercup features catalog

What the app does today, one entry per feature. Status words: **Built**, **Built (partial)**, **Planned**. Never renumber or rename entries; other documents link to their anchors. New features are appended after the last entry with a matching index row.

## Index

| # | Feature | Status |
|---|---|---|
| 1 | [Accounts and pairing](#1-accounts-and-pairing) | Built |

---

## 1. Accounts and pairing

**Status:** Built

**What it does:** Signs a person in with a six-digit email code, asks for their name, and pairs them with their partner. Once paired, the app opens on the Calling / Notes / Hobbies tab shell with the partner's name on the Calling tab.

**Flow:**
1. Email screen: type an email, "Send code". Supabase emails a six-digit code (locally caught by Mailpit at `http://127.0.0.1:54324`).
2. Code screen: type the code, "Sign in". A wrong or expired code shows "That code didn't work." and stays on the screen.
3. Name screen: type a name, "Continue". Saves `profiles.display_name` and `profiles.time_zone` (from the phone).
4. Pair screen: an invite is created on arrival; "Invite" opens the share sheet with `buttercup://invite/CODE` and "Pair with me on buttercup", and the code is shown as selectable text. The partner opens the link or pastes the code and taps "Pair", which calls `accept_invite`. The inviter's screen refreshes every 5 s and on becoming active, so it moves on once the partner accepts.
5. Ready: each phone sets its own `avatar_tint` to the first NotePaper colour (Blue, Pink, Green, Lilac, Yellow) the partner isn't using; on a collision the later-created profile moves on next launch.
6. Sign out: a button on the Calling tab (and on the Pair screen) returns to the email screen.

**Rules:**
- State: no session → email; empty `display_name` → name; no partner profile visible → pair; otherwise the tab shell. The partner's `profiles` row is only readable once paired (RLS), so its presence decides paired vs unpaired.
- A `buttercup://invite/CODE` link opened while signed out or before the name is set is kept in memory and accepted once the app reaches the Pair screen. Links opened while already paired are ignored.
- Invite errors: `invite_not_found` "That code isn't right.", `invite_expired` "That invite has expired. Ask for a new one.", `invite_used` "That invite was already used.", `cannot_pair_self` "That's your own invite.", `already_paired` "You're already paired."
- Session is stored by `supabase-swift` in the Keychain (`kSecAttrAccessibleAfterFirstUnlock`) and survives relaunch.
- Debug builds talk to local Supabase (`http://127.0.0.1:54321`); Release builds to the hosted project. Set by the `SUPABASE_URL` / `SUPABASE_ANON_KEY` build settings, read from `Info.plist`.
- Failed actions play the `.error` haptic; nothing else has a haptic.

**Code:** `ButtercupKit/Sources/ButtercupKit/SessionStore.swift` (client, `Profile`, `SessionStore`), `Buttercup/Onboarding.swift` (email/code, name, pair screens), `Buttercup/ButtercupApp.swift` (root switch, `onOpenURL`), `Buttercup/ContentView.swift` (`CallingTab`), `Buttercup/Info.plist` (URL scheme, Supabase keys), `supabase/config.toml` + `supabase/templates/code.html` (email code template). Spec: [prds/completed/2-foundation-sign-in-pairing.prd.md](../prds/completed/2-foundation-sign-in-pairing.prd.md).

**Known gaps:**
- Sign in with Apple is not built (needs a paid Apple Developer account).
- No unpairing.
- Screens are plain SwiftUI, not yet restyled to the design system.
