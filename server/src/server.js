require("dotenv").config();

const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { Pool } = require("pg");
const { v4: uuidv4 } = require("uuid");

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
      password_hash TEXT NOT NULL,
      avatar_url TEXT,
      coins INTEGER NOT NULL DEFAULT 0,
      level INTEGER NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS rooms (
      id UUID PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      password_hash TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
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

    const passwordHash = await bcrypt.hash(password, 10);
    const id = uuidv4();

    const result = await pool.query(
      `
      INSERT INTO users
      (id, username, password_hash)
      VALUES ($1, $2, $3)
      RETURNING id, username, avatar_url, coins, level, created_at
      `,
      [id, username, passwordHash]
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
    const result = await pool.query(
      `
      SELECT id, username, avatar_url, coins, level, created_at
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

    res.json({
      user: result.rows[0],
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not load profile",
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
        rooms.created_at,
        users.username AS owner_username
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
    const { name, password } = req.body;

    if (!name || name.trim().length < 2) {
      return res.status(400).json({
        message: "Room name is required",
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
      (id, name, owner_id, password_hash)
      VALUES ($1, $2, $3, $4)
      RETURNING id, name, owner_id, created_at
      `,
      [
        roomId,
        name.trim(),
        req.user.id,
        passwordHash,
      ]
    );

    res.status(201).json({
      room: result.rows[0],
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Could not create room",
    });
  }
});

// -------------------------
// Demo Coins
// -------------------------

app.post("/api/coins/demo", authMiddleware, async (req, res) => {
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
