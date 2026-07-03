#!/usr/bin/env bash
#
# setup.sh — UnDeadJournal one-command setup.
#
#   ./setup.sh              interactive: asks a few questions, then does everything
#   ./setup.sh --defaults   no questions: sensible defaults + random passwords
#
# What it does: checks Docker, writes .env (random passwords), downloads the
# authentic DeadJournal artwork (optional), builds & starts the site, waits for
# first-run setup to finish, and offers to create your account.
#
# Safe to re-run any time (it won't wipe your journal).

set -uo pipefail
cd "$(dirname "$0")" || exit 1

DEFAULTS=0
[ "${1:-}" = "--defaults" ] && DEFAULTS=1

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
die()  { printf '\n\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

ask() { # ask <prompt> <default> -> stdout answer
    local prompt="$1" def="$2" ans
    if [ $DEFAULTS -eq 1 ]; then echo "$def"; return; fi
    read -r -p "$prompt [$def]: " ans </dev/tty || true
    echo "${ans:-$def}"
}

randpass() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20; }

# ------------------------------------------------------------------ docker check
say "UnDeadJournal setup"
if ! command -v docker >/dev/null 2>&1; then
    die "Docker isn't installed. Install Docker Desktop (Mac/Windows) or Docker Engine (Linux):
       https://docs.docker.com/get-docker/   — then run ./setup.sh again."
fi
if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose";
elif command -v docker-compose >/dev/null 2>&1; then COMPOSE="docker-compose";
else die "Docker Compose isn't available. Install/upgrade Docker Desktop, or 'docker-compose'."
fi
docker info >/dev/null 2>&1 || die "Docker is installed but not running. Start Docker Desktop and re-run ./setup.sh."

# ------------------------------------------------------------------ .env
if [ -f .env ]; then
    say "Found an existing .env — keeping your settings and passwords."
    # shellcheck disable=SC1091
    . ./.env
else
    say "A few questions (press Enter to accept the defaults)..."
    SITE_NAME=$(ask "Site name" "DeadJournal")
    HTTP_PORT=$(ask "Port to run on" "8080")
    if [ $DEFAULTS -eq 1 ]; then scope="1"; else
        echo "Who should be able to reach it?"
        echo "  1) Only this computer (safest — you can widen later)"
        echo "  2) Other devices on my home network / this is a home server"
        scope=$(ask "Choose 1 or 2" "1")
    fi
    if [ "$scope" = "2" ]; then
        BIND_ADDR="0.0.0.0"
        host_default="$(hostname 2>/dev/null || echo localhost)"
        HOSTPART=$(ask "Address others will use in the browser (this machine's LAN IP or hostname)" "$host_default")
    else
        BIND_ADDR="127.0.0.1"
        HOSTPART="localhost"
    fi
    SYSTEM_PASSWORD=$(randpass); DB_PASSWORD=$(randpass); DB_ROOT_PASSWORD=$(randpass)
    cat > .env <<EOF
# Written by setup.sh on $(date). Edit and re-run ./setup.sh to apply changes.
SITE_NAME=$SITE_NAME
LJ_DOMAIN=$HOSTPART:$HTTP_PORT
LJ_SITEROOT=http://$HOSTPART:$HTTP_PORT
LJ_SERVERNAME=$HOSTPART
HTTP_PORT=$HTTP_PORT
BIND_ADDR=$BIND_ADDR
LJ_SCHEME=deadjournal
SYSTEM_PASSWORD=$SYSTEM_PASSWORD
DB_PASSWORD=$DB_PASSWORD
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
EOF
    echo ".env written (with freshly generated random passwords)."
fi
# shellcheck disable=SC1091
. ./.env
HTTP_PORT="${HTTP_PORT:-8080}"
SITEURL="http://localhost:$HTTP_PORT"

# ------------------------------------------------------------------ authentic skin
if [ ! -s overlay/htdocs/img/deadjournal_header_01.jpg ]; then
    fetch_skin=$(ask "Download the authentic DeadJournal artwork from the Internet Archive? (recommended) y/n" "y")
    if [ "$fetch_skin" = "y" ] || [ "$fetch_skin" = "Y" ]; then
        bash scripts/fetch-authentic-skin.sh || {
            echo "Artwork download had failures — continuing with the plain classic look."
            echo "You can retry later:  scripts/fetch-authentic-skin.sh  then re-run ./setup.sh"
            sed -i.bak 's/^LJ_SCHEME=.*/LJ_SCHEME=bluewhite/' .env && rm -f .env.bak
        }
    else
        echo "Skipping artwork — using the plain classic-LiveJournal look."
        sed -i.bak 's/^LJ_SCHEME=.*/LJ_SCHEME=bluewhite/' .env && rm -f .env.bak
    fi
else
    echo "Authentic artwork already present."
fi

# ------------------------------------------------------------------ build + start
say "Building the site (first build downloads a lot — 5-15 minutes; later runs are fast)..."
$COMPOSE build web || die "Build failed. Scroll up for the error; re-running ./setup.sh often helps
       (package downloads can be flaky). If it keeps failing, open a GitHub issue with the last lines."

say "Starting..."
$COMPOSE up -d || die "Could not start containers."

say "Waiting for first-run database setup (takes a minute on the very first start)..."
i=0
until $COMPOSE logs web 2>/dev/null | grep -q "starting Apache"; do
    i=$((i+1))
    [ $i -gt 120 ] && die "The site didn't come up after 10 minutes. See logs:  $COMPOSE logs web"
    sleep 5
done

# reachability check
code=$(curl -s -o /dev/null -w "%{http_code}" "$SITEURL/" 2>/dev/null || echo 000)
[ "$code" = "200" ] || echo "(warning: homepage returned HTTP $code — it may need a few more seconds)"

# ------------------------------------------------------------------ first account
if [ $DEFAULTS -eq 0 ]; then
    say "Create your journal account now? (you can also do it later at $SITEURL/create.bml)"
    yn=$(ask "Create account now? y/n" "y")
    if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
        u=$(ask "Username (letters/numbers/underscores, max 15)" "")
        while [ -z "$u" ]; do u=$(ask "Username (required)" ""); done
        printf 'Password (typing is hidden): '
        read -r -s p </dev/tty; echo
        n=$(ask "Display name" "$u")
        e=$(ask "Email" "$u@example.com")
        out=$(curl -s -X POST \
            --data-urlencode "user=$u" --data-urlencode "name=$n" \
            --data-urlencode "password1=$p" --data-urlencode "password2=$p" \
            --data-urlencode "email=$e" "$SITEURL/create.bml")
        if echo "$out" | grep -q "has risen"; then
            echo "Account '$u' created — your journal lives at $SITEURL/users/$u/"
        else
            echo "Couldn't create the account automatically (maybe the name is taken)."
            echo "Just do it in the browser: $SITEURL/create.bml"
        fi
    fi
fi

# ------------------------------------------------------------------ done
say "🪦  UnDeadJournal is up!"
cat <<EOF
   Your site:        $SITEURL
   Sign up:          $SITEURL/create.bml   ("Join the Undead")
   Write an entry:   $SITEURL/update.bml
   Import old posts: ./export-journal  (from deadjournal.com)  then  ./import-journal
   Back it up:       ./backup.sh
   Stop / start:     $COMPOSE down   /   $COMPOSE up -d   (your journal is kept)

   Your admin ('system') and database passwords are saved in .env — keep it safe.
EOF
