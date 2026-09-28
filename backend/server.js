const express = require("express");
const cors = require("cors");
const { MongoClient, ObjectId } = require("mongodb");
const dotenv = require("dotenv");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8001;

app.use(cors());
app.use(express.json());

const MONGODB_URI = process.env.MONGODB_URI;
const JWT_SECRET = process.env.JWT_SECRET;

if (!MONGODB_URI) {
  console.error("ERROR: MONGODB_URI was not found in backend/.env");
  process.exit(1);
}

if (!JWT_SECRET) {
  console.error("ERROR: JWT_SECRET was not found in backend/.env");
  process.exit(1);
}

const client = new MongoClient(MONGODB_URI);

let db;
let usersCollection;
let goalsCollection;
let tasksCollection;

// =====================================================
// HELPERS
// =====================================================

function validObjectId(id) {
  return ObjectId.isValid(id);
}

function serializeGoal(goal) {
  return {
    id: goal._id.toString(),
    title: goal.title || "",
    description: goal.description || "",
    deadline: goal.deadline || "",
    created_at: goal.created_at || null
  };
}

function serializeTask(task) {
  return {
    id: task._id.toString(),
    title: task.title || "",
    goal_id: task.goal_id || "",
    deadline: task.deadline || "",
    priority: task.priority || "Medium",
    completed: task.completed === true,
    created_at: task.created_at || null
  };
}

function isOverdue(dateString) {
  if (!dateString) return false;

  const date = new Date(`${dateString}T23:59:59`);

  if (Number.isNaN(date.getTime())) {
    return false;
  }

  return date < new Date();
}

// =====================================================
// AUTHENTICATION MIDDLEWARE
// =====================================================

function authenticateToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({
        detail: "Authentication required."
      });
    }

    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        detail: "Invalid authorization format."
      });
    }

    const token = authHeader.substring(7);

    const decoded = jwt.verify(token, JWT_SECRET);

    req.user = {
      userId: decoded.userId,
      username: decoded.username
    };

    next();
  } catch (error) {
    return res.status(401).json({
      detail: "Invalid or expired token."
    });
  }
}

// =====================================================
// BASIC ROUTES
// =====================================================

app.get("/", (req, res) => {
  res.json({
    message: "Personal Productivity & Goal Management System API",
    status: "running"
  });
});

app.get("/hello", (req, res) => {
  res.json({
    message: "Hello from Node.js!"
  });
});

app.get("/database-test", async (req, res) => {
  try {
    await db.command({ ping: 1 });

    res.json({
      message: "MongoDB connection successful!"
    });
  } catch (error) {
    console.error("Database test error:", error);

    res.status(500).json({
      detail: "MongoDB connection failed."
    });
  }
});

// =====================================================
// REGISTER
// =====================================================

app.post("/auth/register", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        detail: "Username and password are required."
      });
    }

    const cleanUsername = username.toString().trim();

    if (cleanUsername.length < 3) {
      return res.status(400).json({
        detail: "Username must contain at least 3 characters."
      });
    }

    // Password must contain:
    // 1 uppercase letter
    // 1 number
    // 1 special character
    const passwordPattern =
      /^(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$/;

    if (!passwordPattern.test(password.toString())) {
      return res.status(400).json({
        detail:
          "Password must contain at least one uppercase letter, one number, and one special character."
      });
    }

    const normalizedUsername = cleanUsername.toLowerCase();

    const existingUser = await usersCollection.findOne({
      username_normalized: normalizedUsername
    });

    if (existingUser) {
      return res.status(409).json({
        detail: "Username already exists."
      });
    }

    const hashedPassword = await bcrypt.hash(password.toString(), 12);

    const newUser = {
      username: cleanUsername,
      username_normalized: normalizedUsername,
      password: hashedPassword,
      created_at: new Date()
    };

    const result = await usersCollection.insertOne(newUser);

    const token = jwt.sign(
      {
        userId: result.insertedId.toString(),
        username: cleanUsername
      },
      JWT_SECRET,
      {
        expiresIn: "7d"
      }
    );

    res.status(201).json({
      message: "Registration successful.",
      token: token,
      username: cleanUsername
    });
  } catch (error) {
    // Handles MongoDB unique-index race condition.
    if (error.code === 11000) {
      return res.status(409).json({
        detail: "Username already exists."
      });
    }

    console.error("POST /auth/register error:", error);

    res.status(500).json({
      detail: "Failed to register user."
    });
  }
});

