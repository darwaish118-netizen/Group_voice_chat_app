require("dotenv").config();

const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { Pool } = require("pg");
const { v4: uuidv4 } = require("uuid");
const crypto = require("crypto");

function containsRestrictedMindoName(value) {
  if (typeof value !== "string") return false;

  const normalized = value
    .normalize("NFKD")
    .toUpperCase()
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[1!|]/g, "I")
    .replace(/0/g, "O")
    .replace(/[^A-Z]/g, "");

  return normalized.includes("MINDO");
}

const app = express();

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 4000;
const JWT_SECRET = process.env.JWT_SECRET || "change-this-secret";

const pool = process.env.DATABASE_URL
  ? new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl:
        process.env.NODE_ENV === "production"
          ? { rejectUnauthorized: false }
          : false,
    })
  : null;

// -------------------------
// Database
// -------------------------

async function initDatabase() {
  if (!pool) {
    console.log("DATABASE_URL is not configured.");
    return;
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      public_uid INTEGER UNIQUE,
      password_hash TEXT NOT NULL,
      avatar_url TEXT,
      display_name VARCHAR(50),
      signature VARCHAR(150),
      birthday DATE,
      coins INTEGER NOT NULL DEFAULT 0,
      level INTEGER NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS public_uid INTEGER
  `);
  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS wallet_frozen BOOLEAN NOT NULL DEFAULT FALSE
  `);

  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS display_name VARCHAR(50)
  `);

  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS signature VARCHAR(150)
  `);

  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS birthday DATE
  `);
await pool.query(`
  ALTER TABLE users
  ADD COLUMN IF NOT EXISTS gender VARCHAR(20)
`);

await pool.query(`
  ALTER TABLE users
  ADD COLUMN IF NOT EXISTS country VARCHAR(100)
`);
  const usersWithoutUid = await pool.query(
    `SELECT id FROM users WHERE public_uid IS NULL`
  );

  for (const existingUser of usersWithoutUid.rows) {
    let newUid;

    while (true) {
      newUid = Math.floor(100000 + Math.random() * 900000);

      const uidCheck = await pool.query(
        `SELECT id FROM users WHERE public_uid = $1`,
        [newUid]
      );

      if (uidCheck.rows.length === 0) {
        break;
      }
    }

    await pool.query(
      `UPDATE users SET public_uid = $1 WHERE id = $2`,
      [newUid, existingUser.id]
    );
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS rooms (
      id UUID PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      password_hash TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      seat_count INTEGER NOT NULL DEFAULT 10
    );
  `);

  await pool.query(`
    ALTER TABLE rooms
    ADD COLUMN IF NOT EXISTS seat_count INTEGER NOT NULL DEFAULT 10
  `);

  await pool.query(`
    ALTER TABLE rooms
    ADD COLUMN IF NOT EXISTS cover_image_url TEXT
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS room_seats (
      id UUID PRIMARY KEY,
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      seat_number INTEGER NOT NULL,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      UNIQUE (room_id, seat_number),
      UNIQUE (user_id)
    )
  `);

  // Public profile social features and room presence (independent of seats).
  await pool.query(`
    CREATE TABLE IF NOT EXISTS room_presence (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      entered_at TIMESTAMP NOT NULL DEFAULT NOW(),
      last_seen TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS room_presence_room_idx ON room_presence(room_id, last_seen DESC)`);
  // Global app presence is separate from room presence. Mobile clients heartbeat
  // while foregrounded; stale rows automatically age out after 90 seconds.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_presence (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      app_state VARCHAR(20) NOT NULL DEFAULT 'active'
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS user_presence_last_seen_idx ON user_presence(last_seen DESC)`);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS room_emoji_reactions (
      id BIGSERIAL PRIMARY KEY,
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      emoji VARCHAR(32) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS room_emoji_reactions_room_id_idx ON room_emoji_reactions(room_id, id)`);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS room_seat_requests (
      id UUID PRIMARY KEY,
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      seat_number INTEGER NOT NULL CHECK (seat_number > 0),
      status VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      decided_at TIMESTAMP,
      decided_by UUID REFERENCES users(id)
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS room_seat_requests_pending_idx ON room_seat_requests(room_id, status, created_at)`);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_follows (
      follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      followed_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      PRIMARY KEY (follower_id, followed_id),
      CHECK (follower_id <> followed_id)
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS user_follows_followed_idx ON user_follows(followed_id)`);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS private_messages (
      id UUID PRIMARY KEY,
      sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      CHECK (sender_id <> recipient_id)
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS private_messages_pair_idx ON private_messages(sender_id, recipient_id, created_at DESC)`);
  await pool.query(`CREATE INDEX IF NOT EXISTS private_messages_recipient_idx ON private_messages(recipient_id, created_at DESC)`);
  await pool.query(`
  CREATE TABLE IF NOT EXISTS room_moderators (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (room_id, user_id)
  )
`);

await pool.query(`
  CREATE TABLE IF NOT EXISTS room_user_blocks (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_by UUID NOT NULL REFERENCES users(id),
    blocked_until TIMESTAMP,
    permanent BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (room_id, user_id)
  )
`);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS room_seat_blocks (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      seat_number INTEGER NOT NULL CHECK (seat_number > 0),
      blocked_by UUID NOT NULL REFERENCES users(id),
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      UNIQUE (room_id, seat_number)
    )
  `);

  // -------------------------
  // Wallet, recharge packages, and transaction ledger
  // -------------------------
  await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS diamonds BIGINT NOT NULL DEFAULT 0`);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS gift_catalog (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      code VARCHAR(80) UNIQUE NOT NULL,
      name VARCHAR(100) NOT NULL,
      image_url TEXT,
      coin_price BIGINT NOT NULL CHECK (coin_price > 0),
      active BOOLEAN NOT NULL DEFAULT TRUE,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS gift_catalog_active_sort_idx ON gift_catalog(active, sort_order)`);
  await pool.query("ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS category VARCHAR(60) NOT NULL DEFAULT 'Popular'");
  await pool.query('ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS svga_url TEXT');
  await pool.query('ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS gif_url TEXT');
  await pool.query('ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS mp4_url TEXT');
  await pool.query('ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS mp3_url TEXT');
  await pool.query('ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS target_counting_percentage NUMERIC(5,2) NOT NULL DEFAULT 100 CHECK (target_counting_percentage BETWEEN 0 AND 100)');
  await pool.query('ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS host_diamond_percentage NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (host_diamond_percentage BETWEEN 0 AND 100)');
  await pool.query(`CREATE TABLE IF NOT EXISTS gift_category_settings (
    category VARCHAR(60) PRIMARY KEY,
    target_counting_percent NUMERIC(5,2) NOT NULL DEFAULT 100 CHECK (target_counting_percent BETWEEN 0 AND 100),
    host_diamond_percent NUMERIC(5,2) NOT NULL DEFAULT 5 CHECK (host_diamond_percent BETWEEN 0 AND 100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS wallet_recharge_packages (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      code VARCHAR(80) UNIQUE NOT NULL,
      title VARCHAR(100) NOT NULL,
      coins INTEGER NOT NULL CHECK (coins > 0),
      bonus_coins INTEGER NOT NULL DEFAULT 0 CHECK (bonus_coins >= 0),
      google_product_id VARCHAR(200),
      apple_product_id VARCHAR(200),
      active BOOLEAN NOT NULL DEFAULT FALSE,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS wallet_transactions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      kind VARCHAR(40) NOT NULL,
      currency VARCHAR(20) NOT NULL,
      amount BIGINT NOT NULL,
      balance_after BIGINT,
      status VARCHAR(20) NOT NULL DEFAULT 'success',
      source VARCHAR(40) NOT NULL,
      external_transaction_id TEXT,
      idempotency_key TEXT UNIQUE,
      details JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS wallet_transactions_user_created_idx ON wallet_transactions(user_id, created_at DESC)`);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS wallet_settings (
      key VARCHAR(100) PRIMARY KEY,
      value JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  // Wealth / Charm levels. Values are cumulative gift coins sent/received,
  // never wallet recharge coins. Thresholds are controlled by the admin.
  await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE`);
  await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_main_admin BOOLEAN NOT NULL DEFAULT FALSE`);
  await pool.query(`UPDATE users SET is_main_admin=TRUE WHERE id=(SELECT id FROM users WHERE is_admin=TRUE ORDER BY created_at ASC LIMIT 1) AND NOT EXISTS (SELECT 1 FROM users WHERE is_main_admin=TRUE)`);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_level_stats (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      wealth_value BIGINT NOT NULL DEFAULT 0 CHECK (wealth_value >= 0),
      charm_value BIGINT NOT NULL DEFAULT 0 CHECK (charm_value >= 0),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS level_config (
      level_type VARCHAR(10) NOT NULL CHECK (level_type IN ('wealth','charm')),
      level_number INTEGER NOT NULL CHECK (level_number BETWEEN 1 AND 110),
      min_coins BIGINT CHECK (min_coins IS NULL OR min_coins >= 0),
      icon_url TEXT,
      entry_effect_key VARCHAR(100),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
      PRIMARY KEY (level_type, level_number)
    )
  `);
  await pool.query(`
    INSERT INTO level_config(level_type, level_number, min_coins)
    SELECT kind, level_no, CASE WHEN level_no = 1 THEN 0 ELSE NULL END
    FROM (VALUES ('wealth'), ('charm')) AS kinds(kind)
    CROSS JOIN generate_series(1, 110) AS levels(level_no)
    ON CONFLICT (level_type, level_number) DO NOTHING
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS level_config_type_threshold_idx ON level_config(level_type, min_coins)`);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS gift_transactions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
      coin_amount BIGINT NOT NULL CHECK (coin_amount > 0),
      status VARCHAR(20) NOT NULL DEFAULT 'success' CHECK (status IN ('pending','success','failed','refunded')),
      idempotency_key TEXT UNIQUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`ALTER TABLE gift_transactions DROP CONSTRAINT IF EXISTS gift_transactions_sender_id_receiver_id_check`);
  await pool.query(`ALTER TABLE gift_transactions ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES rooms(id) ON DELETE SET NULL`);
  await pool.query(`ALTER TABLE gift_transactions ADD COLUMN IF NOT EXISTS gift_id UUID REFERENCES gift_catalog(id) ON DELETE SET NULL`);
  await pool.query(`ALTER TABLE gift_transactions ADD COLUMN IF NOT EXISTS gift_name VARCHAR(100)`);
  await pool.query(`ALTER TABLE gift_transactions ADD COLUMN IF NOT EXISTS quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0)`);
  await pool.query(`CREATE INDEX IF NOT EXISTS gift_transactions_room_created_idx ON gift_transactions(room_id, created_at DESC) WHERE room_id IS NOT NULL`);
  await pool.query(`CREATE INDEX IF NOT EXISTS gift_transactions_sender_created_idx ON gift_transactions(sender_id, created_at DESC)`);
  await pool.query(`CREATE INDEX IF NOT EXISTS gift_transactions_receiver_created_idx ON gift_transactions(receiver_id, created_at DESC)`);
  await pool.query(`
    CREATE OR REPLACE FUNCTION update_user_level_stats_from_gift() RETURNS TRIGGER AS $$
    DECLARE delta BIGINT := 0;
    DECLARE charm_delta BIGINT := 0;
    DECLARE target_pct NUMERIC := 100;
    BEGIN
      IF TG_OP = 'INSERT' THEN
        IF NEW.status = 'success' THEN delta := NEW.coin_amount; END IF;
      ELSE
        IF OLD.status <> 'success' AND NEW.status = 'success' THEN delta := NEW.coin_amount;
        ELSIF OLD.status = 'success' AND NEW.status <> 'success' THEN delta := -OLD.coin_amount;
        ELSIF OLD.status = 'success' AND NEW.status = 'success' AND OLD.coin_amount <> NEW.coin_amount THEN delta := NEW.coin_amount - OLD.coin_amount;
        END IF;
      END IF;
      IF delta <> 0 THEN
        SELECT COALESCE(target_counting_percentage,100) INTO target_pct
        FROM gift_catalog WHERE id = NEW.gift_id;
        charm_delta := FLOOR(delta * COALESCE(target_pct,100) / 100.0);
        INSERT INTO user_level_stats(user_id, wealth_value, charm_value)
        VALUES (NEW.sender_id, GREATEST(delta, 0), 0)
        ON CONFLICT (user_id) DO UPDATE SET wealth_value = GREATEST(0, user_level_stats.wealth_value + delta), updated_at = NOW();
        INSERT INTO user_level_stats(user_id, wealth_value, charm_value)
        VALUES (NEW.receiver_id, 0, GREATEST(charm_delta, 0))
        ON CONFLICT (user_id) DO UPDATE SET charm_value = GREATEST(0, user_level_stats.charm_value + charm_delta), updated_at = NOW();
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
  `);
  await pool.query(`DROP TRIGGER IF EXISTS gift_level_progress_trigger ON gift_transactions`);
  await pool.query(`
    CREATE TRIGGER gift_level_progress_trigger
    AFTER INSERT OR UPDATE ON gift_transactions
    FOR EACH ROW EXECUTE FUNCTION update_user_level_stats_from_gift()
  `);
  // Agency identity and membership foundation. Only approved agencies appear in rankings.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS agencies (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      agency_uid VARCHAR(20) NOT NULL UNIQUE,
      name VARCHAR(20) NOT NULL,
      avatar_url TEXT,
      cover_image_url TEXT,
      country VARCHAR(100) NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','approved','rejected','suspended')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      reviewed_at TIMESTAMPTZ,
      reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS agency_members (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      agency_id UUID NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
      user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      role VARCHAR(20) NOT NULL DEFAULT 'host' CHECK (role IN ('owner','host')),
      status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','left','removed')),
      joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (agency_id, user_id)
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS agency_members_agency_idx ON agency_members(agency_id, status)`);
  // Agency application documents are stored as private upload URLs, never device-local paths.
  await pool.query(`ALTER TABLE agencies ADD COLUMN IF NOT EXISTS phone VARCHAR(40)`);
  await pool.query(`ALTER TABLE agencies ADD COLUMN IF NOT EXISTS address TEXT`);
  await pool.query(`ALTER TABLE agencies ADD COLUMN IF NOT EXISTS admin_public_uid VARCHAR(20)`);
  await pool.query(`ALTER TABLE agencies ADD COLUMN IF NOT EXISTS id_front_url TEXT`);
  await pool.query(`ALTER TABLE agencies ADD COLUMN IF NOT EXISTS id_back_url TEXT`);
  await pool.query(`ALTER TABLE agencies ADD COLUMN IF NOT EXISTS id_front_public_id TEXT`);
  await pool.query(`ALTER TABLE agencies ADD COLUMN IF NOT EXISTS id_back_public_id TEXT`);


  // Deliberately disabled until an authorized admin configures a conversion rate.
  await pool.query(`
    INSERT INTO wallet_settings(key, value)
    VALUES ('diamond_exchange', '{"enabled": false, "diamonds_per_exchange": 0, "coins_per_exchange": 0}'::jsonb)
    ON CONFLICT (key) DO NOTHING
  `);

  console.log("Database initialized.");
}


