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
    // Wallet balances
  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS diamonds BIGINT NOT NULL DEFAULT 0
    CHECK (diamonds >= 0)
  `);

  // Recharge packages configured by admin
  await pool.query(`
    CREATE TABLE IF NOT EXISTS recharge_packages (
      id UUID PRIMARY KEY,
      title VARCHAR(100) NOT NULL,
      product_id_android VARCHAR(200) NOT NULL UNIQUE,
      product_id_ios VARCHAR(200) NOT NULL UNIQUE,
      base_coins INTEGER NOT NULL CHECK (base_coins > 0),
      bonus_coins INTEGER NOT NULL DEFAULT 0 CHECK (bonus_coins >= 0),
      display_price VARCHAR(40),
      currency VARCHAR(10),
      active BOOLEAN NOT NULL DEFAULT TRUE,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS wallet_settings (
      setting_key VARCHAR(100) PRIMARY KEY,
      setting_value JSONB NOT NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    INSERT INTO wallet_settings (setting_key, setting_value)
    VALUES (
      'diamond_exchange',
      '{"enabled":false,"coins_per_diamond":0,"min_diamonds":1,"max_diamonds":100000}'::jsonb
    )
    ON CONFLICT (setting_key) DO NOTHING
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS wallet_transactions (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      transaction_type VARCHAR(40) NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'success',
      coins_delta BIGINT NOT NULL DEFAULT 0,
      diamonds_delta BIGINT NOT NULL DEFAULT 0,
      provider VARCHAR(30),
      provider_transaction_id VARCHAR(255),
      package_id UUID REFERENCES recharge_packages(id) ON DELETE SET NULL,
      description VARCHAR(255),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      CHECK (status IN ('pending','success','failed','refunded'))
    )
  `);

  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS wallet_transactions_provider_tx_unique
    ON wallet_transactions(provider, provider_transaction_id)
    WHERE provider IS NOT NULL
      AND provider_transaction_id IS NOT NULL
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS wallet_transactions_user_created_idx
    ON wallet_transactions(user_id, created_at DESC)
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

      user = result.rows[0];
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
        level
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

app.get("/api/rooms/:roomId/members", async (req, res) => {
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
        u.level
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
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not load room members",
    });
  }
});

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
        level
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
          u.level
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
// Demo Coins
// -------------------------


 // Demo Coins - disabled for production
app.post("/api/coins/demo", authMiddleware, (req, res) => {
  return res.status(410).json({
    message: "Demo coins are disabled."
  });
});


/* =========================================
   MINDO VOICE CHAT - WALLET APIs
   Store purchase verification is disabled
   until Google/Apple verification is configured.
========================================= */

// Get current wallet balance
app.get("/api/wallet/balance", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({ message: "Database is not configured" });
  }

  try {
    const result = await pool.query(
      `SELECT coins, diamonds FROM users WHERE id = $1`,
      [req.user.id]
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.json({ wallet: result.rows[0] });
  } catch (error) {
    console.error("Wallet balance error:", error);
    return res.status(500).json({ message: "Could not load wallet balance" });
  }
});

// Get active recharge packages
app.get("/api/wallet/recharge-packages", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({ message: "Database is not configured" });
  }

  try {
    const result = await pool.query(`
      SELECT id, title, base_coins, bonus_coins,
             display_price, currency, product_id_android,
             product_id_ios
      FROM recharge_packages
      WHERE active = TRUE
      ORDER BY sort_order ASC, created_at ASC
    `);

    return res.json({ packages: result.rows });
  } catch (error) {
    console.error("Recharge packages error:", error);
    return res.status(500).json({ message: "Could not load recharge packages" });
  }
});

// Secure purchase verification is NOT enabled yet.
// Never credit coins from an unverified client receipt.
app.post("/api/wallet/purchases/verify", authMiddleware, async (req, res) => {
  return res.status(503).json({
    verified: false,
    message:
      "Store purchase verification is not configured. No coins were added."
  });
});

// Get coin transaction history
app.get("/api/wallet/coin-history", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({ message: "Database is not configured" });
  }

  try {
    const limit = Math.min(
      Math.max(parseInt(req.query.limit, 10) || 30, 1),
      100
    );
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    const result = await pool.query(
      `SELECT id, transaction_type, status, coins_delta,
              description, provider, provider_transaction_id, created_at
       FROM wallet_transactions
       WHERE user_id = $1 AND coins_delta <> 0
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, limit, offset]
    );

    return res.json({ transactions: result.rows });
  } catch (error) {
    console.error("Coin history error:", error);
    return res.status(500).json({ message: "Could not load coin history" });
  }
});

