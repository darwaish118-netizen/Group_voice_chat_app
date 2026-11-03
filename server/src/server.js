require("dotenv").config();

const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { Pool } = require("pg");
const { v4: uuidv4 } = require("uuid");

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
      coin_amount BIGINT NOT NULL CHECK (coin_amount > 0),
      status VARCHAR(20) NOT NULL DEFAULT 'success' CHECK (status IN ('pending','success','failed','refunded')),
      idempotency_key TEXT UNIQUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CHECK (sender_id <> receiver_id)
    )
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS gift_transactions_sender_created_idx ON gift_transactions(sender_id, created_at DESC)`);
  await pool.query(`CREATE INDEX IF NOT EXISTS gift_transactions_receiver_created_idx ON gift_transactions(receiver_id, created_at DESC)`);
  await pool.query(`
    CREATE OR REPLACE FUNCTION update_user_level_stats_from_gift() RETURNS TRIGGER AS $$
    DECLARE delta BIGINT := 0;
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
        INSERT INTO user_level_stats(user_id, wealth_value, charm_value)
        VALUES (NEW.sender_id, GREATEST(delta, 0), 0)
        ON CONFLICT (user_id) DO UPDATE SET wealth_value = GREATEST(0, user_level_stats.wealth_value + delta), updated_at = NOW();
        INSERT INTO user_level_stats(user_id, wealth_value, charm_value)
        VALUES (NEW.receiver_id, 0, GREATEST(delta, 0))
        ON CONFLICT (user_id) DO UPDATE SET charm_value = GREATEST(0, user_level_stats.charm_value + delta), updated_at = NOW();
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
    users.public_uid AS owner_public_uid
FROM rooms
JOIN users ON users.id = rooms.owner_id
ORDER BY rooms.created_at DESC
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
// Room Members / Seats
// -------------------------

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