// -------------------------
// Authentication
// -------------------------

function createToken(user) {
  return jwt.sign(
    {
      id: user.id,
      username: user.username,
    },
    JWT_SECRET,
    {
      expiresIn: "7d",
    }
  );
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({
      message: "Authentication required",
    });
  }

  const token = header.substring(7);

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (error) {
    return res.status(401).json({
      message: "Invalid or expired token",
    });
  }
}

async function adminMiddleware(req, res, next) {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const result = await pool.query(`SELECT is_admin FROM users WHERE id = $1`, [req.user.id]);
    if (!result.rows[0]?.is_admin) {
      return res.status(403).json({ message: "Admin access required" });
    }
    next();
  } catch (error) {
    console.error("Admin authorization failed:", error);
    res.status(500).json({ message: "Could not verify admin access" });
  }
}

async function mainAdminMiddleware(req, res, next) {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const result = await pool.query(`SELECT is_admin,is_main_admin FROM users WHERE id=$1`, [req.user.id]);
    if (!result.rows[0]?.is_admin || !result.rows[0]?.is_main_admin) return res.status(403).json({ message: "Main Admin authorization required" });
    next();
  } catch (error) {
    console.error("Main Admin authorization failed:", error);
    res.status(500).json({ message: "Could not verify Main Admin access" });
  }
}

// -------------------------
// Health
// -------------------------

app.get("/", (req, res) => {
  res.json({
    app: "Group Voice Chat App",
    status: "online",
  });
});

app.get("/health", async (req, res) => {
  if (!pool) {
    return res.json({
      status: "ok",
      database: "not configured",
    });
  }

  try {
    await pool.query("SELECT 1");

    res.json({
      status: "ok",
      database: "connected",
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      database: "disconnected",
    });
  }
});

// -------------------------
// Register
// -------------------------

app.post("/api/auth/register", async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const { username, password } = req.body;

if (containsRestrictedMindoName(username)) {
  return res.status(400).json({
    message: "This username is not allowed. Please choose another name.",
  });
}

    if (!username || !password) {
      return res.status(400).json({
        message: "Username and password are required",
      });
    }

    if (username.length < 3) {
      return res.status(400).json({
        message: "Username must be at least 3 characters",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        message: "Password must be at least 6 characters",
      });
    }

    const existingUser = await pool.query(
      "SELECT id FROM users WHERE username = $1",
      [username]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        message: "Username already exists",
      });
    }

    let publicUid;

    while (true) {
      publicUid =
        Math.floor(100000 + Math.random() * 900000);

      const uidCheck = await pool.query(
        "SELECT id FROM users WHERE public_uid = $1",
        [publicUid]
      );

      if (uidCheck.rows.length === 0) {
        break;
      }
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const id = uuidv4();

    const result = await pool.query(
      `
      INSERT INTO users
      (id, username, public_uid, password_hash)
      VALUES ($1, $2, $3, $4)
      RETURNING
        id,
        username,
        public_uid,
        avatar_url,
        coins,
        diamonds,
        level,
        created_at
      `,
      [
        id,
        username,
        publicUid,
        passwordHash,
      ]
    );

    const user = result.rows[0];

    res.status(201).json({
      user,
      token: createToken(user),
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Registration failed",
    });
  }
});
// One-time Main Admin bootstrap. Requires MAIN_ADMIN_SETUP_KEY in Render env.
// Refuses to run after the first admin exists; public registration never grants admin.
app.post("/api/auth/bootstrap-admin", async (req, res) => {
  if (!pool) return res.status(500).json({ message: "Database is not configured" });
  const configuredKey = process.env.MAIN_ADMIN_SETUP_KEY || "";
  const suppliedKey = String(req.body?.setup_key || "");
  const username = String(req.body?.username || "").trim();
  const password = String(req.body?.password || "");
  if (configuredKey.length < 24) return res.status(503).json({ message: "Main Admin setup is not configured. Set MAIN_ADMIN_SETUP_KEY in Render first." });
  if (suppliedKey.length !== configuredKey.length || !require("crypto").timingSafeEqual(Buffer.from(suppliedKey), Buffer.from(configuredKey))) {
    return res.status(403).json({ message: "Invalid one-time setup key" });
  }
  if (!username || username.length < 3 || username.length > 50 || password.length < 10) {
    return res.status(400).json({ message: "Username must be 3-50 characters and password at least 10 characters" });
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("LOCK TABLE users IN SHARE ROW EXCLUSIVE MODE");
    const admins = await client.query("SELECT id FROM users WHERE is_admin = TRUE LIMIT 1");
    if (admins.rows.length) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "A Main Admin already exists. Ask that admin to authorize additional accounts." });
    }
    const exists = await client.query("SELECT id FROM users WHERE username = $1", [username]);
    if (exists.rows.length) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "Username already exists" });
    }
    let publicUid;
    do { publicUid = Math.floor(100000 + Math.random() * 900000); }
    while ((await client.query("SELECT id FROM users WHERE public_uid = $1", [publicUid])).rows.length);
    const id = uuidv4();
    const passwordHash = await bcrypt.hash(password, 12);
    const created = await client.query(
      `INSERT INTO users (id, username, public_uid, password_hash, is_admin, is_main_admin)
       VALUES ($1, $2, $3, $4, TRUE, TRUE)
       RETURNING id, username, public_uid, avatar_url, coins, diamonds, level, is_admin, is_main_admin, created_at`,
      [id, username, publicUid, passwordHash]
    );
    await client.query("COMMIT");
    const user = created.rows[0];
    return res.status(201).json({ message: "Main Admin account created", user, token: createToken(user) });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Main Admin bootstrap failed:", error);
    return res.status(500).json({ message: "Could not create Main Admin account" });
  } finally { client.release(); }
});

// -------------------------
// Login
// -------------------------

app.post("/api/auth/login", async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        message: "Username and password are required",
      });
    }

    const result = await pool.query(
      "SELECT * FROM users WHERE username = $1",
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        message: "Invalid username or password",
      });
    }

    const user = result.rows[0];

    const validPassword = await bcrypt.compare(
      password,
      user.password_hash
    );

    if (!validPassword) {
      return res.status(401).json({
        message: "Invalid username or password",
      });
    }

    delete user.password_hash;

    res.json({
      user,
      token: createToken(user),
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Login failed",
    });
  }
});

// -------------------------
// Current User
// -------------------------

app.get("/api/me", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    let result = await pool.query(
      `
      SELECT
        id,
        username,
        public_uid,
        avatar_url,
        display_name,
        signature,
        birthday,
        country,
        gender,
        coins,
        level,
        created_at
      FROM users
      WHERE id = $1
      `,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    let user = result.rows[0];

    await pool.query(`INSERT INTO user_level_stats(user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`, [req.user.id]);
    const levelStatsResult = await pool.query(`SELECT wealth_value, charm_value FROM user_level_stats WHERE user_id = $1`, [req.user.id]);
    const levelStats = levelStatsResult.rows[0] || { wealth_value: 0, charm_value: 0 };
    user.wealth_value = Number(levelStats.wealth_value);
    user.charm_value = Number(levelStats.charm_value);
    for (const type of ["wealth", "charm"]) {
      const levelResult = await pool.query(`
        SELECT level_number, icon_url
        FROM level_config
        WHERE level_type = $1 AND min_coins IS NOT NULL AND min_coins <= $2
        ORDER BY level_number DESC LIMIT 1
      `, [type, type === "wealth" ? user.wealth_value : user.charm_value]);
      const selected = levelResult.rows[0] || { level_number: 1, icon_url: null };
      user[`${type}_level`] = Number(selected.level_number);
      user[`${type}_level_icon_url`] = selected.icon_url;
    }

    // Generate a UID if this user does not have one
    if (!user.public_uid) {
      let newUid;

      while (true) {
        newUid =
          Math.floor(100000 + Math.random() * 900000);

        const uidCheck = await pool.query(
          `
          SELECT id
          FROM users
          WHERE public_uid = $1
          `,
          [newUid]
        );

        if (uidCheck.rows.length === 0) {
          break;
        }
      }

      result = await pool.query(
        `
        UPDATE users
        SET public_uid = $1
        WHERE id = $2
        RETURNING
          id,
          username,
          public_uid,
          avatar_url,
          display_name,
          signature,
          birthday,
          coins,
          level,
          created_at
        `,
        [newUid, req.user.id]
      );

      user = { ...user, ...result.rows[0] };
    }

    res.json({
      user,
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not load profile",
    });
  }
});

// -------------------------
// Global app presence and Main Admin live-user / wallet controls
// -------------------------

app.post("/api/presence/heartbeat", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    await pool.query(`
      INSERT INTO user_presence(user_id, last_seen, app_state)
      VALUES($1, NOW(), 'active')
      ON CONFLICT(user_id) DO UPDATE
      SET last_seen=NOW(), app_state='active'
    `, [req.user.id]);
    res.json({ ok: true, last_seen: new Date().toISOString() });
  } catch (error) {
    console.error("Global presence heartbeat failed:", error);
    res.status(500).json({ message: "Could not update online status" });
  }
});

app.delete("/api/presence", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    await pool.query(`DELETE FROM user_presence WHERE user_id=$1`, [req.user.id]);
    res.json({ ok: true });
  } catch (error) {
    console.error("Global presence end failed:", error);
    res.status(500).json({ message: "Could not end online status" });
  }
});

app.get("/api/admin/online-users", authMiddleware, mainAdminMiddleware, async (req, res) => {
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 100, 1), 500);
  try {
    const result = await pool.query(`
      SELECT u.public_uid, u.username, COALESCE(u.display_name,u.username) AS display_name,
             u.avatar_url, up.last_seen,
             r.id AS room_id, r.name AS room_name
      FROM user_presence up
      JOIN users u ON u.id=up.user_id
      LEFT JOIN room_presence rp ON rp.user_id=u.id
        AND rp.last_seen >= NOW()-INTERVAL '90 seconds'
      LEFT JOIN rooms r ON r.id=rp.room_id
      WHERE up.last_seen >= NOW()-INTERVAL '90 seconds'
        AND up.app_state='active'
      ORDER BY up.last_seen DESC
      LIMIT $1
    `, [limit]);
    res.json({ users: result.rows, count: result.rowCount, checked_at: new Date().toISOString(), stale_after_seconds: 90 });
  } catch (error) {
    console.error("Live online users lookup failed:", error);
    res.status(500).json({ message: "Could not load online users" });
  }
});

app.post("/api/admin/wallet/freeze", authMiddleware, mainAdminMiddleware, async (req, res) => {
  const publicUid = String(req.body?.public_uid || "").trim();
  const frozen = req.body?.frozen;
  const reason = String(req.body?.reason || "").trim().slice(0, 240);
  const key = String(req.body?.idempotency_key || "").trim();
  if (!/^[0-9]{1,12}$/.test(publicUid) || typeof frozen !== "boolean" ||
      reason.length < 3 || !/^[A-Za-z0-9:_-]{12,100}$/.test(key)) {
    return res.status(400).json({ message: "Provide valid UID, freeze status, reason and unique request key" });
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const target = await client.query(
      `SELECT id, public_uid, username, coins, wallet_frozen FROM users WHERE public_uid=$1 FOR UPDATE`,
      [Number(publicUid)]
    );
    if (!target.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "User UID not found" });
    }
    const user = target.rows[0];
    const changed = await client.query(
      `UPDATE users SET wallet_frozen=$1 WHERE id=$2
       RETURNING public_uid, username, coins, wallet_frozen`,
      [frozen, user.id]
    );
    const transaction = await client.query(
      `INSERT INTO wallet_transactions
       (user_id,kind,currency,amount,balance_after,status,source,idempotency_key,details)
       VALUES($1,$2,'coin',0,$3,'success','main_admin',$4,$5::jsonb)
       RETURNING id,created_at`,
      [user.id, frozen ? "wallet_frozen" : "wallet_unfrozen", user.coins, key,
       JSON.stringify({ actor_admin_id:req.user.id, public_uid:user.public_uid, reason, frozen })]
    );
    await client.query("COMMIT");
    res.status(200).json({
      message: frozen ? "User wallet frozen" : "User wallet unfrozen",
      transaction_id: transaction.rows[0].id,
      created_at: transaction.rows[0].created_at,
      user: changed.rows[0]
    });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23505") return res.status(409).json({ message: "This wallet control request was already processed" });
    console.error("Main Admin wallet freeze update failed:", error);
    res.status(500).json({ message: "Could not update wallet freeze status" });
  } finally {
    client.release();
  }
});

// -------------------------
// Public Profile Actions: room presence, follow, and private chat
// -------------------------

// Called when a user enters a room. This is intentionally separate from room_seats.
app.post("/api/rooms/:roomId/presence", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const room = await pool.query(`SELECT id, name FROM rooms WHERE id = $1`, [req.params.roomId]);
    if (!room.rows.length) return res.status(404).json({ message: "Room not found" });
    await pool.query(`
      INSERT INTO room_presence(user_id, room_id, entered_at, last_seen)
      VALUES ($1, $2, NOW(), NOW())
      ON CONFLICT (user_id) DO UPDATE
      SET room_id = EXCLUDED.room_id, entered_at = NOW(), last_seen = NOW()
    `, [req.user.id, req.params.roomId]);
    res.json({ message: "Room presence started", room: room.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not start room presence" });
  }
});