// Get diamond transaction history
app.get("/api/wallet/diamond-history", authMiddleware, async (req, res) => {
  if (!pool) {
    return res.status(500).json({ message: "Database is not configured" });
  }

  try {
    const limit = Math.min(
      Math.max(parseInt(req.query.limit, 10) || 30, 1),
      100
    );
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    const result = await pool.query(
      `SELECT id, transaction_type, status, diamonds_delta,
              coins_delta, description, created_at
       FROM wallet_transactions
       WHERE user_id = $1 AND diamonds_delta <> 0
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, limit, offset]
    );

    return res.json({ transactions: result.rows });
  } catch (error) {
    console.error("Diamond history error:", error);
    return res.status(500).json({ message: "Could not load diamond history" });
  }
});

// Read diamond exchange settings
app.get(
  "/api/wallet/diamond-exchange-config",
  authMiddleware,
  async (req, res) => {
    if (!pool) {
      return res.status(500).json({ message: "Database is not configured" });
    }

    try {
      const result = await pool.query(
        `SELECT setting_value
         FROM wallet_settings
         WHERE setting_key = 'diamond_exchange'`
      );

      const config = result.rows[0]?.setting_value || {
        enabled: false,
        coins_per_diamond: 0,
        min_diamonds: 1,
        max_diamonds: 100000
      };

      return res.json({ config });
    } catch (error) {
      console.error("Exchange config error:", error);
      return res.status(500).json({
        message: "Could not load diamond exchange settings"
      });
    }
  }
);

// Exchange diamonds for coins (disabled until admin configures a valid rate)
app.post(
  "/api/wallet/diamond-exchange",
  authMiddleware,
  async (req, res) => {
    if (!pool) {
      return res.status(500).json({ message: "Database is not configured" });
    }

    const diamonds = Number(req.body.diamonds);

    if (!Number.isSafeInteger(diamonds) || diamonds <= 0) {
      return res.status(400).json({
        message: "Enter a valid whole number of diamonds"
      });
    }

    const client = await pool.connect();

    try {
      await client.query("BEGIN");

      const settingResult = await client.query(
        `SELECT setting_value
         FROM wallet_settings
         WHERE setting_key = 'diamond_exchange'
         FOR UPDATE`
      );

      const config = settingResult.rows[0]?.setting_value;

      if (
        !config ||
        config.enabled !== true ||
        !Number.isSafeInteger(config.coins_per_diamond) ||
        config.coins_per_diamond <= 0
      ) {
        await client.query("ROLLBACK");
        return res.status(503).json({
          message: "Diamond exchange is not enabled by the administrator"
        });
      }

      const min = Number(config.min_diamonds) || 1;
      const max = Number(config.max_diamonds) || 100000;

      if (diamonds < min || diamonds > max) {
        await client.query("ROLLBACK");
        return res.status(400).json({
          message: `Exchange must be between ${min} and ${max} diamonds`
        });
      }

      const coins = diamonds * config.coins_per_diamond;

      if (!Number.isSafeInteger(coins) || coins <= 0) {
        await client.query("ROLLBACK");
        return res.status(400).json({ message: "Invalid exchange amount" });
      }

      const userResult = await client.query(
        `UPDATE users
         SET diamonds = diamonds - $1,
             coins = coins + $2
         WHERE id = $3 AND diamonds >= $1
         RETURNING coins, diamonds`,
        [diamonds, coins, req.user.id]
      );

      if (!userResult.rows.length) {
        await client.query("ROLLBACK");
        return res.status(409).json({
          message: "Insufficient diamonds or user not found"
        });
      }

      await client.query(
        `INSERT INTO wallet_transactions
         (id, user_id, transaction_type, status,
          coins_delta, diamonds_delta, description)
         VALUES
         ($1, $2, 'diamond_exchange', 'success',
          $3, $4, $5)`,
        [
          uuidv4(),
          req.user.id,
          coins,
          -diamonds,
          `Exchanged ${diamonds} diamonds for ${coins} coins`
        ]
      );

      await client.query("COMMIT");

      return res.json({
        message: "Diamond exchange successful",
        exchanged_diamonds: diamonds,
        coins_received: coins,
        wallet: userResult.rows[0]
      });
    } catch (error) {
      try {
        await client.query("ROLLBACK");
      } catch (_) {}

      console.error("Diamond exchange error:", error);
      return res.status(500).json({ message: "Diamond exchange failed" });
    } finally {
      client.release();
    }
  }
);

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