// =====================================================
// LOGIN
// =====================================================

app.post("/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        detail: "Username and password are required."
      });
    }

    const normalizedUsername =
      username.toString().trim().toLowerCase();

    const user = await usersCollection.findOne({
      username_normalized: normalizedUsername
    });

    if (!user) {
      return res.status(401).json({
        detail: "Invalid username or password."
      });
    }

    const passwordMatches = await bcrypt.compare(
      password.toString(),
      user.password
    );

    if (!passwordMatches) {
      return res.status(401).json({
        detail: "Invalid username or password."
      });
    }

    const token = jwt.sign(
      {
        userId: user._id.toString(),
        username: user.username
      },
      JWT_SECRET,
      {
        expiresIn: "7d"
      }
    );

    res.json({
      message: "Login successful.",
      token: token,
      username: user.username
    });
  } catch (error) {
    console.error("POST /auth/login error:", error);

    res.status(500).json({
      detail: "Failed to login."
    });
  }
});

// =====================================================
// CURRENT USER
// =====================================================

app.get("/auth/me", authenticateToken, async (req, res) => {
  try {
    const user = await usersCollection.findOne({
      _id: new ObjectId(req.user.userId)
    });

    if (!user) {
      return res.status(404).json({
        detail: "User not found."
      });
    }

    res.json({
      id: user._id.toString(),
      username: user.username
    });
  } catch (error) {
    console.error("GET /auth/me error:", error);

    res.status(500).json({
      detail: "Failed to fetch user."
    });
  }
});

// =====================================================
// GOALS
// =====================================================

// CREATE GOAL
app.post("/goals", authenticateToken, async (req, res) => {
  try {
    const {
      title,
      description = "",
      deadline
    } = req.body;

    if (!title || !deadline) {
      return res.status(400).json({
        detail: "Title and deadline are required."
      });
    }

    const newGoal = {
      user_id: req.user.userId,
      title: title.toString().trim(),
      description: description.toString().trim(),
      deadline: deadline.toString(),
      created_at: new Date()
    };

    const result = await goalsCollection.insertOne(newGoal);

    const createdGoal = {
      _id: result.insertedId,
      ...newGoal
    };

    res.status(201).json(serializeGoal(createdGoal));
  } catch (error) {
    console.error("POST /goals error:", error);

    res.status(500).json({
      detail: "Failed to create goal."
    });
  }
});

// GET ALL USER GOALS
app.get("/goals", authenticateToken, async (req, res) => {
  try {
    const goals = await goalsCollection
      .find({
        user_id: req.user.userId
      })
      .sort({ created_at: -1 })
      .toArray();

    res.json(goals.map(serializeGoal));
  } catch (error) {
    console.error("GET /goals error:", error);

    res.status(500).json({
      detail: "Failed to fetch goals."
    });
  }
});

// GET ONE USER GOAL
app.get("/goals/:id", authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid goal ID."
      });
    }

    const goal = await goalsCollection.findOne({
      _id: new ObjectId(id),
      user_id: req.user.userId
    });

    if (!goal) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    res.json(serializeGoal(goal));
  } catch (error) {
    console.error("GET /goals/:id error:", error);

    res.status(500).json({
      detail: "Failed to fetch goal."
    });
  }
});

// UPDATE USER GOAL
app.put("/goals/:id", authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const {
      title,
      description = "",
      deadline
    } = req.body;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid goal ID."
      });
    }

    if (!title || !deadline) {
      return res.status(400).json({
        detail: "Title and deadline are required."
      });
    }

    const result = await goalsCollection.updateOne(
      {
        _id: new ObjectId(id),
        user_id: req.user.userId
      },
      {
        $set: {
          title: title.toString().trim(),
          description: description.toString().trim(),
          deadline: deadline.toString()
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    const updatedGoal = await goalsCollection.findOne({
      _id: new ObjectId(id),
      user_id: req.user.userId
    });

    res.json(serializeGoal(updatedGoal));
  } catch (error) {
    console.error("PUT /goals/:id error:", error);

    res.status(500).json({
      detail: "Failed to update goal."
    });
  }
});