app.post("/api/rooms/:roomId/presence/heartbeat", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const result = await pool.query(`UPDATE room_presence SET last_seen = NOW() WHERE user_id = $1 AND room_id = $2 RETURNING user_id`, [req.user.id, req.params.roomId]);
    if (!result.rows.length) return res.status(404).json({ message: "Room presence not found" });
    res.json({ ok: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not refresh room presence" });
  }
});

app.delete("/api/rooms/:roomId/presence", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    await pool.query(`DELETE FROM room_presence WHERE user_id = $1 AND room_id = $2`, [req.user.id, req.params.roomId]);
    res.json({ message: "Room presence ended" });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not end room presence" });
  }
});

app.get("/api/users/:id/track-room", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const result = await pool.query(`
      SELECT r.id, r.name, r.seat_count, r.cover_image_url, owner.public_uid AS owner_public_uid
      FROM room_presence rp
      JOIN rooms r ON r.id = rp.room_id
      JOIN users owner ON owner.id = r.owner_id
      WHERE rp.user_id = $1 AND rp.last_seen >= NOW() - INTERVAL '90 seconds'
      LIMIT 1
    `, [req.params.id]);
    if (!result.rows.length) return res.status(404).json({ message: "User is not in a room right now" });
    res.json({ room: result.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not find user's room" });
  }
});

app.post("/api/users/:id/follow", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  if (req.params.id === req.user.id) return res.status(400).json({ message: "You cannot follow yourself" });
  try {
    const target = await pool.query(`SELECT id FROM users WHERE id = $1`, [req.params.id]);
    if (!target.rows.length) return res.status(404).json({ message: "User not found" });
    const existing = await pool.query(`SELECT 1 FROM user_follows WHERE follower_id = $1 AND followed_id = $2`, [req.user.id, req.params.id]);
    let following;
    if (existing.rows.length) {
      await pool.query(`DELETE FROM user_follows WHERE follower_id = $1 AND followed_id = $2`, [req.user.id, req.params.id]);
      following = false;
    } else {
      await pool.query(`INSERT INTO user_follows(follower_id, followed_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [req.user.id, req.params.id]);
      following = true;
    }
    const counts = await pool.query(`SELECT (SELECT COUNT(*)::int FROM user_follows WHERE followed_id = $1) AS fans_count, (SELECT COUNT(*)::int FROM user_follows WHERE follower_id = $1) AS following_count`, [req.params.id]);
    res.json({ following, ...counts.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not update follow" });
  }
});

app.get("/api/users/:id/follow-status", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const result = await pool.query(`
      SELECT
        EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $1 AND followed_id = $2) AS following,
        (SELECT COUNT(*)::int FROM user_follows WHERE followed_id = $2) AS fans_count,
        (SELECT COUNT(*)::int FROM user_follows WHERE follower_id = $2) AS following_count
    `, [req.user.id, req.params.id]);
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not load follow status" });
  }
});

app.get("/api/chat/:userId/messages", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const result = await pool.query(`
      SELECT pm.id, pm.sender_id, pm.recipient_id, pm.body, pm.created_at,
        sender.display_name AS sender_name, sender.avatar_url AS sender_avatar
      FROM private_messages pm JOIN users sender ON sender.id = pm.sender_id
      WHERE (pm.sender_id = $1 AND pm.recipient_id = $2) OR (pm.sender_id = $2 AND pm.recipient_id = $1)
      ORDER BY pm.created_at ASC LIMIT 500
    `, [req.user.id, req.params.userId]);
    res.json({ messages: result.rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not load chat history" });
  }
});

app.post("/api/chat/:userId/messages", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const body = typeof req.body.body === "string" ? req.body.body.trim() : "";
  if (!body || body.length > 2000) return res.status(400).json({ message: "Message must be between 1 and 2000 characters" });
  if (req.params.userId === req.user.id) return res.status(400).json({ message: "Cannot message yourself" });
  try {
    const recipient = await pool.query(`SELECT id FROM users WHERE id = $1`, [req.params.userId]);
    if (!recipient.rows.length) return res.status(404).json({ message: "User not found" });
    const result = await pool.query(`
      INSERT INTO private_messages(id, sender_id, recipient_id, body) VALUES ($1, $2, $3, $4)
      RETURNING id, sender_id, recipient_id, body, created_at
    `, [uuidv4(), req.user.id, req.params.userId, body]);
    res.status(201).json({ message: result.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not send message" });
  }
});

// -------------------------
// Public User Profile
// -------------------------

app.get("/api/users/:id/profile", async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const result = await pool.query(
      `
      SELECT
        id,
        username,
        public_uid,
        avatar_url,
        display_name,
        signature,
        level,
        COALESCE((SELECT MAX(lc.level_number) FROM level_config lc JOIN user_level_stats uls ON uls.user_id = users.id WHERE lc.level_type = 'wealth' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.wealth_value), 1) AS wealth_level,
        COALESCE((SELECT MAX(lc.level_number) FROM level_config lc JOIN user_level_stats uls ON uls.user_id = users.id WHERE lc.level_type = 'charm' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.charm_value), 1) AS charm_level,
        (SELECT lc.icon_url FROM level_config lc JOIN user_level_stats uls ON uls.user_id = users.id WHERE lc.level_type = 'wealth' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.wealth_value ORDER BY lc.level_number DESC LIMIT 1) AS wealth_level_icon_url,
        (SELECT lc.icon_url FROM level_config lc JOIN user_level_stats uls ON uls.user_id = users.id WHERE lc.level_type = 'charm' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.charm_value ORDER BY lc.level_number DESC LIMIT 1) AS charm_level_icon_url,
        (SELECT COUNT(*)::int FROM user_follows WHERE followed_id = users.id) AS fans_count,
        (SELECT COUNT(*)::int FROM user_follows WHERE follower_id = users.id) AS following_count
      FROM users
      WHERE id = $1
      `,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    res.json({
      user: result.rows[0],
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not load public profile",
    });
  }
});

// -------------------------
// Public Users List
// -------------------------

app.get("/api/users/public", async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const result = await pool.query(`
      SELECT
        id,
        public_uid,
        username,
        display_name,
        avatar_url,
        signature,
        level
      FROM users
      ORDER BY created_at DESC
    `);

    res.json({
      users: result.rows,
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not load users",
    });
  }
});

// -------------------------
// Save Profile Details
// -------------------------

app.put("/api/me/profile", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
const {
  display_name,
  signature,
  birthday,
  country,
  gender,
} = req.body;

    const cleanName =
      display_name?.toString().trim() || null;

    const cleanSignature =
      signature?.toString().trim() || null;

    const cleanBirthday =
      birthday?.toString().trim() || null;

    if (cleanName && cleanName.length > 50) {
      return res.status(400).json({
        message: "Name must be 50 characters or less",
      });
    }

    if (cleanSignature && cleanSignature.length > 150) {
      return res.status(400).json({
        message: "Signature must be 150 characters or less",
      });
    }

    if (cleanBirthday) {
      const birthdayDate = new Date(
        `${cleanBirthday}T00:00:00Z`
      );

      if (Number.isNaN(birthdayDate.getTime())) {
        return res.status(400).json({
          message: "Invalid birthday",
        });
      }
    }
    
const result = await pool.query(
  `
    UPDATE users
    SET
      display_name = $1,
      signature = $2,
      birthday = $3,
      country = $4,
      gender = $5
    WHERE id = $6
    RETURNING
      id,
      username,
      public_uid,
      avatar_url,
      display_name,
      signature,
      birthday,
      country,
      gender,
      coins,
      level,
      created_at
  `,
  [
    cleanName,
    cleanSignature,
    cleanBirthday,
    country?.toString().trim() || null,
    gender?.toString().trim() || null,
    req.user.id,
  ]
);

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    res.json({
      message: "Profile updated successfully",
      user: result.rows[0],
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not update profile",
    });
  }
});

// -------------------------
// Save Profile Avatar
// -------------------------

app.put("/api/me/avatar", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const { avatar_url } = req.body;

    if (!avatar_url) {
      return res.status(400).json({
        message: "Avatar URL is required",
      });
    }

    if (!avatar_url.startsWith("https://res.cloudinary.com/")) {
      return res.status(400).json({
        message: "Invalid avatar URL",
      });
    }

    const result = await pool.query(
      `
      UPDATE users
      SET avatar_url = $1
      WHERE id = $2
      RETURNING
        id,
        username,
        public_uid,
        avatar_url,
        coins,
        level,
        created_at
      `,
      [avatar_url, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    res.json({
      user: result.rows[0],
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not save profile photo",
    });
  }
});

// -------------------------
// Rooms
// -------------------------

app.get("/api/rooms", async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const result = await pool.query(`
  SELECT
    rooms.id,
    rooms.name,
    rooms.owner_id,
    rooms.seat_count,
    rooms.cover_image_url,
    rooms.created_at,
    users.username AS owner_username,
    users.public_uid AS owner_public_uid,
    COALESCE(gifts.total_coins, 0)::BIGINT AS total_coins,
    COALESCE(members.member_count, 0)::INTEGER AS member_count
FROM rooms
JOIN users ON users.id = rooms.owner_id
LEFT JOIN (
  SELECT room_id, SUM(coin_amount) AS total_coins
  FROM gift_transactions WHERE status = 'success' AND room_id IS NOT NULL
  GROUP BY room_id
) gifts ON gifts.room_id = rooms.id
LEFT JOIN (
  SELECT room_id, COUNT(DISTINCT user_id) AS member_count
  FROM room_presence WHERE last_seen >= NOW() - INTERVAL '2 minutes'
  GROUP BY room_id
) members ON members.room_id = rooms.id
ORDER BY total_coins DESC, rooms.created_at DESC
    `);

    res.json({
      rooms: result.rows,
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not load rooms",
    });
  }
});

app.post("/api/rooms", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const existingRoom = await pool.query(
      `
      SELECT id, name
      FROM rooms
      WHERE owner_id = $1
      LIMIT 1
      `,
      [req.user.id]
    );

    if (existingRoom.rows.length > 0) {
      return res.status(409).json({
        message: "You have already created a room. One account can create only one room.",
        room: existingRoom.rows[0],
      });
    }
    const { name, password, seat_count, cover_image_url } = req.body;

if (containsRestrictedMindoName(name)) {
  return res.status(400).json({
    message: "This room name is not allowed. Please choose another name.",
  });
}
    
    const allowedSeats = [5, 10, 15, 20, 25, 30];
const seatCount = Number(seat_count) || 10;

if (!allowedSeats.includes(seatCount)) {
  return res.status(400).json({
    message: "Seat count must be 5, 10, 15, 20, 25 or 30"
  });
}

    if (!name || name.trim().length < 2) {
      return res.status(400).json({
        message: "Room name is required",
      });
    }
    if (
      cover_image_url &&
      !cover_image_url.startsWith("https://res.cloudinary.com/")
    ) {
      return res.status(400).json({
        message: "Invalid room cover URL",
      });
    }
    const roomId = uuidv4();

    let passwordHash = null;

    if (password) {
      passwordHash = await bcrypt.hash(password, 10);
    }

const result = await pool.query(
  `
    INSERT INTO rooms
      (id, name, owner_id, password_hash, seat_count, cover_image_url)
    VALUES ($1, $2, $3, $4, $5, $6)
    RETURNING id, name, owner_id, seat_count, cover_image_url, created_at
  `,
  [
    roomId,
    name.trim(),
    req.user.id,
    passwordHash,
    seatCount,
    cover_image_url || null,
  ]
);


const ownerResult = await pool.query(
    "SELECT public_uid FROM users WHERE id = $1",
    [req.user.id]
);

res.status(201).json({
    room: {
        ...result.rows[0],
        owner_public_uid: ownerResult.rows[0]?.public_uid ?? null,
    },
});
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not create room",
    });
  }
});


// -------------------------
// Secure room gifts and wallet debit
// -------------------------
// Admin gift category and percentage controls. Percentages are copied to each gift
// in the category so gift-send transactions use a stable, server-side snapshot.
app.get("/api/admin/gift-categories", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT c.category,
             COALESCE(s.target_counting_percent, 100) AS target_counting_percent,
             COALESCE(s.host_diamond_percent, 5) AS host_diamond_percent
      FROM (SELECT DISTINCT category FROM gift_catalog UNION SELECT category FROM gift_category_settings) c
      LEFT JOIN gift_category_settings s ON s.category=c.category
      ORDER BY c.category`);
    res.json({ categories: result.rows });
  } catch (error) {
    console.error("Gift categories load failed:", error);
    res.status(500).json({ message: "Could not load gift categories" });
  }
});

app.post("/api/admin/gift-categories", authMiddleware, adminMiddleware, async (req, res) => {
  const category = String(req.body.category || "").trim().slice(0, 60);
  if (!category) return res.status(400).json({ message: "Category name is required" });
  try {
    await pool.query(`INSERT INTO gift_category_settings(category) VALUES($1) ON CONFLICT(category) DO NOTHING`, [category]);
    res.status(201).json({ category });
  } catch (error) {
    console.error("Gift category create failed:", error);
    res.status(500).json({ message: "Could not create gift category" });
  }
});

