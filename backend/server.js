const express = require("express");
const cors = require("cors");
const { MongoClient, ObjectId } = require("mongodb");
const dotenv = require("dotenv");

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8001;

app.use(cors());
app.use(express.json());

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  console.error("ERROR: MONGODB_URI was not found in backend/.env");
  process.exit(1);
}

const client = new MongoClient(MONGODB_URI);

let db;
let goalsCollection;
let tasksCollection;

// -------------------------
// Helpers
// -------------------------

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

// -------------------------
// Basic routes
// -------------------------

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

// -------------------------
// GOALS
// -------------------------

app.post("/goals", async (req, res) => {
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

app.get("/goals", async (req, res) => {
  try {
    const goals = await goalsCollection
      .find({})
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

app.get("/goals/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid goal ID."
      });
    }

    const goal = await goalsCollection.findOne({
      _id: new ObjectId(id)
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

app.put("/goals/:id", async (req, res) => {
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
      { _id: new ObjectId(id) },
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
      _id: new ObjectId(id)
    });

    res.json(serializeGoal(updatedGoal));
  } catch (error) {
    console.error("PUT /goals/:id error:", error);

    res.status(500).json({
      detail: "Failed to update goal."
    });
  }
});

app.delete("/goals/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid goal ID."
      });
    }

    const objectId = new ObjectId(id);

    const result = await goalsCollection.deleteOne({
      _id: objectId
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    // Delete tasks belonging to this goal.
    await tasksCollection.deleteMany({
      goal_id: id
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

// -------------------------
// TASKS
// -------------------------

app.post("/tasks", async (req, res) => {
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

    const goalExists = await goalsCollection.findOne({
      _id: new ObjectId(goal_id)
    });

    if (!goalExists) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    const newTask = {
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

app.get("/tasks", async (req, res) => {
  try {
    const tasks = await tasksCollection
      .find({})
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

app.get("/tasks/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid task ID."
      });
    }

    const task = await tasksCollection.findOne({
      _id: new ObjectId(id)
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

app.put("/tasks/:id", async (req, res) => {
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

    const goalExists = await goalsCollection.findOne({
      _id: new ObjectId(goal_id)
    });

    if (!goalExists) {
      return res.status(404).json({
        detail: "Goal not found."
      });
    }

    const result = await tasksCollection.updateOne(
      { _id: new ObjectId(id) },
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
      _id: new ObjectId(id)
    });

    res.json(serializeTask(updatedTask));
  } catch (error) {
    console.error("PUT /tasks/:id error:", error);

    res.status(500).json({
      detail: "Failed to update task."
    });
  }
});

app.patch("/tasks/:id/complete", async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid task ID."
      });
    }

    const task = await tasksCollection.findOne({
      _id: new ObjectId(id)
    });

    if (!task) {
      return res.status(404).json({
        detail: "Task not found."
      });
    }

    const newCompletedStatus = !task.completed;

    await tasksCollection.updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          completed: newCompletedStatus
        }
      }
    );

    const updatedTask = await tasksCollection.findOne({
      _id: new ObjectId(id)
    });

    res.json(serializeTask(updatedTask));
  } catch (error) {
    console.error("PATCH /tasks/:id/complete error:", error);

    res.status(500).json({
      detail: "Failed to update task status."
    });
  }
});

app.delete("/tasks/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!validObjectId(id)) {
      return res.status(400).json({
        detail: "Invalid task ID."
      });
    }

    const result = await tasksCollection.deleteOne({
      _id: new ObjectId(id)
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

// -------------------------
// STATISTICS
// -------------------------

app.get("/stats", async (req, res) => {
  try {
    const goals = await goalsCollection.find({}).toArray();
    const tasks = await tasksCollection.find({}).toArray();

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
      (task) => !task.completed && isOverdue(task.deadline)
    ).length;

    const completionRate =
      totalTasks === 0
        ? 0
        : Math.round((completedTasks / totalTasks) * 100);

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

// -------------------------
// Start server
// -------------------------

async function startServer() {
  try {
    await client.connect();

    db = client.db("productivity_db");

    goalsCollection = db.collection("goals");
    tasksCollection = db.collection("tasks");

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