// DELETE USER GOAL
app.delete("/goals/:id", authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid goal ID."
      });
    }

    const objectId = new ObjectId(id);

    const result = await goalsCollection.deleteOne({
      _id: objectId,
      user_id: req.user.userId
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    // Delete tasks belonging to this user's goal.
    await tasksCollection.deleteMany({
      goal_id: id,
      user_id: req.user.userId
    });

    res.json({
      message: "Goal deleted successfully."
    });
  } catch (error) {
    console.error("DELETE /goals/:id error:", error);

    res.status(500).json({
      detail: "Failed to delete goal."
    });
  }
});

// =====================================================
// TASKS
// =====================================================

// CREATE TASK
app.post("/tasks", authenticateToken, async (req, res) => {
  try {
    const {
      title,
      goal_id,
      deadline,
      priority = "Medium"
    } = req.body;

    if (!title || !goal_id || !deadline) {
      return res.status(400).json({
        detail: "Title, goal_id and deadline are required."
      });
    }

    if (!validObjectId(goal_id)) {
      return res.status(400).json({
        detail: "Invalid goal_id."
      });
    }

    // IMPORTANT:
    // The goal must belong to the logged-in user.
    const goalExists = await goalsCollection.findOne({
      _id: new ObjectId(goal_id),
      user_id: req.user.userId
    });

    if (!goalExists) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    const newTask = {
      user_id: req.user.userId,
      title: title.toString().trim(),
      goal_id: goal_id.toString(),
      deadline: deadline.toString(),
      priority: priority.toString(),
      completed: false,
      created_at: new Date()
    };

    const result = await tasksCollection.insertOne(newTask);

    const createdTask = {
      _id: result.insertedId,
      ...newTask
    };

    res.status(201).json(serializeTask(createdTask));
  } catch (error) {
    console.error("POST /tasks error:", error);

    res.status(500).json({
      detail: "Failed to create task."
    });
  }
});

// GET ALL USER TASKS
app.get("/tasks", authenticateToken, async (req, res) => {
  try {
    const tasks = await tasksCollection
      .find({
        user_id: req.user.userId
      })
      .sort({ created_at: -1 })
      .toArray();

    res.json(tasks.map(serializeTask));
  } catch (error) {
    console.error("GET /tasks error:", error);

    res.status(500).json({
      detail: "Failed to fetch tasks."
    });
  }
});

// GET ONE USER TASK
app.get("/tasks/:id", authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid task ID."
      });
    }

    const task = await tasksCollection.findOne({
      _id: new ObjectId(id),
      user_id: req.user.userId
    });

    if (!task) {
      return res.status(404).json({
        detail: "Task not found."
      });
    }

    res.json(serializeTask(task));
  } catch (error) {
    console.error("GET /tasks/:id error:", error);

    res.status(500).json({
      detail: "Failed to fetch task."
    });
  }
});

// UPDATE USER TASK
app.put("/tasks/:id", authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const {
      title,
      goal_id,
      deadline,
      priority = "Medium",
      completed = false
    } = req.body;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid task ID."
      });
    }

    if (!title || !goal_id || !deadline) {
      return res.status(400).json({
        detail: "Title, goal_id and deadline are required."
      });
    }

    if (!validObjectId(goal_id)) {
      return res.status(400).json({
        detail: "Invalid goal_id."
      });
    }

    // Make sure the goal belongs to the logged-in user.
    const goalExists = await goalsCollection.findOne({
      _id: new ObjectId(goal_id),
      user_id: req.user.userId
    });

    if (!goalExists) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    const result = await tasksCollection.updateOne(
      {
        _id: new ObjectId(id),
        user_id: req.user.userId
      },
      {
        $set: {
          title: title.toString().trim(),
          goal_id: goal_id.toString(),
          deadline: deadline.toString(),
          priority: priority.toString(),
          completed: completed === true
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({
        detail: "Task not found."
      });
    }

    const updatedTask = await tasksCollection.findOne({
      _id: new ObjectId(id),
      user_id: req.user.userId
    });

    res.json(serializeTask(updatedTask));
  } catch (error) {
    console.error("PUT /tasks/:id error:", error);

    res.status(500).json({
      detail: "Failed to update task."
    });
  }
});

