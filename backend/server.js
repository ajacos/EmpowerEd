const WebSocket = require("ws")
const http = require("http")
const url = require("url")

const server = http.createServer()
const wss = new WebSocket.Server({ server })

const rooms = new Map()

wss.on("connection", (ws, req) => {
  const parameters = url.parse(req.url, true)
  ws.userId = parameters.query.userId
  console.log(`User ${ws.userId} connected`)

  ws.on("message", (message) => {
    const data = JSON.parse(message)
    console.log("Received message:", data)

    switch (data.type) {
      case "create-room":
        handleCreateRoom(ws, data)
        break
      case "join-room":
        handleJoinRoom(ws, data)
        break
      case "leave-room":
        handleLeaveRoom(ws, data)
        break
      case "offer":
      case "answer":
      case "ice-candidate":
        forwardMessage(ws, data)
        break
    }
  })

  ws.on("close", () => {
    console.log(`User ${ws.userId} disconnected`)
    handleLeaveRoom(ws, { userId: ws.userId })
  })
})

function handleCreateRoom(ws, data) {
  const { roomId, password } = data
  console.log(`User ${ws.userId} creating room ${roomId}`)

  if (rooms.has(roomId)) {
    sendTo(ws, { type: "error", message: "Room already exists" })
    return
  }

  rooms.set(roomId, {
    password,
    users: new Map().set(ws.userId, ws),
  })

  ws.roomId = roomId
  sendTo(ws, { type: "room-created", roomId })
}

function handleJoinRoom(ws, data) {
  const { roomId, password } = data
  console.log(`User ${ws.userId} joining room ${roomId}`)

  if (!rooms.has(roomId)) {
    sendTo(ws, { type: "error", message: "Room not found" })
    return
  }

  const room = rooms.get(roomId)

  if (room.password !== password) {
    sendTo(ws, { type: "error", message: "Invalid password" })
    return
  }

  if (room.users.size >= 3) {
    sendTo(ws, { type: "error", message: "Room is full" })
    return
  }

  room.users.set(ws.userId, ws)
  ws.roomId = roomId

  // Notify existing users about the new user
  room.users.forEach((user, userId) => {
    if (userId !== ws.userId) {
      sendTo(user, { type: "user-joined", userId: ws.userId })
    }
  })

  sendTo(ws, { type: "room-joined", roomId })
}

function handleLeaveRoom(ws, data) {
  if (!ws.roomId) return

  const room = rooms.get(ws.roomId)
  if (room) {
    room.users.delete(ws.userId)

    // Notify other users
    room.users.forEach((user) => {
      sendTo(user, { type: "user-left", userId: ws.userId })
    })

    if (room.users.size === 0) {
      rooms.delete(ws.roomId)
    }
  }

  delete ws.roomId
}

function forwardMessage(ws, data) {
  if (!ws.roomId) return

  const room = rooms.get(ws.roomId)
  if (room && data.targetUserId) {
    const targetUser = room.users.get(data.targetUserId)
    if (targetUser) {
      console.log(`Forwarding ${data.type} from ${ws.userId} to ${data.targetUserId}`)
      sendTo(targetUser, data)
    }
  }
}

function sendTo(ws, message) {
  ws.send(JSON.stringify(message))
}

const PORT = process.env.PORT || 8080
server.listen(PORT, () => {
  console.log(`Signaling server running on port ${PORT}`)
})