app.put("/api/admin/gift-categories/:category/settings", authMiddleware, adminMiddleware, async (req, res) => {
  const category = String(req.params.category || "").trim().slice(0, 60);
  const target = Number(req.body.target_counting_percent);
  const diamond = Number(req.body.host_diamond_percent);
  if (!category || !Number.isFinite(target) || target < 0 || target > 100 || !Number.isFinite(diamond) || diamond < 0 || diamond > 100) {
    return res.status(400).json({ message: "Both percentages must be between 0 and 100" });
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const saved = await client.query(`INSERT INTO gift_category_settings(category,target_counting_percent,host_diamond_percent)
      VALUES($1,$2,$3) ON CONFLICT(category) DO UPDATE SET target_counting_percent=EXCLUDED.target_counting_percent,
      host_diamond_percent=EXCLUDED.host_diamond_percent,updated_at=NOW()
      RETURNING category,target_counting_percent,host_diamond_percent`, [category,target,diamond]);
    await client.query(`UPDATE gift_catalog SET target_counting_percentage=$1,host_diamond_percentage=$2,updated_at=NOW() WHERE category=$3`, [target,diamond,category]);
    await client.query("COMMIT");
    res.json({ settings: { category: saved.rows[0].category, target_counting_percent: Number(saved.rows[0].target_counting_percent), host_diamond_percent: Number(saved.rows[0].host_diamond_percent) } });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Gift category settings save failed:", error);
    res.status(500).json({ message: "Could not save gift category settings" });
  } finally { client.release(); }
});

app.post("/api/cloudinary/gift-upload-signature", authMiddleware, adminMiddleware, async (req, res) => {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;
  if (!cloudName || !apiKey || !apiSecret) { console.error("Gift upload signature unavailable: Cloudinary environment variables missing"); return res.status(503).json({ message: "Cloudinary is not configured" }); }
  const kind = String(req.body.kind || "");
  const resourceType = kind === "gift_picture" || kind === "gift_gif" ? "image" : kind === "gift_svga" ? "raw" : kind === "gift_mp4" || kind === "gift_mp3" ? "video" : null;
  if (!resourceType) { console.warn("Gift upload signature rejected unsupported kind:", kind); return res.status(400).json({ message: "Invalid gift media type" }); }
  const timestamp = Math.floor(Date.now() / 1000);
  const folder = "mindo-voice-chat/gifts";
  const params = { folder, timestamp };
  const toSign = Object.keys(params).sort().map(key => `${key}=${params[key]}`).join("&");
  const signature = crypto.createHash("sha1").update(toSign + apiSecret).digest("hex");
  console.info("Gift upload signature issued", { kind, resource_type: resourceType, admin_id: req.user.id });
  res.json({ cloud_name: cloudName, api_key: apiKey, timestamp, folder, signature, resource_type: resourceType });
});

// Main Admin-only coin issuance and audited test-wallet adjustments.
app.get("/api/admin/coin-users", authMiddleware, mainAdminMiddleware, async (req, res) => {
  const q = String(req.query.q || "").trim();
  if (q.length < 2) return res.status(400).json({ message: "Enter at least 2 characters of UID or username" });
  try {
    const result = await pool.query(`SELECT id,public_uid,username,display_name,coins,wallet_frozen FROM users WHERE public_uid::text ILIKE $1 OR username ILIKE $1 OR COALESCE(display_name,'') ILIKE $1 ORDER BY username LIMIT 20`, [`%${q}%`]);
    res.json({ users: result.rows });
  } catch (error) { console.error("Coin user search failed:", error); res.status(500).json({ message: "Could not search users" }); }
});

app.post("/api/admin/coins/adjust", authMiddleware, mainAdminMiddleware, async (req, res) => {
  const publicUid=String(req.body.public_uid||"").trim(), amount=Number(req.body.amount), action=String(req.body.action||"").trim(), reason=String(req.body.reason||"").trim().slice(0,240), key=String(req.body.idempotency_key||"").trim();
  if (!/^[0-9]{1,12}$/.test(publicUid) || !Number.isSafeInteger(amount) || amount<=0 || amount>2000000000 || !["add","deduct"].includes(action) || reason.length<3 || !/^[A-Za-z0-9:_-]{12,100}$/.test(key)) return res.status(400).json({message:"Provide valid UID, positive whole coin amount, action, reason and unique request key"});
  const client=await pool.connect();
  try {
    await client.query("BEGIN");
    const target=await client.query(`SELECT id,public_uid,username,coins FROM users WHERE public_uid=$1 FOR UPDATE`,[Number(publicUid)]);
    if(!target.rowCount){await client.query("ROLLBACK");return res.status(404).json({message:"User UID not found"});}
    const user=target.rows[0], delta=action==="add"?amount:-amount;
    const changed=await client.query(`UPDATE users SET coins=(coins::BIGINT+$1::BIGINT)::INTEGER WHERE id=$2 AND coins::BIGINT+$1::BIGINT BETWEEN 0 AND 2147483647 RETURNING coins`,[delta,user.id]);
    if(!changed.rowCount){await client.query("ROLLBACK");return res.status(409).json({message:"Insufficient user coin balance for deduction"});}
    const tx=await client.query(`INSERT INTO wallet_transactions(user_id,kind,currency,amount,balance_after,status,source,idempotency_key,details) VALUES($1,$2,'coin',$3,$4,'success','main_admin',$5,$6::jsonb) RETURNING id,created_at`,[user.id,action==="add"?"admin_coin_credit":"admin_coin_debit",delta,changed.rows[0].coins,key,JSON.stringify({actor_admin_id:req.user.id,public_uid:user.public_uid,reason,action})]);
    await client.query("COMMIT");
    res.status(201).json({message:action==="add"?"Coins added successfully":"Coins deducted successfully",transaction_id:tx.rows[0].id,created_at:tx.rows[0].created_at,user:{public_uid:user.public_uid,username:user.username,coins:changed.rows[0].coins},amount:delta});
  } catch(error) { await client.query("ROLLBACK"); if(error.code==="23505")return res.status(409).json({message:"This coin adjustment request was already processed"}); console.error("Main Admin coin adjustment failed:",error); res.status(500).json({message:"Could not adjust user coins"}); }
  finally {client.release();}
});

app.get("/api/admin/coins/history", authMiddleware, mainAdminMiddleware, async (req,res)=>{
  const uid=String(req.query.public_uid||"").trim();
  try { const values=[]; let where=`wt.source='main_admin' AND wt.currency='coin'`; if(uid){values.push(uid);where+=` AND u.public_uid::text=$${values.length}`;}
    const result=await pool.query(`SELECT wt.id,u.public_uid,u.username,wt.kind,wt.amount,wt.balance_after,wt.details,wt.created_at FROM wallet_transactions wt JOIN users u ON u.id=wt.user_id WHERE ${where} ORDER BY wt.created_at DESC LIMIT 100`,values);
    res.json({transactions:result.rows});
  } catch(error){console.error("Coin adjustment history failed:",error);res.status(500).json({message:"Could not load coin adjustment history"});}
});

app.get("/api/gifts/catalog", authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, code, name, image_url, svga_url, gif_url, mp4_url, mp3_url, coin_price, category, target_counting_percentage, host_diamond_percentage
       FROM gift_catalog WHERE active = TRUE ORDER BY sort_order, name`
    );
    res.json({ gifts: result.rows });
  } catch (error) {
    console.error("Gift catalog failed:", error);
    res.status(500).json({ message: "Could not load gift catalog" });
  }
});

app.post("/api/admin/gifts", authMiddleware, adminMiddleware, async (req, res) => {
  const code = String(req.body.code || "").trim();
  const name = String(req.body.name || "").trim();
  const imageUrl = String(req.body.image_url || "").trim() || null;
  const category = String(req.body.category || "Popular").trim().slice(0, 60) || "Popular";
  const coinPrice = Number(req.body.coin_price);
  const targetPct = Number(req.body.target_counting_percentage ?? 100);
  const diamondPct = Number(req.body.host_diamond_percentage ?? 0);
  const svgaUrl = String(req.body.svga_url || '').trim() || null;
  const gifUrl = String(req.body.gif_url || '').trim() || null;
  const mp4Url = String(req.body.mp4_url || '').trim() || null;
  const mp3Url = String(req.body.mp3_url || '').trim() || null;
  if (!code || !name || !Number.isSafeInteger(coinPrice) || coinPrice <= 0 || !Number.isFinite(targetPct) || targetPct < 0 || targetPct > 100 || !Number.isFinite(diamondPct) || diamondPct < 0 || diamondPct > 100) {
    return res.status(400).json({ message: "Valid code, name and positive coin_price are required" });
  }
  try {
    const categorySettings = await pool.query(`SELECT target_counting_percent,host_diamond_percent FROM gift_category_settings WHERE category=$1`, [category]);
    const effectiveTargetPct = categorySettings.rowCount ? Number(categorySettings.rows[0].target_counting_percent) : targetPct;
    const effectiveDiamondPct = categorySettings.rowCount ? Number(categorySettings.rows[0].host_diamond_percent) : diamondPct;
    const result = await pool.query(
      `INSERT INTO gift_catalog(code,name,image_url,coin_price,category,active,sort_order,svga_url,gif_url,mp4_url,mp3_url,target_counting_percentage,host_diamond_percentage)
       VALUES($1,$2,$3,$4,$5,TRUE,$6,$7,$8,$9,$10,$11,$12)
       ON CONFLICT(code) DO UPDATE SET name=EXCLUDED.name,image_url=EXCLUDED.image_url,
         coin_price=EXCLUDED.coin_price,category=EXCLUDED.category,svga_url=EXCLUDED.svga_url,gif_url=EXCLUDED.gif_url,mp4_url=EXCLUDED.mp4_url,mp3_url=EXCLUDED.mp3_url,
         target_counting_percentage=EXCLUDED.target_counting_percentage,host_diamond_percentage=EXCLUDED.host_diamond_percentage,
         active=TRUE,sort_order=EXCLUDED.sort_order,updated_at=NOW()
       RETURNING id,code,name,image_url,svga_url,gif_url,mp4_url,mp3_url,coin_price,category,target_counting_percentage,host_diamond_percentage`,
      [code, name, imageUrl, coinPrice, category, Number(req.body.sort_order) || 0, svgaUrl, gifUrl, mp4Url, mp3Url, effectiveTargetPct, effectiveDiamondPct]
    );
    res.status(201).json({ gift: result.rows[0] });
  } catch (error) {
    console.error("Gift upsert failed:", error);
    res.status(500).json({ message: "Could not save gift" });
  }
});

// Admin gift catalogue management: list, edit and safely deactivate gifts.
app.get("/api/admin/gifts", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, code, name, image_url, svga_url, gif_url, mp4_url, mp3_url, coin_price, category, target_counting_percentage, host_diamond_percentage, active, sort_order, created_at, updated_at
       FROM gift_catalog ORDER BY category, sort_order, name`
    );
    const categories = [...new Set(result.rows.map(row => row.category).filter(Boolean))];
    res.json({ gifts: result.rows, categories });
  } catch (error) {
    console.error("Admin gift list failed:", error);
    res.status(500).json({ message: "Could not load admin gift catalogue" });
  }
});

app.patch("/api/admin/gifts/:giftId", authMiddleware, adminMiddleware, async (req, res) => {
  const { giftId } = req.params;
  const allowed = ["code", "name", "image_url", "svga_url", "gif_url", "mp4_url", "mp3_url", "coin_price", "category", "target_counting_percentage", "host_diamond_percentage", "active", "sort_order"];
  const updates = Object.entries(req.body || {}).filter(([key]) => allowed.includes(key));
  if (!updates.length) return res.status(400).json({ message: "No supported gift fields supplied" });
  if (req.body.coin_price !== undefined && (!Number.isSafeInteger(Number(req.body.coin_price)) || Number(req.body.coin_price) <= 0)) {
    return res.status(400).json({ message: "coin_price must be a positive integer" });
  }
  for (const field of ['target_counting_percentage', 'host_diamond_percentage']) {
    if (req.body[field] !== undefined && (!Number.isFinite(Number(req.body[field])) || Number(req.body[field]) < 0 || Number(req.body[field]) > 100)) return res.status(400).json({ message: `${field} must be between 0 and 100` });
  }
  if (req.body.name !== undefined && !String(req.body.name).trim()) {
    return res.status(400).json({ message: "Gift name cannot be empty" });
  }
  try {
    const values = updates.map(([key, value]) => key === "name" || key === "code" || key === "category"
      ? String(value).trim() : key === "coin_price" || key === "sort_order" ? Number(value) : value);
    const setSql = updates.map(([key], index) => `${key}=$${index + 1}`).join(", ");
    const result = await pool.query(
      `UPDATE gift_catalog SET ${setSql}, updated_at=NOW() WHERE id=$${values.length + 1}
       RETURNING id, code, name, image_url, svga_url, gif_url, mp4_url, mp3_url, coin_price, category, target_counting_percentage, host_diamond_percentage, active, sort_order`,
      [...values, giftId]
    );
    if (!result.rowCount) return res.status(404).json({ message: "Gift not found" });
    res.json({ gift: result.rows[0] });
  } catch (error) {
    if (error.code === "23505") return res.status(409).json({ message: "Gift code already exists" });
    console.error("Admin gift update failed:", error);
    res.status(500).json({ message: "Could not update gift" });
  }
});