// COMPLETE / UNCOMPLETE TASK
app.patch(
  "/tasks/:id/complete",
  authenticateToken,
  async (req, res) => {
    try {
      const { id } = req.params;

      if (!validObjectId(id)) {
        return res.status(400).json({
          detail: "Invalid task ID."
        });
      }

      const task = await tasksCollection.findOne({
        _id: new ObjectId(id),
        user_id: req.user.userId
      });

      if (!task) {
        return res.status(404).json({
          detail: "Task not found."
        });
      }

      const newCompletedStatus = !task.completed;

      await tasksCollection.updateOne(
        {
          _id: new ObjectId(id),
          user_id: req.user.userId
        },
        {
          $set: {
            completed: newCompletedStatus
          }
        }
      );

      const updatedTask = await tasksCollection.findOne({
        _id: new ObjectId(id),
        user_id: req.user.userId
      });

      res.json(serializeTask(updatedTask));
    } catch (error) {
      console.error(
        "PATCH /tasks/:id/complete error:",
        error
      );

      res.status(500).json({
        detail: "Failed to update task status."
      });
    }
  }
);

// DELETE USER TASK
app.delete("/tasks/:id", authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid task ID."
      });
    }

    const result = await tasksCollection.deleteOne({
      _id: new ObjectId(id),
      user_id: req.user.userId
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({
        detail: "Task not found."
      });
    }

    res.json({
      message: "Task deleted successfully."
    });
  } catch (error) {
    console.error("DELETE /tasks/:id error:", error);

    res.status(500).json({
      detail: "Failed to delete task."
    });
  }
});

// =====================================================
// STATISTICS
// =====================================================

app.get("/stats", authenticateToken, async (req, res) => {
  try {
    const goals = await goalsCollection
      .find({
        user_id: req.user.userId
      })
      .toArray();

    const tasks = await tasksCollection
      .find({
        user_id: req.user.userId
      })
      .toArray();

    const totalGoals = goals.length;
    const totalTasks = tasks.length;

    const completedTasks = tasks.filter(
      (task) => task.completed === true
    ).length;

    const pendingTasks = totalTasks - completedTasks;

    const overdueGoals = goals.filter(
      (goal) => isOverdue(goal.deadline)
    ).length;

    const overdueTasks = tasks.filter(
      (task) =>
        !task.completed &&
        isOverdue(task.deadline)
    ).length;

    const completionRate =
      totalTasks === 0
        ? 0
        : Math.round(
            (completedTasks / totalTasks) * 100
          );

    res.json({
      total_goals: totalGoals,
      total_tasks: totalTasks,
      completed_tasks: completedTasks,
      pending_tasks: pendingTasks,
      overdue_goals: overdueGoals,
      overdue_tasks: overdueTasks,
      completion_rate: completionRate
    });
  } catch (error) {
    console.error("GET /stats error:", error);

    res.status(500).json({
      detail: "Failed to calculate statistics."
    });
  }
});

// =====================================================
// START SERVER
// =====================================================

async function startServer() {
  try {
    await client.connect();

    db = client.db("productivity_db");

    usersCollection = db.collection("users");
    goalsCollection = db.collection("goals");
    tasksCollection = db.collection("tasks");

    // Prevent duplicate usernames.
    await usersCollection.createIndex(
      { username_normalized: 1 },
      { unique: true }
    );

    await db.command({ ping: 1 });

    console.log("MongoDB connected successfully.");
    console.log("Database: productivity_db");

    app.listen(PORT, "0.0.0.0", () => {
      console.log(
        `Node.js server running at http://127.0.0.1:${PORT}`
      );
    });
  } catch (error) {
    console.error("Failed to connect to MongoDB:");
    console.error(error);
    process.exit(1);
  }
}

startServer();