app.delete("/api/admin/gifts/:giftId", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE gift_catalog SET active=FALSE, updated_at=NOW() WHERE id=$1
       RETURNING id, code, name, active`, [req.params.giftId]
    );
    if (!result.rowCount) return res.status(404).json({ message: "Gift not found" });
    res.json({ gift: result.rows[0], message: "Gift deactivated; transaction history is preserved" });
  } catch (error) {
    console.error("Admin gift deactivation failed:", error);
    res.status(500).json({ message: "Could not deactivate gift" });
  }
});

app.post("/api/gifts/send", authMiddleware, async (req, res) => {
  const giftId = String(req.body.gift_id || "").trim();
  const roomId = String(req.body.room_id || "").trim();
  const idempotencyKey = String(req.body.idempotency_key || "").trim();
  const quantity = Number.parseInt(req.body.quantity ?? "1", 10);
  const receiverUids = Array.isArray(req.body.receiver_uids)
    ? [...new Set(req.body.receiver_uids.map(value => String(value).trim()).filter(Boolean))]
    : [String(req.body.receiver_uid || "").trim()].filter(Boolean);

  if (!giftId || !roomId || !idempotencyKey || idempotencyKey.length > 100 ||
      !receiverUids.length || receiverUids.length > 25 ||
      !Number.isInteger(quantity) || quantity < 1 || quantity > 177) {
    return res.status(400).json({ message: "A gift, room, 1-25 recipients, quantity (1-177) and idempotency key are required" });
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const giftResult = await client.query(
      `SELECT id, coin_price, name, target_counting_percentage, host_diamond_percentage FROM gift_catalog WHERE id=$1 AND active=TRUE`, [giftId]
    );
    if (!giftResult.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Gift is unavailable" });
    }
    const receivers = await client.query(
      `SELECT id, public_uid FROM users WHERE public_uid::text = ANY($1::text[]) FOR UPDATE`,
      [receiverUids]
    );
    if (receivers.rowCount !== receiverUids.length) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "One or more recipients were not found" });
    }
    const receiverIds = receivers.rows.map(row => row.id);
    const presence = await client.query(
      `SELECT user_id FROM room_presence
       WHERE room_id=$1 AND user_id = ANY($2::uuid[])
         AND last_seen > NOW()-INTERVAL '2 minutes'`,
      [roomId, [req.user.id, ...receiverIds]]
    );
    const presentIds = new Set(presence.rows.map(row => row.user_id));
    if (!presentIds.has(req.user.id) || receiverIds.some(id => !presentIds.has(id))) {
      await client.query("ROLLBACK");
      return res.status(403).json({ message: "Sender and all selected recipients must be present in this room" });
    }
    const price = Number(giftResult.rows[0].coin_price);
    const perRecipient = price * quantity;
    const totalDebit = perRecipient * receiverIds.length;
    if (!Number.isSafeInteger(totalDebit) || totalDebit <= 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Gift total is outside the supported range" });
    }
    // Match the exact per-recipient keys; LIKE would treat '%' and '_' in a
    // caller-supplied idempotency key as wildcards.
    const recipientKeys = receiverIds.map(id => `${idempotencyKey}:${id}`);
    const existing = await client.query(
      `SELECT id, sender_id, receiver_id, coin_amount, status, gift_id, gift_name, quantity, created_at
       FROM gift_transactions WHERE idempotency_key = ANY($1::text[])`,
      [recipientKeys]
    );
    if (existing.rowCount) {
      if (existing.rows.some(row =>
            row.sender_id !== req.user.id ||
            row.gift_id !== giftId ||
            Number(row.quantity) !== quantity) ||
          existing.rowCount !== receiverIds.length ||
          new Set(existing.rows.map(row => row.receiver_id)).size !== receiverIds.length) {
        await client.query("ROLLBACK");
        return res.status(409).json({ message: "Idempotency key already used or incomplete" });
      }
      const replayDebit = existing.rows.reduce((sum, row) => sum + Number(row.coin_amount), 0);
      await client.query("COMMIT");
      return res.json({
        duplicate: true,
        transactions: existing.rows,
        quantity,
        recipient_count: existing.rowCount,
        total_debit: replayDebit,
        animation_mode: quantity === 1 ? "individual" : "combined"
      });
    }
    const debit = await client.query(
      `UPDATE users SET coins=coins-$1
       WHERE id=$2 AND coins >= $1 AND wallet_frozen=FALSE
       RETURNING coins`,
      [totalDebit, req.user.id]
    );
    if (!debit.rowCount) {
      const walletState = await client.query(`SELECT wallet_frozen FROM users WHERE id=$1`, [req.user.id]);
      await client.query("ROLLBACK");
      if (walletState.rows[0]?.wallet_frozen) {
        return res.status(423).json({ message: "Your wallet is frozen by Main Admin. Coin spending is disabled." });
      }
      return res.status(402).json({ message: "Insufficient coin balance" });
    }
    const transactions = [];
    for (const receiver of receivers.rows) {
      const transaction = await client.query(
        `INSERT INTO gift_transactions
         (sender_id,receiver_id,room_id,coin_amount,status,idempotency_key,gift_id,gift_name,quantity)
         VALUES($1,$2,$3,$4,'success',$5,$6,$7,$8)
         RETURNING id,sender_id,receiver_id,room_id,coin_amount,status,gift_id,gift_name,quantity,created_at`,
        [req.user.id, receiver.id, roomId, perRecipient, `${idempotencyKey}:${receiver.id}`,
         giftId, giftResult.rows[0].name, quantity]
      );
      transactions.push(transaction.rows[0]);
      // Global charm/host target is counted once by gift_level_progress_trigger.
      // Credit host diamonds atomically with the sender debit and gift record.
      // Formula: gift coins x target-counting % x host-diamond %.
      const diamondCredit = Math.floor(
        Number(perRecipient) * Number(giftResult.rows[0].target_counting_percentage) *
        Number(giftResult.rows[0].host_diamond_percentage) / 10000
      );
      if (diamondCredit > 0) {
        const credited = await client.query(
          `UPDATE users SET diamonds=diamonds+$1 WHERE id=$2 RETURNING diamonds`,
          [diamondCredit, receiver.id]
        );
        await client.query(
          `INSERT INTO wallet_transactions(user_id,kind,currency,amount,balance_after,status,source,idempotency_key,details)
           VALUES($1,'gift_income','diamonds',$2,$3,'success','gift',$4,$5::jsonb)`,
          [receiver.id, diamondCredit, credited.rows[0].diamonds,
           `gift-income:${idempotencyKey}:${receiver.id}`,
           JSON.stringify({ gift_id: giftId, gift_name: giftResult.rows[0].name,
             sender_id: req.user.id, room_id: roomId, coin_amount: perRecipient,
             target_counting_percentage: Number(giftResult.rows[0].target_counting_percentage),
             target_counted_coins: targetCountedCoins,
             host_diamond_percentage: Number(giftResult.rows[0].host_diamond_percentage) })]
        );
      }
    }
    await client.query(
      `INSERT INTO wallet_transactions(user_id,kind,currency,amount,balance_after,status,source,idempotency_key,details)
       VALUES($1,'gift_spend','coin',$2,$3,'success','gift',$4,$5::jsonb)`,
      [req.user.id, -totalDebit, debit.rows[0].coins, `gift:${idempotencyKey}`,
       JSON.stringify({ gift_id: giftId, gift_name: giftResult.rows[0].name, receiver_ids: receiverIds, room_id: roomId, quantity, recipient_count: receiverIds.length })]
    );
    await client.query("COMMIT");
    res.status(201).json({ transactions, balance: debit.rows[0].coins, quantity, recipient_count: receiverIds.length, total_debit: totalDebit, animation_mode: quantity === 1 ? "individual" : "combined", target_counting_percentage: Number(giftResult.rows[0].target_counting_percentage), target_counted_coins_total: Math.floor(perRecipient * receiverIds.length * Number(giftResult.rows[0].target_counting_percentage) / 100), host_diamond_percentage: Number(giftResult.rows[0].host_diamond_percentage) });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23505") return res.status(409).json({ message: "Duplicate gift request" });
    console.error("Gift send failed:", error);
    res.status(500).json({ message: "Could not send gift" });
  } finally {
    client.release();
  }
});


app.get("/api/rooms/:roomId/gifts/events", authMiddleware, async (req, res) => {
  const roomId = String(req.params.roomId || "").trim();
  try {
    const presence = await pool.query(
      `SELECT 1 FROM room_presence
       WHERE room_id=$1 AND user_id=$2
         AND last_seen > NOW()-INTERVAL '2 minutes' LIMIT 1`,
      [roomId, req.user.id]
    );
    if (!presence.rowCount) {
      return res.status(403).json({ message: "You must be present in this room to view gift events" });
    }
    const result = await pool.query(
      `SELECT gt.id, gt.sender_id, gt.receiver_id, gt.coin_amount,
              gt.gift_name, gt.quantity, gt.created_at,
              su.display_name AS sender_name, su.username AS sender_username,
              su.public_uid AS sender_uid, su.avatar_url AS sender_avatar,
              ru.display_name AS receiver_name, ru.username AS receiver_username,
              ru.public_uid AS receiver_uid, ru.avatar_url AS receiver_avatar,
              gc.image_url AS gift_image, gc.svga_url, gc.gif_url, gc.mp4_url, gc.mp3_url, gc.coin_price
       FROM gift_transactions gt
       JOIN users su ON su.id=gt.sender_id
       JOIN users ru ON ru.id=gt.receiver_id
       LEFT JOIN gift_catalog gc ON gc.id=gt.gift_id
       WHERE gt.room_id=$1 AND gt.status='success'
         AND gt.created_at > NOW()-INTERVAL '60 seconds'
       ORDER BY gt.created_at DESC
       LIMIT 30`,
      [roomId]
    );
    res.json({ events: result.rows });
  } catch (error) {
    console.error("Room gift events failed:", error);
    res.status(500).json({ message: "Could not load room gift events" });
  }
});

// Signed Cloudinary uploads. Agency identity documents use authenticated delivery.


app.post("/api/cloudinary/agency-upload-signature", authMiddleware, async (req, res) => {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;
  if (!cloudName || !apiKey || !apiSecret) {
    return res.status(503).json({ message: "Cloudinary is not configured" });
  }
  const kind = String(req.body.kind || "");
  if (!["agency_avatar", "agency_id_front", "agency_id_back"].includes(kind)) {
    return res.status(400).json({ message: "Invalid agency upload type" });
  }
  const timestamp = Math.floor(Date.now() / 1000);
  const folder = kind === "agency_avatar"
    ? `mindo-voice-chat/agencies/${req.user.id}`
    : `mindo-voice-chat/private-agency-ids/${req.user.id}`;
  const type = kind === "agency_avatar" ? "upload" : "authenticated";
  const params = { folder, timestamp, type };
  const toSign = Object.keys(params).sort().map(key => `${key}=${params[key]}`).join("&");
  const signature = crypto.createHash("sha1").update(toSign + apiSecret).digest("hex");
  res.json({ cloud_name: cloudName, api_key: apiKey, timestamp, folder, type, signature });
});

// -------------------------
// Agency applications and main-admin review
// -------------------------
app.post("/api/agencies", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const name = String(req.body.name || "").trim();
  const country = String(req.body.country || "").trim();
  const phone = String(req.body.phone || "").trim();
  const address = String(req.body.address || "").trim();
  const avatarUrl = String(req.body.avatar_url || "").trim();
  const idFrontPublicId = String(req.body.id_front_public_id || "").trim();
  const idBackPublicId = String(req.body.id_back_public_id || "").trim();
  const adminPublicUid = String(req.body.admin_public_uid || "").trim() || null;
  const isHttpUrl = value => /^https?:\/\//i.test(value);
  const privateAgencyFolder = `mindo-voice-chat/private-agency-ids/${req.user.id}/`;
  const isPrivateAgencyDocument = value =>
    value.startsWith(privateAgencyFolder) &&
    !value.includes("..") && !value.includes("\\");
  if (!name || name.length > 20 || !country || !phone || !address ||
      !isHttpUrl(avatarUrl) || !isPrivateAgencyDocument(idFrontPublicId) ||
      !isPrivateAgencyDocument(idBackPublicId) || idFrontPublicId === idBackPublicId) {
    return res.status(400).json({ message: "Name (max 20), country, phone, address and uploaded image URLs are required" });
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const existing = await client.query("SELECT id FROM agencies WHERE owner_id = $1", [req.user.id]);
    if (existing.rowCount) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "One account can create only one agency" });
    }
    const uid = String(Math.floor(100000 + Math.random() * 900000));
    const created = await client.query(`
      INSERT INTO agencies (owner_id, agency_uid, name, avatar_url, country, phone, address,
        admin_public_uid, id_front_public_id, id_back_public_id, status)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending') RETURNING *
    `, [req.user.id, uid, name, avatarUrl, country, phone, address, adminPublicUid, idFrontPublicId, idBackPublicId]);
    await client.query(`INSERT INTO agency_members (agency_id, user_id, role, status)
      VALUES ($1,$2,'owner','active')`, [created.rows[0].id, req.user.id]);
    await client.query("COMMIT");
    return res.status(201).json({ agency: created.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Agency application failed:", error);
    return res.status(500).json({ message: "Could not submit agency application" });
  } finally { client.release(); }
});

app.get("/api/agencies/me", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const result = await pool.query(`SELECT a.* FROM agencies a WHERE a.owner_id = $1`, [req.user.id]);
    res.json({ agency: result.rows[0] || null });
  } catch (error) { console.error(error); res.status(500).json({ message: "Could not load agency" }); }
});

app.get("/api/agencies", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const q = String(req.query.search || "").trim();
  try {
    const result = await pool.query(`SELECT a.id, a.name, a.agency_uid, a.avatar_url, a.cover_image_url,
      a.country, a.status, COUNT(am.user_id)::INT AS members
      FROM agencies a LEFT JOIN agency_members am ON am.agency_id = a.id AND am.status = 'active'
      WHERE a.status = 'approved' AND ($1 = '' OR a.agency_uid ILIKE $2 OR a.name ILIKE $2)
      GROUP BY a.id ORDER BY a.name LIMIT 100`, [q, `%${q}%`]);
    res.json({ agencies: result.rows });
  } catch (error) { console.error(error); res.status(500).json({ message: "Could not load agencies" }); }
});

app.get("/api/admin/agencies/pending", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(`SELECT a.*, u.username AS owner_username, u.public_uid AS owner_public_uid
      FROM agencies a JOIN users u ON u.id = a.owner_id WHERE a.status = 'pending' ORDER BY a.created_at`);
    res.json({ agencies: result.rows });
  } catch (error) { console.error(error); res.status(500).json({ message: "Could not load pending agencies" }); }
});

// Admin-only identity document metadata for the review dashboard. Never expose these IDs publicly.
app.get("/api/admin/agencies/:agencyId/documents", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(`SELECT id, agency_uid, name, id_front_public_id, id_back_public_id
      FROM agencies WHERE id = $1`, [req.params.agencyId]);
    if (!result.rowCount) return res.status(404).json({ message: "Agency not found" });
    res.json({ documents: {
      agency_id: result.rows[0].id,
      agency_uid: result.rows[0].agency_uid,
      agency_name: result.rows[0].name,
      id_front_public_id: result.rows[0].id_front_public_id,
      id_back_public_id: result.rows[0].id_back_public_id,
      delivery: "authenticated_private_cloudinary"
    }});
  } catch (error) {
    console.error("Agency document lookup failed:", error);
    res.status(500).json({ message: "Could not load agency documents" });
  }
});

app.post("/api/admin/agencies/:agencyId/review", authMiddleware, adminMiddleware, async (req, res) => {
  const decision = String(req.body.decision || "").toLowerCase();
  if (!["approved", "rejected"].includes(decision)) return res.status(400).json({ message: "decision must be approved or rejected" });
  try {
    const result = await pool.query(`UPDATE agencies SET status = $1, reviewed_at = NOW(), reviewed_by = $2
      WHERE id = $3 AND status = 'pending' RETURNING *`, [decision, req.user.id, req.params.agencyId]);
    if (!result.rowCount) return res.status(404).json({ message: "Pending agency not found" });
    res.json({ agency: result.rows[0] });
  } catch (error) { console.error(error); res.status(500).json({ message: "Could not review agency" }); }
});

// -------------------------
// Approved agency rankings: gifts received by active agency hosts.
// -------------------------
app.get("/api/rankings/agencies", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const period = String(req.query.period || "daily").toLowerCase();
  if (!["daily", "weekly", "monthly"].includes(period)) {
    return res.status(400).json({ message: "period must be daily, weekly or monthly" });
  }
  const dateFilter = period === "daily" ? "date_trunc('day', NOW())"
    : period === "weekly" ? "date_trunc('week', NOW())" : "date_trunc('month', NOW())";
  try {
    const result = await pool.query(`
      SELECT a.id, a.name, a.agency_uid, a.avatar_url, a.cover_image_url, a.country,
        COALESCE(SUM(gt.coin_amount), 0)::BIGINT AS total_coins
      FROM agencies a
      LEFT JOIN agency_members am ON am.agency_id = a.id AND am.status = 'active'
      LEFT JOIN gift_transactions gt ON gt.receiver_id = am.user_id
        AND gt.status = 'success' AND gt.created_at >= ${dateFilter}
      WHERE a.status = 'approved'
      GROUP BY a.id
      ORDER BY total_coins DESC, a.created_at ASC
      LIMIT 100
    `);
    res.json({ period, ranking: result.rows });
  } catch (error) {
    console.error("Agency ranking failed:", error);
    res.status(500).json({ message: "Could not load agency ranking" });
  }
});

// -------------------------
// Global room rankings (gift coins sent in each room)
// -------------------------
app.get("/api/rankings/rooms", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const period = String(req.query.period || "daily").toLowerCase();
  if (!["daily", "weekly", "monthly"].includes(period)) {
    return res.status(400).json({ message: "period must be daily, weekly or monthly" });
  }
  const dateFilter = period === "daily"
    ? "date_trunc('day', NOW())"
    : period === "weekly"
      ? "date_trunc('week', NOW())"
      : "date_trunc('month', NOW())";
  try {
    const result = await pool.query(`
      SELECT r.id, r.name, r.owner_id, r.seat_count, r.cover_image_url,
        u.public_uid AS owner_public_uid,
        COALESCE(SUM(gt.coin_amount), 0)::BIGINT AS total_coins,
        COUNT(DISTINCT rp.user_id)::INTEGER AS member_count
      FROM rooms r
      JOIN users u ON u.id = r.owner_id
      LEFT JOIN gift_transactions gt ON gt.room_id = r.id
        AND gt.status = 'success' AND gt.created_at >= ${dateFilter}
      LEFT JOIN room_presence rp ON rp.room_id = r.id AND rp.last_seen >= NOW() - INTERVAL '2 minutes'
      GROUP BY r.id, u.public_uid
      ORDER BY total_coins DESC, r.created_at ASC
      LIMIT 100
    `);
    res.json({ period, ranking: result.rows });
  } catch (error) {
    console.error("Global room ranking failed:", error);
    res.status(500).json({ message: "Could not load global room ranking" });
  }
});

// -------------------------
// Global user Wealth / Charm rankings
// -------------------------
app.get("/api/rankings/users", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const category = String(req.query.category || "wealth").toLowerCase();
  const period = String(req.query.period || "daily").toLowerCase();
  if (!["wealth", "charm"].includes(category)) {
    return res.status(400).json({ message: "category must be wealth or charm" });
  }
  if (!["daily", "weekly", "monthly"].includes(period)) {
    return res.status(400).json({ message: "period must be daily, weekly or monthly" });
  }
  const dateFilter = period === "daily"
    ? "date_trunc('day', NOW())"
    : period === "weekly"
      ? "date_trunc('week', NOW())"
      : "date_trunc('month', NOW())";
  const userColumn = category === "wealth" ? "gt.sender_id" : "gt.receiver_id";
  try {
    const result = await pool.query(`
      SELECT u.id, u.username, u.display_name, u.avatar_url, u.public_uid,
        COALESCE(SUM(gt.coin_amount), 0)::BIGINT AS total_coins
      FROM gift_transactions gt
      JOIN users u ON u.id = ${userColumn}
      WHERE gt.status = 'success' AND gt.created_at >= ${dateFilter}
      GROUP BY u.id
      ORDER BY total_coins DESC, u.created_at ASC
      LIMIT 100
    `);
    res.json({ category, period, ranking: result.rows });
  } catch (error) {
    console.error("Global user ranking failed:", error);
    res.status(500).json({ message: "Could not load global user ranking" });
  }
});

// -------------------------
// Room Wealth / Charm rankings
// -------------------------
app.get("/api/rooms/:roomId/rankings", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const { roomId } = req.params;
  const category = String(req.query.category || "wealth").toLowerCase();
  const period = String(req.query.period || "daily").toLowerCase();
  if (!["wealth", "charm"].includes(category)) {
    return res.status(400).json({ message: "category must be wealth or charm" });
  }
  if (!["daily", "weekly", "monthly"].includes(period)) {
    return res.status(400).json({ message: "period must be daily, weekly or monthly" });
  }
  const dateFilter = period === "daily"
    ? "date_trunc('day', NOW())"
    : period === "weekly"
      ? "date_trunc('week', NOW())"
      : "date_trunc('month', NOW())";
  const userColumn = category === "wealth" ? "gt.sender_id" : "gt.receiver_id";
  try {
    const room = await pool.query("SELECT id FROM rooms WHERE id = $1", [roomId]);
    if (room.rows.length === 0) return res.status(404).json({ message: "Room not found" });
    const result = await pool.query(`
      SELECT u.id, u.username, u.display_name, u.avatar_url, u.public_uid,
        COALESCE(SUM(gt.coin_amount), 0)::BIGINT AS total_coins
      FROM gift_transactions gt
      JOIN users u ON u.id = ${userColumn}
      WHERE gt.room_id = $1 AND gt.status = 'success'
        AND gt.created_at >= ${dateFilter}
      GROUP BY u.id
      ORDER BY total_coins DESC, u.created_at ASC
      LIMIT 100
    `, [roomId]);
    res.json({ room_id: roomId, category, period, ranking: result.rows });
  } catch (error) {
    console.error("Room ranking failed:", error);
    res.status(500).json({ message: "Could not load room ranking" });
  }
});

// -------------------------
// Room Members / Seats
// -------------------------

// Room reactions are separate events and are never inserted into room chat.
app.post("/api/rooms/:roomId/reactions", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const emoji = String(req.body?.emoji || '').trim();
    if (!emoji || [...emoji].length > 8) return res.status(400).json({ message: "Choose a valid emoji" });
    const room = await pool.query(`SELECT id FROM rooms WHERE id = $1`, [req.params.roomId]);
    if (!room.rows.length) return res.status(404).json({ message: "Room not found" });
    const present = await pool.query(`SELECT 1 FROM room_presence WHERE room_id = $1 AND user_id = $2 AND last_seen > NOW() - INTERVAL '2 minutes'`, [req.params.roomId, req.user.id]);
    if (!present.rows.length) return res.status(403).json({ message: "Enter the room before sending a reaction" });
    const result = await pool.query(`INSERT INTO room_emoji_reactions(room_id,user_id,emoji) VALUES($1,$2,$3) RETURNING id, user_id, emoji, created_at`, [req.params.roomId, req.user.id, emoji]);
    res.status(201).json({ reaction: result.rows[0] });
  } catch (error) { console.error('Room reaction create error:', error); res.status(500).json({ message: "Could not send room reaction" }); }
});

app.get("/api/rooms/:roomId/reactions", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const afterId = Math.max(0, Number.parseInt(req.query.afterId || '0', 10) || 0);
    const result = await pool.query(`
      SELECT r.id, r.user_id, r.emoji, r.created_at
      FROM room_emoji_reactions r
      JOIN room_presence p ON p.room_id = r.room_id AND p.user_id = $2 AND p.last_seen > NOW() - INTERVAL '2 minutes'
      WHERE r.room_id = $1 AND r.id > $3 AND r.created_at > NOW() - INTERVAL '30 seconds'
      ORDER BY r.id ASC LIMIT 100
    `, [req.params.roomId, req.user.id, afterId]);
    res.json({ reactions: result.rows });
  } catch (error) { console.error('Room reaction read error:', error); res.status(500).json({ message: "Could not load room reactions" }); }
});

app.post("/api/rooms/:roomId/seat-requests", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const seatNumber = Number(req.body?.seatNumber);
    const room = await pool.query(`SELECT id, seat_count FROM rooms WHERE id = $1`, [req.params.roomId]);
    if (!room.rows.length) return res.status(404).json({ message: "Room not found" });
    if (!Number.isInteger(seatNumber) || seatNumber < 1 || seatNumber > Number(room.rows[0].seat_count)) return res.status(400).json({ message: "Invalid seat number" });
    const occupied = await pool.query(`SELECT 1 FROM room_seats WHERE room_id=$1 AND seat_number=$2`, [req.params.roomId, seatNumber]);
    if (occupied.rows.length) return res.status(409).json({ message: "That seat is already occupied" });
    const existing = await pool.query(`SELECT id FROM room_seat_requests WHERE room_id=$1 AND user_id=$2 AND status='pending'`, [req.params.roomId, req.user.id]);
    if (existing.rows.length) return res.status(409).json({ message: "You already have a pending seat request" });
    const created = await pool.query(`INSERT INTO room_seat_requests(id,room_id,user_id,seat_number) VALUES($1,$2,$3,$4) RETURNING id, seat_number, status, created_at`, [uuidv4(), req.params.roomId, req.user.id, seatNumber]);
    res.status(201).json({ message: "Seat request sent", request: created.rows[0] });
  } catch (error) { console.error('Seat request create error:', error); res.status(500).json({ message: "Could not create seat request" }); }
});

app.get("/api/rooms/:roomId/seat-requests", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  try {
    const role = await pool.query(`SELECT CASE WHEN r.owner_id=$2 THEN 'owner' WHEN EXISTS(SELECT 1 FROM room_moderators m WHERE m.room_id=r.id AND m.user_id=$2) THEN 'moderator' ELSE 'member' END AS role FROM rooms r WHERE r.id=$1`, [req.params.roomId, req.user.id]);
    if (!role.rows.length) return res.status(404).json({ message: "Room not found" });
    if (!['owner','moderator'].includes(role.rows[0].role)) return res.status(403).json({ message: "Only owner or moderator can view seat requests" });
    const result = await pool.query(`SELECT q.id,q.seat_number,q.created_at,u.id AS user_id,u.username,u.display_name,u.avatar_url FROM room_seat_requests q JOIN users u ON u.id=q.user_id WHERE q.room_id=$1 AND q.status='pending' ORDER BY q.created_at ASC`, [req.params.roomId]);
    res.json({ requests: result.rows });
  } catch (error) { console.error('Seat request list error:', error); res.status(500).json({ message: "Could not load seat requests" }); }
});

app.post("/api/rooms/:roomId/seat-requests/:requestId/decision", authMiddleware, async (req, res) => {
  if (!pool) return res.status(503).json({ message: "Database is not configured" });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const room = await client.query(`SELECT id,owner_id,seat_count FROM rooms WHERE id=$1 FOR UPDATE`, [req.params.roomId]);
    if (!room.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ message: "Room not found" }); }
    const role = await client.query(`SELECT CASE WHEN $1=owner_id THEN 'owner' WHEN EXISTS(SELECT 1 FROM room_moderators WHERE room_id=$2 AND user_id=$1) THEN 'moderator' ELSE 'member' END AS role FROM rooms WHERE id=$2`, [req.user.id, req.params.roomId]);
    if (!['owner','moderator'].includes(role.rows[0].role)) { await client.query('ROLLBACK'); return res.status(403).json({ message: "Only owner or moderator can decide requests" }); }
    const request = await client.query(`SELECT * FROM room_seat_requests WHERE id=$1 AND room_id=$2 AND status='pending' FOR UPDATE`, [req.params.requestId, req.params.roomId]);
    if (!request.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ message: "Pending request not found" }); }
    const approve = req.body?.approve === true;
    if (approve) {
      const seat = Number(request.rows[0].seat_number);
      const occupied = await client.query(`SELECT 1 FROM room_seats WHERE room_id=$1 AND seat_number=$2 FOR UPDATE`, [req.params.roomId, seat]);
      if (occupied.rows.length) { await client.query('ROLLBACK'); return res.status(409).json({ message: "Requested seat is no longer available" }); }
      const alreadySeated = await client.query(`SELECT 1 FROM room_seats WHERE room_id=$1 AND user_id=$2`, [req.params.roomId, request.rows[0].user_id]);
      if (alreadySeated.rows.length) { await client.query('ROLLBACK'); return res.status(409).json({ message: "User is already seated" }); }
      await client.query(`INSERT INTO room_seats(id,room_id,seat_number,user_id) VALUES($1,$2,$3,$4)`, [uuidv4(), req.params.roomId, seat, request.rows[0].user_id]);
    }
    await client.query(`UPDATE room_seat_requests SET status=$1,decided_at=NOW(),decided_by=$2 WHERE id=$3`, [approve ? 'approved' : 'rejected', req.user.id, req.params.requestId]);
    await client.query('COMMIT');
    res.json({ message: approve ? "Seat request approved" : "Seat request rejected" });
  } catch (error) { await client.query('ROLLBACK').catch(()=>{}); console.error('Seat request decision error:', error); res.status(500).json({ message: "Could not decide seat request" }); }
  finally { client.release(); }
});

app.get("/api/rooms/:roomId/members", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const roomResult = await pool.query(
      `
      SELECT id, name, seat_count, owner_id
      FROM rooms
      WHERE id = $1
      `,
      [req.params.roomId]
    );

    if (roomResult.rows.length === 0) {
      return res.status(404).json({
        message: "Room not found",
      });
    }

    const room = roomResult.rows[0];

    const roleResult = await pool.query(
      `SELECT CASE
        WHEN r.owner_id = $2 THEN 'owner'
        WHEN EXISTS (SELECT 1 FROM room_moderators rm WHERE rm.room_id = r.id AND rm.user_id = $2) THEN 'moderator'
        ELSE 'member'
      END AS role FROM rooms r WHERE r.id = $1`,
      [req.params.roomId, req.user.id]
    );

    const result = await pool.query(
      `
      SELECT
        rs.seat_number,
        u.id,
        u.public_uid,
        u.username,
        u.display_name,
        u.avatar_url,
        u.signature,
        u.level,
        COALESCE((SELECT MAX(lc.level_number) FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'wealth' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.wealth_value), 1) AS wealth_level,
        COALESCE((SELECT MAX(lc.level_number) FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'charm' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.charm_value), 1) AS charm_level,
        (SELECT lc.icon_url FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'wealth' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.wealth_value ORDER BY lc.level_number DESC LIMIT 1) AS wealth_level_icon_url,
        (SELECT lc.icon_url FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'charm' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.charm_value ORDER BY lc.level_number DESC LIMIT 1) AS charm_level_icon_url
      FROM room_seats rs
      JOIN users u ON u.id = rs.user_id
      WHERE rs.room_id = $1
      ORDER BY rs.seat_number ASC
      `,
      [req.params.roomId]
    );

    const occupiedSeats = new Map();

    for (const row of result.rows) {
      occupiedSeats.set(Number(row.seat_number), {
        id: row.id,
        public_uid: row.public_uid,
        username: row.username,
        display_name: row.display_name,
        avatar_url: row.avatar_url,
        signature: row.signature,
        level: row.level,
        wealth_level: Number(row.wealth_level || 1),
        charm_level: Number(row.charm_level || 1),
        wealth_level_icon_url: row.wealth_level_icon_url,
        charm_level_icon_url: row.charm_level_icon_url,
      });
    }

    const seats = [];

    for (
      let seatNumber = 1;
      seatNumber <= Number(room.seat_count);
      seatNumber++
    ) {
      seats.push({
        seatNumber,
        user: occupiedSeats.get(seatNumber) || null,
      });
    }

    res.json({
      room: {
        id: room.id,
        name: room.name,
        owner_id: room.owner_id,
        seat_count: Number(room.seat_count),
      },
      seats,
      currentUser: { id: req.user.id, role: roleResult.rows[0]?.role || "member" },
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not load room members",
    });
  }
});

app.post(
  "/api/rooms/:roomId/moderation",
  authMiddleware,
  async (req, res) => {
    if (!pool) return res.status(503).json({ message: "Database is not configured" });
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const roomResult = await client.query(
        `SELECT id, owner_id, seat_count FROM rooms WHERE id = $1 FOR UPDATE`,
        [req.params.roomId]
      );
      if (!roomResult.rows.length) {
        await client.query("ROLLBACK");
        return res.status(404).json({ message: "Room not found" });
      }
      const room = roomResult.rows[0];
      const isOwner = room.owner_id === req.user.id;
      const mod = await client.query(
        `SELECT 1 FROM room_moderators WHERE room_id = $1 AND user_id = $2`,
        [room.id, req.user.id]
      );
      const isModerator = mod.rows.length > 0;
      if (!isOwner && !isModerator) {
        await client.query("ROLLBACK");
        return res.status(403).json({ message: "Only the room owner or moderator can perform this action" });
      }
      const action = String(req.body?.action || "");
      const seatNumber = Number(req.body?.seatNumber);
      const targetUserId = req.body?.targetUserId ? String(req.body.targetUserId) : null;
      if (!Number.isInteger(seatNumber) || seatNumber < 1 || seatNumber > Number(room.seat_count)) {
        await client.query("ROLLBACK");
        return res.status(400).json({ message: "Invalid seat number" });
      }
      if (action === "block_seat") {
        const occupied = await client.query(
          `SELECT 1 FROM room_seats WHERE room_id = $1 AND seat_number = $2 FOR UPDATE`,
          [room.id, seatNumber]
        );
        if (occupied.rows.length) {
          await client.query("ROLLBACK");
          return res.status(409).json({ message: "An occupied seat cannot be blocked" });
        }
        await client.query(
          `INSERT INTO room_seat_blocks(room_id, seat_number, blocked_by)
           VALUES ($1, $2, $3) ON CONFLICT (room_id, seat_number)
           DO UPDATE SET blocked_by = EXCLUDED.blocked_by, created_at = NOW()`,
          [room.id, seatNumber, req.user.id]
        );
        await client.query("COMMIT");
        return res.json({ message: "Seat blocked", seatNumber });
      }
      if (action === "set_admin") {
        if (!isOwner) {
          await client.query("ROLLBACK");
          return res.status(403).json({ message: "Only the room owner can assign a moderator" });
        }
        if (!targetUserId || targetUserId === room.owner_id) {
          await client.query("ROLLBACK");
          return res.status(400).json({ message: "Choose a valid room member" });
        }
        const target = await client.query(
          `SELECT 1 FROM room_seats WHERE room_id = $1 AND user_id = $2`,
          [room.id, targetUserId]
        );
        if (!target.rows.length) {
          await client.query("ROLLBACK");
          return res.status(404).json({ message: "That user is not sitting in this room" });
        }
        await client.query(
          `INSERT INTO room_moderators(id, room_id, user_id, assigned_by)
           VALUES ($1, $2, $3, $4) ON CONFLICT (room_id, user_id) DO NOTHING`,
          [uuidv4(), room.id, targetUserId, req.user.id]
        );
        await client.query("COMMIT");
        return res.json({ message: "Room moderator assigned" });
      }
      if (action === "kick_user" || action === "remove_from_seat") {
        if (!targetUserId || targetUserId === room.owner_id) {
          await client.query("ROLLBACK");
          return res.status(403).json({ message: "A valid non-owner room member is required" });
        }
        const targetSeat = await client.query(
          `SELECT user_id FROM room_seats WHERE room_id = $1 AND seat_number = $2 FOR UPDATE`,
          [room.id, seatNumber]
        );
        if (!targetSeat.rows.length || targetSeat.rows[0].user_id !== targetUserId) {
          await client.query("ROLLBACK");
          return res.status(409).json({ message: "Seat occupant changed. Refresh and try again." });
        }
        const targetMod = await client.query(
          `SELECT 1 FROM room_moderators WHERE room_id = $1 AND user_id = $2`,
          [room.id, targetUserId]
        );
        if (!isOwner && targetMod.rows.length) {
          await client.query("ROLLBACK");
          return res.status(403).json({ message: "A moderator cannot remove another moderator" });
        }
        await client.query(
          `DELETE FROM room_seats WHERE room_id = $1 AND seat_number = $2 AND user_id = $3`,
          [room.id, seatNumber, targetUserId]
        );
        await client.query("COMMIT");
        return res.json({ message: action === "kick_user" ? "User kicked from the mic" : "User removed from the seat" });
      }
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Unsupported moderation action. Mute, invite and move require voice-room services." });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => {});
      console.error("Room moderation error:", error);
      return res.status(500).json({ message: "Could not complete room moderation action" });
    } finally {
      client.release();
    }
  }
);

app.post(
  "/api/rooms/:roomId/seats/:seatNumber/join",
  authMiddleware,
  async (req, res) => {
    if (!pool) {
      return res.status(500).json({
        message: "Database is not configured",
      });
    }

    const client = await pool.connect();

    try {
      await client.query("BEGIN");

      const roomResult = await client.query(
        `
        SELECT id, name, seat_count, owner_id
        FROM rooms
        WHERE id = $1
        FOR UPDATE
        `,
        [req.params.roomId]
      );

      if (roomResult.rows.length === 0) {
        await client.query("ROLLBACK");

        return res.status(404).json({
          message: "Room not found",
        });
      }

      const room = roomResult.rows[0];
      const seatNumber = Number(req.params.seatNumber);

      if (
        !Number.isInteger(seatNumber) ||
        seatNumber < 1 ||
        seatNumber > Number(room.seat_count)
      ) {
        await client.query("ROLLBACK");

        return res.status(400).json({
          message: "Invalid seat number",
        });
      }

      const blockedSeat = await client.query(
        `SELECT 1 FROM room_seat_blocks WHERE room_id = $1 AND seat_number = $2`,
        [req.params.roomId, seatNumber]
      );
      if (blockedSeat.rows.length) {
        await client.query("ROLLBACK");
        return res.status(403).json({ message: "This seat is blocked by room management" });
      }

      const currentSeat = await client.query(
        `
        SELECT
          rs.room_id,
          rs.seat_number,
          r.name AS room_name
        FROM room_seats rs
        JOIN rooms r ON r.id = rs.room_id
        WHERE rs.user_id = $1
        FOR UPDATE
        `,
        [req.user.id]
      );


if (currentSeat.rows.length > 0) {
  const current = currentSeat.rows[0];

  if (
    current.room_id === req.params.roomId &&
    Number(current.seat_number) === seatNumber
  ) {
    const userResult = await client.query(
      `
      SELECT
        id,
        public_uid,
        username,
        display_name,
        avatar_url,
        signature,
        level,
        (SELECT COUNT(*)::int FROM user_follows WHERE followed_id = users.id) AS fans_count,
        (SELECT COUNT(*)::int FROM user_follows WHERE follower_id = users.id) AS following_count
      FROM users
      WHERE id = $1
      `,
      [req.user.id]
    );

    await client.query("COMMIT");

    return res.json({
      message: "Already sitting on this seat",
      seat: {
        seatNumber,
        user: userResult.rows[0],
      },
    });
  }

  // User is changing seats or moving to another room.
  // Keep the old seat until the new seat is confirmed available.
}

      const occupied = await client.query(
        `
        SELECT
          rs.seat_number,
          u.id AS user_id,
          u.public_uid,
          u.username,
          u.display_name,
          u.avatar_url,
          u.signature,
          u.level,
          COALESCE((SELECT MAX(lc.level_number) FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'wealth' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.wealth_value), 1) AS wealth_level,
          COALESCE((SELECT MAX(lc.level_number) FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'charm' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.charm_value), 1) AS charm_level,
        (SELECT lc.icon_url FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'wealth' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.wealth_value ORDER BY lc.level_number DESC LIMIT 1) AS wealth_level_icon_url,
        (SELECT lc.icon_url FROM level_config lc JOIN user_level_stats uls ON uls.user_id = u.id WHERE lc.level_type = 'charm' AND lc.min_coins IS NOT NULL AND lc.min_coins <= uls.charm_value ORDER BY lc.level_number DESC LIMIT 1) AS charm_level_icon_url
        FROM room_seats rs
        JOIN users u ON u.id = rs.user_id
        WHERE rs.room_id = $1
          AND rs.seat_number = $2
        FOR UPDATE
        `,
        [req.params.roomId, seatNumber]
      );

      if (occupied.rows.length > 0) {
        await client.query("ROLLBACK");

        return res.status(409).json({
          message: "This seat is already occupied",
        });
      }

      await client.query(
        `
        DELETE FROM room_seats
        WHERE user_id = $1
        `,
        [req.user.id]
      );

      await client.query(
        `
        INSERT INTO room_seats
          (id, room_id, seat_number, user_id)
        VALUES
          ($1, $2, $3, $4)
        `,
        [
          uuidv4(),
          req.params.roomId,
          seatNumber,
          req.user.id,
        ]
      );

      const userResult = await client.query(
        `
        SELECT
          id,
          public_uid,
          username,
          display_name,
          avatar_url,
          signature,
          level
        FROM users
        WHERE id = $1
        `,
        [req.user.id]
      );

      await client.query("COMMIT");

      res.status(201).json({
        message: "Seat joined successfully",
        seat: {
          seatNumber,
          user: userResult.rows[0],
        },
      });
    } catch (error) {
      try {
        await client.query("ROLLBACK");
      } catch (_) {}

      console.error(error);

      if (error.code === "23505") {
        return res.status(409).json({
          message: "This seat or user is already occupied",
        });
      }

      res.status(500).json({
        message: "Could not join seat",
      });
    } finally {
      client.release();
    }
  }
);

app.post(
  "/api/rooms/:roomId/seats/:seatNumber/leave",
  authMiddleware,
  async (req, res) => {
    if (!pool) {
      return res.status(500).json({
        message: "Database is not configured",
      });
    }

    try {
      const seatNumber = Number(req.params.seatNumber);

      if (!Number.isInteger(seatNumber) || seatNumber < 1) {
        return res.status(400).json({
          message: "Invalid seat number",
        });
      }

      const result = await pool.query(
        `
        DELETE FROM room_seats
        WHERE room_id = $1
          AND seat_number = $2
          AND user_id = $3
        RETURNING seat_number
        `,
        [
          req.params.roomId,
          seatNumber,
          req.user.id,
        ]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          message: "You are not sitting on this seat",
        });
      }

      res.json({
        message: "Seat left successfully",
        seatNumber: Number(result.rows[0].seat_number),
      });
    } catch (error) {
      console.error(error);

      res.status(500).json({
        message: "Could not leave seat",
      });
    }
  }
);

app.post(
  "/api/rooms/:roomId/leave",
  authMiddleware,
  async (req, res) => {
    if (!pool) {
      return res.status(500).json({
        message: "Database is not configured",
      });
    }

    try {
      const result = await pool.query(
        `
        DELETE FROM room_seats
        WHERE room_id = $1
          AND user_id = $2
        RETURNING seat_number
        `,
        [
          req.params.roomId,
          req.user.id,
        ]
      );

      res.json({
        message:
          result.rows.length > 0
            ? "Room seat left successfully"
            : "You were not sitting in this room",
        seatNumber:
          result.rows.length > 0
            ? Number(result.rows[0].seat_number)
            : null,
      });
    } catch (error) {
      console.error(error);

      res.status(500).json({
        message: "Could not leave room",
      });
    }
  }
);

// -------------------------
// Wealth and Charm level APIs
// -------------------------
function levelDbRequired(req, res) {
  if (!pool) {
    res.status(503).json({ message: "Database is not configured" });
    return false;
  }
  return true;
}

app.get("/api/levels/me", authMiddleware, async (req, res) => {
  if (!levelDbRequired(req, res)) return;
  try {
    await pool.query(`INSERT INTO user_level_stats(user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`, [req.user.id]);
    const statsResult = await pool.query(`SELECT wealth_value, charm_value FROM user_level_stats WHERE user_id = $1`, [req.user.id]);
    const stats = statsResult.rows[0];
    const output = {};
    for (const type of ["wealth", "charm"]) {
      const value = Number(type === "wealth" ? stats.wealth_value : stats.charm_value);
      const currentResult = await pool.query(`
        SELECT level_number, min_coins, icon_url, entry_effect_key
        FROM level_config
        WHERE level_type = $1 AND min_coins IS NOT NULL AND min_coins <= $2
        ORDER BY level_number DESC LIMIT 1
      `, [type, value]);
      const nextResult = await pool.query(`
        SELECT level_number, min_coins, icon_url, entry_effect_key
        FROM level_config WHERE level_type = $1
          AND level_number > $2 AND min_coins IS NOT NULL
        ORDER BY level_number ASC LIMIT 1
      `, [type, currentResult.rows[0]?.level_number || 1]);
      const current = currentResult.rows[0] || { level_number: 1, min_coins: 0, icon_url: null, entry_effect_key: null };
      const next = nextResult.rows[0] || null;
      output[type] = {
        value,
        level: Number(current.level_number),
        icon_url: current.icon_url,
        entry_effect_key: current.entry_effect_key,
        next_level: next ? Number(next.level_number) : null,
        next_min_coins: next?.min_coins == null ? null : Number(next.min_coins),
        remaining: next?.min_coins == null ? null : Math.max(0, Number(next.min_coins) - value),
        progress: next?.min_coins == null ? 0 : Math.max(0, Math.min(1, (value - Number(current.min_coins || 0)) / Math.max(1, Number(next.min_coins) - Number(current.min_coins || 0))))
      };
    }
    res.json({ levels: output });
  } catch (error) {
    console.error("Level progress lookup failed:", error);
    res.status(500).json({ message: "Could not load level progress" });
  }
});

app.get("/api/levels/config", authMiddleware, async (req, res) => {
  if (!levelDbRequired(req, res)) return;
  try {
    const result = await pool.query(`
      SELECT level_type, level_number, min_coins, icon_url, entry_effect_key
      FROM level_config ORDER BY level_type, level_number
    `);
    res.json({ levels: result.rows });
  } catch (error) {
    console.error("Level configuration lookup failed:", error);
    res.status(500).json({ message: "Could not load level configuration" });
  }
});

// Admin dashboard saves cumulative coin thresholds and optional badge/effect assets.
// Set users.is_admin = TRUE for the authorized main-admin account in the database.
app.put("/api/admin/levels/config", authMiddleware, adminMiddleware, async (req, res) => {
  if (!levelDbRequired(req, res)) return;
  const type = String(req.body?.type || "").toLowerCase();
  const levels = req.body?.levels;
  if (!["wealth", "charm"].includes(type) || !Array.isArray(levels) || levels.length < 1 || levels.length > 110) {
    return res.status(400).json({ message: "type must be wealth or charm and levels must contain 1 to 110 entries" });
  }
  const seen = new Set();
  for (const item of levels) {
    const level = Number(item?.level_number);
    const minCoins = item?.min_coins == null ? null : Number(item.min_coins);
    if (!Number.isInteger(level) || level < 1 || level > 110 || seen.has(level) ||
        (minCoins !== null && (!Number.isSafeInteger(minCoins) || minCoins < 0))) {
      return res.status(400).json({ message: "Each level needs a unique level_number (1-110) and a non-negative integer min_coins" });
    }
    seen.add(level);
  }
  if (!levels.some(item => Number(item.level_number) === 1 && Number(item.min_coins) === 0)) {
    return res.status(400).json({ message: "Level 1 must start at 0 coins" });
  }
  const configuredThresholds = levels
    .filter(item => item.min_coins != null)
    .sort((a, b) => Number(a.level_number) - Number(b.level_number));
  for (let i = 1; i < configuredThresholds.length; i++) {
    if (Number(configuredThresholds[i].min_coins) <= Number(configuredThresholds[i - 1].min_coins)) {
      return res.status(400).json({ message: "Coin thresholds must increase with every higher level" });
    }
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    for (const item of levels) {
      await client.query(`
        INSERT INTO level_config(level_type, level_number, min_coins, icon_url, entry_effect_key, updated_at, updated_by)
        VALUES ($1,$2,$3,$4,$5,NOW(),$6)
        ON CONFLICT (level_type, level_number) DO UPDATE SET
          min_coins = EXCLUDED.min_coins,
          icon_url = EXCLUDED.icon_url,
          entry_effect_key = EXCLUDED.entry_effect_key,
          updated_at = NOW(), updated_by = EXCLUDED.updated_by
      `, [type, Number(item.level_number), item.min_coins == null ? null : Number(item.min_coins), item.icon_url || null, item.entry_effect_key || null, req.user.id]);
    }
    await client.query("COMMIT");
    res.json({ message: `${type} level configuration saved`, updated: levels.length });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Level configuration update failed:", error);
    res.status(500).json({ message: "Could not save level configuration" });
  } finally {
    client.release();
  }
});

// -------------------------
// Wallet APIs (store purchase verification intentionally fail-closed)
// -------------------------
function walletDbRequired(req, res) {
  if (!pool) {
    res.status(503).json({ message: "Database is not configured" });
    return false;
  }
  return true;
}

app.get("/api/wallet/recharge-packages", authMiddleware, async (req, res) => {
  if (!walletDbRequired(req, res)) return;
  try {
    const result = await pool.query(`
      SELECT code, title, coins, bonus_coins, google_product_id, apple_product_id
      FROM wallet_recharge_packages
      WHERE active = TRUE
      ORDER BY sort_order ASC, created_at ASC
    `);
    res.json({ packages: result.rows });
  } catch (error) {
    console.error("Recharge package lookup failed:", error);
    res.status(500).json({ message: "Could not load recharge packages" });
  }
});

// Do NOT credit coins from client claims. Store verification must be implemented
// with Google Play Developer API / Apple App Store Server API credentials first.
app.post("/api/wallet/recharge/verify", authMiddleware, async (req, res) => {
  if (!walletDbRequired(req, res)) return;
  const { platform, productId, purchaseToken, transactionId, receipt } = req.body || {};
  if (!["google_play", "app_store"].includes(platform) || !productId ||
      !(purchaseToken || transactionId || receipt)) {
    return res.status(400).json({
      message: "platform, productId, and store purchase proof are required"
    });
  }
  return res.status(503).json({
    code: "STORE_VERIFICATION_NOT_CONFIGURED",
    message: "Purchase verification is not configured yet. No coins were added. Configure and test Google Play / Apple server verification before enabling recharge."
  });
});

app.get("/api/wallet/coin-history", authMiddleware, async (req, res) => {
  if (!walletDbRequired(req, res)) return;
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 30, 1), 100);
  const offset = Math.max(Number.parseInt(req.query.offset, 10) || 0, 0);
  try {
    const result = await pool.query(`
      SELECT id, kind, currency, amount, balance_after, status, source,
             external_transaction_id, details, created_at
      FROM wallet_transactions
      WHERE user_id = $1 AND currency = 'coins'
      ORDER BY created_at DESC
      LIMIT $2 OFFSET $3
    `, [req.user.id, limit, offset]);
    res.json({ transactions: result.rows, limit, offset });
  } catch (error) {
    console.error("Coin history lookup failed:", error);
    res.status(500).json({ message: "Could not load coin history" });
  }
});

app.get("/api/wallet/diamond-history", authMiddleware, async (req, res) => {
  if (!walletDbRequired(req, res)) return;
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 30, 1), 100);
  const offset = Math.max(Number.parseInt(req.query.offset, 10) || 0, 0);
  try {
    const result = await pool.query(`
      SELECT id, kind, currency, amount, balance_after, status, source,
             external_transaction_id, details, created_at
      FROM wallet_transactions
      WHERE user_id = $1 AND currency = 'diamonds'
      ORDER BY created_at DESC
      LIMIT $2 OFFSET $3
    `, [req.user.id, limit, offset]);
    res.json({ transactions: result.rows, limit, offset });
  } catch (error) {
    console.error("Diamond history lookup failed:", error);
    res.status(500).json({ message: "Could not load diamond history" });
  }
});

app.get("/api/wallet/diamonds", authMiddleware, async (req, res) => {
  if (!walletDbRequired(req, res)) return;
  try {
    const result = await pool.query(`SELECT diamonds, coins FROM users WHERE id = $1`, [req.user.id]);
    if (!result.rows.length) return res.status(404).json({ message: "User not found" });
    const setting = await pool.query(`SELECT value FROM wallet_settings WHERE key = 'diamond_exchange'`);
    const config = setting.rows[0]?.value || { enabled: false, diamonds_per_exchange: 0, coins_per_exchange: 0 };
    res.json({ diamonds: Number(result.rows[0].diamonds), coins: Number(result.rows[0].coins), exchange: config });
  } catch (error) {
    console.error("Diamond wallet lookup failed:", error);
    res.status(500).json({ message: "Could not load diamond wallet" });
  }
});

app.post("/api/wallet/diamonds/exchange", authMiddleware, async (req, res) => {
  if (!walletDbRequired(req, res)) return;
  const diamondsToExchange = Number(req.body?.diamonds);
  if (!Number.isSafeInteger(diamondsToExchange) || diamondsToExchange <= 0) {
    return res.status(400).json({ message: "diamonds must be a positive whole number" });
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const settingResult = await client.query(
      `SELECT value FROM wallet_settings WHERE key = 'diamond_exchange' FOR UPDATE`
    );
    const config = settingResult.rows[0]?.value;
    if (!config || config.enabled !== true ||
        !Number.isSafeInteger(Number(config.diamonds_per_exchange)) ||
        !Number.isSafeInteger(Number(config.coins_per_exchange)) ||
        Number(config.diamonds_per_exchange) <= 0 || Number(config.coins_per_exchange) <= 0) {
      await client.query("ROLLBACK");
      return res.status(503).json({ message: "Diamond exchange is not enabled by admin yet" });
    }
    const unitDiamonds = Number(config.diamonds_per_exchange);
    const unitCoins = Number(config.coins_per_exchange);
    if (diamondsToExchange % unitDiamonds !== 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: `Exchange amount must be a multiple of ${unitDiamonds} diamonds` });
    }
    const coinsToCredit = (diamondsToExchange / unitDiamonds) * unitCoins;
    if (!Number.isSafeInteger(coinsToCredit) || coinsToCredit <= 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Exchange amount is too large" });
    }
    const userResult = await client.query(
      `UPDATE users SET diamonds = diamonds - $1, coins = coins + $2
       WHERE id = $3 AND diamonds >= $1
       RETURNING diamonds, coins`,
      [diamondsToExchange, coinsToCredit, req.user.id]
    );
    if (!userResult.rows.length) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "Insufficient diamonds or user not found" });
    }
    const user = userResult.rows[0];
    const transactionId = uuidv4();
    await client.query(`
      INSERT INTO wallet_transactions
        (id, user_id, kind, currency, amount, balance_after, status, source, external_transaction_id, idempotency_key, details)
      VALUES
        ($1, $2, 'diamond_exchange_out', 'diamonds', $3, $4, 'success', 'exchange', $5, $6, $7::jsonb),
        ($8, $2, 'diamond_exchange_in', 'coins', $9, $10, 'success', 'exchange', $5, $11, $12::jsonb)
    `, [
      uuidv4(), req.user.id, -diamondsToExchange, user.diamonds, transactionId,
      `diamond-exchange:${transactionId}:diamonds`, JSON.stringify({ coins_received: coinsToCredit }),
      uuidv4(), coinsToCredit, user.coins, `diamond-exchange:${transactionId}:coins`,
      JSON.stringify({ diamonds_exchanged: diamondsToExchange })
    ]);
    await client.query("COMMIT");
    return res.json({
      message: "Diamond exchange successful",
      transactionId,
      diamondsExchanged: diamondsToExchange,
      coinsReceived: coinsToCredit,
      diamondsBalance: Number(user.diamonds),
      coinsBalance: Number(user.coins)
    });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Diamond exchange failed:", error);
    return res.status(500).json({ message: "Could not exchange diamonds" });
  } finally {
    client.release();
  }
});

// -------------------------
// Demo Coins
// -------------------------

app.post("/api/coins/demo", authMiddleware, async (req, res) => {
  if (process.env.WALLET_DEMO_ENABLED !== "true") {
    return res.status(404).json({ message: "Not found" });
  }
  if (!pool) {
    return res.status(500).json({
      message: "Database is not configured",
    });
  }

  try {
    const result = await pool.query(
      `
      UPDATE users
      SET coins = coins + 100
      WHERE id = $1
      RETURNING id, username, coins, level
      `,
      [req.user.id]
    );

    res.json({
      message: "100 demo coins added",
      user: result.rows[0],
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not add coins",
    });
  }
});

// -------------------------
// Start Server
// -------------------------

async function startServer() {
  try {
    await initDatabase();

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Group Voice Chat API running on port ${PORT}`);
    });
  } catch (error) {
    console.error("Server startup failed:", error);
    process.exit(1);
  }
}

startServer();
